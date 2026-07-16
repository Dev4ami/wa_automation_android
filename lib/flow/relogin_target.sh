# =====================================================================
# TRANSFER RELOGIN — DEVICE B (target)
# ---------------------------------------------------------------------
# Ambil akun 'ready' dari server (pairing), daftar ulang nomornya di WA
# personal fresh, input kode transfer (dibaca device A), sampai HOME, lalu
# re-backup & upload ke server FRESH/.
#
# Device B SELALU pakai com.whatsapp (RELOGIN_WA_PKG). Akun bisnis -> dialog
# "Alihkan ke Messenger" ditap "Alihkan Sekarang" (katalog/label hilang).
# =====================================================================

run_target_flow() {
    echo "START TARGET (device B)"
    log "START TARGET FLOW"

    # File lokal tidak dipakai di sisi B; kosongkan biar handler generic
    # (report/mv) tidak menyentuh file iterasi sebelumnya.
    FILE=""

    # 1. Ambil akun ready (pairing) -> PAIR_FILE + PAIR_PHONE.
    claim_target || return 1
    PHONE="$PAIR_PHONE"
    WA_PKG="${RELOGIN_WA_PKG:-com.whatsapp}"
    FOLDER_WA_SYMLINK="/data/data/$WA_PKG"
    FOLDER_WA="/data/user/0/$WA_PKG"

    # 2. Reset data WA -> tampil Welcome (fresh register).
    log "RESET WHATSAPP DATA (device B) untuk $PHONE"
    am force-stop "$WA_PKG"
    clear_whatsapp_data
    clear_whatsapp_data_symlink
    am start -n "$WA_PKG/com.whatsapp.Main" >/dev/null 2>&1
    sleep 2

    # 3. State machine registrasi sampai HOME.
    local START NOW STATE
    START=$(date +%s)
    while true; do
        if ! update_ui; then
            log "UI NOT READY, RETRY..."
            continue
        fi
        STATE=$(detect_screen)
        case "$STATE" in
            HOME)
                log "DEVICE B HOME -> transfer sukses ($PHONE)"
                run_rebackup_flow
                return $?
            ;;
            WELCOME)             handle_welcome;              continue ;;
            INPUT_NUMBER)        handle_input_number;         continue ;;
            CONFIRM_NUMBER)      handle_confirm_number;       continue ;;
            SWITCH_TO_MESSENGER) handle_switch_to_messenger;  continue ;;
            ENTER_TRANSFER_CODE)
                handle_enter_transfer_code || { log "GAGAL INPUT KODE TRANSFER"; return 1; }
                continue
            ;;
            INPUT_NAME)          handle_input_name;           continue ;;
            INPUT_EMAIL)         handle_input_email;          continue ;;
            SYNCING_WHATSAPP)    handle_syncing_data;         continue ;;
            POPUP_BACKUP_VALIDATION) handle_popup_backup_validation; continue ;;
            BACKUP_VALIDATION)   handle_backup_validation;    continue ;;
            SKIP_RESTORE)        handle_skip_restore;   sleep 1; continue ;;
            SKIP_RESTORE_CONFIRM) handle_skip_restore_confirm; sleep 1; continue ;;
            BANNED)
                log "DEVICE B BANNED saat register $PHONE"
                return 1
            ;;
            *)
                log "TARGET MENUNGGU REDIRECT... ($STATE)"
            ;;
        esac

        NOW=$(date +%s)
        if [ $((NOW - START)) -gt "${TARGET_MAX_WAIT:-300}" ]; then
            log "TARGET TIMEOUT (registrasi tidak selesai)"
            return 1
        fi
        sleep 1
    done
}

# Backup fresh device B setelah transfer, upload ke server FRESH/.
# Struktur arsip = data/user/0/<pkg> (mirror yg dicari apply_restore).
run_rebackup_flow() {
    log "RE-BACKUP device B untuk $PHONE"
    local NEW OUT
    am force-stop "$WA_PKG"
    sleep 1
    NEW="${PHONE}_$(date +%Y%m%d%H%M%S).tar.gz"
    OUT="$TEMP/$NEW"
    tar -czf "$OUT" -C / "data/user/0/$WA_PKG" 2>/dev/null
    if [ ! -s "$OUT" ]; then
        log "RE-BACKUP GAGAL: arsip kosong ($OUT)"
        return 1
    fi
    if upload_fresh "$OUT" "$NEW"; then
        rm -f "$OUT"
        log "TARGET DONE: $PHONE -> FRESH/$NEW"
        return 0
    fi
    rm -f "$OUT"
    return 1
}
