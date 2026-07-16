
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
UI_XML="$BASE_DIR/window_dump.xml"


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
    if exists_id "$WA_PKG:id/ban_info" || \
        exists_id "$WA_PKG:id/ban_info_text_layout" || \
        exists_text "This account can't use WhatsApp" || \
        exists_text "Download the official"; then
        echo "BANNED"
        return
    fi

    # Nomor tidak lagi terdaftar di HP ini = akun ke-logout (banner di atas
    # HomeActivity). Harus menang dari deteksi HOME, makanya dicek di sini.
    if exists_text "tidak lagi terdaftar dengan WhatsApp" || \
        exists_text "no longer registered with WhatsApp" || \
        exists_text "Your phone number is no longer"; then
        echo "LOGOUT"
        return
    fi

    if exists_text "Menginisialisasi" || exists_text "Initializing"; then
        echo "INITIALIZING"
        return
    fi

    if { exists_text "Something went wrong with your chat history" || exists_text "Terjadi kesalahan dengan riwayat chat"; } && exists_id "android:id/button2"; then
        echo "SKIP_RESTORE"
        return
    fi


    if { exists_text "If you skip restore" || exists_text "Jika melewati pemulihan"; } && exists_id "android:id/button1"; then
        echo "SKIP_RESTORE_CONFIRM"
        return
    fi


    if exists_text "Restore chat history" || exists_text "Pulihkan riwayat chat"; then
        echo "RESTORE"
        return
    fi

    # --- TARGET (device B): dialog autofill "Lanjutkan dengan" ---
    # Google account picker nutupin field nomor pas register fresh. Tolak lewat
    # Batal (android:id/button2) biar balik ke input nomor manual. HARUS dicek
    # sebelum PHONE_PREFILL karena layar ini juga punya id prefill_hint yg sama.
    if { exists_text "Lanjutkan dengan" || exists_text "Continue with"; } && \
        exists_id "android:id/button2"; then
        echo "PREFILL_PICKER"
        return
    fi

    if exists_id "$WA_PKG:id/phone_number_prefill_hint_text_view"; then
        echo "PHONE_PREFILL"
        return
    fi

    if exists_id "$WA_PKG:id/alertTitle"; then
        echo "PAIR_FAILED"
        return
    fi

    if exists_id "$WA_PKG:id/name"; then
        echo "PAIR_SUCCESS"
        return
    fi

    if exists_id  "$WA_PKG:id/registration_name"; then
        echo "INPUT_NAME"
        return
    fi

    # --- TRANSFER RELOGIN: layar device B (target) ---
    # Dialog biz->personal (akun bisnis didaftar ulang di WA personal). Dicek
    # sebelum INPUT_NUMBER karena dialog nutupin field nomor di belakangnya.
    if { exists_text "Alihkan ke WhatsApp Messenger" || exists_text "Switch to WhatsApp Messenger"; } && \
        exists_id "android:id/button1"; then
        echo "SWITCH_TO_MESSENGER"
        return
    fi

    # Layar input kode transfer (device B). verify_wa_old_content_title = marker
    # khusus transfer; verify_sms_code_input = field kodenya.
    if exists_id "$WA_PKG:id/verify_wa_old_content_title" || \
        exists_id "$WA_PKG:id/verify_sms_code_input"; then
        echo "ENTER_TRANSFER_CODE"
        return
    fi

    # Dialog konfirmasi nomor setelah BERIKUTNYA (defensif; belum ter-capture).
    if { exists_text "Anda memasukkan nomor" || exists_text "You entered the phone number" || \
         exists_text "nomor telepon ini benar" || exists_text "Is this the correct"; } && \
        exists_id "android:id/button1"; then
        echo "CONFIRM_NUMBER"
        return
    fi

    # Layar input nomor (device B daftar ulang).
    if exists_id "$WA_PKG:id/registration_phone"; then
        echo "INPUT_NUMBER"
        return
    fi

    if exists_id  "$WA_PKG:id/initial_sync_progress"; then
        echo "SYNCING_WHATSAPP"
        return
    fi

    if exists_id "$WA_PKG:id/register_email_text_input" || \
        exists_id "$WA_PKG:id/register_email_text_submit" || \
        exists_id "$WA_PKG:id/register_email_text_skip" || \
        exists_id "$WA_PKG:id/register_email_skip"; then
        echo "INPUT_EMAIL"
        return
    fi

    if exists_text "If you previously backed up to Google storage" || \
        exists_id "$WA_PKG:id/chat_transfer_subtitle"; then
        echo "POPUP_BACKUP_VALIDATION"
        return
    fi

    if exists_id "$WA_PKG:id/gdrive_new_user_setup_not_now_btn"; then
        echo "BACKUP_VALIDATION"
        return
    fi

    if exists_text "This may be a scam"; then
        echo "SCAM_WARNING"
        return
    fi

    if exists_text "is not on WhatsApp" || \
        exists_text "isn't on WhatsApp" || \
        exists_text "tidak menggunakan WhatsApp" || \
        exists_text "belum menggunakan WhatsApp"; then
        echo "NOT_ON_WA"
        return
    fi

    # --- TRANSFER RELOGIN: device A code-display bottom sheet ---
    # Muncul sebagai bottom-sheet DI ATAS HomeActivity saat device B memulai
    # transfer. mResumedActivity tetap HomeActivity, jadi deteksi WAJIB via
    # id/text XML dan HARUS menang dari deteksi HOME (dicek sebelum HOME).
    if exists_id "$WA_PKG:id/code_container" || \
        exists_id "$WA_PKG:id/verification_code_bottom_sheet_text_layout" || \
        exists_text "Masukkan Kode Verifikasi Ini di Telepon Baru" || \
        exists_text "Enter this verification code on your new phone"; then
        echo "SHOW_TRANSFER_CODE"
        return
    fi

    # HOME (daftar chat) via XML bottom-nav. Tahan banting: sebagian device/
    # WA non-root gak expose mResumedActivity ke shell, jadi deteksi activity
    # gagal terus (UNKNOWN). Bottom-nav "Komunitas + Panggilan" cuma muncul di
    # HomeActivity. Ditaruh SETELAH cek LOGOUT/BANNED biar banner logout menang.
    if { exists_text "Komunitas" || exists_text "Communities"; } && \
        { exists_text "Panggilan" || exists_text "Calls"; }; then
        echo "HOME"
        return
    fi

    # CHAT (ruang percakapan) via XML. Kotak ketik pesan (id/entry) cuma ada
    # di ConversationActivity. Fallback kalau deteksi activity gak jalan.
    if exists_id "$WA_PKG:id/entry"; then
        echo "CHAT"
        return
    fi

    # ACTIVITY DATA
    if echo "$CURRENT" | grep -q "Conversation"; then
        echo "CHAT"
        return
    fi

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


exists_id() {
    grep -q "resource-id=\"$1\"" "$UI_XML"
}


exists_text() {
    grep -q "$1" "$UI_XML"
}


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

    input tap "$X" "$Y"
    sleep 1
}


tap_input_field() {

    ID="$1"

    BOUNDS=$(grep -o "resource-id=\"$ID\"[^>]*bounds=\"[^\"]*\"" "$UI_XML" \
    | head -n1 \
    | grep -o 'bounds="[^"]*"' \
    | sed 's/bounds="//;s/"//')

    [ -z "$BOUNDS" ] && return 1

    X1=$(echo "$BOUNDS" | cut -d'[' -f2 | cut -d',' -f1)
    Y1=$(echo "$BOUNDS" | cut -d',' -f2 | cut -d']' -f1)
    Y2=$(echo "$BOUNDS" | cut -d',' -f3 | cut -d']' -f1)

    X=$(( X1 + 30 ))
    Y=$(( (Y1+Y2)/2 ))

    input tap "$X" "$Y"
    sleep 0.2
    input tap "$X" "$Y"
}


# Baca kode transfer 6-digit dari layar device A (SHOW_TRANSFER_CODE).
# Tiap digit = TextView 1 karakter dengan resource-id KOSONG di dalam
# code_container. Home di belakang bottom-sheet bisa punya badge angka
# (jumlah chat belum dibaca), jadi kita sekat pakai y-band code_container
# lalu urutkan digit by X. Echo 6 digit (atau kosong kalau bukan 6).
read_transfer_code() {
    local BAND Y1 Y2 CODE
    BAND=$(grep -oE "resource-id=\"$WA_PKG:id/code_container\"[^>]*bounds=\"\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]\"" "$UI_XML" \
        | head -n1 | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"')
    [ -z "$BAND" ] && BAND=$(grep -oE "resource-id=\"$WA_PKG:id/verification_code_bottom_sheet_text_layout\"[^>]*bounds=\"\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]\"" "$UI_XML" \
        | head -n1 | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"')
    if [ -n "$BAND" ]; then
        Y1=$(echo "$BAND" | sed -E 's/.*\[[0-9]+,([0-9]+)\]\[[0-9]+,[0-9]+\]".*/\1/')
        Y2=$(echo "$BAND" | sed -E 's/.*\[[0-9]+,[0-9]+\]\[[0-9]+,([0-9]+)\]".*/\1/')
    else
        Y1=0; Y2=999999
    fi

    CODE=$(tr '>' '\n' < "$UI_XML" \
        | grep -oE 'text="[0-9]".*bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' \
        | sed -E 's/text="([0-9])".*bounds="\[([0-9]+),([0-9]+)\]\[[0-9]+,([0-9]+)\]"/\2 \3 \4 \1/' \
        | while read -r X YT YB D; do
              YC=$(( (YT + YB) / 2 ))
              if [ "$YC" -ge "$Y1" ] && [ "$YC" -le "$Y2" ]; then
                  echo "$X $D"
              fi
          done \
        | sort -n | awk '{printf "%s",$2}')

    # Hanya valid kalau tepat 6 digit.
    if echo "$CODE" | grep -qE '^[0-9]{6}$'; then
        echo "$CODE"
    fi
}