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
FOLDER_WA_SYMLINK="/data/data/com.whatsapp"
FOLDER_WA="/data/user/0/com.whatsapp"
# FOLDER_WA_SYMLINK="/data/data/com.whatsapp.w4b"
# FOLDER_WA="/data/user/0/com.whatsapp.w4b"
TEMP="/data/local/tmp/restore_wa"

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