sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw allow 3478/tcp comment 'TURN TCP'
sudo ufw allow 3478/udp comment 'TURN UDP'
sudo ufw allow 5349/tcp comment 'TURNS TCP'
sudo ufw allow 5349/udp comment 'TURNS UDP'
sudo ufw allow 49152:65535/udp comment 'TURN/LiveKit relay UDP'
sudo ufw allow 7881/tcp comment 'LiveKit TURN TCP'
sudo ufw allow from 172.16.0.0/12 to any port 7880 comment 'Docker bridge to LiveKit API'
sudo ufw enable
sudo ufw status
