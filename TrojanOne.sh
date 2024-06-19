#!/bin/bash

# 提示用户输入参数
read -p "请输入域名: " value_url
read -p "请输入Trojan连接密码: " value_trojan_psw

# 声明字符串
string_cert="/etc/letsencrypt/live/$value_url/fullchain.pem"
string_key="/etc/letsencrypt/live/$value_url/privkey.pem"


# 步骤1. 安装必备软件
sudo yum install jq git aria2 vim wget pcre pcre-devel openssl openssl-devel gcc -y
sudo yum install epel-release -y && sudo yum update -y && sudo yum install certbot python2-certbot-nginx -y


# 步骤2. 源码安装nginx
wget -q http://nginx.org/download/nginx-1.20.0.tar.gz
useradd www -s /sbin/nologin -M
tar xf nginx-1.20.0.tar.gz
cd nginx-1.20.0
./configure --user=www --group=www --with-http_ssl_module --with-http_stub_status_module --prefix=/application/nginx-1.20.0/
make
sudo make install
sudo ln -s /application/nginx-1.20.0/ /application/nginx
sudo ln -s /application/nginx/sbin/nginx /usr/bin/nginx

# 步骤3. 修改nginx nginx/conf/nginx.conf 域名指向
nginx_conf="/application/nginx/conf/nginx.conf"
sudo sed -i "s/localhost\s\+\S\+/localhost $value_url;/" "$nginx_conf"

# 步骤4. 启动nginx
sudo /application/nginx/sbin/nginx

# 步骤5. 安装https证书
certbot --nginx --register-unsafely-without-email --agree-tos --nginx-server-root=/application/nginx/conf -d $value_url
certbot certificates
sudo systemctl enable certbot-renew.timer
sudo systemctl start certbot-renew.timer

# 打印新的证书路径和私钥路径
echo "新的证书路径: $string_cert"
echo "新的私钥路径: $string_key"

# 步骤6. 停止nginx服务
sudo /application/nginx/sbin/nginx -s stop

# 步骤7. 更换nginx config
sudo cp /application/nginx/conf/nginx.conf /application/nginx/conf/nginxBK2024.conf
sudo cp /application/nginx/conf/nginx.conf.default /application/nginx/conf/nginx.conf

# 步骤8. 再次启动nginx
sudo /application/nginx/sbin/nginx

# 步骤9. 安装Trojan
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh)"

# 修改配置文件
trojan_config="/usr/local/etc/trojan/config.json"
jq --arg password "$value_trojan_psw" --arg cert "$string_cert" --arg key "$string_key" \
   '.password = [$password] | .ssl.cert = $cert | .ssl.key = $key' \
   "$trojan_config" > "/tmp/config.json" && sudo mv /tmp/config.json "$trojan_config"


# 步骤10 启用并启动 Trojan
sudo systemctl enable trojan
sudo systemctl start trojan
