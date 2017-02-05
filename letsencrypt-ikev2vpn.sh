#! /usr/bash
# set your aliyun api
aliyum_api_key=$Ali_Key
aliyum_api_sec=$Ali_Secret
# set your domain name (eg:  example.com)
domain_name=""

function __debug() {
  echo "[`date`][DEBUG] $1 "
}

function __error(){
    echo -e “\033[41;33m[`date`][ERROR] $1 \033[0m” 
}

## only support CentOS6/7
__debug "check the the OS has been supportted."
if ! grep -qs -e "release 6." -e "release 7." /etc/redhat-release; then
    __error "This script only supports CentOS/RHEL 6 and 7."
    exit 1;
fi

if [ -z $aliyum_api_key ]; then
  __error "the aliyum_api_key and aliyum_api_key must be setting."
  exit 1;
fi

if [ -z $domain_name ]; then
   __error "the domain name must be setting."
   exit 1;
fi

__debug "the operation system and software updating...."
yum update

__debug "install strongswan"
yum install -y strongswan 

__debug "dowanlod acme.sh and install it. "
curl https://get.acme.sh | sh
source ~/.bashrc

__debug "acme.sh has been ready. init the variable. "

# list sub domains
domain_param=" -d $domain_name \
     -d www.$domain_name \
cert_dir="/etc/my_ssl_cert"
my_key_file=$cert_dir/key.pem
my_ca_file=$cert_dir/ca.pem    
my_cert_file=$cert_dir/cert.pem
my_fullchain_file=$cert_dir/fullchain.pem
__debug "check the cert dir"
if [ ! -d $cert_dir ]; then
  mkdir $cert_dir
fi

__debug "export aliyun Ali_Key and Ali_Secret.  "
export Ali_Key=${aliyum_api_key}
export Ali_Secret=${aliyum_api_sec}
__debug "excute issue domain cert domain param is $domain_param"
acme.sh --debug --issue $domain_param --dns dns_ali

__debug "install cert to the cert dir"
acme.sh --debug --installcert -d $domain_name  \
        --keypath  $my_key_file \
        --capath   $my_ca_file \
        --certpath  $my_cert_file \
        --fullchainpath $my_fullchain_file \
        --reloadcmd  "systemctl restart strongswan.service && systemctl restart firewalld.service "  
__debug "complete"

cp -f $my_key_file /etc/strongswan/ipsec.d/private/serverKey.pem
cp -f $my_key_file /etc/strongswan/ipsec.d/private/clientKey.pem
cp -f $my_ca_file /etc/strongswan/ipsec.d/cacerts/caCert.pem
cp -f $my_cert_file /etc/strongswan/ipsec.d/certs/server.cert.pem
cp -f $my_cert_file /etc/strongswan/ipsec.d/certs/client.cert.pem

__debug "dowload the ipsec.conf and copy to /etc/strongswan/ipsec.conf. "
wget https://github.com/ymdwar/letsencrypt-ikev2vpn-shell/raw/master/ipsec.conf
cp -f ipsec.conf /etc/strongswan/ipsec.conf

__debug "dowload the strongswan.conf and copy to /etc/strongswan/strongswan.conf. "
wget https://github.com/ymdwar/letsencrypt-ikev2vpn-shell/raw/master/strongswan.conf
cp -f strongswan.conf /etc/strongswan/strongswan.conf

__debug "set user name and password"
cat > /etc/strongswan/ipsec.secrets<<EOF
: RSA serverKey.pem
: PSK "myPskPass"
myUser  : EAP "myPass"
myUser %any : XAUTH "myPass"
EOF

__debug "config the firewall"
if ! systemctl is-active firewalld > /dev/null; then
    systemctl start firewalld.service
fi
firewall-cmd --permanent --add-service="ipsec"
firewall-cmd --permanent --add-port=500/udp
firewall-cmd --permanent --add-port=4500/udp
firewall-cmd --permanent --add-masquerade
firewall-cmd --reload

systemctl enable strongswan.service
systemctl start strongswan.service
systemctl restart firewalld.service

echo "##############################################"
echo "## the use name: myUser"
echo "## the password: myPass"
echo "## the PSK: myPass"
echo "## You can change the user name and password, edit /etc/strongswan/ipsec.secrets "
echo "############################################"

__debug "complete all, enjoy it :) "
