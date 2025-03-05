#!/bin/bash

# Mengecek apakah domain diberikan sebagai argumen
if [ -z "$1" ]; then
  echo "Penggunaan: $0 namadomain.com"
  exit 1
fi

DOMAIN=$1
EMAIL="admin@$DOMAIN"

# Menentukan path acme.sh
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

# Memastikan PATH mengarah ke acme.sh
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

# Validasi apakah documentroot ditemukan
if [ -z "$DOCUMENT_ROOT" ]; then
  echo "Gagal menemukan documentroot untuk $DOMAIN"
  exit 1
fi

echo "DocumentRoot ditemukan: $DOCUMENT_ROOT"

# Menghapus SSL yang sudah ada sebelum menginstall yang baru
echo "Menghapus SSL lama untuk $DOMAIN..."
uapi SSL delete_ssl domain="$DOMAIN"

# Menjalankan proses issue SSL menggunakan acme.sh
echo "Mengeluarkan sertifikat SSL untuk $DOMAIN..."
$ACME_PATH --issue -d "$DOMAIN" --webroot "$DOCUMENT_ROOT"

# Mengecek apakah SSL berhasil di-issue
if [ $? -ne 0 ]; then
  echo "Gagal mengeluarkan sertifikat SSL untuk $DOMAIN"
  exit 1
fi

# Deploy SSL ke cPanel
echo "Melakukan deploy SSL untuk $DOMAIN..."
$ACME_PATH --deploy -d "$DOMAIN" --deploy-hook cpanel_uapi

# Mengecek apakah deploy berhasil
if [ $? -eq 0 ]; then
  echo "SSL berhasil diinstall dan diterapkan ke cPanel untuk $DOMAIN"
else
  echo "Gagal melakukan deploy SSL ke cPanel untuk $DOMAIN"
  exit 1
fi
