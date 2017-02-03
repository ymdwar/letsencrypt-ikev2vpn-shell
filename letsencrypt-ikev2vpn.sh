#!/bin/sh

function main_install(){
    pre_init_env
    
    if [! -f /etc/nginx/nginx.conf];then
        install_nginx
    fi
    
    install_vpn
    
    install_acme
    
    deploy_cert
}

function pre_init_env(){
    if ! grep -qs -e "release 6" -e "release 7" /etc/redhat-release; then
      echo "the srcipt only support CentOS/RHEL 6 and 7."
      exit 1;
    fi
    
    
    read -p "please input the domain name(Multiple domains split by quote(,))):" domain
    read -p "Is the domain OK(y/n)?:${domain_name}, " confirmed
    
    if ["$confirmed"!="y"]  ; then
        exit 1
    fi

    domain_array=(${domain//,/ })
    domain=""
    for $single_domain in ${domain_array[@]}
    do
        domain="$domain -d ${single_domain} "
    done
    
    yum update
}

function install_nginx(){
    os_version = "7";
    if grep -qs "release 6" /etc/redhat-release; then
        os_version = "6"
    fi
    
    if [ ! -f "/etc/yum.repos.d/nginx.repo" ]; then
        cat > /etc/yum.repos.d/nginx.repo << EOF
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/${os_version}/\$basearch/
gpgcheck=0
enabled=1
EOF
    fi
    yum -y install nginx
}

function install_vpn(){
    wget --no-check-certificate https://raw.githubusercontent.com/quericy/one-key-ikev2-vpn/master/one-key-ikev2.sh
    chmod +x one-key-ikev2.sh
    bash one-key-ikev2.sh
}

function install_acme(){
    curl  https://get.acme.sh | sh
    
    # use tls issue , use 443 port
    acme.sh  --issue  $domain  --tls
}

function deploy_cert(){
    cert_dir="/etc/ssl.cert"
    if [! -d $cert_dir]; then
        mkdir $cert_dir
    else
        rm -f $cert_dir/key.pem $cert_dir/ca.pem $cert_dir/cert.pem $cert_dir/fullchain.pem
    fi
    
    acme.sh  --installcert  $domain  \
            --keypath  $cert_dir/key.pem \
            --certpath  $cert_dir/cert.pem \
            --fullchainpath $cert_dir/fullchain.pem \
            --reloadcmd  "service nginx force-reload & service ipsec restart" 
    acme.sh  --upgrade  --auto-upgrade
    
    
cat > /etc/nginx/conf.d/default.conf << EOF
server {
    listen                    80 | 443 ssl default_server;
    server_name                localhost;
    ssl                        on;
    ssl_certificate            $cert_dir/cert.pem;
    ssl_certificate_key        $cert_dir/key.pem;
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
}


main_install
