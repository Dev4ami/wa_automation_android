run_send_flow() {

    echo "START SEND"
    log "START SEND"

    handle_send_input || return 1

    START_TIME=$(date +%s)
    MAX_WAIT="${SEND_MAX_WAIT:-60}"

    while true; do
        if ! update_ui; then
            log "UI NOT READY, RETRY..."
            continue
        fi
        STATE=$(detect_screen)
        case "$STATE" in
            CHAT)
                if handle_send; then
                    finalize_send
                    return $?
                fi
                # tombol kirim belum siap, lanjut loop
            ;;

            NOT_ON_WA)
                handle_not_on_wa
                return 1
            ;;

            HOME)
                # chat belum kebuka, buka ulang link verifikasi (pin paket akun)
                am start -a android.intent.action.VIEW -d "$WA_LINK" "$WA_PKG" >/dev/null 2>&1
                sleep 3
                continue
            ;;

            BANNED)
                handle_banned
                return 1
            ;;

            LOGOUT)
                handle_logout
                return 1
            ;;

            *)
                log "MENUNGGU CHAT TERBUKA..."
            ;;

        esac

        NOW=$(date +%s)
        if [ $((NOW - START_TIME)) -gt $MAX_WAIT ]; then
            log "TIMEOUT SEND (chat/tap)"
            mv "$FILE" "$FOLDER_TIMEOUT/"
            log_number "timeout" "$PHONE"
            return 1
        fi

        sleep 1

    done
}
