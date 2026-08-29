# =====================================================================
# SERVER QUEUE CLIENT
# ---------------------------------------------------------------------
# Device ambil akun dari PC pusat (account_management [3] SERVER QUEUE)
# dan lapor hasilnya. Tidak ada lagi bagi-bagi file manual ke tiap HP.
#
# Auto-discovery: device scan LAN cari PC yg port-nya kebuka + identitas
# cocok (/ping = WA_QUEUE_SERVER). Jadi tiap teman gak perlu set IP manual.
#
# Butuh var dari config.sh:
#   SERVER, SERVER_FIXED, SERVER_PORT, SERVER_CACHE,
#   DEVICE_ID, CLAIM_IDLE_WAIT, FOLDER_AKUN
# =====================================================================

# Token identitas yg dibalikin server di GET /ping.
SERVER_PING_TOKEN="WA_QUEUE_SERVER"

# Cek 1 URL: apakah itu server queue yg bener (bukan service lain).
probe_server() {
    [ -z "$1" ] && return 1
    curl -s --connect-timeout 1 --max-time 2 "$1/ping" 2>/dev/null \
        | grep -q "$SERVER_PING_TOKEN"
}

# IP device sendiri (utamakan rute default = interface aktif/wifi).
get_own_ip() {
    local ip
    ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oE 'src[[:space:]]+[0-9.]+' | awk '{print $2}' | head -n1)
    [ -z "$ip" ] && ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oE 'src[[:space:]]+[0-9.]+' | awk '{print $2}' | head -n1)
    [ -z "$ip" ] && ip=$(ifconfig 2>/dev/null | grep -oE 'inet (addr:)?[0-9.]+' | grep -oE '[0-9.]+' | grep -v '^127\.' | head -n1)
    echo "$ip"
}

# Prefix /24 dari IP sendiri, mis. "192.168.0."
get_subnet_base() {
    local ip
    ip=$(get_own_ip)
    [ -z "$ip" ] && return 1
    echo "$ip" | sed -E 's/\.[0-9]+$/./'
}

# Scan subnet /24 paralel, cari server. Echo URL kalau ketemu.
discover_server() {
    local base found tmp i batch
    base=$(get_subnet_base) || { log "DISCOVER: gagal deteksi subnet"; return 1; }
    log "DISCOVER: scan ${base}0/24 port $SERVER_PORT..."

    tmp="${TMPDIR:-/data/local/tmp}/qsrv_found.$$"
    : > "$tmp"

    i=1
    batch=0
    while [ "$i" -le 254 ]; do
        url="http://${base}${i}:${SERVER_PORT}"
        ( probe_server "$url" && echo "$url" >> "$tmp" ) &
        batch=$((batch + 1))
        # batasi konkurensi biar gak kebanyakan proses sekaligus
        if [ "$batch" -ge 50 ]; then
            wait
            batch=0
            # progress per batch: user tahu scan jalan (gak stuck).
            # kalau server udah ketemu di batch ini, stop lebih awal.
            if [ -s "$tmp" ]; then
                log "DISCOVER: scan ${base}1-${i} selesai, server ketemu -> stop"
                break
            fi
            log "DISCOVER: scan ${base}1-${i}/254 ... belum ketemu"
        fi
        i=$((i + 1))
    done
    wait

    found=$(head -n1 "$tmp" 2>/dev/null)
    rm -f "$tmp"
    [ -z "$found" ] && { log "DISCOVER: server tidak ketemu di LAN"; return 1; }

    log "DISCOVER: ketemu $found"
    echo "$found"
}

# Turunkan GATEWAY (node /api/pair) dari host SERVER, port GATEWAY_PORT.
# Gateway ada di PC yg sama dgn queue server -> gak perlu scan/hardcode lagi.
derive_gateway() {
    local host
    host=$(echo "$SERVER" | sed -E 's#^https?://([^:/]+).*#\1#')
    [ -z "$host" ] && return 1
    GATEWAY="http://${host}:${GATEWAY_PORT}"
}

# Turunkan REGISTER (node /api/register, port REGISTER_PORT) dari host SERVER.
# Service ada di PC yg sama dgn queue server -> gak perlu scan/hardcode IP.
derive_register() {
    if [ -n "$REGISTER_FIXED" ]; then
        REGISTER="$REGISTER_FIXED"
        return 0
    fi
    local host
    host=$(echo "$SERVER" | sed -E 's#^https?://([^:/]+).*#\1#')
    [ -z "$host" ] && return 1
    REGISTER="http://${host}:${REGISTER_PORT}"
}

# Turunkan OTP_BASE (service OTP autonomous listen_ag, port OTP_PORT) dari host
# SERVER. Pola sama derive_register. OTP_BASE_FIXED override (subdomain/LAN IP).
derive_otp() {
    if [ -n "$OTP_BASE_FIXED" ]; then
        OTP_BASE="$OTP_BASE_FIXED"
        return 0
    fi
    local host
    host=$(echo "$SERVER" | sed -E 's#^https?://([^:/]+).*#\1#')
    [ -z "$host" ] && return 1
    OTP_BASE="http://${host}:${OTP_PORT}"
}

# Pastikan SERVER + GATEWAY + REGISTER terisi & valid.
ensure_server() {
    _locate_server || return 1
    derive_gateway
    derive_register
    derive_otp
    return 0
}

# Cari/validasi SERVER. Urutan: override > cache > scan.
_locate_server() {
    # 1. Override manual menang mutlak.
    if [ -n "$SERVER_FIXED" ]; then
        SERVER="$SERVER_FIXED"
        return 0
    fi
    # 2. SERVER yg sekarang masih hidup?
    if [ -n "$SERVER" ] && probe_server "$SERVER"; then
        return 0
    fi
    # 3. Coba cache.
    if [ -f "$SERVER_CACHE" ]; then
        local cached
        cached=$(cat "$SERVER_CACHE" 2>/dev/null)
        if probe_server "$cached"; then
            SERVER="$cached"
            return 0
        fi
    fi
    # 4. Scan LAN.
    local found
    found=$(discover_server) || return 1
    SERVER="$found"
    echo "$SERVER" > "$SERVER_CACHE" 2>/dev/null
    return 0
}

# Klaim 1 akun dari server lalu download ke FOLDER_AKUN.
# - Sukses : echo path file lokal, return 0
# - Kosong / gagal : tunggu sebentar (anti-hammer), return 1
claim_account() {
    local RESP ST FNAME DEST

    # Cari/validasi server dulu (auto-discovery).
    if ! ensure_server; then
        log "SERVER QUEUE TIDAK DITEMUKAN, tunggu ${CLAIM_IDLE_WAIT}s"
        sleep "$CLAIM_IDLE_WAIT"
        return 1
    fi

    RESP=$(curl -s --max-time 15 "$SERVER/claim?device=$DEVICE_ID")
    ST=$(echo "$RESP" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')

    if [ -z "$RESP" ]; then
        log "CLAIM: server tidak respon, tunggu ${CLAIM_IDLE_WAIT}s"
        SERVER=""   # paksa re-discover ronde berikutnya
        sleep "$CLAIM_IDLE_WAIT"
        return 1
    fi
    if [ "$ST" != "ok" ]; then
        log "CLAIM: antrian kosong, tunggu ${CLAIM_IDLE_WAIT}s"
        sleep "$CLAIM_IDLE_WAIT"
        return 1
    fi

    FNAME=$(echo "$RESP" | sed -n 's/.*"file":"\([^"]*\)".*/\1/p')
    if [ -z "$FNAME" ]; then
        log "CLAIM: nama file kosong"
        sleep "$CLAIM_IDLE_WAIT"
        return 1
    fi

    DEST="$FOLDER_AKUN/$FNAME"
    curl -s --max-time 180 "$SERVER/download/$FNAME" -o "$DEST"
    if [ ! -s "$DEST" ]; then
        log "DOWNLOAD GAGAL/KOSONG: $FNAME"
        rm -f "$DEST"
        sleep 3
        return 1
    fi

    log "CLAIM OK: $FNAME"
    echo "$DEST"
}

# Lapor hasil akhir ke server (server pindah file QUEUE -> DONE/<status>).
# Dipanggil otomatis dari log_number; aman kalau SERVER kosong.
report_result() {
    local STATUS="$1" PHONE="$2" FNAME="$3"
    [ -z "$SERVER" ] && return 0
    [ -z "$FNAME" ] && return 0
    curl -s --max-time 10 -X POST "$SERVER/report" \
        -H "Content-Type: application/json" \
        --data "{\"device\":\"$DEVICE_ID\",\"file\":\"$FNAME\",\"phone\":\"$PHONE\",\"status\":\"$STATUS\"}" \
        >/dev/null 2>&1
    log "REPORT $STATUS ($FNAME) -> server"
}

# =====================================================================
# TRANSFER RELOGIN — message bus (device A reader <-> device B target)
# ---------------------------------------------------------------------
# Server pairing keyed by nama file tgz LAMA (yg di-claim device A).
# Butuh SERVER sudah ke-resolve (ensure_server). Global set: PAIR_FILE/PAIR_PHONE.
# =====================================================================

# Device A: lapor akun sudah HOME & siap jadi sumber kode. Pakai $FILE (file
# yg di-claim) + $PHONE. state pairing -> ready.
mark_ready() {
    [ -z "$SERVER" ] && return 1
    local FNAME
    FNAME=$(basename "$FILE" 2>/dev/null)
    [ -z "$FNAME" ] && return 1
    curl -s --max-time 10 -X POST "$SERVER/ready" \
        -H "Content-Type: application/json" \
        --data "{\"file\":\"$FNAME\",\"phone\":\"$PHONE\",\"device\":\"$DEVICE_ID\"}" \
        >/dev/null 2>&1
    log "READY ($FNAME / $PHONE) -> server"
}

# Device B: ambil 1 akun 'ready' (pairing). Set PAIR_FILE + PAIR_PHONE.
# return 0 kalau dapat, 1 kalau kosong/gagal (sudah tidur anti-hammer).
claim_target() {
    local RESP ST
    if ! ensure_server; then
        log "SERVER QUEUE TIDAK DITEMUKAN, tunggu ${CLAIM_IDLE_WAIT}s"
        sleep "$CLAIM_IDLE_WAIT"
        return 1
    fi
    RESP=$(curl -s --max-time 15 "$SERVER/claim_target?device=$DEVICE_ID")
    if [ -z "$RESP" ]; then
        log "CLAIM_TARGET: server tidak respon, tunggu ${CLAIM_IDLE_WAIT}s"
        SERVER=""   # paksa re-discover ronde berikutnya
        sleep "$CLAIM_IDLE_WAIT"
        return 1
    fi
    ST=$(echo "$RESP" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')
    if [ "$ST" != "ok" ]; then
        log "CLAIM_TARGET: belum ada akun ready, tunggu ${CLAIM_IDLE_WAIT}s"
        sleep "$CLAIM_IDLE_WAIT"
        return 1
    fi
    PAIR_FILE=$(echo "$RESP" | sed -n 's/.*"file":"\([^"]*\)".*/\1/p')
    PAIR_PHONE=$(echo "$RESP" | sed -n 's/.*"phone":"\([^"]*\)".*/\1/p')
    if [ -z "$PAIR_FILE" ] || [ -z "$PAIR_PHONE" ]; then
        log "CLAIM_TARGET: file/phone kosong: $RESP"
        sleep "$CLAIM_IDLE_WAIT"
        return 1
    fi
    log "CLAIM_TARGET OK: $PAIR_FILE ($PAIR_PHONE)"
    return 0
}

# Device A: kirim kode 6-digit yg dibaca dari layar. Key = $FILE (file A).
post_transfer_code() {
    local CODE="$1" FNAME
    [ -z "$SERVER" ] && return 1
    FNAME=$(basename "$FILE" 2>/dev/null)
    [ -z "$FNAME" ] && return 1
    curl -s --max-time 10 -X POST "$SERVER/code" \
        -H "Content-Type: application/json" \
        --data "{\"file\":\"$FNAME\",\"code\":\"$CODE\",\"device\":\"$DEVICE_ID\"}" \
        >/dev/null 2>&1
    log "POST CODE $CODE ($FNAME) -> server"
}

# Device A: cek apakah pairing untuk $FILE sudah LENYAP di server (status 'gone').
# Terjadi kalau target lapor /pairing_fail (akun ke-filter unofficial) atau pairing
# basi ke-prune. return 0 = gone -> reader gak perlu nunggu kode, bisa nyerah cepat.
pairing_gone() {
    local RESP ST FNAME
    [ -z "$SERVER" ] && return 1
    FNAME=$(basename "$FILE" 2>/dev/null)
    [ -z "$FNAME" ] && return 1
    RESP=$(curl -s --max-time 8 "$SERVER/code?file=$FNAME")
    [ -z "$RESP" ] && return 1
    ST=$(echo "$RESP" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')
    [ "$ST" = "gone" ]
}

# Device B: poll kode dari server (pakai PAIR_FILE). Echo kode kalau code_ready,
# selain itu return 1 (pending/gone).
get_transfer_code() {
    local RESP ST
    [ -z "$SERVER" ] && return 1
    [ -z "$PAIR_FILE" ] && return 1
    RESP=$(curl -s --max-time 10 "$SERVER/code?file=$PAIR_FILE")
    [ -z "$RESP" ] && return 1
    ST=$(echo "$RESP" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')
    [ "$ST" != "ok" ] && return 1
    echo "$RESP" | sed -n 's/.*"code":"\([^"]*\)".*/\1/p'
}

# Device B: upload backup baru (.tar.gz) ke server -> FRESH/. NAME = nama file
# baru; ?pairing=PAIR_FILE biar server nandain pairing done.
upload_fresh() {
    local LOCAL="$1" NAME="$2" RESP ST
    [ -z "$SERVER" ] && return 1
    if [ ! -s "$LOCAL" ]; then
        log "UPLOAD: file lokal kosong: $LOCAL"
        return 1
    fi
    RESP=$(curl -s --max-time 180 -X POST "$SERVER/upload/$NAME?pairing=$PAIR_FILE" \
        -H "Content-Type: application/gzip" \
        --data-binary "@$LOCAL")
    ST=$(echo "$RESP" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')
    if [ "$ST" = "ok" ]; then
        log "UPLOAD-FRESH OK: $NAME -> server FRESH/"
        return 0
    fi
    log "UPLOAD-FRESH GAGAL: $RESP"
    return 1
}

# Device B (target): akun transfer ke-flag "klien tidak resmi" (registration
# block). Target GAK BISA /report (master dipegang reader = ownership nolak),
# jadi pakai /pairing_fail: server pindahin master QUEUE -> DONE/unofficial +
# drop pairing biar reader nyerah & sweeper gak requeue (stop loop akun busuk).
report_pairing_unofficial() {
    log "TARGET NOT OFFICIAL -> filter akun ($PAIR_PHONE)"
    [ -z "$SERVER" ] && return 0
    [ -z "$PAIR_FILE" ] && return 0
    curl -s --max-time 10 -X POST "$SERVER/pairing_fail" \
        -H "Content-Type: application/json" \
        --data "{\"file\":\"$PAIR_FILE\",\"phone\":\"$PAIR_PHONE\",\"device\":\"$DEVICE_ID\",\"reason\":\"unofficial\"}" \
        >/dev/null 2>&1
    log "REPORT pairing_fail unofficial ($PAIR_FILE) -> server"
}

# =====================================================================
# OTP AUTONOMOUS (listen_ag) — request+submit OTP langsung ke service :8757
# ---------------------------------------------------------------------
# OTP_BASE di-resolve ensure_server (derive_otp). BYPASS wa-monitor.
# Dipanggil dari lib/flow/listen_ag.sh.
# =====================================================================

# Minta OTP buat 1 nomor: POST /get_otp {nomor}. SUKSES: echo `id` (uuid sesi),
# return 0. GAGAL: echo pesan service (buat ditampilkan pemanggil), return 1.
# $1 = nomor (62...).
#
# PENTING: deteksi success pakai `grep -E` (bukan sed `\(true\|false\)`) — pola
# alternation `\|` itu ekstensi GNU sed, TIDAK jalan di toybox sed (Android/HP)
# -> dulu success:true ke-baca gagal walau service balas 200 OK.
otp_get() {
    local NOMOR="$1" RESP ID MSG
    [ -z "$OTP_BASE" ] && { echo "OTP_BASE kosong (ensure_server gagal?)"; return 1; }
    [ -z "$NOMOR" ] && { echo "nomor kosong"; return 1; }
    RESP=$(curl -s --max-time 15 -X POST "$OTP_BASE/get_otp" \
        -H "Content-Type: application/json" \
        --data "{\"nomor\":\"$NOMOR\"}")
    if [ -z "$RESP" ]; then
        log "OTP_GET: service tidak respon ($OTP_BASE)"
        echo "service OTP tidak respon"
        return 1
    fi
    if printf '%s' "$RESP" | grep -qE '"success"[[:space:]]*:[[:space:]]*true'; then
        ID=$(printf '%s' "$RESP" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
        if [ -z "$ID" ]; then
            log "OTP_GET: id kosong: $RESP"
            echo "id sesi kosong dari service"
            return 1
        fi
        log "OTP_GET OK ($NOMOR) id=$ID"
        echo "$ID"
        return 0
    fi
    # Gagal: ambil "message" (JSON) atau body mentah (non-JSON, mis. 500 plain-text).
    MSG=$(printf '%s' "$RESP" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
    [ -z "$MSG" ] && MSG=$(printf '%s' "$RESP" | tr '\n' ' ' | cut -c1-160)
    log "OTP_GET GAGAL: $RESP"
    echo "$MSG"
    return 1
}

# Submit OTP: POST /set_otp {id, otp}. otp dikirim INTEGER (sesuai API; leading
# zero hilang). SUKSES: return 0. GAGAL: echo pesan-error service (buat ditampilkan
# pemanggil), return 1. $1 = id sesi, $2 = kode (digit).
otp_set() {
    local ID="$1" CODE="$2" RESP NUM MSG
    [ -z "$OTP_BASE" ] && { echo "OTP_BASE kosong"; return 1; }
    [ -z "$ID" ] || [ -z "$CODE" ] && { echo "id/kode kosong"; return 1; }
    # Kirim sbg INTEGER base-10 (10# cegah tafsir oktal + JSON invalid dari leading
    # zero, mis. "otp":012345). Konsisten dgn wa-monitor (code.parse::<i64>).
    NUM=$((10#$CODE))
    RESP=$(curl -s --max-time 15 -X POST "$OTP_BASE/set_otp" \
        -H "Content-Type: application/json" \
        --data "{\"id\":\"$ID\",\"otp\":$NUM}")
    if [ -z "$RESP" ]; then
        log "OTP_SET: service tidak respon ($OTP_BASE)"
        echo "service OTP tidak respon"
        return 1
    fi
    # Deteksi success:true pakai grep -E (bukan sed \|, ekstensi GNU yg mati di
    # toybox sed HP). Lihat catatan di otp_get.
    if printf '%s' "$RESP" | grep -qE '"success"[[:space:]]*:[[:space:]]*true'; then
        log "OTP_SET OK (id=$ID otp=$CODE): $RESP"
        return 0
    fi
    # Gagal: ambil "message" (JSON) atau body mentah (non-JSON, mis. 500 plain-text).
    MSG=$(printf '%s' "$RESP" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
    [ -z "$MSG" ] && MSG=$(printf '%s' "$RESP" | tr '\n' ' ' | cut -c1-160)
    log "OTP_SET GAGAL (id=$ID otp=$CODE): $RESP"
    echo "$MSG"
    return 1
}
