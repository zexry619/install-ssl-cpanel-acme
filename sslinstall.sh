#!/bin/bash

# Pastikan argumen domain diberikan
if [ -z "$1" ]; then
  echo "Penggunaan: $0 namadomain.com [--ca letsencrypt]"
  exit 1
fi

DOMAIN=$1
WWW_DOMAIN="www.$DOMAIN"
# Mail domain tidak disertakan sesuai permintaan
# MAIL_DOMAIN="mail.$DOMAIN" # Baris ini dihapus
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
  # Penting: Pastikan PATH sudah diperbarui setelah instalasi
  source ~/.bashrc || source ~/.bash_profile || source ~/.profile # Coba beberapa sumber profil
  echo "acme.sh berhasil diinstall."
else
  echo "acme.sh sudah terinstall, melanjutkan proses..."
fi

# Pastikan PATH mencakup direktori acme.sh
export PATH="$HOME/.acme.sh:$PATH"

# Mengecek apakah akun acme.sh sudah terdaftar
# Gunakan --list-account bukan --list untuk memeriksa akun
if ! $ACME_PATH --list-account 2>/dev/null | grep -q "Registered"; then
  echo "Mendaftarkan akun acme.sh dengan email $EMAIL ke $CA_SERVER..."
  $ACME_PATH --register-account -m "$EMAIL" --server "$CA_SERVER"
  if [ $? -ne 0 ]; then
    echo "Gagal mendaftarkan akun acme.sh. Pastikan email valid dan koneksi tersedia."
    exit 1
  fi
  echo "Pendaftaran akun berhasil."
else
  echo "Akun acme.sh sudah terdaftar."
fi

# Mendapatkan documentroot menggunakan uapi dan jq
DOCUMENT_ROOT=$(uapi --output=json DomainInfo domains_data | jq -r --arg domain "$DOMAIN" '
  .result.data as $data |
  ($data.main_domain | select(.domain == $domain) | .documentroot) //
  ($data.addondomains[] | select(.domain == $domain) | .documentroot) //
  ($data.sub_domains[] | select(.domain == $domain) | .documentroot)
')

# Validasi documentroot
if [ -z "$DOCUMENT_ROOT" ]; then
  echo "Gagal menemukan documentroot untuk $DOMAIN. Pastikan domain ada di cPanel dan domain utama/addon/sub."
  exit 1
fi

echo "DocumentRoot ditemukan: $DOCUMENT_ROOT"

# Uninstall SSL yang sudah ada sebelum deploy yang baru (opsional, tapi disarankan)
echo "Menghapus SSL lama untuk $DOMAIN (jika ada)..."
uapi SSL delete_ssl domain="$DOMAIN" 2>/dev/null # Redirect stderr to /dev/null to suppress "no SSL found" errors

# Mengeluarkan sertifikat SSL dengan acme.sh hanya untuk domain utama dan www
echo "Mengeluarkan sertifikat SSL untuk $DOMAIN dan $WWW_DOMAIN menggunakan $CA_SERVER..."
$ACME_PATH --issue -d "$DOMAIN" -d "$WWW_DOMAIN" --webroot "$DOCUMENT_ROOT" --server "$CA_SERVER" --force
if [ $? -ne 0 ]; then
  echo "Gagal mengeluarkan sertifikat SSL untuk $DOMAIN dan $WWW_DOMAIN."
  echo "Pastikan DNS sudah terpropagasi dan mengarah ke server ini, serta documentroot benar."
  exit 1
fi

# Deploy SSL ke cPanel
# acme.sh akan secara otomatis menginstal sertifikat yang baru saja dikeluarkan untuk domain utama.
echo "Melakukan deploy SSL untuk $DOMAIN dan $WWW_DOMAIN ke cPanel..."
$ACME_PATH --deploy -d "$DOMAIN" --deploy-hook cpanel_uapi --force
if [ $? -eq 0 ]; then
  echo "SSL berhasil diinstall dan diterapkan ke cPanel untuk $DOMAIN dan $WWW_DOMAIN."
  echo "Verifikasi SSL mungkin memerlukan beberapa saat untuk diterapkan di semua layanan."
else
  echo "Gagal melakukan deploy SSL ke cPanel untuk $DOMAIN dan $WWW_DOMAIN."
  echo "Periksa log acme.sh atau cPanel untuk detail lebih lanjut."
  exit 1
fi

echo "Script selesai."