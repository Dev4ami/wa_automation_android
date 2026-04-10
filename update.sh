SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1
git pull
chmod -R +x *
echo "Update selesai!"
exit 0
