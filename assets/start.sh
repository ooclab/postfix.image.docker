#! /bin/bash

# ADMIN_MAIL=admin@ooclab.com
# MAIL_DOMAIN=ooclab.cn
# MAIL_ACCOUNTS=team

check_envs()
{
  if [ "X${MAIL_DOMAIN}" == "X" ]; then
    echo "need MAIL_DOMAIN"
    exit 1
  fi

  if [ "X${MAIL_ACCOUNTS}" == "X" ]; then
    echo "need MAIL_ACCOUNTS"
    exit 1
  fi

  if [ "X${ADMIN_MAIL}" == "X" ]; then
    echo "need ADMIN_MAIL"
    exit 1
  fi
}

setup_virtual()
{
  cat > /etc/postfix/virtual << EOF
#Format: mail@from.address  forward@to.address
#multiple mailboxs can be declared
info@${MAIL_DOMAIN} ${ADMIN_MAIL}
admin@${MAIL_DOMAIN} ${ADMIN_MAIL}
#postmaster@${MAIL_DOMAIN} ${ADMIN_MAIL}
EOF

  postmap /etc/postfix/virtual
}

configure_postfix()
{
    domain=$1

    postconf compatibility_level=2

    # base
    postconf -e "myhostname = ${domain}"
    postconf -e "mydomain = ${domain}"
    postconf -e "myorigin = ${domain}"

    # virtual
    postconf -e "virtual_alias_domains = ${domain}"
    postconf -e "virtual_alias_maps = hash:/etc/postfix/virtual"
}

configure_postfix_tls()
{

  if [[ -z "$(find /etc/postfix/certs -iname *.key)" ]]; then
      return
  fi

  # tls
  postconf -e "smtpd_use_tls = yes"
  postconf -e "smtpd_tls_auth_only = yes"
  postconf -e "smtpd_tls_key_file = /etc/postfix/certs/${domain}.key"
  postconf -e "smtpd_tls_cert_file = /etc/postfix/certs/${domain}.crt"
  postconf -e "smtpd_tls_CAfile = /etc/postfix/certs/cacert.pem"
  postconf -e "tls_random_source = dev:/dev/urandom"

  cat > /etc/postfix/sasl/smtpd.conf <<EOF
sasl_pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM
log_level: 7
EOF

  cat >> /etc/postfix/master.cf <<EOF
submission inet n       -       n       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=may
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
EOF
}

create_accounts()
{
    domain=$1
    accounts=$2

    ACCOUNTS_NO_WHITESPACE="$(echo -e "${accounts}" | tr -d '[[:space:]]')"
    backend=$(echo $ACCOUNTS_NO_WHITESPACE | tr ";" "\n")
    for x in $backend; do
        username=$(echo $x | cut -d ':' -f 1)
        password=$(echo $x | cut -d ':' -f 2)

        echo "创建用户 (如果用户己存在,等同于重置其密码) : ${username}@${domain}"
        echo $password | saslpasswd2 -p -c -u $domain $username
    done

    chown postfix.sasl /etc/sasldb2

    echo "检查用户是否创建"
    sasldblistusers2

    echo "设置文件(/etc/sasldb2)权限"
    chmod 400 /etc/sasldb2
    chown postfix /etc/sasldb2
}

setup_dkim()
{

    if [[ -z "$(find /etc/opendkim/keys -iname *.private)" ]]; then
        return
    fi

    domain=$1

    # 参考: https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-dkim-with-postfix-on-debian-wheezy
    # sudo apt-get install opendkim opendkim-tools -y
    cat >> /etc/opendkim.conf<<EOF
AutoRestart             Yes
AutoRestartRate         10/1h
UMask                   002
Syslog                  yes
SyslogSuccess           Yes
LogWhy                  Yes

Canonicalization        relaxed/simple

ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable

Mode                    sv
PidFile                 /var/run/opendkim/opendkim.pid
SignatureAlgorithm      rsa-sha256

UserID                  opendkim:opendkim

Socket                  inet:12301@localhost
EOF

    cat >> /etc/default/opendkim <<EOF
SOCKET="inet:12301@localhost"
EOF


    # postfix main.cf
    postconf -e "milter_protocol = 2"
    postconf -e "milter_default_action = accept"

    ## 如果有下面配置也要添加
    #smtpd_milters = unix:/spamass/spamass.sock, inet:localhost:12301
    #non_smtpd_milters = unix:/spamass/spamass.sock, inet:localhost:12301
    postconf -e "smtpd_milters = inet:localhost:12301"
    postconf -e "non_smtpd_milters = inet:localhost:12301"

    # mkdir -pv /etc/opendkim/keys

    cat >> /etc/opendkim/TrustedHosts <<EOF
127.0.0.1
localhost
192.168.0.1/24

*.${domain}

#*.example.net
#*.example.org
EOF

    cat >> /etc/opendkim/KeyTable <<EOF
mail._domainkey.${domain} ${domain}:mail:/etc/opendkim/keys/${domain}/mail.private
EOF

    cat >> /etc/opendkim/SigningTable <<EOF
*@${domain} mail._domainkey.${domain}
EOF
}

bug_fix()
{
    # 如果 postfix 不能写日志, 可能是权限问题
    touch /var/log/mail.log
    chown syslog.adm /var/log/mail.log
}

check_envs
setup_virtual

configure_postfix ${MAIL_DOMAIN}
create_accounts ${MAIL_DOMAIN} ${MAIL_ACCOUNTS}

configure_postfix_tls

setup_dkim ${MAIL_DOMAIN}

bug_fix

service rsyslog start
service opendkim start
service postfix start

# 等待 log 文件生成
while [ ! -f /var/log/mail.log ]; do
    sleep 1
done
tail -f /var/log/mail.log
