SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
echo "Menghapus versi lama..."
rm -rf wa_automation_android
echo "Mengunduh versi baru..."
git clone https://github.com/dev4ami/wa_automation_android.git
chmod -R +x wa_automation_android
mv wa_automation_android/update.sh update.sh
mv wa_automation_android/stop.sh stop.sh
echo "Menyiapkan shortcut Termux:Widget..."
mkdir -p "$SCRIPT_DIR/.shortcuts"
cp wa_automation_android/shortcuts/*.sh "$SCRIPT_DIR/.shortcuts/"
chmod +x "$SCRIPT_DIR/.shortcuts/"*.sh
rm -f "$SCRIPT_DIR/.shortcuts/run.sh"
echo "Update selesai!"
sleep 3
exit 0



