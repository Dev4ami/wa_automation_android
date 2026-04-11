SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
pwd
echo "Menghapus versi lama..."
rm -rf wa_automation_android
echo "Mengunduh versi baru..."
git clone https://github.com/dev4ami/wa_automation_android.git
chmod -R +x wa_automation_android
mv wa_automation_android/update.sh update.sh
echo "Update selesai!"
sleep 10
exit 0
