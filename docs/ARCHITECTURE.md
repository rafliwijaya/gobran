# Arsitektur GoBran

## Peran

- `customer`: beranda, Ojek, Express, Makanan, Jasa, Darurat, Berita, Promosi, History, dan Kontak Masuk.
- `driver`: status aktif, broadcast order berdasarkan zona, penerimaan atomik, navigasi, status perjalanan, history, dan pendapatan.
- `umkm`: buka/tutup toko, CRUD produk, konfirmasi serta persiapan pesanan.
- `service`: tersedia/tidak tersedia, CRUD listing, dan konfirmasi permintaan jasa.
- `admin`: verifikasi mitra, konten, kontak darurat, zona, tarif, serta QRIS.

## Alur order Ojek/Express

1. Pelanggan menentukan jemput dan tujuan di peta atau pencarian Nominatim.
2. OSRM mengembalikan rute, jarak, dan estimasi waktu jalan sebenarnya.
3. Aplikasi menghitung harga dan membuat dokumen `orders` berstatus `searching`.
4. Cloud Function mengirim FCM ke driver aktif dengan `zone_id` yang sama.
5. Semua driver zona melihat order. `runTransaction` memastikan hanya driver pertama yang dapat mengubahnya menjadi `accepted`.
6. Driver memperbarui status sampai `completed`; pelanggan menerima inbox dan push notification.

## Alur makanan

1. Pelanggan memilih produk dari satu UMKM per checkout.
2. UMKM menerima lalu mengubah status menjadi `preparing`.
3. Saat siap, UMKM mengubah status menjadi `searching`; order dibroadcast ke driver zona.
4. Driver pertama menerima, mengambil pesanan, mengantar, dan menyelesaikan order.

## Batas layanan gratis

Tile OpenStreetMap, Nominatim publik, dan server demo OSRM harus diganti atau di-self-host sebelum penggunaan produksi berskala besar.

