# ghi
cd /tmp
URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
  | grep browser_download_url \
  | grep 'x86_64.deb' \
  | cut -d '"' -f 4 | head -n 1)
echo "$URL"
wget "$URL" -O rustdesk.deb
sudo apt install -y ./rustdesk.deb
