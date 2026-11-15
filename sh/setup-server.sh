#!/bin/bash
#
# =============================================================
#  Script Instalasi & Konfigurasi Server - UKK TKJ SPK PAKET 1
#  Target OS  : Ubuntu Server 24.04 LTS
#  IP Server  : 192.168.30.10/24 (VLAN 30)
#  Layanan    : DNS (bind9), Web (nginx + HTTPS), Monitoring (netdata)
#
#  CATATAN:
#  Script ini TIDAK mengubah konfigurasi IP.
#  - IP Static NIC 1 (192.168.30.10/24, VLAN 30) harus SUDAH dikonfigurasi
#    manual dan server sudah bisa akses internet SEBELUM script ini jalan.
#  - NIC 2 (Host-Only, IP dinamis dari DHCP)
#    netplan agar server bisa diakses lewat PuTTY dari PC host
#    (copy-paste dari konsol VMware sering terpotong).
#  - Landing page berupa SATU file: /var/www/lab-smk.xyz/index.html (CSS
#    dan JS ada di dalamnya). Siswa WAJIB mengganti identitas di file ini.
#
#  Cara pakai:
#    sudo chmod +x setup-server.sh
#    sudo ./setup-server.sh
# =============================================================

set -e

# --------- Cek harus dijalankan sebagai root ----------
if [ "$EUID" -ne 0 ]; then
    echo ">> Jalankan script ini dengan sudo/root!"
    echo "   sudo ./setup-server.sh"
    exit 1
fi

# ================= VARIABEL KONFIGURASI =================
IP_ADDRESS="192.168.30.10"    # harus sama dengan IP static yang sudah diset manual
MGMT_IP=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -vx "${IP_ADDRESS}" | head -n1)   # IP NIC 2 (Host-Only, DHCP) untuk PuTTY
DOMAIN="lab-smk.xyz"
ALLOWED_RECURSION_NETS="192.168.30.0/24; 192.168.10.0/24"   # VLAN 30 & VLAN 10 boleh recursive query (VLAN 20 tidak)
WEBROOT="/var/www/${DOMAIN}"

ROUTER_IP="192.168.30.1"       # IP Router MikroTik (VLAN 30) - SNMP client harus sudah "on"
SNMP_COMMUNITY="public"        # sesuaikan dengan SNMP community string di router MikroTik

echo "======================================================"
echo " Memulai konfigurasi server ${DOMAIN} (${IP_ADDRESS})"
echo "======================================================"

# --------- Cek dulu apakah IP server sudah sesuai & internet nyambung ----------
ALL_IPS=$(hostname -I 2>/dev/null || ip addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if ! echo " ${ALL_IPS} " | grep -q " ${IP_ADDRESS} "; then
    echo ">> PERINGATAN: IP ${IP_ADDRESS} tidak ditemukan. IP server saat ini: ${ALL_IPS}"
    echo "   Pastikan IP static sudah dikonfigurasi manual sebelum lanjut."
    printf "   Lanjutkan tetap? (y/n): "
    read confirm
    [ "$confirm" != "y" ] && exit 1
fi

if ! ping -c 2 8.8.8.8 >/dev/null 2>&1; then
    echo ">> ERROR: Server belum terkoneksi ke internet."
    echo "   Selesaikan konfigurasi IP static & gateway secara manual dulu."
    exit 1
fi

echo "   OK - IP: ${ALL_IPS}, internet: terkoneksi."

if [ -z "${MGMT_IP}" ]; then
    echo "   Catatan: NIC Host-Only belum mendapat IP (cek DHCP Host-Only di VMware), PuTTY dari PC host belum bisa dipakai."
else
    echo "   NIC Host-Only terdeteksi: ${MGMT_IP} (untuk PuTTY dari PC host)."
fi

# ================= 1. UPDATE SISTEM =================
echo ">> [1/5] Update sistem, zona waktu, dan SSH server..."
apt update -y

# Zona waktu WIB agar log berwaktu benar
timedatectl set-timezone Asia/Jakarta

# SSH server (untuk PuTTY dari PC host lewat NIC Host-Only)
# apt install -y openssh-server
# systemctl enable --now ssh

# ================= 2. INSTALL & KONFIGURASI BIND9 (DNS SERVER) =================
echo ">> [2/5] Install & konfigurasi BIND9 (DNS Server)..."
apt install -y bind9 bind9utils bind9-doc dnsutils

# --- named.conf.options : disable recursion untuk VLAN 20, izinkan VLAN 10 & VLAN 30 ---
cat > /etc/bind/named.conf.options <<EOF
acl "allowed-recursion" {
    ${ALLOWED_RECURSION_NETS};
    localhost;
};

options {
    directory "/var/cache/bind";

    recursion yes;
    allow-recursion { allowed-recursion; };
    // VLAN 20 (192.168.20.0/24) tidak termasuk allowed-recursion -> otomatis ditolak

    listen-on { any; };
    listen-on-v6 { any; };

    dnssec-validation auto;

    forwarders {
        8.8.8.8;
    };
};
EOF

# --- named.conf.local : definisikan zone ---
cat > /etc/bind/named.conf.local <<EOF
zone "${DOMAIN}" {
    type master;
    file "/etc/bind/db.${DOMAIN}";
};
EOF

# --- File zone / record DNS ---
cat > /etc/bind/db.${DOMAIN} <<EOF
\$TTL    604800
@       IN      SOA     ${DOMAIN}. admin.${DOMAIN}. (
                              3         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ${DOMAIN}.
@       IN      A       ${IP_ADDRESS}
www     IN      A       ${IP_ADDRESS}
monitor IN      A       ${IP_ADDRESS}
EOF

# Cek konfigurasi bind
named-checkconf
named-checkzone ${DOMAIN} /etc/bind/db.${DOMAIN}

systemctl enable named
systemctl restart named
echo "   DNS server aktif untuk zone ${DOMAIN} (www, monitor -> ${IP_ADDRESS})"

# ================= 4. INSTALL & KONFIGURASI NGINX (WEB SERVER) =================
echo ">> [3/5] Install & konfigurasi NGINX (Web Server + HTTPS self-signed)..."
apt install -y nginx openssl

mkdir -p "${WEBROOT}"
mkdir -p /etc/nginx/ssl

# --- Landing Page: SATU file index.html (CSS dan JS di dalamnya) ---
# Siswa WAJIB mengganti blok "var DATA" di bagian atas file agar halaman autentik.
cat > "${WEBROOT}/index.html" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="theme-color" content="#111827">
  <meta name="description" content="Profil administrator lab jaringan SMK Negeri 1 Banyumas.">
  <title>Muhammad Haikal Kamil | Lab TJKT</title>
  <style>
    :root {
      --bg: #f3f4f6;
      --surface: #ffffff;
      --ink: #111827;
      --muted: #6b7280;
      --line: #e5e7eb;
      --accent: #7c3aed;
      --accent2: #ec4899;
      --navy: #111827;
    }
    * { box-sizing: border-box; }
    html { scroll-behavior: smooth; }
    body {
      margin: 0; background: var(--bg); color: var(--ink);
      font-family: Inter, "Segoe UI", Arial, sans-serif; line-height: 1.6;
    }
    .topbar {
      position: sticky; top: 0; z-index: 5; background: rgba(255,255,255,.92);
      backdrop-filter: blur(12px); border-bottom: 1px solid var(--line);
    }
    .nav {
      max-width: 1050px; margin: auto; padding: 14px 22px;
      display: flex; align-items: center; justify-content: space-between; gap: 12px;
    }
    .brand { font-weight: 800; letter-spacing: -.4px; }
    .brand span { color: var(--accent); }
    .nav small { color: var(--muted); }
    .hero {
      background: linear-gradient(120deg, #111827 0%, #312e81 55%, #7c3aed 100%);
      color: white; padding: 64px 20px 92px;
    }
    .hero-inner { max-width: 950px; margin: auto; display: flex; align-items: center; gap: 28px; }
    .avatar {
      width: 112px; height: 112px; flex: 0 0 112px; border-radius: 50%;
      display: grid; place-items: center; font-size: 2.2rem; font-weight: 800;
      background: linear-gradient(135deg, var(--accent2), #8b5cf6);
      border: 4px solid rgba(255,255,255,.85); box-shadow: 0 8px 30px rgba(0,0,0,.25);
    }
    .eyebrow {
      display: inline-block; border: 1px solid rgba(255,255,255,.28);
      background: rgba(255,255,255,.1); padding: 5px 12px; border-radius: 30px;
      font-size: .78rem; letter-spacing: .5px; text-transform: uppercase;
    }
    h1 { margin: 10px 0 3px; font-size: clamp(1.8rem, 5vw, 2.7rem); line-height: 1.15; }
    .hero p { margin: 6px 0; color: #e5e7eb; }
    .status { display: inline-flex; align-items: center; gap: 8px; margin-top: 12px; font-size: .85rem; color: #dcfce7; }
    .dot { width: 8px; height: 8px; border-radius: 50%; background: #4ade80; box-shadow: 0 0 0 4px rgba(74,222,128,.15); }
    main { max-width: 950px; margin: -42px auto 40px; padding: 0 20px; position: relative; }
    .panel {
      background: var(--surface); border: 1px solid var(--line); border-radius: 18px;
      padding: 25px; margin-bottom: 18px; box-shadow: 0 10px 28px rgba(17,24,39,.06);
    }
    .section-title { display: flex; align-items: center; gap: 10px; margin: 0 0 17px; font-size: 1.15rem; }
    .section-title:before { content: ""; width: 5px; height: 22px; border-radius: 5px; background: linear-gradient(var(--accent),var(--accent2)); }
    .profile-grid { display: grid; grid-template-columns: repeat(2,minmax(0,1fr)); gap: 12px 22px; }
    .item { padding: 10px 0; border-bottom: 1px solid var(--line); min-width: 0; }
    .item small { display: block; color: var(--muted); margin-bottom: 3px; }
    .item strong { overflow-wrap: anywhere; }
    .cards { display: grid; grid-template-columns: repeat(3,minmax(0,1fr)); gap: 13px; }
    .card { padding: 17px; border-radius: 14px; background: #f9fafb; border: 1px solid var(--line); }
    .card .symbol { font-size: 1.35rem; }
    .card h3 { margin: 8px 0 3px; font-size: 1rem; }
    .card p { margin: 0; color: var(--muted); font-size: .9rem; }
    .tags { display: flex; flex-wrap: wrap; gap: 8px; }
    .tag { padding: 7px 11px; border-radius: 30px; background: #f3e8ff; color: #6b21a8; font-size: .85rem; font-weight: 600; }
    .project { border-left: 3px solid var(--accent); padding: 3px 0 3px 15px; margin: 12px 0; }
    .project p { margin: 3px 0; color: var(--muted); }
    .monitor {
      display: flex; align-items: center; justify-content: space-between; gap: 16px;
      background: #111827; color: white; border-radius: 16px; padding: 22px;
    }
    .monitor p { margin: 4px 0 0; color: #cbd5e1; font-size: .9rem; }
    .btn {
      display: inline-block; white-space: nowrap; text-decoration: none; color: white;
      background: linear-gradient(100deg,var(--accent),var(--accent2));
      padding: 11px 17px; border-radius: 10px; font-weight: 700; transition: transform .2s, opacity .2s;
    }
    .btn:hover { transform: translateY(-2px); opacity: .92; }
    footer { text-align: center; color: var(--muted); padding: 10px 20px 30px; font-size: .88rem; }
    @media (max-width: 650px) {
      .hero { padding: 45px 20px 78px; }
      .hero-inner { flex-direction: column; text-align: center; gap: 15px; }
      .profile-grid, .cards { grid-template-columns: 1fr; }
      .monitor { align-items: flex-start; flex-direction: column; }
      .panel { padding: 20px; }
      .nav small { display: none; }
    }
  </style>
</head>
<body>
  <div class="topbar">
    <nav class="nav">
      <div class="brand">LAB<span>TJKT</span></div>
      <small>SMK Negeri 1 Banyumas · UKK 2026</small>
    </nav>
  </div>

  <header class="hero">
    <div class="hero-inner">
      <div class="avatar" aria-label="Inisial HK">HK</div>
      <div>
        <span class="eyebrow">Administrator Lab / Web</span>
        <h1 id="nama">Muhammad Haikal Kamil</h1>
        <p id="kelas">XII TJKT 1 · SMK Negeri 1 Banyumas</p>
        <div class="status"><span class="dot"></span><span id="statusText">Profil server aktif</span></div>
      </div>
    </div>
  </header>

  <main>
    <section class="panel">
      <h2 class="section-title">Profil Administrator</h2>
      <div class="profile-grid">
        <div class="item"><small>Nama lengkap</small><strong id="namaInfo"></strong></div>
        <div class="item"><small>Kelas</small><strong id="kelasInfo"></strong></div>
        <div class="item"><small>Sekolah</small><strong id="sekolahInfo"></strong></div>
        <div class="item"><small>Program keahlian</small><strong id="jurusanInfo"></strong></div>
        <div class="item"><small>Nomor absen</small><strong id="absenInfo"></strong></div>
        <div class="item"><small>Peran</small><strong>Administrator Lab/Web</strong></div>
      </div>
    </section>

    <section class="panel">
      <h2 class="section-title">Layanan Server</h2>
      <div class="cards">
        <article class="card"><div class="symbol">🌐</div><h3>DNS Server</h3><p>BIND9 · Domain lab-smk.xyz</p></article>
        <article class="card"><div class="symbol">🖥️</div><h3>Web Server</h3><p>Nginx · HTTPS</p></article>
        <article class="card"><div class="symbol">📊</div><h3>Monitoring</h3><p>Netdata · Server & Router</p></article>
      </div>
    </section>

    <section class="panel">
      <h2 class="section-title">Kompetensi</h2>
      <div class="tags">
        <span class="tag">Administrasi Jaringan</span>
        <span class="tag">MikroTik</span>
        <span class="tag">Linux Server</span>
        <span class="tag">DNS & Web Server</span>
        <span class="tag">Internet of Things</span>
        <span class="tag">Cloud Computing</span>
      </div>
      <div class="project">
        <strong>Proyek: IoT Gas Detector</strong>
        <p>Sistem pendeteksi gas menggunakan ESP32 dan sensor MQ-2.</p>
      </div>
      <div class="project">
        <strong>Prestasi: Juara 1 LKS tingkat Kabupaten Banyumas</strong>
        <p>Pengalaman kompetisi bidang keahlian jaringan dan teknologi informasi.</p>
      </div>
    </section>

    <section class="panel">
      <h2 class="section-title">Informasi Jaringan</h2>
      <div class="profile-grid">
        <div class="item"><small>Domain utama</small><strong>lab-smk.xyz</strong></div>
        <div class="item"><small>IP server</small><strong>192.168.30.10</strong></div>
        <div class="item"><small>Halaman diakses melalui</small><strong id="alamat">-</strong></div>
        <div class="item"><small>Waktu akses</small><strong id="waktu">-</strong></div>
      </div>
    </section>

    <section class="monitor">
      <div>
        <strong>Dashboard Monitoring Server</strong>
        <p>Lihat pemantauan server dan jaringan melalui Netdata.</p>
      </div>
      <a class="btn" href="https://monitor.lab-smk.xyz" target="_blank" rel="noopener noreferrer">Buka Monitoring ↗</a>
    </section>
  </main>

  <footer>
    © <span id="tahun"></span> Muhammad Haikal Kamil · XII TJKT 1 · SMK Negeri 1 Banyumas
  </footer>

  <script>
    // Ubah nomor absen di sini sebelum deployment jika sudah diketahui.
    const DATA_SISWA = {
      nama: "Muhammad Haikal Kamil",
      kelas: "XII TJKT 1",
      sekolah: "SMK Negeri 1 Banyumas",
      jurusan: "Teknik Jaringan Komputer dan Telekomunikasi",
      nomorAbsen: "ISI NOMOR ABSEN"
    };

    document.getElementById("nama").textContent = DATA_SISWA.nama;
    document.getElementById("kelas").textContent = DATA_SISWA.kelas + " · " + DATA_SISWA.sekolah;
    document.getElementById("namaInfo").textContent = DATA_SISWA.nama;
    document.getElementById("kelasInfo").textContent = DATA_SISWA.kelas;
    document.getElementById("sekolahInfo").textContent = DATA_SISWA.sekolah;
    document.getElementById("jurusanInfo").textContent = DATA_SISWA.jurusan;
    document.getElementById("absenInfo").textContent = DATA_SISWA.nomorAbsen;
    document.getElementById("alamat").textContent = window.location.hostname;
    document.getElementById("tahun").textContent = new Date().getFullYear();

    function perbaruiWaktu() {
      document.getElementById("waktu").textContent =
        new Date().toLocaleString("id-ID", { dateStyle: "full", timeStyle: "medium" });
    }
    perbaruiWaktu();
    setInterval(perbaruiWaktu, 1000);
    document.title = DATA_SISWA.nama + " | Lab TJKT";
  </script>
</body>
</html>
HTMLEOF

chown -R www-data:www-data "${WEBROOT}"
chmod 644 "${WEBROOT}/index.html"

# --- Buat sertifikat self-signed untuk HTTPS ---
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/${DOMAIN}.key -out /etc/nginx/ssl/${DOMAIN}.crt -subj "/C=ID/ST=JawaTengah/L=Purwokerto/O=SMK/OU=TKJ/CN=${DOMAIN}"

# --- Virtual host nginx (HTTP redirect ke HTTPS + HTTPS) ---
cat > /etc/nginx/sites-available/${DOMAIN} <<EOF
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name ${DOMAIN} www.${DOMAIN};

    ssl_certificate     /etc/nginx/ssl/${DOMAIN}.crt;
    ssl_certificate_key /etc/nginx/ssl/${DOMAIN}.key;

    root ${WEBROOT};
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/${DOMAIN}
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable nginx
systemctl restart nginx
echo "   Web server aktif: https://${DOMAIN} (self-signed)"

# ================= 5. INSTALL & KONFIGURASI NETDATA (MONITORING) =================
echo ">> [4/5] Install Netdata (Monitoring Server)..."

# Fallback nilai domain jika variabel DOMAIN belum terisi
DOMAIN="${DOMAIN:-lab-smk.xyz}"
ROUTER_IP="${ROUTER_IP:-192.168.30.1}"
SNMP_COMMUNITY="${SNMP_COMMUNITY:-public}"

install_netdata_service() {
    # 1. Hapus versi lama/rusak jika ada
    if dpkg -l | grep -q netdata || [ -d "/etc/netdata" ]; then
        echo "   Membersihkan versi Netdata lama..."
        apt remove --purge -y netdata netdata-* >/dev/null 2>&1 || true
        rm -rf /etc/netdata /var/lib/netdata /var/cache/netdata /usr/share/netdata /var/log/netdata /tmp/kickstart*
    fi

    # 2. Tambah Repository Resmi Netdata (PackageCloud)
    echo "   Menambahkan repository resmi Netdata (PackageCloud)..."
    curl -s https://packagecloud.io/install/repositories/netdata/netdata/script.deb.sh | bash || return 1

    # 3. Install Netdata via APT dengan Auto-Retry
    echo "   Menginstal Netdata via APT..."
    apt update -o Acquire::Retries=5 -o Acquire::http::Timeout=60 || true
    apt install -y -o Acquire::Retries=10 -o Acquire::http::Timeout=120 --fix-missing netdata || return 1

    CONF_DIR="/etc/netdata"
    mkdir -p "${CONF_DIR}" "${CONF_DIR}/vnodes" "${CONF_DIR}/go.d"

    # 4. Buat konfigurasi netdata.conf yang bersih (bind ke 127.0.0.1)
    cat > "${CONF_DIR}/netdata.conf" <<EOF
[global]
    run as user = netdata

[web]
    bind to = 127.0.0.1
EOF

    # 5. Buat registrasi Virtual Node di /etc/netdata/vnodes/vnodes.conf (WAJIB DIBUAT)
    cat > "${CONF_DIR}/vnodes/vnodes.conf" <<EOF
- hostname: Router-MikroTik
  guid: "11111111-2222-3333-4444-555555555555"
EOF

    # 6. Aktifkan modul SNMP di go.d.conf
    cat > "${CONF_DIR}/go.d.conf" <<EOF
modules:
  snmp: yes
EOF

    # 7. Konfigurasi job SNMP (snmp.conf) yang terhubung ke vnode Router-MikroTik
    cat > "${CONF_DIR}/go.d/snmp.conf" <<EOF
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
EOF

    # Install alat penguji SNMP
    apt install -y snmp >/dev/null 2>&1 || true

    # Atur kepemilikan direktori konfigurasi ke user netdata
    chown -R netdata:netdata "${CONF_DIR}" 2>/dev/null || true

    systemctl enable netdata || true
    systemctl restart netdata || true
    echo "   Netdata & Virtual Node Router-MikroTik (${ROUTER_IP}) berhasil dikonfigurasi."
    return 0
}

# Jalankan fungsi instalasi Netdata
if install_netdata_service; then
    echo ">> [OK] Netdata Berhasil Terinstal & Dikonfigurasi."
else
    echo ">> [WARNING] Netdata gagal diunduh."
fi

# --- 6. Reverse proxy Nginx untuk monitor.${DOMAIN} (HTTPS + WebSocket) ---
echo ">> Konfigurasi reverse proxy HTTPS untuk monitor.${DOMAIN}..."

mkdir -p /etc/nginx/ssl

cat > /etc/nginx/sites-available/monitor.${DOMAIN} <<EOF
server {
    listen 80;
    server_name monitor.${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name monitor.${DOMAIN};

    ssl_certificate     /etc/nginx/ssl/${DOMAIN}.crt;
    ssl_certificate_key /etc/nginx/ssl/${DOMAIN}.key;

    location / {
        proxy_pass http://127.0.0.1:19999;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Support Streaming & WebSocket Netdata
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_buffering off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/monitor.${DOMAIN} /etc/nginx/sites-enabled/monitor.${DOMAIN}
nginx -t
systemctl restart nginx
echo "   Monitoring aktif via HTTPS: https://monitor.${DOMAIN}"

# ================= 6. FIREWALL DASAR SERVER (UFW) =================
echo ">> [5/5] Konfigurasi firewall dasar (UFW) pada server..."
apt install -y ufw
ufw allow 22/tcp      # SSH (PuTTY dari PC host lewat NIC Host-Only)
ufw allow 53          # DNS
ufw allow 80/tcp      # HTTP
ufw allow 443/tcp     # HTTPS
ufw deny 19999/tcp    # Netdata TIDAK diakses langsung dari luar, hanya via proxy nginx
ufw --force enable

echo "======================================================"
echo " SELESAI!"
echo " - DNS   : dig @${IP_ADDRESS} ${DOMAIN}"
echo " - Web   : https://${DOMAIN}  (atau https://${IP_ADDRESS})"
echo " - Monitor: https://monitor.${DOMAIN}   (port 19999 tertutup dari luar)"
echo "   Host di monitoring: 'server' (localhost) & 'router' (${ROUTER_IP} via SNMP)"
echo "   Verifikasi SNMP router: snmpwalk -v2c -c ${SNMP_COMMUNITY} ${ROUTER_IP} system"
echo " WAJIB: ganti identitas siswa di ${WEBROOT}/index.html"
echo "   (PuTTY ke ${MGMT_IP:-<IP NIC Host-Only>}, lalu: sudo nano ${WEBROOT}/index.html)"
echo " Pastikan client (VLAN 10/20/30) mengarahkan DNS ke ${IP_ADDRESS}"
echo " agar domain ${DOMAIN} bisa di-resolve."
echo "======================================================"