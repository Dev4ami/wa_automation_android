handle_pair_input() {

    log "REQUEST PAIR CODE"
    # Gateway diturunkan dari host SERVER (PC sama, port 4000). Tanpa hardcode IP.
    # Kalau gateway lagi down (transient), JANGAN tandai failed_pairing permanen;
    # return saja, biar file di-requeue oleh stale-timeout & dicoba ulang nanti.
    if ! ensure_server || [ -z "$GATEWAY" ]; then
        echo "GATEWAY TIDAK DITEMUKAN, skip (akan dicoba ulang)"
        log "GATEWAY TIDAK DITEMUKAN, skip pairing"
        return 1
    fi
    # --max-time besar: server auto-retry saat token cooldown (429). Kalau curl
    # timeout duluan, RESPONSE kosong -> ditangani sbg transient (requeue) di bawah.
    RESPONSE=$(curl -s --noproxy '*' --max-time 120 -X POST "$GATEWAY/api/pair" \
    -H "Content-Type: application/json" \
    --data "{\"phone\":\"$PHONE\"}")
    # log "RAW: $RESPONSE"
    MESSAGE=$(echo "$RESPONSE" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
    ERR=$(echo "$RESPONSE" | sed -n 's/.*"error":"\([^"]*\)".*/\1/p')
    if echo "$RESPONSE" | grep -q 'masukkan kode ini'; then
        CODE=$(echo "$RESPONSE" | sed -n 's/.*"code":"\([^"]*\)".*/\1/p')
        CODE_CLEAN=$(echo "$CODE" | tr -d '-')
        echo "PAIR CODE: $CODE"
        log "PAIR CODE: $CODE"
    elif echo "$RESPONSE" | grep -q 'Session sudah login dan aktif di server'; then
        echo "SUDAH AKTIF DI SERVER: $MESSAGE"
        log "SUDAH AKTIF DI SERVER: $MESSAGE"
        mv "$FILE" "$FOLDER_SUCCESS/"
        log_number "success" "$PHONE"
        return 1
    elif [ -z "$RESPONSE" ] || echo "$ERR" | grep -qE 'all_tokens_cooldown|no_token|token_expired'; then
        # TRANSIENT: token belum siap (cooldown 429 / expired / pool kosong / timeout).
        # JANGAN tandai failed_pairing -> jangan mv & jangan log_number, supaya
        # claim di-requeue server (stale-timeout) & nomor dicoba ulang nanti.
        echo "TUNDA PAIRING (token belum siap: ${ERR:-timeout}) -> requeue"
        log "TUNDA PAIRING (${ERR:-timeout}): $PHONE"
        return 1
    else
        echo "GAGAL GENERATE PAIR CODE: $MESSAGE"
        log "GAGAL PAIR: $MESSAGE"
        mv "$FILE" "$FOLDER_FAILED_PAIRING/"
        log_number "failed_pairing" "$PHONE"
        return 1
    fi

    sleep 2
    input text "$CODE_CLEAN"
    sleep 1
    input keyevent 66

    echo "Menunggu hasil login..."

}

