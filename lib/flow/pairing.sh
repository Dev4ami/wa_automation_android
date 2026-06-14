run_pairing_flow() {

    echo "START PAIRING"
    log "START PAIRING"
    
    handle_home_pairing
    handle_pair_input || return 1


    START_TIME=$(date +%s)
    MAX_WAIT=60
    
    while true; do
        if ! update_ui; then
            log "UI NOT READY, RETRY..."
            continue
        fi
        STATE=$(detect_screen)
        case "$STATE" in
            HOME)
                am start -n "$WA_PKG/com.whatsapp.companiondevice.LinkedDevicesActivity"
                sleep 3
                continue
            ;;

           PAIR_FAILED)
                handle_pair_failed
                return 1
            ;;

           PAIR_SUCCESS)
                handle_pair_success
                return 0
            ;;

            PAIR)
                handle_pair
                continue
            ;;

            RESTORE)
                handle_restore
                return 1
            ;;
            REGISTER)
                handle_register
                return 1
            ;;
            VERIFY)
                handle_verify
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
            WELCOME)
                handle_welcome
                return 1
            ;;
            PHONE_PREFILL)
                handle_phone_prefill
                return 1
            ;;

            *)
                log "MENUNGGU REDIRECT..."
            ;;

        esac

        NOW=$(date +%s)
        if [ $((NOW - START_TIME)) -gt $MAX_WAIT ]; then
            log "TIMEOUT PAIRING"
            mv "$FILE" "$FOLDER_TIMEOUT/"
            log_number "timeout" "$PHONE"
            return 1
        fi

        sleep 1

    done
}