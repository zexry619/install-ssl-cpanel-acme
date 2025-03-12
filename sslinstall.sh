#!/bin/bash

# Pastikan argumen domain diberikan
if [ -z "$1" ]; then
  echo "Penggunaan: $0 namadomain.com"
  exit 1
fi

DOMAIN=$1
WWW_DOMAIN="www.$DOMAIN"
MAIL_DOMAIN="mail.$DOMAIN"
EMAIL="admin@$DOMAIN"
ACME_PATH="$HOME/.acme.sh/acme.sh"

# Mengecek apakah acme.sh sudah terinstall
if [ ! -f "$ACME_PATH" ]; then
  echo "acme.sh tidak ditemukan, menginstal acme.sh..."
  curl https://get.acme.sh | sh
  source ~/.bashrc
  echo "acme.sh berhasil diinstall."
else
  echo "acme.sh sudah terinstall, melanjutkan proses..."
fi

# Pastikan PATH mencakup direktori acme.sh
export PATH="$HOME/.acme.sh:$PATH"

# Mengecek apakah akun acme.sh sudah terdaftar
if ! $ACME_PATH --list 2>/dev/null | grep -q "Registered"; then
  echo "Mendaftarkan akun acme.sh dengan email $EMAIL..."
  $ACME_PATH --register-account -m "$EMAIL" --server zerossl
  echo "Pendaftaran akun berhasil."
else
  echo "Akun acme.sh sudah terdaftar."
fi

# Mendapatkan documentroot menggunakan uapi dan jq
DOCUMENT_ROOT=$(uapi --output=json DomainInfo domains_data | jq -r --arg domain "$DOMAIN" '
  .result.data as $data |
  ($data.main_domain | select(.domain == $domain) | .documentroot) //
  ($data.addon_domains[] | select(.domain == $domain) | .documentroot) //
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
uapi SSL delete_ssl domain="$DOMAIN"

# Mengeluarkan sertifikat SSL dengan acme.sh untuk domain utama, www, dan mail
echo "Mengeluarkan sertifikat SSL untuk $DOMAIN, $WWW_DOMAIN, dan $MAIL_DOMAIN..."
$ACME_PATH --issue -d "$DOMAIN" -d "$WWW_DOMAIN" -d "$MAIL_DOMAIN" --webroot "$DOCUMENT_ROOT"
if [ $? -ne 0 ]; then
  echo "Gagal mengeluarkan sertifikat SSL untuk $DOMAIN, $WWW_DOMAIN, dan $MAIL_DOMAIN"
  exit 1
fi

# Deploy SSL ke cPanel
echo "Melakukan deploy SSL untuk $DOMAIN, $WWW_DOMAIN, dan $MAIL_DOMAIN..."
$ACME_PATH --deploy -d "$DOMAIN" --deploy-hook cpanel_uapi
if [ $? -eq 0 ]; then
  echo "SSL berhasil diinstall dan diterapkan ke cPanel untuk $DOMAIN, $WWW_DOMAIN, dan $MAIL_DOMAIN"
else
  echo "Gagal melakukan deploy SSL ke cPanel untuk $DOMAIN, $WWW_DOMAIN, dan $MAIL_DOMAIN"
  exit 1
fi
