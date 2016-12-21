#! /bin/bash

create_keys()
{
    domain=$1

    echo "创建私钥"
    openssl genrsa -out ${domain}.key 4096
    #openssl genrsa -des3 -out ${domain}.key 2048

    echo "生成私钥和证书请求"
    openssl req -new -key ${domain}.key -out ${domain}.csr

    echo "生成Self-signed的Certifacte"
    openssl x509 -req -days 3650 -in ${domain}.csr -signkey ${domain}.key -out ${domain}.crt

    echo "删除私钥密码"
    openssl rsa -in ${domain}.key -out ${domain}.key.nopass
    mv ${domain}.key.nopass ${domain}.key

    echo "创建CA"
    openssl genrsa -out ca_${domain}.key 4096
    openssl req -new -x509 -days 365 -key ca_${domain}.key -out cacert.pem
    # openssl req -new -x509 -extensions v3_ca -keyout cakey.pem -out cacert.pem -days 3650

    echo "设置权限"
    mv ${domain}.key /etc/postfix/certs/
    mv ${domain}.crt /etc/postfix/certs/
    mv ca_${domain}.key /etc/postfix/certs/
    mv cacert.pem /etc/postfix/certs/
    chmod 600 /etc/postfix/certs/${domain}.key
    chmod 600 /etc/postfix/certs/ca_${domain}.key
    rm ${domain}.csr
}

if [ "X${MAIL_DOMAIN}" == "X" ]; then
  echo "need MAIL_DOMAIN"
  exit 1
fi

create_keys ${MAIL_DOMAIN}
