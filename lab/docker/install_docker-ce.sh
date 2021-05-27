
curl -fsSL https://get.docker.com -o get-docker.sh
chmod 755 get-docker.sh
./get-docker.sh
rm ./get-docker.sh

systemctl enable docker
systemctl start docker

echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf
systemctl restart network

curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

docker version

