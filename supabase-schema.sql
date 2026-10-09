-- Eskişehir Bike Shop: Supabase SQL setup
-- Supabase Dashboard > SQL Editor > New query > paste and Run.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (char_length(username) between 3 and 24),
  district text default 'Eskişehir',
  role text not null default 'user' check (role in ('user','admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 5 and 90),
  category text not null,
  price numeric(12,2) not null check (price >= 0),
  condition text not null default 'İkinci el',
  district text default 'Eskişehir',
  description text not null check (char_length(description) between 1 and 2000),
  image_url text,
  instagram text,
  whatsapp text,
  status text not null default 'pending' check (status in ('pending','approved','rejected','sold')),
  created_at timestamptz not null default now()
);

create table if not exists public.favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

create index if not exists listings_status_created_idx on public.listings(status, created_at desc);
create index if not exists listings_user_idx on public.listings(user_id);
create index if not exists favorites_user_idx on public.favorites(user_id);

alter table public.profiles enable row level security;
alter table public.listings enable row level security;
alter table public.favorites enable row level security;

-- Profile rows are created automatically after signup.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare uname text;
begin
  uname := coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1));
  insert into public.profiles (id, username)
  values (new.id, left(uname, 24))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Admin checks use the profile role; users cannot update their own role.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists(select 1 from public.profiles where id = (select auth.uid()) and role = 'admin');
$$;

drop policy if exists "profiles are visible to everyone" on public.profiles;
create policy "profiles are visible to everyone" on public.profiles for select using (true);
drop policy if exists "users can update own profile" on public.profiles;
create policy "users can update own profile" on public.profiles for update using (id = (select auth.uid())) with check (id = (select auth.uid()) and (role = 'user' or public.is_admin()));
-- No client insert policy: profile rows are created by the auth trigger.

drop policy if exists "approved listings are public and owners see own" on public.listings;
create policy "approved listings are public and owners see own" on public.listings for select using (status = 'approved' or user_id = (select auth.uid()) or public.is_admin());
drop policy if exists "authenticated users can submit listings" on public.listings;
create policy "authenticated users can submit listings" on public.listings for insert to authenticated with check (user_id = (select auth.uid()) and status = 'pending');
drop policy if exists "owners can update their listings" on public.listings;
create policy "owners can update their listings" on public.listings for update to authenticated using (user_id = (select auth.uid()) or public.is_admin()) with check ((user_id = (select auth.uid()) and status in ('pending','sold')) or public.is_admin());
drop policy if exists "owners and admins can delete listings" on public.listings;
create policy "owners and admins can delete listings" on public.listings for delete to authenticated using (user_id = (select auth.uid()) or public.is_admin());

drop policy if exists "users can see own favorites" on public.favorites;
create policy "users can see own favorites" on public.favorites for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "users can add own favorites" on public.favorites;
create policy "users can add own favorites" on public.favorites for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "users can remove own favorites" on public.favorites;
create policy "users can remove own favorites" on public.favorites for delete to authenticated using (user_id = (select auth.uid()));

-- Public product photos. File paths must begin with the authenticated user's UUID.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('listing-images', 'listing-images', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "public can view listing photos" on storage.objects;
create policy "public can view listing photos" on storage.objects for select using (bucket_id = 'listing-images');
drop policy if exists "users upload photos to own folder" on storage.objects;
create policy "users upload photos to own folder" on storage.objects for insert to authenticated with check (bucket_id = 'listing-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "users can delete photos in own folder" on storage.objects;
create policy "users can delete photos in own folder" on storage.objects for delete to authenticated using (bucket_id = 'listing-images' and ((storage.foldername(name))[1] = (select auth.uid())::text or public.is_admin()));

-- IMPORTANT: After creating your account, set its role to admin manually in SQL Editor.
-- Replace YOUR-USER-UUID with the UUID from Authentication > Users.
-- update public.profiles set role = 'admin' where id = 'YOUR-USER-UUID';
