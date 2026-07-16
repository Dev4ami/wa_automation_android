echo "Menghentikan agent.sh..."
su -c 'pkill -9 -f "[a]gent\.sh"' && echo "agent.sh dihentikan." || echo "Tidak ada yang berjalan."
echo "Menutup Termux..."
# HARUS baris terakhir: force-stop bunuh shell ini juga (com.termux).
su -c 'am force-stop com.termux'
