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
FOLDER_FAILED_REGISTER="$FOLDER_END/failed_register" # web (verifikasi/register)
FOLDER_RELOGIN="$FOLDER_END/relogin" # transfer relogin (device A: tgz lama ke-rotate)
FOLDER_UNOFFICIAL="$FOLDER_END/unofficial" # akun ke-flag "klien tidak resmi" (di-filter)
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
FILE_FAILED_REGISTER="$FOLDER_AKUN/nomor_gagal_register.txt" # web (verifikasi)
FILE_RELOGIN="$FOLDER_AKUN/relogin.txt" # transfer relogin (device A)
FILE_UNOFFICIAL="$FOLDER_AKUN/unofficial.txt" # akun ke-flag klien tidak resmi
FILE_SESSION_MAP="$FOLDER_AKUN/session_map.txt" # nomor|session_id|file (buat poll)

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
# Port wa_gateway (node) buat /api/pair. Host-nya = host SERVER (PC sama),
# diturunkan otomatis -> GATEWAY. Jangan hardcode IP.
GATEWAY_PORT=4000
GATEWAY=""
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
# POST-LOGIN ACTION
# =====================
# Aksi setelah login sukses:
#   pairing = link akun ke server (linked device) -> kontrol via wa_gateway
#   send    = HP kirim pesan verifikasi (api/register), opsional poll status
#   both    = pairing dulu, lalu send
POST_LOGIN_ACTION="send"

# =====================
# REGISTER / VERIFY SEND (service node /api/register port 4500)
# =====================
# Host service = host SERVER (PC sama), diturunkan otomatis -> REGISTER.
REGISTER_PORT=4500
REGISTER=""
# Override manual opsional (skip derive): "http://192.168.0.23:4500"
REGISTER_FIXED=""
# user_reff: identitas pemilik akun. Sekarang konstanta (lihat resolve_user_reff;
# gampang di-upgrade ke "dari /claim atau nama file" tanpa ubah pemanggil).
USER_REFF="automation"
# Tunggu chat kebuka + tap kirim (detik).
SEND_MAX_WAIT=60
# Auto-recovery saat buka chat verif nyangkut (jamkot):
SEND_STUCK_AFTER=10   # detik nyangkut sebelum force-stop WA + buka ulang chat
SEND_MAX_RESTARTS=3   # maksimal restart WA per akun

# --- Cek status verifikasi (poll /api/check_status pakai session_id) ---
# on  = HP poll sampai verified/timeout, lapor hasil asli
# off = berhenti di 'terkirim' (lapor success begitu pesan terkirim)
VERIFY_CHECK="on"
POLL_MAX_WAIT=120   # 2 menit, samakan dgn timeout server
POLL_INTERVAL=5     # jeda antar cek (detik)
# Auto-flush pesan nyangkut (clock/pending) SETELAH tap kirim:
# kalau server masih 'pending' selama SEND_PENDING_AFTER detik, force-stop WA +
# buka ulang chat biar socket reconnect & antrian ke-flush (niru fix manual).
SEND_PENDING_AFTER=3      # detik pending sebelum kick WA (reconnect)
SEND_PENDING_MAX_KICKS=15  # maksimal kick per akun
# Daftar status (dari /api/check_status) yg dianggap BERHASIL terverifikasi.
# Sesuaikan kalau server pakai istilah lain. Status di luar ini + bukan
# pending/timeout/error -> tetap di-poll sampai cap waktu.
VERIFY_OK_STATUS="success verified"

# =====================
# TRANSFER RELOGIN (device-to-device, SIM-less)
# =====================
# Device A (reader): restore tgz lama -> HOME -> POST /ready -> tunggu WA pop
# bottom-sheet kode 6-digit -> baca -> POST /code -> ke-logout (tgz lama mati).
# Device B (target): GET /claim_target -> daftar ulang nomor -> layar kode ->
# poll GET /code -> input -> HOME -> re-backup -> POST /upload ke FRESH/.
#
# Device B selalu pakai WA personal (com.whatsapp); kalau akun bisnis muncul
# dialog "Alihkan ke Messenger" -> tap "Alihkan Sekarang" (katalog/label hilang).
RELOGIN_WA_PKG="com.whatsapp"
# Reader (A): total tunggu di HOME buat kode + logout sebelum nyerah (detik).
READER_MAX_WAIT=300
READER_POLL=2            # jeda antar dump layar A (detik)
# Target (B): total tunggu state-machine registrasi sampai HOME (detik).
TARGET_MAX_WAIT=300
# Target (B): tunggu files/key + files/me ke-flush setelah HOME sebelum backup.
# Transfer login nulis identity asinkron; force-stop dini bikin key/me hilang.
REBACKUP_LOGIN_WAIT=40
# Target (B): cara reset data WA sebelum daftar ulang.
#   pm_clear  = pm clear penuh + re-grant izin (paling bersih; rule-out residu).
#   selective = rm -rf subdir inti (lama; lebih cepat, izin tetap).
# Catatan: block "Login tidak tersedia"/"unofficial" itu anti-abuse device/IP,
# kemungkinan besar TETAP muncul walau pm clear -> ini buat mbuktiin bukan residu.
TARGET_CLEAR_MODE="pm_clear"
# Target (B): poll GET /code sampai kode siap.
CODE_POLL_MAX_WAIT=180
CODE_POLL_INTERVAL=3
# Nama acak buat layar RegisterName (device B). Dipisah spasi.
RELOGIN_NAME_POOL="Dimas Rian Aldi Bayu Reza Fajar Gilang Yoga Adit Nanda"

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
"$FOLDER_FAILED_PAIRING" \
"$FOLDER_FAILED_REGISTER" \
"$FOLDER_RELOGIN" \
"$FOLDER_UNOFFICIAL"