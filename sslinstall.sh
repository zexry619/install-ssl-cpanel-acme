#!/bin/bash

# Pastikan argumen domain diberikan
if [ -z "$1" ]; then
  echo "Penggunaan: $0 namadomain.com [--ca letsencrypt]"
  exit 1
fi

DOMAIN=$1
WWW_DOMAIN="www.$DOMAIN"
# MAIL_DOMAIN="mail.$DOMAIN" # Baris ini dihapus sesuai permintaan
EMAIL="admin@$DOMAIN"
ACME_PATH="$HOME/.acme.sh/acme.sh"

# Default CA adalah ZeroSSL
CA_SERVER="https://acme.zerossl.com/v2/DV90"

# Cek jika ada opsi --ca letsencrypt
if [[ "$2" == "--ca" && "$3" == "letsencrypt" ]]; then
  CA_SERVER="https://acme-v02.api.letsencrypt.org/directory"
  echo "Menggunakan Let's Encrypt sebagai CA."
else
  echo "Menggunakan ZeroSSL sebagai CA (default)."
fi

# Mengecek apakah acme.sh sudah terinstall
if [ ! -f "$ACME_PATH" ]; then
  echo "acme.sh tidak ditemukan, menginstal acme.sh..."
  curl https://get.acme.sh | sh
  source ~/.bashrc # Menggunakan yang asli
  echo "acme.sh berhasil diinstall."
else
  echo "acme.sh sudah terinstall, melanjutkan proses..."
fi

# Pastikan PATH mencakup direktori acme.sh
export PATH="$HOME/.acme.sh:$PATH"

# Mengecek apakah akun acme.sh sudah terdaftar
if ! $ACME_PATH --list 2>/dev/null | grep -q "Registered"; then # Menggunakan --list yang asli
  echo "Mendaftarkan akun acme.sh dengan email $EMAIL ke $CA_SERVER..."
  $ACME_PATH --register-account -m "$EMAIL" --server "$CA_SERVER"
  echo "Pendaftaran akun berhasil."
else
  echo "Akun acme.sh sudah terdaftar."
fi

# Mendapatkan documentroot menggunakan uapi dan jq
DOCUMENT_ROOT=$(uapi --output=json DomainInfo domains_data | jq -r --arg domain "$DOMAIN" '
  .result.data as $data |
  ($data.main_domain | select(.domain == $domain) | .documentroot) //
  ($data.addon_domains[] | select(.domain == $domain) | .documentroot) // # Menggunakan addon_domains yang asli
  ($data.sub_domains[] | select(.domain == $domain) | .documentroot)
')

# Validasi documentroot
if [ -z "$DOCUMENT_ROOT" ]; then
  echo "Gagal menemukan documentroot untuk $DOMAIN"
  exit 1
fi

echo "DocumentRoot ditemukan: $DOCUMENT_ROOT"

# Uninstall SSL yang sudah ada sebelum deploy yang baru
echo "Menghapus SSL lama untuk $DOMAIN..."
uapi SSL delete_ssl domain="$DOMAIN" # Tanpa 2>/dev/null, sesuai asli

# Mengeluarkan sertifikat SSL dengan acme.sh untuk domain utama dan www
echo "Mengeluarkan sertifikat SSL untuk $DOMAIN dan $WWW_DOMAIN menggunakan $CA_SERVER..." # Pesan diupdate
$ACME_PATH --issue -d "$DOMAIN" -d "$WWW_DOMAIN" --webroot "$DOCUMENT_ROOT" --server "$CA_SERVER" --force # MAIL_DOMAIN dihapus di sini
if [ $? -ne 0 ]; then
  echo "Gagal mengeluarkan sertifikat SSL untuk $DOMAIN dan $WWW_DOMAIN" # Pesan diupdate
  exit 1
fi

# Deploy SSL ke cPanel
echo "Melakukan deploy SSL untuk $DOMAIN dan $WWW_DOMAIN..." # Pesan diupdate
$ACME_PATH --deploy -d "$DOMAIN" --deploy-hook cpanel_uapi --force
if [ $? -eq 0 ]; then
  echo "SSL berhasil diinstall dan diterapkan ke cPanel untuk $DOMAIN dan $WWW_DOMAIN" # Pesan diupdate
else
  echo "Gagal melakukan deploy SSL ke cPanel untuk $DOMAIN dan $WWW_DOMAIN" # Pesan diupdate
  exit 1
fi