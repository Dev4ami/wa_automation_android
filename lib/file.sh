
# function log number no duplicate in file
save_unique() {
    TEXT="$1"
    FILE="$2"
    [ -f "$FILE" ] || touch "$FILE"
    if ! grep -Fxq "$TEXT" "$FILE"; then
        echo "$TEXT" >> "$FILE"
    fi
}

log_number() {
    STATUS="$1"
    VALUE="$2"
    TARGET_FILE=""
    case "$STATUS" in
        success) FILE="$FILE_SUCCESS" ;;
        logout) FILE="$FILE_LOGOUT" ;;
        banned) FILE="$FILE_BANNED" ;;
        timeout) FILE="$FILE_TIMEOUT" ;;
        terdaftar) FILE="$FILE_TERDAFTAR" ;; 
        invalid) FILE="$FILE_INVALID" ;;
        failed_pairing) FILE="$FILE_FAILED_PAIRING" ;;
        *) return ;;
    esac

    save_unique "$VALUE" "$FILE"
}