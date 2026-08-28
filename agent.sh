
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
