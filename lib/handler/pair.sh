handle_pair_input() {

    log "REQUEST PAIR CODE"
    RESPONSE=$(curl -s -X POST http://wa.dev4ami.my.id/api/pair \
    -H "Content-Type: application/json" \
    --data "{\"phone\":\"$PHONE\"}")
    # log "RAW: $RESPONSE"
    MESSAGE=$(echo "$RESPONSE" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
    if echo "$RESPONSE" | grep -q 'masukkan kode ini'; then
        CODE=$(echo "$RESPONSE" | sed -n 's/.*"code":"\([^"]*\)".*/\1/p')
        CODE_CLEAN=$(echo "$CODE" | tr -d '-')
        echo "PAIR CODE: $CODE"
        log "PAIR CODE: $CODE"
    elif echo "$RESPONSE" | grep -q 'Session sudah login dan aktif di server'; then
        echo "GAGAL GENERATE PAIR CODE: $MESSAGE"
        log "GAGAL GENERATE PAIR CODE: $MESSAGE"
        mv "$FILE" "$FOLDER_SUCCESS/"
        log_number "success" "$PHONE"
        return 1
    else
        MESSAGE=$(echo "$RESPONSE" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
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

