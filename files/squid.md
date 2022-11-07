# Настраиваем squid proxy

## Базовая база 

Конфигурацию сквида можно условно разделить на три части:
1. Настройки самого сквида
2. Настройки ACL
3. Настройки правил доступа

### Настройки сквида

Тут мы будем подключать внешние плагины и настраивать порт, который должен слушать сквид

Порт настраивается через параметр в конфге `http_port 0.0.0.0:3128`. Вместо нулей можно указать адрес конкретного интерфейса.

### Какие бывают АЦЛ

**Формат написания примерно такой:** `acl ИМЯ ТИП ПАРАМЕТРЫ`

```
#АЦЛ, которая контролирует по каким портам можно или нельзя ходить
acl GoodPorts port 80 443 8080 9090  
acl BadPorts port 3099 4098 

#Ацл, которая контролирует, каким адресам можно или нельзя ходить
acl GoodHost src 192.168.1.10/32 
acl BadHost src 192.168.1.11/32
acl GoodSubnet src 192.168.1.0/24
acl BadSubnet src 192.168.10.0/24

#АЦЛ, которая контролирует, до каких адресов можно ходить
acl GoodDest dst 8.8.8.8 
acl BadDest dst 9.9.9.9

#АЦЛ, которая контролирует, по каким протоколам можно ходить
acl GoodProto proto HTTPS
acl BadProto proto HTTP

#АЦЛ, которая контролирует, по каким доменным именам можно ходить
acl GoodSites dstdomain yandex.ru google.com
acl BadSites dstdomain pornhub.com

#АЦЛ, которая контролирует, во сколько можно или нельзя ходить
acl WORKDAY time 06:00-18:00
```

### Конфигурим правила доступа

**Просто комбинация ацл**

```
http_access allow GoodPorts #Разрешаем ходить по ацл GoodPorts
http_access allow BadHost BadPorts #Разрешаем хосту с адресом из ацл BadHost ходить на порты из ацл BadPorts
http_access allow GoodHost BadPorts BadProto #Разрешаем хоступ из ацл GoodHost ходить на порты из ацл BadPorts по протоколам из ацл BadProto
http_access allow BadHost GoodPorts BadSites WORKDAY #Разрешаем хосту BadHost ходить на сайты BadSites только во время WORKDAY и только по GoodPorts
http_access deny all
```

### Базовая аутентификация

```
auth_param basic program /usr/lib/squid/baisc_ncsa_auth /etc/squid/pass #Подключаем плагин для базовой аутентификации и указываем ему базу с юзерами
auth_param basic realm squid #Имя реалма
acl auth proxy_auth REQUIRED #АЦЛ, которая говорит, что нужна аутентификация
http_access allow auth #Пускаем только прошедших аутентификацию
```

Это что касается конфиги сквида. Надо еще юзеров добавить. Делается вот так

```
apt install apache2-utils #Ставим htpasswd
htpasswd -c /etc/squid/pass user1 #Добавляем юзера в базу
```

### LDAP аутентификация

**Сначала проверь пути через ldapsearch -x на ldap сервере**

```
#Подключаем LDAP
auth_param basic program /usr/lib/squid/basic_ldap_auth -d -b "dc=wsr,dc=local" -D "uid=admin,cn=users,cn=compat,dc=wsr,dc=local" -w P@ssw0rd -f uid=%s 192.168.1.10 
auth_param basic realm squid
auth_param basic children 5

#Подключаем LDAP группы если надо 
external_acl_type ldapgroup %LOGIN /usr/lib/squid/ext_ldap_group_acl -b "dc=wsr,dc=local" -D "uid=admin,cn=users,cn=compat,dc=wsr,dc=local" -w P@ssw0rd -f (&(memberOf=cn=%g,cn=groups,cn=accounts,dc=wsr,dc=local)(uid=%u)) 192.168.1.10

#Пишем ACL
acl auth proxy_auth REQUIRED #Говорим, что аутентификация нужна
acl ldapgroup-proxy external ldapgroup groupname #Опционально определяем groupname

#Пишем правила доступа
http_access allow auth #Любому аутентифицированному юзеру можно
http_access allow auth ldapgroup-proxy #Можно только тем, кто состоит в группе groupname
```

### Kerberos аутентификация

**Обязательно должен работать DNS либо костыли через hosts. Прокси конфигурится не по адресу, а по DNS имени**

1. Добавили сервак со сквидом в домен
2. На ипа сервере добавляем принципал `ipa service-add HTTP/squid.domain.name`
3. На сквид сервере получаем keytab `ipa-getkeytab -s squid.domain.name -p HTTP/squid.domain.name -k /etc/squid/keytab`
4. Назначаем на кейтаб права `chown proxy:proxy /etc/squid/keytab`
5. Пишем конфигу сквида

```
auth_param negotiate program /usr/lib/squid/negotiate_kerberos_auth -d -k /etc/squid/keytab -s HTTP/ca-rtr.wsr.local #Подключаем плагин, где указываем keytab (через -k) и принципал (через -s)
auth_param negotiate children 5
auth_param negotiate keep_alive on

acl auth proxy_auth REQUIRED  #АЦЛ для аутентификации

http_access allow auth  #Можно только аутентифицированным
```
