
# function log number no duplicate in file
# save_unique() {
#     TEXT="$1"
#     FILE="$2"
#     [ -f "$FILE" ] || touch "$FILE"
#     if ! grep -Fxq "$TEXT" "$FILE"; then
#         echo "$TEXT" >> "$FILE"
#     fi
# }






save_unique() {
    local TEXT="$1"
    local DEST_FILE="$2" # Gunakan nama lain (misal DEST_FILE), dan pastikan local
    [ -f "$DEST_FILE" ] || touch "$DEST_FILE"
    if ! grep -Fxq "$TEXT" "$DEST_FILE"; then
        echo "$TEXT" >> "$DEST_FILE"
    fi
}

log_number() {
    local STATUS="$1"
    local VALUE="$2"
    local TARGET_FILE="" # Gunakan nama TARGET_FILE dan wajib local
    
    case "$STATUS" in
        success) TARGET_FILE="$FILE_SUCCESS" ;;
        logout) TARGET_FILE="$FILE_LOGOUT" ;;
        banned) TARGET_FILE="$FILE_BANNED" ;;
        timeout) TARGET_FILE="$FILE_TIMEOUT" ;;
        terdaftar) TARGET_FILE="$FILE_TERDAFTAR" ;; 
        invalid) TARGET_FILE="$FILE_INVALID" ;;
        failed_pairing) TARGET_FILE="$FILE_FAILED_PAIRING" ;;
        *) return ;;
    esac

    # Lempar ke save_unique
    save_unique "$VALUE" "$TARGET_FILE"

    # === SERVER QUEUE: lapor hasil otomatis ke PC pusat ===
    # $FILE = path backup yang lagi diproses; basename-nya = nama file di server.
    if command -v report_result >/dev/null 2>&1; then
        report_result "$STATUS" "$VALUE" "$(basename "$FILE" 2>/dev/null)"
    fi
}