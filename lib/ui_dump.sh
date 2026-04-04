
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
UI_XML="$BASE_DIR/window_dump.xml"
# Get UI to XML data
# update_ui() {
#     UI_XML="/storage/emulated/0/window_dump.xml"
#     for i in 1 2 3 4 5; do
#         uiautomator dump "$UI_XML" >/dev/null 2>&1
#         if grep -q "resource-id=" "$UI_XML" 2>/dev/null; then
#             return 0
#         fi
#         sleep 1
#     done
#     return 1
# }

update_ui() {
    UI_XML="$BASE_DIR/window_dump.xml"

    for i in 1 2 3 4 5; do
        uiautomator dump "$UI_XML" >/dev/null 2>&1

        if grep -q "resource-id=" "$UI_XML" 2>/dev/null; then
            return 0
        fi

        sleep 1
    done

    return 1
}


detect_screen() {

    CURRENT=$(dumpsys activity activities | grep mResumedActivity | awk '{print $4}')
    
    # XML DATA
    if exists_id "com.whatsapp:id/ban_info" || \
        exists_id "com.whatsapp:id/ban_info_text_layout" || \
        exists_text "This account can't use WhatsApp" || \
        exists_text "Download the official"; then
        echo "BANNED"
        return
    fi

    if exists_text "Restore chat history"; then
        echo "RESTORE"
        return
    fi

    if exists_id "com.whatsapp:id/phone_number_prefill_hint_text_view"; then
        echo "PHONE_PREFILL"
        return
    fi

    if exists_id "com.whatsapp:id/alertTitle"; then
        echo "PAIR_FAILED"
        return
    fi

    if exists_id "com.whatsapp:id/name"; then
        echo "PAIR_SUCCESS"
        return
    fi

    if exists_id  "com.whatsapp:id/registration_name"; then
        echo "INPUT_NAME"
        return
    fi

    if exists_id  "com.whatsapp:id/initial_sync_progress"; then
        echo "SYNCING_WHATSAPP"
        return
    fi

    if exists_id "com.whatsapp:id/register_email_text_input" || \
        exists_id "com.whatsapp:id/register_email_text_submit" || \
        exists_id "com.whatsapp:id/register_email_text_skip"; then
        echo "INPUT_EMAIL"
        return
    fi

    if exists_text "If you previously backed up to Google storage" || \
        exists_id "com.whatsapp:id/chat_transfer_subtitle"; then
        echo "POPUP_BACKUP_VALIDATION"
        return
    fi

    if exists_id "com.whatsapp:id/gdrive_new_user_setup_not_now_btn"; then
        echo "BACKUP_VALIDATION"
        return
    fi

    if exists_text "This may be a scam"; then
        echo "SCAM_WARNING"
        return
    fi
    
    # ACTIVITY DATA
    if echo "$CURRENT" | grep -q "LinkedDevicesEnterCodeActivity"; then
        echo "PAIR"
        return
    fi

    if echo "$CURRENT" | grep -q "LinkedDevicesActivity"; then
        echo "PAIR HOME"
        return
    fi

    if echo "$CURRENT" | grep -q "HomeActivity"; then
        echo "HOME"
        return
    fi

    if echo "$CURRENT" | grep -q "VerifyPhoneNumberActivity"; then
        echo "VERIFY"
        return
    fi

    if echo "$CURRENT" | grep -q "LogoutMessageActivity"; then
        echo "LOGOUT"
        return
    fi

    if echo "$CURRENT" | grep -q "EULA"; then
        echo "WELCOME"
        return
    fi

    if echo "$CURRENT" | grep -q "RegisterPhone"; then
        echo "REGISTER"
        return
    fi

    echo "UNKNOWN"
}



# Get bounds by resource-id from XML
exists_id() {
    grep -q "resource-id=\"$1\"" "$UI_XML"
}

# Get bounds by text from XML
exists_text() {
    grep -q "$1" "$UI_XML"
}

# Tap element by resource-id from XML
tap_by_id() {

    ID="$1"
    BOUNDS=$(grep -o "resource-id=\"$ID\"[^>]*bounds=\"[^\"]*\"" "$UI_XML" \
    | head -n1 \
    | grep -o 'bounds="[^"]*"' \
    | sed 's/bounds="//;s/"//')

    if [ -z "$BOUNDS" ]; then
        echo "ELEMENT NOT FOUND: $ID"
        return
    fi

    X1=$(echo "$BOUNDS" | cut -d'[' -f2 | cut -d',' -f1)
    Y1=$(echo "$BOUNDS" | cut -d',' -f2 | cut -d']' -f1)

    X2=$(echo "$BOUNDS" | cut -d'[' -f3 | cut -d',' -f1)
    Y2=$(echo "$BOUNDS" | cut -d',' -f3 | cut -d']' -f1)

    X=$(( (X1+X2)/2 ))
    Y=$(( (Y1+Y2)/2 ))

    # echo "TAP $ID → $X,$Y"
    input tap "$X" "$Y"
    sleep 1
}
