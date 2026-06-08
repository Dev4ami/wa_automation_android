run_login_flow() {
    echo "START LOGIN"
    am start -n com.whatsapp/com.whatsapp.Main
    sleep 1
    log "START LOGIN"
    
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
                handle_home
                return 0
            ;;
            PAIR)
                handle_pair
                return 0
            ;;
            RESTORE)
                handle_restore
                return 1
            ;;
            REGISTER)
                handle_register
                continue
            ;;
            VERIFY)
                handle_verify
                return 1
            ;;
            INPUT_NAME)
                handle_input_name
                continue
            ;;
            INPUT_EMAIL)
                handle_input_email
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
            WELCOME)
                handle_welcome
                continue
            ;;
            PHONE_PREFILL)
                handle_phone_prefill
                return 1
            ;;
            SYNCING_WHATSAPP)
                handle_syncing_data
                continue
            ;;
            POPUP_BACKUP_VALIDATION)
                handle_popup_backup_validation
                continue
            ;;
            BACKUP_VALIDATION)
                handle_backup_validation
                continue
            ;;
            SKIP_RESTORE)
                handle_skip_restore
                sleep 1
                continue
            ;;

            SKIP_RESTORE_CONFIRM)
                handle_skip_restore_confirm
                sleep 1
                continue
            ;;
            
            *)
                log "MENUNGGU REDIRECT..."
            ;;

        esac

        NOW=$(date +%s)
        if [ $((NOW - START_TIME)) -gt $MAX_WAIT ]; then
            log "TIMEOUT LOGIN"
            mv "$FILE" "$FOLDER_TIMEOUT/"
            log_number "timeout" "$PHONE"
            return 1
        fi

        sleep 1

    done
}