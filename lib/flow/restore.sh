
prepare_backup_file() {
    local FILE
    FILE=$(ls "$FOLDER_AKUN"/*.tar.gz 2>/dev/null | head -n1)
    if [ -z "$FILE" ]; then
        log "TIDAK ADA FILE BACKUP"
        return 1
    fi
    echo "$FILE"
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


run_restore_flow() {

    log "START RESTORE"
    cleanup_temp
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