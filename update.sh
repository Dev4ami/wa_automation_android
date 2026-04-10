SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1
rm -rf wa_automation_android"
git clone https://github.com/dev4ami/wa_automation_android.git
su -c "chmod -R +x wa_automation_android"
exit