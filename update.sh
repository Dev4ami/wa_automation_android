SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1
echo "Menghapus versi lama..."
rm -rf wa_automation_android
echo "Mengunduh versi baru..."
git clone https://github.com/dev4ami/wa_automation_android.git
su 
chmod -R +x wa_automation_android