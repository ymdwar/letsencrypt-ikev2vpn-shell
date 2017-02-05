#! /bin/bash

#！！本脚本只支持CentOS6和7！！

# echo "## 升级操作系统最新版本..."
# yum update
# echo "## 操作系统升级完毕!"

# echo "## 安装acme.sh..."
# cd ~
# wget https://raw.githubusercontent.com/Neilpang/acme.sh/master/acme.sh
# source acme.sh --install --debug
# source ~/.bashrc
# echo "## acme.sh安装完毕！"

echo "## 初始化脚本变量"
#设置域名 adusir.net
domain_base="adusir.net"
#证书路径
domain_param=" -d $domain_base \
     -d www.$domain_base \
     -d m.$domain_base \
     -d test.$domain_base \
     -d blog.$domain_base \
     -d cloud.$domain_base \
     -d i.$domain_base \
     -d sec.$domain_base \
     -d data.$domain_base "
cert_dir="/etc/ssl.cert"
key_file=$cert_dir/key.pem
ca_file=$cert_dir/ca.pem    
cert_file=$cert_dir/cert.pem
fullchain_file=$cert_dir/fullchain.pem

aliyum_api_key="LTAIFKSyg4z9Rbro"
aliyum_api_sec="I8ZD9aEM9GAn5Z5dBFLuykJq2X6Ng4"

echo "## 使用acme.sh给域名颁布数字证书(使用dns的方式)...."
export Ali_Key=${aliyum_api_key}
export Ali_Secret=${aliyum_api_sec}
acme.sh --debug --issue $domain_param --dns dns_ali
echo "## 域名数字证书颁布完毕! "

echo "## 给应用服务器安装数字证书..."
if [ ! -d $cert_dir ]; then
  mkdir $cert_dir
fi

acme.sh --debug --installcert -d $domain_base  \
        --keypath  $key_file \
        --capath   $ca_file \
        --certpath  $cert_file \
        --fullchainpath $fullchain_file \
        --reloadcmd  "echo \"after moment replase the command! \""  
echo "## 应用服务器数字证书安装完毕！"
