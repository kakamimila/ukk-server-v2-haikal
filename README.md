UKK Server Deployment – Ubuntu Server 24.04

Nama: Muhammad Haikal Kamil
Kelas: XII TJKT 1
Sekolah: SMK Negeri 1 Banyumas
Nomor Absen: 23

A. Informasi Server

Komponen| Konfigurasi
Operating System| Ubuntu Server 24.04 LTS
IP Server| 192.168.30.10/24
Gateway| 192.168.30.1
VLAN| 30
Domain| lab-smk.xyz
DNS Server| BIND9
Web Server| Nginx
HTTPS| OpenSSL (Self-Signed Certificate)
Monitoring| Netdata
SNMP Router| MikroTik
Firewall| UFW

B. Persiapan Server

1. Periksa interface jaringan

Jalankan:

ip a

Pastikan:

- NIC 1 terhubung ke VLAN 30.
- NIC 1 menggunakan IP 192.168.30.10/24.
- NIC 2 terhubung ke Host-Only.

Periksa gateway:

ip route

2. Uji koneksi jaringan

Uji koneksi ke gateway:

ping -c 4 192.168.30.1

Uji koneksi internet:

ping -c 4 8.8.8.8

Jika berhasil, lanjutkan konfigurasi.

3. Update repository Ubuntu

sudo sed -i 's|http://id.archive.ubuntu.com/ubuntu/|http://archive.ubuntu.com/ubuntu/|g' /etc/apt/sources.list.d/ubuntu.sources

4. Update sistem

sudo apt update

Catatan: Berikan jeda setelah perubahan repository dan update sistem. Sesuai arahan guru, restart VM apabila diperlukan sebelum melanjutkan instalasi layanan.

C. Konfigurasi Dasar Server

5. Mengatur zona waktu

sudo timedatectl set-timezone Asia/Jakarta

Periksa:

timedatectl

6. Instalasi SSH Server

sudo apt install openssh-server -y

Aktifkan SSH:

sudo systemctl enable --now ssh

Periksa status:

sudo systemctl status ssh

Untuk mengetahui IP Host-Only:

ip -4 addr

IP tersebut dapat digunakan untuk mengakses server melalui PuTTY dari komputer host.

D. Instalasi dan Konfigurasi DNS Server (BIND9)

7. Instalasi BIND9

sudo apt install bind9 bind9utils bind9-doc dnsutils -y

8. Konfigurasi DNS Options

Buka file:

sudo nano /etc/bind/named.conf.options

Isi konfigurasi:

acl "allowed-recursion" {
    192.168.30.0/24;
    192.168.10.0/24;
    localhost;
};

options {
    directory "/var/cache/bind";

    recursion yes;
    allow-recursion { allowed-recursion; };

    listen-on { any; };
    listen-on-v6 { any; };

    dnssec-validation auto;

    forwarders {
        8.8.8.8;
    };
};

Simpan menggunakan Ctrl+X, Y, Enter.

Keterangan:

- VLAN 30 diperbolehkan melakukan recursive query.
- VLAN 10 diperbolehkan melakukan recursive query.
- VLAN 20 tidak dimasukkan ke dalam ACL.
- DNS menggunakan Google DNS sebagai forwarder.

9. Konfigurasi DNS Zone

Buka:

sudo nano /etc/bind/named.conf.local

Masukkan:

zone "lab-smk.xyz" {
    type master;
    file "/etc/bind/db.lab-smk.xyz";
};

10. Membuat file DNS Record

Buat file:

sudo nano /etc/bind/db.lab-smk.xyz

Masukkan:

$TTL    604800
@       IN      SOA     lab-smk.xyz. admin.lab-smk.xyz. (
                              3
                         604800
                          86400
                        2419200
                         604800 )

@       IN      NS      lab-smk.xyz.
@       IN      A       192.168.30.10
www     IN      A       192.168.30.10
monitor IN      A       192.168.30.10

11. Memeriksa konfigurasi DNS

Periksa konfigurasi BIND9:

sudo named-checkconf

Periksa DNS Zone:

sudo named-checkzone lab-smk.xyz /etc/bind/db.lab-smk.xyz

Jika hasilnya OK, aktifkan layanan:

sudo systemctl enable named
sudo systemctl restart named

Periksa status:

sudo systemctl status named

E. Instalasi Web Server (Nginx)

12. Instalasi Nginx dan OpenSSL

sudo apt install nginx openssl -y

Aktifkan Nginx:

sudo systemctl enable --now nginx

Periksa:

sudo systemctl status nginx

13. Membuat direktori website

sudo mkdir -p /var/www/lab-smk.xyz
sudo mkdir -p /etc/nginx/ssl

14. Membuat sertifikat HTTPS

Jalankan:

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/lab-smk.xyz.key -out /etc/nginx/ssl/lab-smk.xyz.crt -subj "/C=ID/ST=JawaTengah/L=Purwokerto/O=SMK/OU=TKJ/CN=lab-smk.xyz"

Sertifikat dan private key akan tersimpan di direktori "/etc/nginx/ssl/".

15. Membuat konfigurasi Virtual Host

Buka:

sudo nano /etc/nginx/sites-available/lab-smk.xyz

Isi:

server {
    listen 80;
    server_name lab-smk.xyz www.lab-smk.xyz;

    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name lab-smk.xyz www.lab-smk.xyz;

    ssl_certificate /etc/nginx/ssl/lab-smk.xyz.crt;
    ssl_certificate_key /etc/nginx/ssl/lab-smk.xyz.key;

    root /var/www/lab-smk.xyz;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}

Aktifkan konfigurasi:

sudo ln -sf /etc/nginx/sites-available/lab-smk.xyz /etc/nginx/sites-enabled/lab-smk.xyz

Nonaktifkan konfigurasi default:

sudo rm -f /etc/nginx/sites-enabled/default

Periksa konfigurasi:

sudo nginx -t

Jika berhasil:

sudo systemctl restart nginx

F. Membuat Landing Page Website

16. Membuat file index.html

sudo nano /var/www/lab-smk.xyz/index.html

Masukkan kode HTML berikut. CSS dan JavaScript sudah menjadi satu file.

<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Muhammad Haikal Kamil - Lab Server</title>

<style>
:root {
  --utama: #2563eb;
  --gelap: #0f172a;
  --terang: #f1f5f9;
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: "Segoe UI", Arial, sans-serif;
  background: var(--terang);
  color: #1e293b;
  line-height: 1.6;
}

.hero {
  background: linear-gradient(135deg, var(--gelap), var(--utama));
  color: white;
  text-align: center;
  padding: 80px 20px 90px;
}

.hero .label {
  display: inline-block;
  background: rgba(255,255,255,.15);
  padding: 4px 14px;
  border-radius: 20px;
  margin-bottom: 16px;
}

.hero h1 {
  font-size: 2.4rem;
  margin-bottom: 8px;
}

.hero p {
  color: #cbd5e1;
}

.badge {
  display: inline-block;
  margin-top: 22px;
  background: #22c55e;
  color: #052e16;
  padding: 8px 18px;
  border-radius: 8px;
  font-weight: 600;
}

.badge.http {
  background: #f59e0b;
  color: #451a03;
}

main {
  max-width: 960px;
  margin: -40px auto 40px;
  padding: 0 20px;
}

.box {
  background: white;
  border-radius: 14px;
  padding: 26px;
  margin-bottom: 20px;
  box-shadow: 0 6px 18px rgba(15,23,42,.08);
}

h2 {
  color: var(--gelap);
  margin-bottom: 12px;
}

.cards {
  display: flex;
  gap: 16px;
  flex-wrap: wrap;
}

.card {
  flex: 1 1 200px;
  border-top: 4px solid var(--utama);
  background: var(--terang);
  border-radius: 10px;
  padding: 18px;
}

.card h3 {
  color: var(--utama);
  margin-bottom: 4px;
}

table {
  width: 100%;
  border-collapse: collapse;
}

td {
  padding: 9px 4px;
  border-bottom: 1px solid #e2e8f0;
}

td:first-child {
  color: #64748b;
  width: 40%;
}

.btn {
  display: inline-block;
  margin-top: 15px;
  background: var(--utama);
  color: white;
  text-decoration: none;
  padding: 10px 22px;
  border-radius: 8px;
}

footer {
  text-align: center;
  padding: 24px;
  color: #64748b;
}
</style>
</head>

<body>

<script>
var DATA = {
  nama: "Muhammad Haikal Kamil",
  kelas: "XII TJKT 1",
  noAbsen: "23",
  sekolah: "SMK Negeri 1 Banyumas",
  tagline: "Server DNS, Web, dan Monitoring Real-Time"
};
</script>

<header class="hero">
  <span class="label" id="sekolah"></span>
  <h1 id="nama"></h1>
  <p id="kelas"></p>
  <p id="tagline"></p>
  <div id="badge" class="badge">Memeriksa koneksi...</div>
</header>

<main>
  <section class="box">
    <h2>Layanan Server</h2>
    <div class="cards">
      <div class="card">
        <h3>DNS Server</h3>
        BIND9 - lab-smk.xyz
      </div>
      <div class="card">
        <h3>Web Server</h3>
        Nginx - HTTPS
      </div>
      <div class="card">
        <h3>Monitoring</h3>
        Netdata
      </div>
    </div>
  </section>

  <section class="box">
    <h2>Informasi Jaringan</h2>
    <table>
      <tr><td>Domain</td><td>lab-smk.xyz</td></tr>
      <tr><td>IP Server</td><td>192.168.30.10</td></tr>
      <tr><td>Nama</td><td id="nama2"></td></tr>
      <tr><td>Kelas</td><td id="kelas2"></td></tr>
      <tr><td>Nomor Absen</td><td id="absen"></td></tr>
      <tr><td>Waktu Akses</td><td id="waktu"></td></tr>
    </table>

    <a class="btn" href="https://monitor.lab-smk.xyz">
      Buka Dashboard Monitoring
    </a>
  </section>
</main>

<footer>
  &copy; 2026 Muhammad Haikal Kamil - SMK Negeri 1 Banyumas
</footer>

<script>
document.getElementById("nama").textContent = DATA.nama;
document.getElementById("nama2").textContent = DATA.nama;
document.getElementById("kelas").textContent =
  DATA.kelas + " | Nomor Absen " + DATA.noAbsen;
document.getElementById("kelas2").textContent = DATA.kelas;
document.getElementById("absen").textContent = DATA.noAbsen;
document.getElementById("sekolah").textContent = DATA.sekolah;
document.getElementById("tagline").textContent = DATA.tagline;

document.title = DATA.nama + " - " + DATA.sekolah;

var aman = location.protocol === "https:";
var badge = document.getElementById("badge");

badge.textContent = aman
  ? "Dibuka lewat HTTPS (terenkripsi)"
  : "Dibuka lewat HTTP (tidak terenkripsi)";

if (!aman) badge.className = "badge http";

document.getElementById("waktu").textContent =
  new Date().toLocaleString("id-ID");
</script>

</body>
</html>

Simpan dengan Ctrl+X, Y, Enter.

Atur permission:

sudo chown -R www-data:www-data /var/www/lab-smk.xyz
sudo chmod 644 /var/www/lab-smk.xyz/index.html

Periksa dan reload Nginx:

sudo nginx -t
sudo systemctl reload nginx

G. Instalasi Netdata Monitoring

17. Instalasi curl

sudo apt install curl -y

18. Menambahkan repository resmi Netdata

curl -s https://packagecloud.io/install/repositories/netdata/netdata/script.deb.sh | sudo bash

19. Update repository

sudo apt update

20. Instalasi Netdata

sudo apt install netdata -y

21. Konfigurasi Netdata

Buka:

sudo nano /etc/netdata/netdata.conf

Isi:

[global]
    run as user = netdata

[web]
    bind to = 127.0.0.1

Simpan konfigurasi.

22. Konfigurasi Virtual Node

Buat direktori:

sudo mkdir -p /etc/netdata/vnodes

Buka:

sudo nano /etc/netdata/vnodes/vnodes.conf

Masukkan:

- hostname: Router-MikroTik
  guid: "11111111-2222-3333-4444-555555555555"

23. Mengaktifkan modul SNMP

Buka:

sudo nano /etc/netdata/go.d.conf

Isi:

modules:
  snmp: yes

24. Konfigurasi SNMP Router MikroTik

Pastikan layanan SNMP pada router MikroTik sudah diaktifkan.

Pada server, instal SNMP:

sudo apt install snmp -y

Buat konfigurasi:

sudo nano /etc/netdata/go.d/snmp.conf

Masukkan:

jobs:
  - name: router
    update_every: 10
    hostname: '192.168.30.1'
    community: 'public'
    vnode:
      hostname: 'Router-MikroTik'
      guid: '11111111-2222-3333-4444-555555555555'
    options:
      port: 161
      version: 2
      timeout: 2
    charts:
      - id: 'cpu_load'
        title: 'Router CPU Load'
        units: '%'
        family: 'cpu'
        type: line
        dimensions:
          - oid: 1.3.6.1.2.1.25.3.3.1.2.1
            name: cpu
            algorithm: absolute

      - id: 'system_uptime'
        title: 'Router Uptime'
        units: 'ticks'
        family: 'system'
        type: line
        dimensions:
          - oid: 1.3.6.1.2.1.1.3.0
            name: uptime
            algorithm: absolute

Catatan: Community "public" harus sama dengan konfigurasi SNMP pada router.

25. Mengatur permission dan menjalankan Netdata

sudo chown -R netdata:netdata /etc/netdata

sudo systemctl enable netdata
sudo systemctl restart netdata

Periksa:

sudo systemctl status netdata

26. Menguji SNMP Router

snmpwalk -v2c -c public 192.168.30.1 system

Jika informasi perangkat muncul, komunikasi SNMP berhasil.

H. Konfigurasi Reverse Proxy Monitoring

27. Membuat konfigurasi monitor.lab-smk.xyz

Buka:

sudo nano /etc/nginx/sites-available/monitor.lab-smk.xyz

Masukkan:

server {
    listen 80;
    server_name monitor.lab-smk.xyz;

    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name monitor.lab-smk.xyz;

    ssl_certificate /etc/nginx/ssl/lab-smk.xyz.crt;
    ssl_certificate_key /etc/nginx/ssl/lab-smk.xyz.key;

    location / {
        proxy_pass http://127.0.0.1:19999;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_buffering off;
    }
}

Aktifkan konfigurasi:

sudo ln -sf /etc/nginx/sites-available/monitor.lab-smk.xyz /etc/nginx/sites-enabled/monitor.lab-smk.xyz

Periksa:

sudo nginx -t

Restart Nginx:

sudo systemctl restart nginx

Dashboard monitoring dapat diakses melalui:

https://monitor.lab-smk.xyz

I. Konfigurasi Firewall UFW

28. Instalasi UFW

sudo apt install ufw -y

29. Mengizinkan port layanan

SSH:

sudo ufw allow 22/tcp

DNS:

sudo ufw allow 53

HTTP:

sudo ufw allow 80/tcp

HTTPS:

sudo ufw allow 443/tcp

Menutup akses langsung Netdata:

sudo ufw deny 19999/tcp

Aktifkan firewall:

sudo ufw --force enable

Periksa:

sudo ufw status verbose

Catatan: Port 161/UDP untuk SNMP harus dapat diakses server dari jaringan router sesuai topologi. Jangan membuka akses SNMP ke jaringan yang tidak diperlukan.

J. Pengujian Seluruh Layanan

30. Pengujian DNS

dig @192.168.30.10 lab-smk.xyz

Uji domain www:

dig @192.168.30.10 www.lab-smk.xyz

Uji domain monitoring:

dig @192.168.30.10 monitor.lab-smk.xyz

31. Pengujian Web Server

Periksa status:

sudo systemctl status nginx

Uji HTTPS:

curl -kI https://lab-smk.xyz

32. Pengujian Netdata

sudo systemctl status netdata

33. Pengujian Firewall

sudo ufw status

34. Pengujian dari PC Client

Atur DNS utama pada PC Client:

192.168.30.10

DNS alternate dikosongkan.

Uji DNS:

nslookup lab-smk.xyz

Buka browser:

- https://lab-smk.xyz
- https://www.lab-smk.xyz
- https://monitor.lab-smk.xyz

Jika browser menampilkan peringatan sertifikat, hal tersebut dapat terjadi karena menggunakan sertifikat HTTPS self-signed.

K. Ringkasan Layanan

Layanan| Domain / Alamat
DNS Server| 192.168.30.10
Website| https://lab-smk.xyz
Website WWW| https://www.lab-smk.xyz
Monitoring| https://monitor.lab-smk.xyz
Gateway| 192.168.30.1
Netdata Internal| 127.0.0.1:19999

---

Dokumentasi UKK TKJ SPK Paket 1 – 2026

Disusun oleh: Muhammad Haikal Kamil
Kelas: XII TJKT 1
SMK Negeri 1 Banyumas
