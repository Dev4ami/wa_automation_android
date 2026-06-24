# =====================================================================
# API CLIENT (register / verifikasi)
# ---------------------------------------------------------------------
# Panggil service node "register" (port 4500, PC sama dgn SERVER).
# REGISTER diturunkan dari host SERVER -> derive_register() di server.sh.
#
# Butuh var dari config.sh: REGISTER, USER_REFF
# api_register taruh hasil di GLOBAL (REG_LINK/REG_SESSION_ID/REG_ERROR/...).
# JANGAN panggil via $(...) -> subshell bikin global hilang ke parent.
# api_check_status balikin status lewat stdout (boleh via $(...)).
# =====================================================================

# user_reff per akun. Sekarang konstanta config.
# Hook upgrade nanti (tanpa ubah pemanggil): coba dari server/nama file dulu,
# fallback ke USER_REFF. Mis:
#   [ -n "$CLAIM_USER_REFF" ] && { echo "$CLAIM_USER_REFF"; return; }
resolve_user_reff() {
    echo "${USER_REFF:-automation}"
}

# POST /api/register {nomor,user_reff}. Hasil di GLOBAL, return 0/1.
# Sukses: REG_LINK + REG_SESSION_ID terisi, return 0.
# Gagal : REG_ERROR berisi alasan, return 1.
# PENTING: panggil LANGSUNG (bukan $(...)) biar global kebawa ke caller.
api_register() {
    local NOMOR="$1" REFF="$2" RESP STATUS LINK MSG
    REG_LINK=""
    REG_SESSION_ID=""
    REG_STATUS=""
    REG_MESSAGE=""
    REG_ERROR=""
    if [ -z "$REGISTER" ]; then
        REG_ERROR="REGISTER URL kosong (service 4500 gak ketemu)"
        log "REGISTER URL kosong"
        return 1
    fi
    RESP=$(curl -s --max-time 30 -X POST "$REGISTER/api/register" \
        -H "Content-Type: application/json" \
        --data "{\"nomor\":\"$NOMOR\",\"user_reff\":\"$REFF\"}")
    if [ -z "$RESP" ]; then
        REG_ERROR="service tidak respon (timeout/koneksi)"
        log "REGISTER: service tidak respon"
        return 1
    fi
    STATUS=$(echo "$RESP" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')
    MSG=$(echo "$RESP" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
    REG_STATUS="$STATUS"
    REG_MESSAGE="$MSG"
    if [ "$STATUS" != "success" ]; then
        if [ -n "$MSG" ]; then
            # Utamakan pesan dari server apa adanya (mis. "Melebihi batas
            # Permintaan OTP, ...").
            REG_ERROR="$MSG"
        else
            # message kosong / JSON aneh -> tampilkan potongan respons mentah
            REG_ERROR="status=${STATUS:-?} | resp: $(echo "$RESP" | cut -c1-200)"
        fi
        log "REGISTER gagal: $RESP"
        return 1
    fi
    # wa_link: nilai ber-encode (%XX) & ada '&', tanpa '\"' di dalamnya,
    # jadi aman diambil dgn [^"]*.
    LINK=$(echo "$RESP" | sed -n 's/.*"wa_link":"\([^"]*\)".*/\1/p')
    if [ -z "$LINK" ]; then
        REG_ERROR="wa_link kosong (status success tapi link gak ada): $(echo "$RESP" | cut -c1-200)"
        log "REGISTER: wa_link kosong: $RESP"
        return 1
    fi
    REG_SESSION_ID=$(echo "$RESP" | sed -n 's/.*"session_id":"\([^"]*\)".*/\1/p')
    REG_LINK="$LINK"
    return 0
}

# POST /api/check_status {session_id}
# Echo status mentah (pending|timeout|error|success|...). Return 1 kalau gagal panggil.
api_check_status() {
    local SID="$1" RESP
    [ -z "$SID" ] && return 1
    [ -z "$REGISTER" ] && return 1
    RESP=$(curl -s --max-time 15 -X POST "$REGISTER/api/check_status" \
        -H "Content-Type: application/json" \
        --data "{\"session_id\":\"$SID\"}")
    [ -z "$RESP" ] && return 1
    echo "$RESP" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p'
}
