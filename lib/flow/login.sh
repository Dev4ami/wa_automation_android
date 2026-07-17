run_login_flow() {
    echo "START LOGIN"
    am start -n "$WA_PKG/com.whatsapp.Main"
    sleep 1
    log "START LOGIN"
    
    START_TIME=$(date +%s)
    MAX_WAIT="${LOGIN_MAX_WAIT:-180}"
    STUCK_SINCE=0
    STUCK_RESTARTS=0
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
            NOT_OFFICIAL)
                handle_not_official
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

            INITIALIZING)
                log "INITIALIZING (loading data)..."
            ;;

            *)
                log "MENUNGGU REDIRECT..."
            ;;

        esac

        # Auto-recovery: WA nyangkut saat inisialisasi/loading.
        # Tiru fix manual: force-stop + buka ulang WA.
        case "$STATE" in
            UNKNOWN|INITIALIZING)
                NOW=$(date +%s)
                [ "$STUCK_SINCE" -eq 0 ] && STUCK_SINCE=$NOW
                if [ $((NOW - STUCK_SINCE)) -ge "${STUCK_RESTART_AFTER:-25}" ]; then
                    if [ "$STUCK_RESTARTS" -lt "${STUCK_MAX_RESTARTS:-3}" ]; then
                        STUCK_RESTARTS=$((STUCK_RESTARTS+1))
                        log "STUCK ${STUCK_RESTART_AFTER:-25}s ($STATE) -> RESTART WA #$STUCK_RESTARTS"
                        am force-stop "$WA_PKG"
                        sleep 2
                        am start -n "$WA_PKG/com.whatsapp.Main"
                        sleep 2
                        STUCK_SINCE=0
                        START_TIME=$(date +%s)
                    fi
                fi
            ;;
            *)
                STUCK_SINCE=0
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