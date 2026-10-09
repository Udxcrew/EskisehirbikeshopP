-- Eskişehir Bike Shop: marketplace orders + manual shipping tracking
-- Run AFTER supabase-schema.sql in Supabase SQL Editor.
-- This migration deliberately does NOT enable client-side payment or order creation.
-- Orders/payments must be created/updated by a trusted server function after a verified provider callback.

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid references public.listings(id) on delete set null,
  listing_title text not null,
  buyer_id uuid not null references public.profiles(id) on delete restrict,
  seller_id uuid not null references public.profiles(id) on delete restrict,
  item_amount numeric(12,2) not null check (item_amount > 0),
  shipping_amount numeric(12,2) not null default 0 check (shipping_amount >= 0),
  platform_commission numeric(12,2) not null default 0 check (platform_commission >= 0),
  total_amount numeric(12,2) not null check (total_amount > 0),
  currency text not null default 'TRY' check (currency = 'TRY'),
  payment_status text not null default 'pending' check (payment_status in ('pending','paid','failed','refunded','cancelled')),
  order_status text not null default 'awaiting_payment' check (order_status in ('awaiting_payment','processing','shipped','delivered','cancelled','disputed')),
  shipping_name text not null,
  shipping_phone text not null,
  shipping_address text not null,
  shipping_district text not null,
  shipping_city text not null default 'Eskişehir',
  shipping_carrier text,
  tracking_number text,
  shipped_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint orders_buyer_not_seller check (buyer_id <> seller_id),
  constraint orders_total_matches check (total_amount = item_amount + shipping_amount)
);

create table if not exists public.payment_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  provider text not null default 'iyzico',
  provider_payment_id text,
  provider_conversation_id text,
  event_type text not null,
  verified boolean not null default false,
  payload_summary jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists orders_buyer_created_idx on public.orders(buyer_id, created_at desc);
create index if not exists orders_seller_created_idx on public.orders(seller_id, created_at desc);
create index if not exists orders_status_idx on public.orders(payment_status, order_status);
create index if not exists payment_events_order_idx on public.payment_events(order_id, created_at desc);

alter table public.orders enable row level security;
alter table public.payment_events enable row level security;

-- Customers and sellers can read their own orders; admins can audit all orders.
drop policy if exists "participants can view orders" on public.orders;
create policy "participants can view orders" on public.orders
  for select to authenticated
  using (buyer_id = (select auth.uid()) or seller_id = (select auth.uid()) or public.is_admin());

-- No direct INSERT/UPDATE/DELETE policies for orders or payment_events.
-- Trusted Edge Functions using the service role must create orders and record verified payment callbacks.
-- Never expose the service role key to app.js or any browser code.

create or replace function public.seller_set_tracking(
  p_order_id uuid,
  p_carrier text,
  p_tracking_number text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Giriş yapmalısın.';
  end if;
  if length(trim(coalesce(p_carrier, ''))) < 2 or length(trim(coalesce(p_carrier, ''))) > 80 then
    raise exception 'Geçerli bir kargo firması gir.';
  end if;
  if length(trim(coalesce(p_tracking_number, ''))) < 3 or length(trim(coalesce(p_tracking_number, ''))) > 120 then
    raise exception 'Geçerli bir takip numarası gir.';
  end if;

  update public.orders
     set shipping_carrier = trim(p_carrier),
         tracking_number = trim(p_tracking_number),
         order_status = 'shipped',
         shipped_at = coalesce(shipped_at, now()),
         updated_at = now()
   where id = p_order_id
     and seller_id = auth.uid()
     and payment_status = 'paid'
     and order_status in ('processing','shipped');

  if not found then
    raise exception 'Sipariş bulunamadı, ödeme onaylanmadı veya kargo bilgisi güncellenemiyor.';
  end if;
end;
$$;

revoke all on function public.seller_set_tracking(uuid,text,text) from public;
grant execute on function public.seller_set_tracking(uuid,text,text) to authenticated;

-- Payment events are intentionally not readable from the browser. Service role only.
