sudo mv /boot/kernel7.img /boot/kernel7_l.img
sudo cp /home/pi/Ultibo-retro-os/kernel7.img /boot/kernel7.img
sudo cp /home/pi/Ultibo-retro-os/kernel7.img /boot/ultibo/OS.u
sudo date +"%H %M %S" >/boot/now.txt
sudo shutdown -r now
