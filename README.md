# GoBran

GoBran adalah super-app lokal Kecamatan Babalan. Satu codebase Flutter menangani pelanggan, driver, UMKM, penyedia jasa, dan admin berdasarkan role akun.

## Fitur

- Registrasi/login email dan password untuk pelanggan, driver, UMKM, dan jasa.
- Verifikasi mitra oleh admin.
- Ojek dan Express dengan OpenStreetMap, Nominatim, rute OSRM, tarif otomatis, dan Google Maps deep link.
- Broadcast order ke seluruh driver aktif dalam zona; transaksi Firestore mengunci driver pertama.
- Makanan, keranjang, checkout, produk UMKM, dan status persiapan.
- Listing serta permintaan jasa.
- Berita, promosi dengan filter, history, kontak masuk, dan direktori darurat.
- Dashboard driver, UMKM, jasa, dan admin.
- Pembayaran tunai serta QRIS manual.
- Firebase Auth, Firestore, Storage, Messaging, Rules, Indexes, dan Cloud Functions.

## Persiapan pertama (Windows/VS Code)

1. Ekstrak proyek, lalu buka terminal pada folder `gobran`.
2. Buat platform bawaan Flutter:

   ```bash
   flutter create --platforms=android,web --org id.gobran .
   ```

3. Ambil dependency:

   ```bash
   flutter pub get
   ```

4. Buat proyek Firebase, aktifkan Email/Password, Firestore, Storage, dan Cloud Messaging.
5. Hubungkan proyek:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   Perintah tersebut harus mengganti `lib/firebase_options.dart` placeholder dengan konfigurasi asli.

6. Deploy rules dan indexes:

   ```bash
   firebase login
   firebase use --add
   firebase deploy --only firestore:rules,firestore:indexes,storage
   ```

7. Untuk push notification otomatis, aktifkan paket Blaze lalu:

   ```bash
   cd functions
   npm install
   cd ..
   firebase deploy --only functions
   ```

8. Jalankan aplikasi:

   ```bash
   flutter run
   ```

## Membuat admin pertama

Daftarkan akun biasa, lalu di Firebase Console buka `users/{uid}` dan ubah field `role` menjadi `admin`. Langkah ini hanya untuk bootstrap awal. Setelah ada admin, verifikasi mitra dan konten dapat dikelola dari dashboard admin.

## Aturan tarif

- Jarak sampai 2 km: Rp10.000.
- Di atas 2 km: Rp10.000 + Rp5.000 untuk setiap kilometer tambahan, dibulatkan ke atas.
- Contoh 3,2 km: Rp20.000.
- Nilai tersimpan di `app_config/pricing` dan dapat diubah admin.

## Catatan produksi

Server publik Nominatim dan OSRM cocok untuk pengembangan/demo. Sebelum trafik produksi, gunakan instance sendiri atau penyedia dengan SLA dan patuhi kebijakan penggunaan OpenStreetMap. Ganti nama package Android jika diperlukan sebelum publikasi Play Store.

