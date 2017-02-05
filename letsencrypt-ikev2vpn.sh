#!/usr/bin/env sh

echo -e "#######################Information############################"
echo -e "#"
echo -e "# LETSENCRYPT-IKEV2VPN-SHELL, function man_install is entry point"
echo -e "# 1. init enveroment"
echo -e "# 2. install acme"
echo -e "# 3. issue domain cert"
echo -e "# 4. install nginx"
echo -e "# 5. install ikeV2-vpn"
echo -e "#"
echo -e "#############################################################"

function main_install(){
    pre_init_env
    
    install_acme
    
    deploy_cert
    
    if [ ! -f /etc/nginx/nginx.conf ]; then
        install_nginx
    fi
    
    install_vpn
}

function pre_init_env(){
    if ! grep -qs -e "release 6" -e "release 7" /etc/redhat-release; then
      echo "the srcipt only support CentOS/RHEL 6 and 7."
      exit 1;
    fi
    
    read -p "please input the domain name(Multiple domains split by quote(,))):" domain
    read -p "Is the domain OK(y/n)?:${domain_name}" confirmed
    
    if [ ! "$confirmed"="y" ]  ; then
        exit 1
    fi

    domain_array=(${domain//,/ })
    domain=""
    for single_domain in ${domain_array[@]}
    do
        domain="$domain -d ${single_domain} "
    done
    
    cert_dir="/etc/ssl.cert"
    key_file=$cert_dir/key.pem
    ca_file=$cert_dir/ca.pem    
    cert_file=$cert_dir/cert.pem
    fullchain_file=$cert_dir/fullchain.pem
    
    echo "####################################"
    get_char(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
    }
    echo ""
    echo -e "#######################Information############################"
    echo -e "#"
    echo -e "# - Domain Name: ${domain}"
    echo -e "# - key_file: ${key_file}"
    echo -e "# - ca_file: ${ca_file}"
    echo -e "# - cert_file: ${cert_file}"
    echo -e "# - fullchain_file: ${fullchain_file}"
    echo -e "#"
    echo -e "#############################################################"
    echo -e ""
    echo "Press any key to start...or Press Ctrl+C to cancel"
    char=`get_char`
    
    yum update
}

function install_nginx(){
    echo "#############################################################"
    echo "# NGINX Installing....."
    echo "#############################################################"
    cd ~
    _os_version='7'
    if grep -qs "release 6" /etc/redhat-release; then
        _os_version='6'
    else
        _os_version='7'
    fi
    echo "$_os_version"
    if [ ! -f "/etc/yum.repos.d/nginx.repo" ]; then
        cat > /etc/yum.repos.d/nginx.repo <<EOF
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/${_os_version}/\$basearch/
gpgcheck=0
enabled=1
EOF
    fi
    yum -y install nginx

    cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen                    80 | 443 ssl default_server;
    server_name                localhost;
    ssl                        on;
    ssl_certificate            $fullchain_file;
    ssl_certificate_key        $key_file;
    ssl_ciphers                ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4;
    ssl_prefer_server_ciphers  on;
    ssl_protocols              TLSv1 TLSv1.1 TLSv1.2;
    ssl_session_cache          shared:SSL:10m;
    ssl_session_timeout        10m;
    
    access_log  /var/log/nginx/log/host.access.log  main;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
    
    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    #location ~ \.php$ {
    #    root           html;
    #    fastcgi_pass   127.0.0.1:9000;
    #    fastcgi_index  index.php;
    #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
    #    include        fastcgi_params;
    #}
}
EOF

    echo ""
    echo "# NGINX install complate! "
    echo "#############################################################"
}

function install_vpn(){
    echo "#############################################################"
    echo "# ikev2-VPN installing..... "
    echo "#############################################################"

    cd ~
    wget --no-check-certificate https://github.com/ymdwar/one-key-ikev2-vpn/raw/letsencrypt_special/one-key-ikev2.sh
    chmod +x one-key-ikev2.sh
    ./one-key-ikev2.sh
    echo ""
    echo "# ikev2-VPN install complate! "
    echo "#############################################################"
}

function install_acme(){
    echo "#############################################################"
    echo "# ACME installing..... "
    echo "#############################################################"
    cd ~
    wget https://raw.githubusercontent.com/Neilpang/acme.sh/master/acme.sh
    chmod +x acme.sh
    ./acme.sh --install
    source ~/.bashrc
    echo ""
    echo "# the ACME install complate!"
    echo "#############################################################"
    echo "#############################################################"
    echo "# the domain cert is issuing..... "
    # use tls issue , use 443 port
    acme.sh  --issue  $domain  --tls
    echo ""
    echo "# the domain cert issue complate!"
    echo "#############################################################"
}

function deploy_cert(){

    echo "#############################################################"
    echo "# deploy_cert installing..... "
    echo "#############################################################"
    cd ~
    
    if [ ! -d $cert_dir ]; then
        mkdir $cert_dir
    else
        rm -f $key_file $ca_file $cert_file $fullchain_file >> /dev/null
    fi
    
    acme.sh  --installcert  $domain  \
            --keypath  $key_file \
            --capath   $ca_file \
            --certpath  $cert_file \
            --fullchainpath $fullchain_file \
            --reloadcmd  "service nginx force-reload && service ipsec restart" 
    acme.sh  --upgrade  --auto-upgrade
    echo ""
    echo "# the cert was issue complate"
    echo "#############################################################"
}
main_install
