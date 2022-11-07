# Почта


## postfix

Сначала надо репы деб9 подключить, делается вот так:

```
apt install debian-archive-keyring
echo "deb https://mirror.yandex.ru/debian stretch main contrib non-free" >> /etc/apt/sources.list
apt update
```

Вводим сервак в домен, убеждаемся, что юзеры могут локально входить на сервак (команда `login`)

Ставим пакеты `apt isntall postfix dovecot-imapd `

При установке постфикса вылетит визард -- можнго протыкать на дефолтных значениях. Как только поставилось -- запускаем `dpkg-reconfigure postfix`

1. Выбираем "Интернет сайт"
2. Системное почтовое имя ставим ваш домен (wsr.local в моем примере)
3. Получателя почты для root и postmaster можно не указывать
4. В других адресатах обязатльено должен быть домен и localhost
5. Синхронные обновления почтовой очереди -- нет
6. В локальных сетях указываем наши подсети, где будет работать почта и 127.0.0.1
7. Дальше все параметры по умолчанию

Идем в `/etc/postfix/main.cf`

```
#Меняем пути к сертам на свои
smtpd_tls_cert_file=/root/newcert.pem
smtpd_tls_key_file=/root/newkey.pem
```

## Dovecot 

Идем в `/etc/dovecot/conf.d/10-auth.conf`

```
disable_plaintext_auth = no #Раскомментируем, пишем no 
auth_mechanisms = plain login #Дописываем login 
```

Потом идем в `/etc/dovecot/conf.d/10-master.conf`

```
#Находим там вот это, раскомментируем

# Postfix smtp-auth
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix    #Дописали
    group = postfix   #Дописали
```

Потом идем в `/etc/dovecot/conf.d/10-mail.conf`

```
mail_location = mbox:/var/mail/mbox/%u:INBOX=/var/mail/%u  #Меняем mbox на /var/mail/mbox
```

**Не забываем потом создать папку /var/mail/mbox и дать на /var/mail права 777**

Потом идем в `/etc/dovecot/conf.d/10-ssl.conf`

```
ssl = yes  #Раскомментировали, сделали yes

#Расскоментировали, написали пути к серту и ключу. < в начале обязательно!!!
ssl_cert = </root/newcert.pem
ssl_key = </root/newkey.pem
```

Делаем `systemctl restart postfix dovecot` и базовая почта готова
