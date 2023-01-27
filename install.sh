#!/bin/bash

if [ "$(whoami)" != "root" ]; then
  echo "Script must be run as root."
  exit 1
fi

if [[ -z $(which jq) || -z $(which curl) ]]; then
  apt-get update --quiet=3
  apt-get install -y --quiet=2 curl jq
fi

systemctl disable --now systemd-resolved.service

export ARCHITECTURE=$(uname -m)
RELEASE_JSON=$(curl --fail --silent https://api.github.com/repos/0xERR0R/blocky/releases/latest)
DOWNLOAD_URL=$(echo $RELEASE_JSON | jq --raw-output '.assets[] | select(.browser_download_url | ascii_downcase | contains("linux_" + env.ARCHITECTURE)) | .browser_download_url')

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "Latest release not found."
  exit 1
fi

systemctl daemon-reload
systemctl disable --now blocky.service &>/dev/null

curl --silent --location --output "/tmp/blocky.tar.gz" "$DOWNLOAD_URL"

mkdir "/tmp/blocky"
tar -xf "/tmp/blocky.tar.gz" -C "/tmp/blocky"

if [[ -e "/opt/blocky/blocky" ]]; then
  VERSION_NEW=$(/tmp/blocky/blocky version)
  VERSION_OLD=$(/opt/blocky/blocky version)

  if [[ $VERSION_NEW == $VERSION_OLD ]]; then
    rm "/tmp/blocky.tar.gz"
    rm --recursive "/tmp/blocky"
    echo "Installed blocky version already up to date."
    exit 0
  else
    echo "Updating blocky..."
  fi
fi

if [[ -e "/opt/blocky" ]]; then
  rm --recursive "/opt/blocky"
fi

mv "/tmp/blocky" "/opt"
rm "/tmp/blocky.tar.gz"

if [[ ! -e "/etc/blocky" ]]; then
  mkdir "/etc/blocky"
fi

if [[ ! -e "/etc/blocky/config.yml" ]]; then
  cat << EOF > /etc/blocky/config.yml
upstream:
  default:
    - https://dns.quad9.net/dns-query
    - tcp-tls:dns.quad9.net
    - https://dns.adguard.com/dns-query
    - tcp-tls:dns.adguard.com
    - https://opennic1.eth-services.de:853
    - https://www.jabber-germany.de/dns-query
    - tcp-tls:www.jabber-germany.de
    - https://opennic2.eth-services.de:853
    - https://doh.libredns.gr/dns-query
    - https://www.morbitzer.de/dns-query
    - tcp-tls:www.morbitzer.de
    - tcp-tls:dns3.digitalcourage.de
    - tcp-tls:dns.digitale-gesellschaft.ch
    - https://dns.digitale-gesellschaft.ch/dns-query
    - tcp-tls:anycast.uncensoreddns.org
    - https://anycast.uncensoreddns.org/dns-query
    - tcp-tls:dnsforge.de
    - https://dnsforge.de/dns-query
    - tcp-tls:fdns1.dismail.de
    - tcp-tls:fdns2.dismail.de
    - https://doh.applied-privacy.net/query
    - tcp-tls:dot1.applied-privacy.net
    - https://odvr.nic.cz/doh
    - https://doh.mullvad.net/dns-query

blocking:
  blackLists:
    abuse:
      - https://blocklistproject.github.io/Lists/abuse.txt
    ads:
      - https://blocklistproject.github.io/Lists/ads.txt
    fraud:
      - https://blocklistproject.github.io/Lists/fraud.txt
    malware:
      - https://blocklistproject.github.io/Lists/malware.txt
    phishing:
      - https://blocklistproject.github.io/Lists/phishing.txt
    ransomware:
      - https://blocklistproject.github.io/Lists/ransomware.txt
    scam:
      - https://blocklistproject.github.io/Lists/scam.txt
    tracking:
      - https://blocklistproject.github.io/Lists/tracking.txt
    smart-tv:
      - https://blocklistproject.github.io/Lists/smart-tv.txt
    stevenblack:
      - https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts

  clientGroupsBlock:
    default:
      - abuse
      - ads
      - fraud
      - malware
      - phishing
      - ransomware
      - scam
      - tracking
      - smart-tv
      - stevenblack

  downloadTimeout: 5m
  startStrategy: fast
  blockTTL: 5s

queryLog:
  type: none

port: 53

logLevel: error
EOF

fi

cat << EOF > /etc/systemd/system/blocky.service
[Unit]
Description=Blocky
After=network-online.target
Wants=network-online.target
[Service]
User=root
WorkingDirectory=/opt/blocky
ExecStart=/opt/blocky/blocky --config /etc/blocky/config.yml
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now blocky.service

cat << EOF > /usr/local/bin/uninstall-blocky.sh
#!/bin/bash
if [ "\$(whoami)" != "root" ]; then
  echo "Script must be run as root."
  exit 1
fi
systemctl daemon-reload
systemctl disable --now blocky.service
rm /etc/systemd/system/blocky.service
systemctl daemon-reload
rm --recursive /opt/blocky
whiptail --title "uninstall-blocky.sh" --yesno "Remove blocky config file?" 8 50 --defaultno && rm --recursive "/etc/blocky"
rm /usr/local/bin/uninstall-blocky.sh
EOF

chmod +x /usr/local/bin/uninstall-blocky.sh
