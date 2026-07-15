echo "Menghentikan agent.sh..."
su -c 'pkill -9 -f "[a]gent\.sh"' && echo "agent.sh dihentikan." || echo "Tidak ada yang berjalan."
