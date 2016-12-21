# ooclab/postfix 邮件服务映像

## 参考

- https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-dkim-with-postfix-on-debian-wheezy
- https://github.com/catatnight/docker-postfix

## docker 用法示例

创建 opendkim keys :

```
docker run -it --rm \
    -e MAIL_DOMAIN=cn1.mail.ooclab.com \
    -v /srv/postfix/opendkim/keys:/etc/opendkim/keys \
    ooclab/postfix bash /opt/bin/build_opendkim_keys.sh
```

创建 certs :

```
docker run -it --rm \
    -e MAIL_DOMAIN=cn1.mail.ooclab.com \
    -v /srv/postfix/certs:/etc/postfix/certs \
    ooclab/postfix bash /opt/bin/build_tls_keys.sh
```

启动 postfix 容器：

```
docker run -it --rm \
    -e MAIL_DOMAIN=cn1.mail.ooclab.com \
    -e MAIL_ACCOUNTS="user1:pass1;user2:pass2" \
    -e ADMIN_MAIL=admin@ooclab.com \
    -v /srv/postfix/opendkim/keys:/etc/opendkim/keys \
    -v /srv/postfix/certs:/etc/postfix/certs \
    ooclab/postfix
```

## docker-compose 用法示例

举例，我需要搭建一个邮件发送服务 ( hk1.mail.ooclab.com )

docker-compose.yml 文件：

```
version: "2.1"
services:
    postfix:
        # restart: always
        image: ooclab/postfix
        ports:
            - "587:587"
        environment:
            MAIL_DOMAIN: hk1.mail.ooclab.com
            MAIL_ACCOUNTS: 用户名:密码
            ADMIN_MAIL: admin@ooclab.com
        volumes:
            - /data/product/postfix/opendkim/keys:/etc/opendkim/keys
            - /data/product/postfix/certs:/etc/postfix/certs
```

第一次运行，需要初始化 postfix 。

创建 opendkim keys :

```
docker-compose run postfix /opt/bin/build_opendkim_keys.sh
```

创建 certs :

```
docker-compose run postfix /opt/bin/build_tls_keys.sh
```

**重要** ：需要配置域名有4项

用 dig 查询结果:

```
$ dig -t a hk1.mail.ooclab.com
hk1.mail.ooclab.com.    86      IN      A       47.91.139.235

$ dig -t mx hk1.mail.ooclab.com
hk1.mail.ooclab.com.    482     IN      MX      1 hk1.mail.ooclab.com.

$ dig -t txt mail._domainkey.hk1.mail.ooclab.com
mail._domainkey.hk1.mail.ooclab.com. 438 IN TXT "v=DKIM1; k=rsa; p=省略"

$ dig -t txt hk1.mail.ooclab.com
hk1.mail.ooclab.com.    375     IN      TXT     "v=spf1 mx -all"
```

其中 `mail._domainkey` 配置项的值查看 `/data/product/postfix/opendkim/keys/hk1.mail.ooclab.com/mail.txt` 内容可得。


## 测试

测试邮件推荐使用 `mail-tester.com`

python 测试程序：

```
import smtplib
from email.MIMEMultipart import MIMEMultipart
from email.MIMEText import MIMEText
from email.Utils import formatdate
from email.utils import  make_msgid

msg = MIMEMultipart()

# 注意：请前往 mail-tester.com 得到一个临时邮件地址
TO_ADDR = "web-eizhu@mail-tester.com"
login_username = "notice@hk1.mail.ooclab.com" # 用户名+域名
login_password = "密码"


msg['From'] = login_username
msg['To'] = TO_ADDR
msg['Subject'] = 'simple email in python'
msg["Date"] = formatdate(localtime=True)
msg['Message-ID'] = make_msgid()

message = 'here is the email'
msg.attach(MIMEText(message))

mailserver = smtplib.SMTP('hk1.mail.ooclab.com', 587)
mailserver.ehlo()
mailserver.starttls()
mailserver.ehlo()
mailserver.login(login_username, login_password)

mailserver.sendmail(login_username, TO_ADDR, msg.as_string())

mailserver.quit()
```
