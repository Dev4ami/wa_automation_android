
handle_home() {
    log "HOME DETECTED"
    echo "HOME"
}

handle_home_pairing() {
    am start -n com.whatsapp/com.whatsapp.companiondevice.LinkedDevicesEnterCodeActivity
    sleep 2
    log "PAIRING CODE SCREEN DETECTED"
}

handle_pair() {
    log "PAIR SCREEN DETECTED"
}

handle_restore() {
    log "RESTORE SCREEN"
    mv "$FILE" "$FOLDER_RESTORE/"
    log_number "restore" "$PHONE"
}

handle_register() {
    log "REGISTER SCREEN DETECTED"
    echo "AKUN BELUM LOGIN"
    mv "$FILE" "$FOLDER_LOGOUT/"
    log_number "logout" "$PHONE"
    # if exists_id "com.whatsapp:id/registration_phone"; then
    #     tap_input_field "com.whatsapp:id/registration_phone"
    #     echo "harusnya tap filed disini"
    #     sleep 0.3
    #     input text "$NUMBER"
    #     sleep 0.5
    # fi
    # if exists_id "com.whatsapp:id/registration_submit"; then
    #     tap_by_id "com.whatsapp:id/registration_submit"
    #     return
    # fi
    # if exists_id "com.whatsapp:id/continue_button"; then
    #     tap_by_id "com.whatsapp:id/continue_button"
    #     return
    # fi
}

handle_verify() {
    log "VERIFY SCREEN DETECTED"
}

handle_input_name() {
    log "INPUT NAME SCREEN DETECTED"
    if exists_id "com.whatsapp:id/registration_name"; then
        tap_by_id "com.whatsapp:id/registration_name"
        sleep 0.5
        input text "Slolok"
        tap_by_id "com.whatsapp:id/register_name_accept"
        return
    fi
}

handle_input_email() {
    log "INPUT EMAIL SCREEN DETECTED AND SKIP"
     if exists_id "com.whatsapp:id/register_email_skip"; then
        tap_by_id "com.whatsapp:id/register_email_skip"
        return
    fi
}

handle_banned() {
    log "ACCOUNT BANNED SCREEN"
    echo "ACCOUNT BANNED"
    mv "$FILE" "$FOLDER_BANNED/"
    log_number "banned" "$PHONE"
}

handle_logout() {
    log "LOGOUT SCREEN DETECTED"
    mv "$FILE" "$FOLDER_BANNED/"
    log_number "banned" "$PHONE"
    if exists_id "com.whatsapp:id/re_login_button"; then
        tap_by_id "com.whatsapp:id/re_login_button"
        return
    fi
    if exists_id "com.whatsapp:id/primary_button"; then
        tap_by_id "com.whatsapp:id/primary_button"
        return
    fi
}

handle_welcome() {
    log "WELCOME SCREEN DETECTED"
    tap_by_id "com.whatsapp:id/eula_accept"
}


handle_phone_prefill() {
    log "PHONE PREFILL SCREEN DETECTED"
    echo "AKUN BELUM LOGIN, BUTUH VERIFIKASI"
    if exists_id "android:id/button2"; then
        tap_by_id "android:id/button2"
        return
    fi
    # mv "$FILE" "$FOLDER_LOGOUT/"
    # log_number "logout" "$PHONE"
}

# handle_input_number() {
#     log "INPUT NUMBER SCREEN DETECTED"
#     echo "MELAKUKAN VERIFIKASI NOMOR"
#     if exists_id "android:id/button2"; then
#         tap_by_id "android:id/button2"
#         return
#     fi
#     # mv "$FILE" "$FOLDER_LOGOUT/"
#     # log_number "logout" "$PHONE"
# }



handle_syncing_data() {
    log "SYNCING WHATSAPP DATA"
    sleep 2
}

handle_pair_failed() {
    log "PAIRING FAILED SCREEN DETECTED"
    echo "PAIRING FAILED"
    mv "$FILE" "$FOLDER_FAILED_PAIRING/"
    log_number "failed_pairing" "$PHONE"
}

handle_pair_success() {
    log "PAIRING SUCCESS SCREEN DETECTED"
    echo "PAIRING SUCCESS"
    mv "$FILE" "$FOLDER_SUCCESS/"
    log_number "success" "$PHONE"
}

handle_popup_backup_validation() {
    log "POPUP BACKUP VALIDATION SCREEN DETECTED"
    if exists_id "android:id/button2"; then
        tap_by_id "android:id/button2"
        return
    fi
    if exists_id "com.whatsapp:id/skip_button"; then
        tap_by_id "com.whatsapp:id/skip_button"
        sleep 0.5
        input tap 494 778
        return
    fi
}


handle_backup_validation() {
    log "BACKUP VALIDATION SCREEN DETECTED"
    if exists_id "com.whatsapp:id/gdrive_new_user_setup_not_now_btn"; then
        tap_by_id "com.whatsapp:id/gdrive_new_user_setup_not_now_btn"
        return
    fi
}


# handle_scam_warning() {
#     log "SCAM WARNING DETECTED"
#     echo "SCAM WARNING: AKUN MUNGKIN DIBANNED"
#     mv "$FILE" "$FOLDER_BANNED/"
#     log_number "banned" "$PHONE"
# }