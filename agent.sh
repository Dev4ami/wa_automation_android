
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$BASE_DIR/config.sh"


for file in $BASE_DIR/lib/*.sh; do . "$file"; done
for file in $BASE_DIR/utils/*.sh; do . "$file"; done
for file in $BASE_DIR/lib/flow/*.sh; do . "$file"; done
for file in $BASE_DIR/lib/handler/*.sh; do . "$file"; done

MODE="restore_login_pairing_wa_web_loop"

case "$MODE" in

    restore_login_pairing_wa_web)
        log "++++++++++++++++++++++++++++++++++++++++"
        rm "$BASE_DIR/window_dump.xml"
        run_restore_flow || exit 1
        run_login_flow || exit 1
        run_pairing_flow || exit 1
    ;;

    restore_login_pairing_wa_web_loop)
        while true; do
            log "++++++++++++++++++++++++++++++++++++++++"
            rm "$BASE_DIR/window_dump.xml"
            run_restore_flow || continue 1
            run_login_flow || continue 1
            run_pairing_flow || continue 1
        done
    ;;

    restore_login_register_klik_wa_web)
        log "++++++++++++++++++++++++++++++++++++++++"
        rm "$BASE_DIR/window_dump.xml"
        run_restore_flow || exit 1
        run_login_flow || exit 1
        # run_register_klik_flow || exit 1
    ;;

    restore_login_request_review)
        log "++++++++++++++++++++++++++++++++++++++++"
        rm "$BASE_DIR/window_dump.xml"
        run_restore_flow || exit 1
        run_login_flow || exit 1
        # run_request_review_flow || exit 1
    ;;

    restore_login_cek_wa)
        log "++++++++++++++++++++++++++++++++++++++++"
        rm /storage/emulated/0/window_dump.xml
        run_restore_flow || exit 1
        run_login_flow || exit 1
        # run_request_review_flow || exit 1
    ;;

    *)
        log "UNKNOWN MODE"
        exit 1
    ;;

esac