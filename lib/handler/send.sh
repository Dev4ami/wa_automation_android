# =====================================================================
# SEND / VERIFIKASI (api/register)
# ---------------------------------------------------------------------
# Setelah login HOME: minta wa_link verifikasi ke service register,
# buka chat WA (teks prefilled), tap kirim, lalu (opsional) poll status.
# Butuh global: PHONE, FILE (di-set run_restore_flow), REGISTER.
# =====================================================================

# Minta link verifikasi + buka chat WA. Set WA_LINK, REG_SESSION_ID.
handle_send_input() {
    log "REQUEST VERIFY LINK"
    WA_LINK=""
    # REGISTER diturunkan dari host SERVER. Kalau service down (transient),
    # JANGAN tandai gagal permanen; return 1 biar di-requeue & dicoba lagi.
    if ! ensure_server || [ -z "$REGISTER" ]; then
        echo "REGISTER SERVICE TIDAK DITEMUKAN, skip (akan dicoba ulang)"
        log "REGISTER TIDAK DITEMUKAN, skip send"
        return 1
    fi

    local REFF
    REFF=$(resolve_user_reff)
    WA_LINK=$(api_register "$PHONE" "$REFF")
    if [ -z "$WA_LINK" ]; then
        echo "GAGAL DAPAT VERIFY LINK ($PHONE): ${REG_ERROR:-unknown}"
        log "GAGAL REGISTER ($PHONE): ${REG_ERROR:-unknown}"
        mv "$FILE" "$FOLDER_FAILED_REGISTER/"
        log_number "failed_register" "$PHONE"
        return 1
    fi
    log "VERIFY LINK OK (session=$REG_SESSION_ID)"

    # Buka chat WA dgn teks verif prefilled. PIN ke paket akun ($WA_PKG)
    # biar gak ke-arah ke WA Business kalau dua-duanya keinstall.
    am start -a android.intent.action.VIEW -d "$WA_LINK" "$WA_PKG" >/dev/null 2>&1
    sleep 3
}

# Chat kebuka -> tap tombol kirim. Return 0 kalau ke-tap, 1 kalau belum siap.
handle_send() {
    log "CHAT SCREEN DETECTED"
    if exists_id "$WA_PKG:id/send"; then
        tap_by_id "$WA_PKG:id/send"
        sleep 2
        log "TAP KIRIM: $PHONE"
        return 0
    fi
    log "TOMBOL KIRIM BELUM ADA, tunggu..."
    return 1
}

# Nomor tujuan gak ada di WA (harusnya jarang; nomor verif tetap).
handle_not_on_wa() {
    log "NOMOR TUJUAN TIDAK ADA DI WA"
    echo "TARGET NOT ON WHATSAPP"
    mv "$FILE" "$FOLDER_FAILED_REGISTER/"
    log_number "failed_register" "$PHONE"
}

# Simpan session_id -> nomor (buat poll, walau beda proses).
persist_session() {
    [ -z "$REG_SESSION_ID" ] && return 0
    save_unique "$PHONE|$REG_SESSION_ID|$(basename "$FILE" 2>/dev/null)" "$FILE_SESSION_MAP"
}

# Cek 1 status termasuk daftar sukses (VERIFY_OK_STATUS).
_is_verify_ok() {
    local s
    for s in $VERIFY_OK_STATUS; do
        [ "$1" = "$s" ] && return 0
    done
    return 1
}

# Poll /api/check_status sampai verified / timeout / error / cap waktu.
# return 0 = verified, 2 = timeout/belum terdaftar, 1 = error
poll_verification() {
    local SID="$1" START NOW ST
    START=$(date +%s)
    while true; do
        ST=$(api_check_status "$SID")
        if _is_verify_ok "$ST"; then
            log "VERIFY OK status=$ST ($PHONE)"
            return 0
        fi
        case "$ST" in
            ""|pending)
                log "VERIFY PENDING ($PHONE)"
            ;;
            timeout)
                log "VERIFY TIMEOUT-server ($PHONE)"
                return 2
            ;;
            error)
                log "VERIFY ERROR-server ($PHONE)"
                return 1
            ;;
            *)
                # Status tak dikenal: jangan asal sukses, tetap tunggu sampai cap.
                log "VERIFY status tak dikenal=$ST, tetap tunggu ($PHONE)"
            ;;
        esac
        NOW=$(date +%s)
        if [ $((NOW - START)) -ge "${POLL_MAX_WAIT:-120}" ]; then
            log "VERIFY TIMEOUT-client 2m ($PHONE)"
            return 2
        fi
        sleep "${POLL_INTERVAL:-5}"
    done
}

# Setelah terkirim: simpan sesi, lalu (opsional) poll status & lapor hasil.
finalize_send() {
    persist_session

    if [ "${VERIFY_CHECK:-off}" = "on" ] && [ -n "$REG_SESSION_ID" ]; then
        poll_verification "$REG_SESSION_ID"
        if [ "$?" -eq 0 ]; then
            echo "VERIFIED"
            mv "$FILE" "$FOLDER_SUCCESS/"
            log_number "success" "$PHONE"
            return 0
        fi
        echo "NOT VERIFIED (timeout/belum terdaftar)"
        mv "$FILE" "$FOLDER_FAILED_REGISTER/"
        log_number "failed_register" "$PHONE"
        return 1
    fi

    # v1: cukup 'terkirim'
    echo "VERIFY MESSAGE SENT"
    mv "$FILE" "$FOLDER_SUCCESS/"
    log_number "success" "$PHONE"
    return 0
}
