
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
    echo "Pemakaian: agent.sh <send_loop|pairing_loop|pairing>"
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

    *)
        echo "Mode tidak dikenal: $MODE"
        echo "Pemakaian: agent.sh <send_loop|pairing_loop|pairing>"
        exit 1
    ;;

esac
