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
    curl -s --noproxy '*' --connect-timeout 1 --max-time 2 "$1/ping" 2>/dev/null \
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
        if [ "$batch" -ge 50 ]; then wait; batch=0; fi
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
        # Service 4500 cuma bisa via http -> paksa https->http kalau ke-set.
        REGISTER=$(echo "$REGISTER_FIXED" | sed -E 's#^https://#http://#')
        return 0
    fi
    local host
    host=$(echo "$SERVER" | sed -E 's#^https?://([^:/]+).*#\1#')
    [ -z "$host" ] && return 1
    REGISTER="http://${host}:${REGISTER_PORT}"
}

# Pastikan SERVER + GATEWAY + REGISTER terisi & valid.
ensure_server() {
    _locate_server || return 1
    derive_gateway
    derive_register
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

    RESP=$(curl -s --noproxy '*' --max-time 15 "$SERVER/claim?device=$DEVICE_ID")
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
    curl -s --noproxy '*' --max-time 180 "$SERVER/download/$FNAME" -o "$DEST"
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
    curl -s --noproxy '*' --max-time 10 -X POST "$SERVER/report" \
        -H "Content-Type: application/json" \
        --data "{\"device\":\"$DEVICE_ID\",\"file\":\"$FNAME\",\"phone\":\"$PHONE\",\"status\":\"$STATUS\"}" \
        >/dev/null 2>&1
    log "REPORT $STATUS ($FNAME) -> server"
}
