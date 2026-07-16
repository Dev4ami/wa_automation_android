
handle_home() {
    log "HOME DETECTED"
    echo "HOME"
}

handle_home_pairing() {
    am start -n "$WA_PKG/com.whatsapp.companiondevice.LinkedDevicesEnterCodeActivity"
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
    # if exists_id "$WA_PKG:id/registration_phone"; then
    #     tap_input_field "$WA_PKG:id/registration_phone"
    #     echo "harusnya tap filed disini"
    #     sleep 0.3
    #     input text "$NUMBER"
    #     sleep 0.5
    # fi
    # if exists_id "$WA_PKG:id/registration_submit"; then
    #     tap_by_id "$WA_PKG:id/registration_submit"
    #     return
    # fi
    # if exists_id "$WA_PKG:id/continue_button"; then
    #     tap_by_id "$WA_PKG:id/continue_button"
    #     return
    # fi
}

handle_verify() {
    log "VERIFY SCREEN DETECTED"
    report_result "verify" "$PHONE" "$(basename "$FILE" 2>/dev/null)"
}

handle_input_name() {
    log "INPUT NAME SCREEN DETECTED"
    if exists_id "$WA_PKG:id/registration_name"; then
        # Nama acak dari pool (device B transfer). Fallback kalau RANDOM/pool kosong.
        local NAME
        set -- ${RELOGIN_NAME_POOL:-Dimas Rian Aldi Bayu Reza}
        if [ "$#" -gt 0 ]; then
            local IDX=$(( (${RANDOM:-0} % $#) + 1 ))
            eval "NAME=\${$IDX}"
        fi
        [ -z "$NAME" ] && NAME="Dimas"
        tap_by_id "$WA_PKG:id/registration_name"
        sleep 0.5
        input text "$NAME"
        tap_by_id "$WA_PKG:id/register_name_accept"
        return
    fi
}

handle_input_email() {
    log "INPUT EMAIL SCREEN DETECTED AND SKIP"
     if exists_id "$WA_PKG:id/register_email_skip"; then
        tap_by_id "$WA_PKG:id/register_email_skip"
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
    echo "ACCOUNT LOGGED OUT"
    mv "$FILE" "$FOLDER_LOGOUT/"
    log_number "logout" "$PHONE"
    if exists_id "$WA_PKG:id/re_login_button"; then
        tap_by_id "$WA_PKG:id/re_login_button"
        return
    fi
    if exists_id "$WA_PKG:id/primary_button"; then
        tap_by_id "$WA_PKG:id/primary_button"
        return
    fi
}

handle_welcome() {
    log "WELCOME SCREEN DETECTED"
    tap_by_id "$WA_PKG:id/eula_accept"
}


handle_phone_prefill() {
    log "PHONE PREFILL SCREEN DETECTED"
    echo "AKUN BELUM LOGIN, BUTUH VERIFIKASI"
    # if exists_id "android:id/button2"; then
    #     tap_by_id "android:id/button2"
    #     return
    # fi
    mv "$FILE" "$FOLDER_LOGOUT/"
    log_number "logout" "$PHONE"
}

# =====================================================================
# TRANSFER RELOGIN handlers (device A reader + device B target)
# =====================================================================

# Device B: isi nomor nasional (tanpa 62) ke registration_phone lalu BERIKUTNYA.
# registration_cc sudah prefilled 62. Posisi BERIKUTNYA bergeser saat keyboard
# kebuka -> dump ulang sebelum tap (tap_by_id baca bounds dari $UI_XML terbaru).
handle_input_number() {
    log "INPUT NUMBER SCREEN DETECTED (device B)"
    local NAT="${PHONE#62}"
    if exists_id "$WA_PKG:id/registration_phone"; then
        tap_input_field "$WA_PKG:id/registration_phone"
        sleep 0.3
        input text "$NAT"
        sleep 0.5
        update_ui   # keyboard kebuka -> BERIKUTNYA pindah, refresh bounds
        if exists_id "$WA_PKG:id/registration_submit"; then
            tap_by_id "$WA_PKG:id/registration_submit"
        elif exists_id "$WA_PKG:id/button_view"; then
            tap_by_id "$WA_PKG:id/button_view"
        fi
        return
    fi
}

# Device B: dialog konfirmasi nomor (setelah BERIKUTNYA) -> OK (button1).
handle_confirm_number() {
    log "CONFIRM NUMBER DIALOG DETECTED (device B)"
    if exists_id "android:id/button1"; then
        tap_by_id "android:id/button1"
        return
    fi
}

# Device B: dialog autofill "Lanjutkan dengan" (Google account picker) nutupin
# field nomor. Tap Batal (button2) buat tolak saran -> balik ke input manual,
# lalu handle_input_number isi nomor target. JANGAN Lanjut (button1): itu bakal
# daftar nomor saran yg SALAH, bukan nomor target.
handle_prefill_picker() {
    log "PREFILL PICKER (Lanjutkan dengan) -> Batal"
    if exists_id "android:id/button2"; then
        tap_by_id "android:id/button2"
        return
    fi
}

# Device B: dialog biz->personal -> "Alihkan Sekarang" (button1). Katalog/label
# akun bisnis hilang permanen (keputusan user: tetap lanjut).
handle_switch_to_messenger() {
    log "SWITCH TO MESSENGER DIALOG (biz->personal) -> Alihkan Sekarang"
    if exists_id "android:id/button1"; then
        tap_by_id "android:id/button1"
        return
    fi
}

# Device B: layar input kode transfer. Poll server (kode dibaca device A) sampai
# 6-digit siap, lalu ketik ke verify_sms_code_input (auto-advance).
handle_enter_transfer_code() {
    log "ENTER TRANSFER CODE SCREEN DETECTED (device B)"
    local WAIT=0 CODE="" STEP="${CODE_POLL_INTERVAL:-3}"
    while [ "$WAIT" -lt "${CODE_POLL_MAX_WAIT:-180}" ]; do
        CODE=$(get_transfer_code)
        if echo "$CODE" | grep -qE '^[0-9]{6}$'; then
            log "GOT TRANSFER CODE FROM SERVER: $CODE"
            break
        fi
        sleep "$STEP"
        WAIT=$(( WAIT + STEP ))
    done
    if ! echo "$CODE" | grep -qE '^[0-9]{6}$'; then
        log "TRANSFER CODE TIMEOUT (device A belum kirim kode)"
        return 1
    fi
    if exists_id "$WA_PKG:id/verify_sms_code_input"; then
        tap_by_id "$WA_PKG:id/verify_sms_code_input"
        sleep 0.3
        input text "$CODE"
        sleep 1
        return 0
    fi
    return 1
}

# Device A: bottom-sheet kode transfer muncul -> baca 6 digit -> kirim ke server.
handle_show_transfer_code() {
    log "SHOW TRANSFER CODE BOTTOM SHEET DETECTED (device A)"
    local CODE
    CODE=$(read_transfer_code)
    if [ -z "$CODE" ]; then
        log "KODE BELUM TERBACA UTUH (retry)"
        return 1
    fi
    log "TRANSFER CODE READ: $CODE"
    post_transfer_code "$CODE"
    return 0
}



handle_syncing_data() {
    log "SYNCING WHATSAPP DATA"
    sleep 2
}

handle_skip_restore() {
    log "RESTORE CHAT HISTORY ERROR - SKIP RESTORE"
    if exists_id "android:id/button2"; then
        tap_by_id "android:id/button2"
        return
    fi
}

handle_skip_restore_confirm() {
    log "CONFIRM SKIP RESTORE DIALOG DETECTED"
    if exists_id "android:id/button1"; then
        tap_by_id "android:id/button1"
        return
    fi
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
    if exists_id "$WA_PKG:id/skip_button"; then
        tap_by_id "$WA_PKG:id/skip_button"
        sleep 0.5
        input tap 494 778
        return
    fi
}


handle_backup_validation() {
    log "BACKUP VALIDATION SCREEN DETECTED"
    if exists_id "$WA_PKG:id/gdrive_new_user_setup_not_now_btn"; then
        tap_by_id "$WA_PKG:id/gdrive_new_user_setup_not_now_btn"
        return
    fi
}


# handle_scam_warning() {
#     log "SCAM WARNING DETECTED"
#     echo "SCAM WARNING: AKUN MUNGKIN DIBANNED"
#     mv "$FILE" "$FOLDER_BANNED/"
#     log_number "banned" "$PHONE"
# }