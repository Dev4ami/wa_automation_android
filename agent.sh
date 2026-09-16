
# Fallback binary termux: agent jalan via `su -c` dgn PATH sistem (tanpa termux),
# jadi tool yg cuma ada di termux (curl di sebagian device, sqlite3 buat listen_ag)
# ke-resolve "not found". Bikin wrapper HANYA kalau tool absent dari PATH, tunjuk
# ke binary termux dgn LD_LIBRARY_PATH SCOPED di panggilan (env prefix, BUKAN
# export global) -> am/pm/dumpsys/tar sistem tetap pakai libc sistem. Device yg
# punya versi /system/bin tak kesentuh.
_TERMUX_LIB="/data/data/com.termux/files/usr/lib"
if ! command -v curl >/dev/null 2>&1; then
    _TERMUX_CURL="/data/data/com.termux/files/usr/bin/curl"
    if [ -x "$_TERMUX_CURL" ]; then
        curl() {
            LD_LIBRARY_PATH="$_TERMUX_LIB" "$_TERMUX_CURL" "$@"
        }
    fi
fi
if ! command -v sqlite3 >/dev/null 2>&1; then
    _TERMUX_SQLITE="/data/data/com.termux/files/usr/bin/sqlite3"
    if [ -x "$_TERMUX_SQLITE" ]; then
        sqlite3() {
            LD_LIBRARY_PATH="$_TERMUX_LIB" "$_TERMUX_SQLITE" "$@"
        }
    fi
fi

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$BASE_DIR/config.sh"


for file in $BASE_DIR/lib/*.sh; do . "$file"; done
for file in $BASE_DIR/utils/*.sh; do . "$file"; done
for file in $BASE_DIR/lib/flow/*.sh; do . "$file"; done
for file in $BASE_DIR/lib/handler/*.sh; do . "$file"; done

# Mode dari argumen: agent.sh <send_loop|pairing_loop|pairing>
MODE="$1"

if [ -z "$MODE" ]; then
    echo "Mode wajib diisi."
    echo "Pemakaian: agent.sh <send_loop|pairing_loop|pairing|listen_ag_loop|listen_ag|relogin_reader|relogin_target>"
    exit 1
fi

case "$MODE" in

    # Loop: restore + login + KIRIM pesan verifikasi (api/register).
    # Sumber akun dari SERVER QUEUE (claim_account).
    send_loop)
        while true; do
            log "++++++++++++++++++++++++++++++++++++++++"
            rm -f "$BASE_DIR/window_dump.xml"
            purge_local_tgz
            run_restore_flow || continue
            run_login_flow   || continue
            run_send_flow    || continue
        done
    ;;

    # Loop: restore + login + PAIRING (linked device / WA web).
    pairing_loop)
        while true; do
            log "++++++++++++++++++++++++++++++++++++++++"
            rm -f "$BASE_DIR/window_dump.xml"
            purge_local_tgz
            run_restore_flow || continue
            run_login_flow   || continue
            run_pairing_flow || continue
        done
    ;;

    # Sekali jalan: restore + login + pairing 1 akun.
    pairing)
        log "++++++++++++++++++++++++++++++++++++++++"
        rm -f "$BASE_DIR/window_dump.xml"
        run_restore_flow || exit 1
        run_login_flow   || exit 1
        run_pairing_flow || exit 1
    ;;

    # Loop: restore + login sampai HOME, lalu OTP AUTONOMOUS (listen_ag).
    listen_ag_loop)
        CLAIM_APP=alfagift   # ambil akun dari MASTER_ALFAGIFT (bukan MASTER umum)
        while true; do
            log "++++++++++++++++++++++++++++++++++++++++"
            rm -f "$BASE_DIR/window_dump.xml"
            purge_local_tgz
            run_restore_flow   || continue
            run_login_flow     || continue
            run_listen_ag_flow || continue
        done
    ;;

    # Sekali jalan: restore + login sampai HOME, lalu OTP autonomous 1 akun.
    listen_ag)
        log "++++++++++++++++++++++++++++++++++++++++"
        rm -f "$BASE_DIR/window_dump.xml"
        purge_local_tgz
        CLAIM_APP=alfagift   # ambil akun dari MASTER_ALFAGIFT (bukan MASTER umum)
        run_restore_flow   || exit 1
        run_login_flow     || exit 1
        run_listen_ag_flow || exit 1
    ;;

    # TRANSFER RELOGIN — DEVICE A (reader): restore tgz lama + login sampai HOME,
    # lalu jadi sumber kode transfer buat device B. Akun ke-logout = tgz lama mati.
    relogin_reader)
        while true; do
            log "++++++++++++++++++++++++++++++++++++++++"
            rm -f "$BASE_DIR/window_dump.xml"
            purge_local_tgz
            run_restore_flow || continue
            run_login_flow   || continue   # return 0 cuma kalau HOME; akun mati self-report
            run_reader_flow  || continue
        done
    ;;

    # TRANSFER RELOGIN — DEVICE B (target): ambil akun ready (pairing), daftar
    # ulang nomornya, input kode dari A, sampai HOME, re-backup -> upload FRESH/.
    relogin_target)
        while true; do
            log "++++++++++++++++++++++++++++++++++++++++"
            rm -f "$BASE_DIR/window_dump.xml"
            run_target_flow || continue   # sudah termasuk claim_target + re-backup + upload
        done
    ;;

    *)
        echo "Mode tidak dikenal: $MODE"
        echo "Pemakaian: agent.sh <send_loop|pairing_loop|pairing|listen_ag_loop|listen_ag|relogin_reader|relogin_target>"
        exit 1
    ;;

esac
