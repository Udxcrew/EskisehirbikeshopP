# Eskişehir Bike Shop — Ödeme ve Kargo Uygulama Planı

## Bu sürümde bulunanlar
- `orders-and-shipping.sql`: sipariş kayıtları, ödeme olayları için tablo, katılımcı RLS ve satıcı kargo bilgisi RPC fonksiyonu.
- Ödeme durumu tarayıcıdan değiştirilemez; sipariş oluşturma ve ödeme doğrulama yalnızca güvenilir sunucu işlevi üzerinden yapılmalıdır.
- Kargo firması ve takip numarası, yalnızca `paid` durumundaki sipariş için satıcı tarafından güncellenebilir.

## Henüz etkin olmayanlar
- iyzico API çağrısı / Checkout Form oluşturma
- iyzico callback veya webhook imzası doğrulaması
- Satıcı (alt üye) onboarding akışı
- Sipariş oluşturma arayüzü ve canlı checkout

Bunlar bilerek sahte bir ödeme akışı gibi gösterilmedi. Gerçek sağlayıcı hesabı ve sunucu sırları olmadan ödeme alınamaz.

## Canlıya geçiş kontrol listesi
1. Ticari kullanıma uygun ön yüz hostingi seç; GitHub repo'yu kod deposu olarak tut.
2. Supabase Auth redirect URL'lerini canlı alan adına göre ayarla.
3. `supabase-schema.sql`, ardından `orders-and-shipping.sql` çalıştır.
4. iyzico Marketplace işyeri hesabı / sözleşme ve alt üye gereksinimlerini sağlayıcıyla netleştir.
5. Edge Function secret'ları olarak `IYZICO_API_KEY`, `IYZICO_SECRET_KEY`, `IYZICO_BASE_URL`, `APP_BASE_URL` ekle. Bu değerleri `app.js`, HTML veya GitHub'a koyma.
6. Checkout başlatma işlevi, oturum JWT'sini doğrulamalı; ilan fiyatını veritabanından yeniden okumalı; sipariş toplamını ve komisyonu sunucuda hesaplamalı; ödeme sağlayıcısında siparişle ilişkilendirilebilir benzersiz kimlik üretmeli.
7. Callback/webhook işlevi sağlayıcının resmî imza doğrulamasını kullanmalı; yalnızca doğrulanmış başarılı sonuçtan sonra `payment_status='paid'` ve `order_status='processing'` yapmalı. Aynı bildirimin tekrar gelmesi ikinci tahsilat/işlem üretmemeli.
8. Satıcı onboarding, iptal/iade, uyuşmazlık, teslimat, KVKK aydınlatma, mesafeli satış/ön bilgilendirme ve tüketici hakları süreçlerini canlıdan önce tamamla. Hukuki gereklilikleri profesyonelle doğrula.
9. Sandbox testleri: başarılı ödeme, reddedilen ödeme, kullanıcı ödeme sayfasını kapatır, yanlış/tekrarlı callback, başka kullanıcının siparişine erişim, satıcının ödenmemiş siparişe takip girmesi.

## Önemli
Bu depo gerçek ödeme almaya hazır **tamamlanmış bir ödeme entegrasyonu değildir**; güvenli veritabanı temelini ve uygulama planını içerir. Sağlayıcı entegrasyonu test edilip onaylanana kadar sitede kartla ödeme seçeneğini etkinleştirme.
