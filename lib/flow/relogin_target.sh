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
            PREFILL_PICKER)      handle_prefill_picker;       continue ;;
            INPUT_NUMBER)        handle_input_number;         continue ;;
            CONFIRM_NUMBER)      handle_confirm_number;       continue ;;
            CHAT_TRANSFER_OFFER) handle_chat_transfer_offer;  continue ;;
            CHAT_THEME)          handle_chat_theme;           continue ;;
            RESTORE_TRANSFER_SELECTOR) handle_restore_transfer_selector; continue ;;
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
# Struktur arsip = data/user/0/<pkg> (mirror yg dicari apply_restore), tapi
# MINIMAL: cuma isi yg sama dgn tgz master asli (sesi/login), BUKAN seluruh dir.
#   files/{key,me,rc2} + databases/axolotl.db + shared_prefs/*
# Media (WhatsApp Images/Video), msgstore.db, cache, logs SENGAJA dibuang:
# tadinya bikin arsip ~27MB (nembus limit body server) & gak perlu buat restore.
run_rebackup_flow() {
    log "RE-BACKUP device B untuk $PHONE"
    local NEW OUT WA_DIR INC p WAIT
    WA_DIR="data/user/0/$WA_PKG"

    # Bukti login akun TRANSFER: files/me (nomor) + databases/axolotl.db (identity
    # keypair). files/key itu LEGACY & TIDAK dibuat device-to-device transfer login
    # (cuma ada di akun master hasil register SMS lama) -> JANGAN dipersyaratkan.
    # me/axolotl.db bisa nongol async setelah HOME -> tunggu dulu sebelum force-stop.
    WAIT=0
    while [ ! -e "/$WA_DIR/files/me" ] || [ ! -e "/$WA_DIR/databases/axolotl.db" ]; do
        if [ "$WAIT" -ge "${REBACKUP_LOGIN_WAIT:-40}" ]; then break; fi
        sleep 2
        WAIT=$((WAIT + 2))
    done
    log "RE-BACKUP: identity check setelah ${WAIT}s (me/axolotl.db)"

    am force-stop "$WA_PKG"
    sleep 1

    # Validasi login beneran: files/me + axolotl.db = akun ready. Kalau salah satu
    # hilang, WA belum login penuh -> jangan upload arsip sampah ke FRESH.
    if [ ! -e "/$WA_DIR/files/me" ] || [ ! -e "/$WA_DIR/databases/axolotl.db" ]; then
        log "RE-BACKUP GAGAL: me/axolotl.db hilang stlh ${WAIT}s. Ada: $(ls "/$WA_DIR/files/" 2>/dev/null | tr '\n' ',')"
        return 1
    fi

    NEW="${PHONE}_$(date +%Y%m%d%H%M%S).tar.gz"
    OUT="$TEMP/$NEW"

    # Kumpulkan cuma path inti yg ADA (skip yg hilang biar tar gak error).
    # files/e2e = kunci signal (identitas transfer). files/key masih di-include
    # kalau kebetulan ada (akun master), tapi transfer login gak punya -> aman skip.
    INC=""
    for p in \
        "$WA_DIR/files/key" \
        "$WA_DIR/files/me" \
        "$WA_DIR/files/rc2" \
        "$WA_DIR/files/e2e" \
        "$WA_DIR/databases/axolotl.db" \
        "$WA_DIR/shared_prefs"; do
        [ -e "/$p" ] && INC="$INC $p"
    done

    tar -czf "$OUT" -C / $INC 2>/dev/null
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
