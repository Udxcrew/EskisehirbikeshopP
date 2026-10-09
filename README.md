# Eskişehir Bike Shop

GitHub Pages üzerinde yayınlanabilen, Supabase altyapılı bisiklet ilan pazarı başlangıç projesi.

## Özellikler
- E-posta ve şifreyle üyelik / giriş
- Profil ve kullanıcı adı
- İlan oluşturma, fotoğraf yükleme, kalıcı kayıt
- İlan onayı bekleme akışı
- Kategori, arama ve fiyat sıralaması
- Favoriler
- Satıcı Instagram / WhatsApp bağlantıları
- Yönetici onay / reddet / satıldı akışı
- Mobil uyumlu koyu tasarım

## 1. Supabase projesi oluştur
1. https://supabase.com adresinde ücretsiz hesap aç.
2. Yeni bir proje oluştur ve veritabanı şifreni güvenli bir yerde sakla.
3. Proje hazır olduğunda Project URL ve anon/public key bilgilerini Project Settings → API bölümünden al.
4. Supabase Dashboard → SQL Editor → New query bölümünü aç.
5. `supabase-schema.sql` içeriğini yapıştırıp çalıştır.

## 2. Uygulamayı Supabase'e bağla
`app.js` dosyasının en üstündeki şu iki değeri değiştir:
```js
const SUPABASE_URL = "PASTE_YOUR_SUPABASE_PROJECT_URL_HERE";
const SUPABASE_ANON_KEY = "PASTE_YOUR_SUPABASE_ANON_KEY_HERE";
```
Project URL ve anon/public key'i koy. **service_role / secret key'i asla buraya koyma.** Anon key'in güvenliği RLS politikalarına bağlıdır; SQL kurulumunu atlama.

## 3. E-posta doğrulaması
Supabase Dashboard → Authentication → URL Configuration:
- Site URL: GitHub Pages adresin, ör. `https://KULLANICIADI.github.io/REPO-ADI/`
- Redirect URLs listesine aynı adresi ekle.
E-posta doğrulamasını açık tutmanı öneririz. Supabase'in varsayılan e-posta gönderim limiti düşük olabilir; topluluğu büyütürken SMTP ayarı gerekebilir.

## 4. GitHub'a yükle ve yayınla
1. GitHub'da yeni bir repository aç. Örn. `eskisehir-bike-shop`.
2. Bu klasördeki dosyaları repo'nun kök dizinine yükle: `index.html`, `style.css`, `app.js`, `supabase-schema.sql`, `README.md`.
3. GitHub repo → Settings → Pages.
4. Build and deployment altında **Deploy from a branch** seç.
5. Branch olarak `main`, folder olarak `/(root)` seç ve Save'e bas.
6. Birkaç dakika sonra `https://KULLANICIADI.github.io/eskisehir-bike-shop/` adresini aç.

Alternatif: GitHub web arayüzünde Add file → Upload files ile dosyaları yükleyebilirsin. `assets` klasörü şu an zorunlu değil.

## 5. Kendini yönetici yap
1. Siteden normal bir hesap oluştur ve e-postanı doğrula.
2. Supabase → Authentication → Users bölümünde kullanıcı kaydını açıp UUID'sini kopyala.
3. Supabase → SQL Editor'da şu sorguyu kendi UUID'n ile çalıştır:
```sql
update public.profiles
set role = 'admin'
where id = 'BURAYA-KENDI-UUID';
```
4. Siteden çıkış yapıp tekrar giriş yap. Profil ekranında Yönetici paneli görünür.
**Kullanıcıya yönetici rolü verme işlemini asla herkese açık istemci koduna ekleme.**

## Nasıl çalışıyor?
- Yeni ilanlar `pending` durumuyla kaydedilir ve herkese görünmez.
- Yönetici ilanı `approved` yapınca ana sayfada görünür.
- Fotoğraflar Supabase Storage içindeki `listing-images` bucket'ına yüklenir.
- Profil, ilan ve favoriler Supabase veritabanında saklanır.
- GitHub Pages yalnızca frontend dosyalarını barındırır; üyelik ve kalıcı veri Supabase tarafından sağlanır.

## Önemli güvenlik notları
- Gerçek ödeme sistemi bu projede yok; alıcı ve satıcı kendi aralarında anlaşır.
- İlanı ve satıcıyı kontrol etmeden ön ödeme yapma.
- Supabase `service_role` anahtarını asla tarayıcı koduna veya GitHub'a koyma.
- Canlıya geçmeden önce RLS politikalarını kendi test hesaplarınla dene.
- İlk sürümde kullanıcı adı benzersizliği ve e-posta doğrulaması kullanılır; profil düzenleme, sohbet ve şikâyet sistemi sonraki geliştirmelerdir.
