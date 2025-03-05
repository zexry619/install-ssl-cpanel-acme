# Script Otomatisasi SSL dengan acme.sh dan cPanel

Script ini digunakan untuk secara otomatis:
- Memastikan instalasi **acme.sh** (dan menginstall jika belum ada)
- Mendaftarkan akun **acme.sh** menggunakan email `admin@<domain>` dengan server ZeroSSL
- Mengambil *document root* domain menggunakan perintah **uapi** dan **jq**
- Menghapus sertifikat SSL lama (jika ada)
- Mengeluarkan sertifikat SSL baru menggunakan metode *webroot*
- Melakukan deploy sertifikat SSL ke cPanel melalui deploy hook `cpanel_uapi`

## Prasyarat

Pastikan server telah terpasang:
- **Bash**
- **curl** (untuk mengunduh dan menginstall acme.sh jika belum ada)
- **uapi** (untuk mengambil informasi domain dan mengelola SSL pada cPanel)
- **jq** (untuk memproses data JSON dari uapi)

Selain itu, pastikan user memiliki akses yang tepat untuk menjalankan perintah-perintah terkait cPanel dan uapi.

## Cara Penggunaan

1. **Clone Repository**  
   Clone repository ini ke server atau lingkungan lokal:
   ```bash
   git clone https://github.com/username/nama-repo.git
   cd nama-repo
   ```

2. **Memberikan Hak Eksekusi**  
   Berikan hak eksekusi pada script:
   ```bash
   chmod +x nama_script.sh
   ```

3. **Menjalankan Script**  
   Jalankan script dengan memberikan nama domain sebagai argumen.  
   Contoh:
   ```bash
   ./nama_script.sh namadomain.com
   ```

   Script akan:
   - Mengecek apakah acme.sh telah terinstall dan menginstallnya jika belum.
   - Mendaftarkan akun acme.sh (jika belum terdaftar) menggunakan email `admin@namadomain.com`.
   - Mengambil document root dari domain menggunakan uapi dan jq.
   - Menghapus SSL lama (jika ada) dan mengeluarkan sertifikat SSL baru.
   - Melakukan deploy sertifikat ke cPanel menggunakan deploy hook `cpanel_uapi`.

## Penjelasan Langkah demi Langkah

1. **Pengecekan Argumen**  
   Script mengecek apakah nama domain telah diberikan sebagai argumen. Jika tidak, maka akan menampilkan pesan penggunaan dan keluar.

2. **Cek dan Instalasi acme.sh**  
   Script mencari file `acme.sh` pada direktori `$HOME/.acme.sh/`. Jika tidak ditemukan, maka script akan mengunduh dan menginstall acme.sh menggunakan `curl`.

3. **Pendaftaran Akun acme.sh**  
   Menggunakan output dari perintah `acme.sh --list`, script mengecek apakah akun telah terdaftar. Jika belum, maka script akan mendaftarkan akun menggunakan email `admin@<domain>` dan server `zerossl`.

4. **Mengambil Document Root**  
   Script menggunakan perintah `uapi` yang menghasilkan output JSON dan diproses dengan **jq** untuk mendapatkan path document root yang sesuai dengan domain.

5. **Penghapusan Sertifikat SSL Lama**  
   Jika ada sertifikat SSL yang sudah terinstall, script akan menghapusnya dengan perintah `uapi SSL delete_ssl`.

6. **Penerbitan Sertifikat SSL Baru**  
   Mengeluarkan sertifikat SSL menggunakan metode `webroot` berdasarkan document root yang telah didapatkan.

7. **Deploy ke cPanel**  
   Setelah sertifikat berhasil diterbitkan, script melakukan deploy sertifikat ke cPanel menggunakan deploy hook `cpanel_uapi`.

## Catatan

- Pastikan perintah `uapi` dan `jq` tersedia dan dikonfigurasi dengan benar di server.
- Script ini menggunakan server **ZeroSSL** untuk pendaftaran akun SSL. Jika ingin menggunakan server lain, sesuaikan parameter pada bagian pendaftaran akun.
- Sebelum menjalankan script di lingkungan produksi, disarankan untuk melakukan testing terlebih dahulu di lingkungan staging.

---

Semoga README ini dapat membantu kamu dalam menggunakan dan memahami script otomatisasi SSL ini!