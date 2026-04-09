get_activity() {
    dumpsys activity activities | grep mResumedActivity | awk '{print $4}'
}


log() {
    echo "$(date '+%H:%M:%S') | $1" >> "$FILE_ACTIVITY"
}


log_activity_time() {
    ACT=$(get_activity)
    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))
    log "ACTIVITY: $ACT | TIME: ${ELAPSED}s"
}