
extract_otp_code() {
    local TEXT="$1" CODE
    # 1) *NNNNNN* — ambil 6 digit di antara bintang.
    CODE=$(printf '%s' "$TEXT" | grep -oE '\*[0-9]{6}\*' | head -n1 | tr -d '*')
    if [ -n "$CODE" ]; then
        echo "$CODE"
        return 0
    fi


    CODE=$(printf ' %s ' "$TEXT" \
        | grep -oE '[^0-9][0-9]{6}[^0-9]' \
        | head -n1 \
        | grep -oE '[0-9]{6}')
    if [ -n "$CODE" ]; then
        echo "$CODE"
        return 0
    fi
    return 1
}

otp_new_texts() {
    local DB="$1" LAST="$2" SQL
    if [ "$LISTEN_AG_SCHEMA" = "new" ]; then
        SQL="SELECT m._id || char(9) ||
               replace(replace(replace(COALESCE(NULLIF(m.text_data,''), mt.content_text_data),char(10),' '),char(13),' '),char(9),' ')
             FROM message m
             JOIN chat c ON m.chat_row_id=c._id
             JOIN jid  j ON c.jid_row_id=j._id
             LEFT JOIN message_template mt ON mt.message_row_id=m._id
             WHERE m.from_me=0 AND m._id>$LAST
                   AND j.raw_string NOT LIKE '%@g.us'
                   AND COALESCE(NULLIF(m.text_data,''), mt.content_text_data) IS NOT NULL
             ORDER BY m._id;"
    else
        SQL="SELECT _id || char(9) ||
               replace(replace(replace(data,char(10),' '),char(13),' '),char(9),' ')
             FROM messages
             WHERE key_from_me=0 AND _id>$LAST AND data IS NOT NULL
                   AND key_remote_jid NOT LIKE '%@g.us'
             ORDER BY _id;"
    fi
    sqlite3 -separator "$(printf '\t')" "$DB" "$SQL" 2>/dev/null
}

run_listen_ag_flow() {
    echo "START LISTEN_AG (OTP autonomous)"
    log "START LISTEN_AG untuk $PHONE"

    local DB="$FOLDER_WA/databases/msgstore.db"
    if [ ! -e "$DB" ]; then
        log "LISTEN_AG: DB tidak ada: $DB"
        echo "DB msgstore.db tidak ditemukan"
        return 1
    fi
    if ! command -v sqlite3 >/dev/null 2>&1; then
        log "LISTEN_AG: sqlite3 tidak terpasang (jalankan update.sh / pkg install sqlite)"
        echo "sqlite3 belum terpasang -> jalankan update (up.sh) atau: pkg install sqlite"
        return 1
    fi


    if sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='message'" 2>/dev/null | grep -q '^message$'; then
        LISTEN_AG_SCHEMA="new"
    else
        LISTEN_AG_SCHEMA="old"
    fi
    log "LISTEN_AG SCHEMA: $LISTEN_AG_SCHEMA"


    local TBL; [ "$LISTEN_AG_SCHEMA" = "new" ] && TBL="message" || TBL="messages"
    local LAST
    LAST=$(sqlite3 "$DB" "SELECT COALESCE(MAX(_id),0) FROM $TBL" 2>/dev/null)
    echo "$LAST" | grep -qE '^[0-9]+$' || LAST=0
    log "LISTEN_AG baseline _id>$LAST"

    local OTP_ID OTP_ERR
    if OTP_ID=$(otp_get "$PHONE"); then
        echo "OTP DIMINTA ($PHONE), tunggu masuk..."
    else
        OTP_ERR="$OTP_ID"
        if printf '%s' "$OTP_ERR" | grep -qiE 'sandi|password|ditutup'; then
            log "LISTEN_AG: akun sudah terdaftar (minta sandi) -> $OTP_AG_STATUS_TERDAFTAR ($PHONE)"
            echo "SUDAH TERDAFTAR: $OTP_ERR -> $OTP_AG_STATUS_TERDAFTAR"
            log_number "$OTP_AG_STATUS_TERDAFTAR" "$PHONE"
            return 0
        fi
        log "LISTEN_AG: get_otp gagal ($OTP_ERR) -> requeue (tak report)"
        echo "GET_OTP GAGAL: $OTP_ERR"
        return 1
    fi


    local START NOW TMP ID TEXT CODE SET_OUT
    START=$(date +%s)
    TMP="${TMPDIR:-/data/local/tmp}/wa_otp.$$"
    while true; do
        otp_new_texts "$DB" "$LAST" > "$TMP" 2>/dev/null
        while IFS="$(printf '\t')" read -r ID TEXT; do
            [ -z "$ID" ] && continue
            LAST="$ID"
            if CODE=$(extract_otp_code "$TEXT"); then
                log "LISTEN_AG: OTP terdeteksi ($CODE) dari pesan _id=$ID"
                echo "OTP TERDETEKSI: $CODE"
                if SET_OUT=$(otp_set "$OTP_ID" "$CODE"); then
                    rm -f "$TMP"
                    log_number "$OTP_AG_STATUS_SUCCESS" "$PHONE"
                    echo "OTP VERIFIED -> $OTP_AG_STATUS_SUCCESS ($PHONE)"
                    return 0
                else

                    rm -f "$TMP"
                    log "LISTEN_AG: set_otp gagal ($SET_OUT) -> requeue (tak report)"
                    echo "SET_OTP GAGAL: $SET_OUT"
                    return 1
                fi
            fi
        done < "$TMP"

        NOW=$(date +%s)
        if [ $((NOW - START)) -gt "${OTP_AG_MAX_WAIT:-120}" ]; then
            rm -f "$TMP"
            log "LISTEN_AG TIMEOUT: OTP tak masuk dlm ${OTP_AG_MAX_WAIT:-120}s -> requeue"
            echo "TIMEOUT: OTP tidak masuk"
            return 1
        fi
        sleep "${OTP_AG_POLL:-3}"
    done
}
