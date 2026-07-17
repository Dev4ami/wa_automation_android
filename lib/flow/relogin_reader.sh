# =====================================================================
# TRANSFER RELOGIN — DEVICE A (reader)
# ---------------------------------------------------------------------
# Dipanggil SETELAH run_restore_flow + run_login_flow return 0 (sudah HOME).
# Global sudah terisi dari restore: FILE, PHONE, WA_PKG.
#
# Alur: mark_ready -> tunggu WA pop bottom-sheet kode (dipicu device B) ->
# baca 6 digit -> post ke server -> WA proses transfer -> A ke-LOGOUT
# (sesi/tgz lama mati = revocation) -> report "relogin".
# =====================================================================

run_reader_flow() {
    echo "START READER (device A)"
    log "START READER FLOW"

    # Sudah di HOME. Tandai akun ini siap jadi sumber kode buat device B.
    mark_ready

    local START NOW STATE POLL_N
    START=$(date +%s)
    POLL_N=0
    while true; do
        # Early-bail: target lapor akun ke-filter unofficial (/pairing_fail) ->
        # pairing 'gone' di server. Reader gak usah nunggu kode sampai
        # READER_MAX_WAIT (300s). Cek berkala (~tiap 3 loop) biar hemat HTTP.
        POLL_N=$((POLL_N + 1))
        if [ $((POLL_N % 3)) -eq 0 ] && pairing_gone; then
            log "READER BAIL: pairing gone (akun ke-filter unofficial di target)"
            return 1
        fi

        if ! update_ui; then
            log "UI NOT READY, RETRY..."
            sleep "${READER_POLL:-2}"
            continue
        fi
        STATE=$(detect_screen)
        case "$STATE" in
            SHOW_TRANSFER_CODE)
                # Baca + kirim kode. Idempotent: kalau sheet masih tampil next
                # loop, baca ulang & post lagi (aman).
                handle_show_transfer_code && \
                    log "KODE TERKIRIM, TUNGGU TRANSFER SELESAI (logout)..."
            ;;
            LOGOUT)
                # Transfer selesai: sesi lama device A mati = tgz lama ter-revoke.
                log "DEVICE A LOGGED OUT -> transfer selesai (tgz lama mati)"
                mv "$FILE" "$FOLDER_RELOGIN/" 2>/dev/null
                log_number "relogin" "$PHONE"
                return 0
            ;;
            BANNED)
                handle_banned
                return 1
            ;;
            HOME)
                : # nunggu B mulai / nunggu logout
            ;;
            *)
                log "READER MENUNGGU... ($STATE)"
            ;;
        esac

        NOW=$(date +%s)
        if [ $((NOW - START)) -gt "${READER_MAX_WAIT:-300}" ]; then
            # Jangan report: biar sweeper server requeue file ke MASTER buat
            # dicoba lagi (akun masih hidup, transfer belum terjadi).
            log "READER TIMEOUT (device B tidak datang / transfer gagal)"
            return 1
        fi
        sleep "${READER_POLL:-2}"
    done
}
