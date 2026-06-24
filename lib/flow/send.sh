run_send_flow() {

    echo "START SEND"
    log "START SEND"

    handle_send_input || return 1

    START_TIME=$(date +%s)
    MAX_WAIT="${SEND_MAX_WAIT:-60}"
    STUCK_SINCE=0
    SEND_RESTARTS=0

    while true; do
        if ! update_ui; then
            log "UI NOT READY, RETRY..."
            continue
        fi
        STATE=$(detect_screen)
        case "$STATE" in
            CHAT)
                STUCK_SINCE=0
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

            BANNED)
                handle_banned
                return 1
            ;;

            LOGOUT)
                handle_logout
                return 1
            ;;

            *)
                # Chat belum kebuka (HOME / "Mencari..." / picker / UNKNOWN).
                log "MENUNGGU CHAT TERBUKA... ($STATE)"
            ;;

        esac

        # --- Auto-recovery jamkot ---
        # Chat gak kebuka-buka: tunggu SEND_STUCK_AFTER detik, kalau masih
        # nyangkut -> force-stop WA + buka ulang chat, lalu tunggu lagi.
        case "$STATE" in
            CHAT|NOT_ON_WA|BANNED|LOGOUT)
                STUCK_SINCE=0
            ;;
            *)
                NOW=$(date +%s)
                [ "$STUCK_SINCE" -eq 0 ] && STUCK_SINCE=$NOW
                if [ $((NOW - STUCK_SINCE)) -ge "${SEND_STUCK_AFTER:-10}" ]; then
                    if [ "$SEND_RESTARTS" -lt "${SEND_MAX_RESTARTS:-3}" ]; then
                        SEND_RESTARTS=$((SEND_RESTARTS+1))
                        log "STUCK ${SEND_STUCK_AFTER:-10}s ($STATE) -> RESTART WA + buka chat #$SEND_RESTARTS"
                        am force-stop "$WA_PKG"
                        sleep 2
                        am start -a android.intent.action.VIEW -d "$WA_LINK" "$WA_PKG" >/dev/null 2>&1
                        sleep 3
                        STUCK_SINCE=0
                        START_TIME=$(date +%s)
                    fi
                fi
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
