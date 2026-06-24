# =====================================================================
# API CLIENT (register / verifikasi)
# ---------------------------------------------------------------------
# Panggil service node "register" (port 4500, PC sama dgn SERVER).
# REGISTER diturunkan dari host SERVER -> derive_register() di server.sh.
#
# Butuh var dari config.sh: REGISTER, USER_REFF
# Output stdout dipakai caller (echo link/status) -> log() nulis ke file,
# bukan stdout, jadi gak ngotori hasil capture.
# =====================================================================

# user_reff per akun. Sekarang konstanta config.
# Hook upgrade nanti (tanpa ubah pemanggil): coba dari server/nama file dulu,
# fallback ke USER_REFF. Mis:
#   [ -n "$CLAIM_USER_REFF" ] && { echo "$CLAIM_USER_REFF"; return; }
resolve_user_reff() {
    echo "${USER_REFF:-automation}"
}

# POST /api/register {nomor,user_reff}
# Sukses (status=success): set REG_SESSION_ID, echo wa_link, return 0
# Gagal: return 1 (REG_SESSION_ID dikosongkan)
api_register() {
    local NOMOR="$1" REFF="$2" RESP STATUS LINK MSG
    # Alasan gagal ditaruh di REG_ERROR (global) biar caller bisa echo ke layar.
    # stdout fungsi ini KHUSUS wa_link -> jangan echo error ke stdout.
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
    echo "$LINK"
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
