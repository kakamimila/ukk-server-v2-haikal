# UKK Server V2 - Muhammad Haikal Kamil

Paket ini berisi:
- `setup-server.sh`: script setup server asli dari bahan yang diberikan, dengan landing page identitas siswa yang sudah disesuaikan.
- `index.html`: salinan landing page jika ingin diedit atau dipasang manual.

## Identitas yang sudah diisi
- Nama: Muhammad Haikal Kamil
- Kelas: XII TJKT 1
- Sekolah: SMK Negeri 1 Banyumas
- Nomor absen: 23

## Penting sebelum deployment
1. Pastikan konfigurasi IP static dan internet server sudah berhasil sesuai README guru.
2. Sesuaikan nomor absen di `index.html` dan pada blok HTML yang tertanam di `setup-server.sh` jika sudah diketahui. Jika hanya mengubah `index.html` terpisah, perubahan itu akan tertimpa saat script dijalankan.
3. Script ini mempertahankan konfigurasi server dari file sumber yang diberikan. Periksa kembali script dan sesuaikan konfigurasi jaringan/SNMP dengan topologi praktik sebelum menjalankannya.
4. Jangan masukkan password, private key, token, atau data rahasia ke repository publik.

## Upload ke GitHub
Buat repository GitHub baru, set **Public** agar raw file bisa diunduh oleh server. Buat folder `sh` di repository, lalu unggah `setup-server.sh` ke folder `sh`. Opsional: unggah `index.html` dan README ini di folder yang sama.

Setelah file tampil di GitHub, buka `sh/setup-server.sh`, tekan **Raw**, dan pastikan URL berformat:
`https://raw.githubusercontent.com/kakamimila/ukk-server-v2-haikal/refs/heads/main/sh/setup-server.sh`

Ganti `USERNAME` dan `NAMA-REPO` dengan milik sendiri.

## Jalankan di Ubuntu Server
Jalankan setelah langkah konfigurasi IP, tes gateway, tes internet, dan penyesuaian repository sesuai instruksi guru:

```bash
wget https://raw.githubusercontent.com/kakamimila/ukk-server-v2-haikal/main/sh/setup-server.sh -O setup-server.sh
sudo chmod +x setup-server.sh
sudo ./setup-server.sh
```

Jika ingin mengubah halaman setelah setup selesai:

```bash
sudo nano /var/www/lab-smk.xyz/index.html
```

Simpan dengan Ctrl+O, Enter, Ctrl+X. Kemudian cek:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Catatan: halaman memakai sertifikat HTTPS self-signed dari script. Browser dapat menampilkan peringatan sertifikat pada lingkungan praktik; itu tidak otomatis berarti konfigurasi web gagal.
