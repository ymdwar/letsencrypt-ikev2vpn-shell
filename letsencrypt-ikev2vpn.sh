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
      echo "本脚本只支持CentOS/RHEL 6 and 7."
      exit 1;
    fi
    
    # 输入需要进行签名的域名
    read -p "请输入域名(如果要对多个域名签名，请使用逗号(,)分隔):" domain
    read -p "需要签名的域名为:${domain_name}, 确认请输入y,取消输入任意键" confirmed
    
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
    
    # 使用tls进行发布
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
}

main_install
