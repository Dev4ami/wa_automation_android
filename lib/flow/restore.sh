
prepare_backup_file() {
    # Sumber file = server queue PC, bukan folder lokal lagi.
    # claim_account: ambil 1 akun dari MASTER + download ke FOLDER_AKUN.
    claim_account || return 1
}

# Deteksi package dari hasil extract di TEMP, lalu set WA_PKG + path global.
# Cek w4b dulu (com.whatsapp.w4b memuat substring com.whatsapp).
detect_wa_pkg() {
    if [ -d "$TEMP/data/data/com.whatsapp.w4b" ] || \
       [ -d "$TEMP/data/user/0/com.whatsapp.w4b" ]; then
        WA_PKG="com.whatsapp.w4b"
    else
        WA_PKG="com.whatsapp"
    fi
    FOLDER_WA_SYMLINK="/data/data/$WA_PKG"
    FOLDER_WA="/data/user/0/$WA_PKG"
    log "DETECTED WA PACKAGE: $WA_PKG"
}


extract_phone_v1() {
    local FILE="$1"
    local PHONE
    PHONE=$(basename "$FILE" | grep -oE '62[0-9]{9,15}')
    if [ -z "$PHONE" ]; then
        log "FORMAT NOMOR TIDAK DITEMUKAN"
        mv "$FILE" "$FOLDER_INVALID/"
        return 1
    fi
    echo "$PHONE"
}

extract_phone() {
    local DIR="$1"
    local PREF_FILE
    PREF_FILE=$(find "$DIR" -path "*/$WA_PKG/shared_prefs/${WA_PKG}_preferences_light.xml" | head -n1)
    if [ -z "$PREF_FILE" ]; then
        log "FILE PREF TIDAK DITEMUKAN"
        report_result "invalid" "" "$(basename "$FILE")"
        mv "$FILE" "$FOLDER_INVALID/"
        return 1
    fi
    log "PREF FILE: $PREF_FILE"
    local PHONE
    PHONE=$(grep 'registration_jid' "$PREF_FILE" | sed -E 's/.*>(62[0-9]{9,15})<.*/\1/')
    if [ -z "$PHONE" ]; then
        PH=$(grep 'name="ph"' "$PREF_FILE" | sed -E 's/.*>([0-9]{9,15})<.*/\1/')

        if [ -n "$PH" ]; then
            PHONE="62$PH"
        fi
    fi
    PHONE=$(echo "$PHONE" | tr -d '+')
    if echo "$PHONE" | grep -qE '^0'; then
        PHONE="62${PHONE#0}"
    elif echo "$PHONE" | grep -qE '^8'; then
        PHONE="62$PHONE"
    fi
    if ! echo "$PHONE" | grep -qE '^62[0-9]{9,13}$'; then
        log "NOMOR TIDAK VALID: $PHONE"
        report_result "invalid" "$PHONE" "$(basename "$FILE")"
        mv "$FILE" "$FOLDER_INVALID/"
        return 1
    fi

    echo "$PHONE"
}


extract_backup() {
    local FILE="$1"
    log "EXTRACT: $FILE"
    tar -xzf "$FILE" -C "$TEMP"
}


clear_whatsapp_data() {
    rm -rf "$FOLDER_WA/databases" \
           "$FOLDER_WA/files" \
           "$FOLDER_WA/shared_prefs" \
           "$FOLDER_WA/app_account_switching" \
           "$FOLDER_WA/cache" \
           "$FOLDER_WA/no_backup" \
           "$FOLDER_WA/code_cache"
}

clear_whatsapp_data_symlink() {
    rm -rf "$FOLDER_WA_SYMLINK/databases" \
           "$FOLDER_WA_SYMLINK/files" \
           "$FOLDER_WA_SYMLINK/shared_prefs" \
           "$FOLDER_WA_SYMLINK/app_account_switching" \
           "$FOLDER_WA_SYMLINK/cache" \
           "$FOLDER_WA_SYMLINK/no_backup" \
           "$FOLDER_WA_SYMLINK/code_cache"
}

apply_restore() {
    SRC1="$TEMP/data/data/$WA_PKG"
    SRC2="$TEMP/data/user/0/$WA_PKG"
    if [ -d "$SRC1" ]; then
        log "RESTORE FROM data/data ✅"
        cp -r "$SRC1/." "$FOLDER_WA/"
        return
    fi
    if [ -d "$SRC2" ]; then
        log "RESTORE FROM data/user/0 ✅"
        cp -r "$SRC2/." "$FOLDER_WA/"
        return
    fi
    log "TIDAK ADA BACKUP ❌"
    return 1
}

fix_permission() {
    chmod -R 700 "$FOLDER_WA"
    UID=$(dumpsys package "$WA_PKG" | grep userId | cut -d= -f2)
    UID=$((UID-10000))
    chown -R u0_a$UID:u0_a$UID "$FOLDER_WA"
}

cleanup_temp() {
    rm -rf "$TEMP"/*
}

# Hapus arsip .tgz lokal di device. Server udah simpan master + pindah
# QUEUE->DONE via report_result, jadi copy lokal cuma redundan & bikin
# storage HP penuh. Sisakan .txt log nomor, cache server, session_map.
# Dipanggil tiap awal loop (sebelum klaim akun baru).
purge_local_tgz() {
    find "$FOLDER_AKUN" -type f \( -name '*.tar.gz' -o -name '*.tgz' \) -delete 2>/dev/null
}


run_restore_flow() {

    log "START RESTORE"
    cleanup_temp

    # PENTING: resolve SERVER/GATEWAY di shell UTAMA dulu. claim_account jalan
    # di subshell ($(...)), jadi kalau ensure_server cuma dipanggil di sana,
    # SERVER hilang dan report_result (logout/banned/dll) gak pernah terkirim.
    if ! ensure_server; then
        log "SERVER QUEUE TIDAK DITEMUKAN, tunggu ${CLAIM_IDLE_WAIT}s"
        sleep "$CLAIM_IDLE_WAIT"
        return 1
    fi

    FILE=$(prepare_backup_file) || return 1
    extract_backup "$FILE"
    detect_wa_pkg
    log "STOP WHATSAPP"
    am force-stop "$WA_PKG"
    PHONE=$(extract_phone "$TEMP") || return 1  #
    log "PHONE: $PHONE"
    clear_whatsapp_data
    clear_whatsapp_data_symlink
    apply_restore
    fix_permission
    cleanup_temp
    log "RESTORE DONE"
    echo "SUKSES RESTORE $PHONE"
    return 0
}