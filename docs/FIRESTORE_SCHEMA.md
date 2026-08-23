# Skema Firestore GoBran

| Koleksi | Kegunaan utama |
|---|---|
| `users` | Profil dasar, role, zona, status verifikasi, FCM token |
| `drivers` | Kendaraan, status aktif, lokasi real-time, dokumen |
| `merchants` | Profil UMKM, alamat, status toko |
| `service_partners` | Profil mitra jasa dan ketersediaan |
| `products` | Produk, harga, stok, foto, pemilik UMKM |
| `service_listings` | Layanan jasa, deskripsi, estimasi harga |
| `orders` | Semua transaksi Ojek, Express, Makanan, dan Jasa |
| `content` | Berita dan promosi |
| `inbox` | Kontak Masuk/notifikasi pelanggan |
| `emergency_contacts` | Direktori sakit, kebakaran, kecelakaan |
| `zones` | Zona broadcast driver |
| `app_config/pricing` | Tarif serta gambar QRIS manual |

Status perjalanan utama: `searching → accepted → heading_to_pickup → picked_up → on_delivery → completed`.

