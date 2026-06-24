# ROOT
FOLDER_AKUN="/storage/emulated/0/XPersonal/20260306"
FOLDER_END="$FOLDER_AKUN/end"

# =====================
# RESULT FOLDER
# =====================
FOLDER_SUCCESS="$FOLDER_END/success" # sesi & web
FOLDER_BANNED="$FOLDER_END/banned" # sesi & web
FOLDER_LOGOUT="$FOLDER_END/logout" # sesi & web
FOLDER_TIMEOUT="$FOLDER_END/timeout" # sesi & web
FOLDER_TERDAFTAR="$FOLDER_END/terdaftar" # web
FOLDER_INVALID="$FOLDER_END/failed" # sesi & web
FOLDER_RESTORE="$FOLDER_END/restore" # sesi & web
FOLDER_LOG="$FOLDER_END/log" # sesi & web
FOLDER_FAILED_PAIRING="$FOLDER_END/failed_pairing" # sesi & web
# =====================
# RESULT FILE
# =====================
FILE_SUCCESS="$FOLDER_AKUN/sukses.txt" # sesi & web 
FILE_LOGOUT="$FOLDER_AKUN/logout.txt" # sesi & web
FILE_BANNED="$FOLDER_AKUN/banned.txt" # sesi & web
FILE_TIMEOUT="$FOLDER_AKUN/timeout.txt" # sesi & web
FILE_TERDAFTAR="$FOLDER_AKUN/akun_terdaftar.txt" # web
FILE_INVALID="$FOLDER_AKUN/nomor_tidak_valid.txt" # sesi & web
FILE_FAILED_PAIRING="$FOLDER_AKUN/nomor_gagal_pairing.txt" # sesi & web

# =====================
# ACTIVITY LOG
# =====================
FILE_ACTIVITY="$FOLDER_LOG/activity.txt"

# =====================
# SYSTEM
# =====================
# WA_PKG: default; auto-detected dari isi backup saat restore
#   com.whatsapp      = WA Personal
#   com.whatsapp.w4b  = WA Business
WA_PKG="com.whatsapp"
FOLDER_WA_SYMLINK="/data/data/$WA_PKG"
FOLDER_WA="/data/user/0/$WA_PKG"
TEMP="/data/local/tmp/restore_wa"

# =====================
# LOGIN AUTO-RECOVERY (init/loading hang)
# =====================
LOGIN_MAX_WAIT=180        # detik, total tunggu login sebelum timeout
STUCK_RESTART_AFTER=10    # detik stuck (UNKNOWN/INITIALIZING) sebelum restart WA
STUCK_MAX_RESTARTS=3      # maksimal restart WA otomatis per login

# =====================
# SERVER QUEUE (PC pusat)
# =====================
# Port server (samakan dgn yg dipilih saat start account_management [3]).
# Default 8787 (hindari 7070 = AnyDesk).
SERVER_PORT=8787
# Override manual (opsional). Isi kalau mau pin IP & skip auto-scan:
#   SERVER_FIXED="http://192.168.0.23:7070"
SERVER_FIXED=""
# Hasil auto-discovery diisi runtime (scan LAN cari port terbuka). Jangan diisi.
SERVER=""
# Cache URL server terakhir yg ketemu (biar run berikutnya instan).
SERVER_CACHE="$FOLDER_AKUN/.server_url"
# ID device buat klaim/lapor (biar server tau HP mana).
DEVICE_ID="$(getprop ro.serialno 2>/dev/null)"
[ -z "$DEVICE_ID" ] && DEVICE_ID="$(getprop ro.boot.serialno 2>/dev/null)"
[ -z "$DEVICE_ID" ] && DEVICE_ID="unknown_device"
# Detik tunggu kalau antrian (MASTER) kosong / server tak respon.
CLAIM_IDLE_WAIT=10

# =====================
# CREATE FOLDER
# =====================
mkdir -p \
"$FOLDER_SUCCESS" \
"$FOLDER_BANNED" \
"$FOLDER_LOGOUT" \
"$FOLDER_TIMEOUT" \
"$FOLDER_TERDAFTAR" \
"$FOLDER_INVALID" \
"$FOLDER_LOG" \
"$TEMP" \
"$FOLDER_FAILED_PAIRING"