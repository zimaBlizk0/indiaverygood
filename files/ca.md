# Центр сертификации

**Перед тем, как что-то делать с сертами -- настрой синхронизацию времени**

## Корневой ЦС

Делается при помощи пакета `openssl-perl`

В астре пакет есть по умолчанию, как и в большинстве других дистров

Сначала конфигурим. Открываем файлик `/etc/ssl/openssl.cnf`, находим там директиву `[ CA_default ]`, там находим переменную dir и меняем ее на директорию, где будет находится наш CA. Там же находим policy, ее меняем на policy_anything.

```
[ CA_default ]

dir = ./demoCA          #Меняем demoCA на что-нибудь свое. Точки в начале быть не должно.
policy = policy_match   #Меняем на policy_anything
copy_extensions = copy  #Раскомментируем
```

Дальше ищем `[ req_distinguished_name ]`. Там меняются параметры запроса по умолчанию. Если надо -- меняем.

```
[ req_distinguished_name ]

countryName_default = AU  #Страна по умолчанию
stateOrProvinceName_default = Some-State #Область или штат
0.organizationName_default  = Internet Widgits Pty Ltd  #Организация
```

Если мы хотим создавать подчиненный CA надо еще изменить параметры в секции `[req]` и `[ v3_req ]`.
 
**Потом нужно поменять все обратно**

```
[req]

# req_extensions = v3_req # Раскомментировать 

[v3_req]

basicConstraints = CA:FALSE #Меняем FALSE на TRUE
```

Дальше идем в `/usr/lib/ssl/misc` и работаем со скриптом `CA.pl`. Для начала надо найти там переменную `$CATOP` и поменять ее на такое же значение, как у `dir` в `openssl.cnf`.

После этого можно создавать центр сертификации и выпускать сертификаты

```console
./CA.pl -newca  #Создать центр сертификации
./CA.pl -newreq-nodes #Создать запрос без шифрования приватного ключа (Если выпускаем серт для веб сервера)
./CA.pl -newreq #Создать запрос с шифрованием приватного ключа (Если выпускаем серт для центра сертификации)
./CA.pl -sign #Подписываем запрос
```

## Подчиненный ЦА

Чтоб создать подчиненный центр сертификации

1. Выписываем на него серт
2. Настраиваем машину с подчиненным CA также, как настраивали Корневой
3. Выписаный серт и ключ передаем на машину и кладем в `/usr/lib/ssl/misc`
4. Идем туда, выполняем `CA.pl -newca`. Когда он предложит ввести имя файла или нажать enter -- вводим имя серта, который мы выписали

**Почему-то иногда он коряво импортирует. Если так произошло -- руками кладем приватный ключ и файл serial (можно забрать с рута)**

## Трасты

1. Копируем рутовый и сабовый (если есть) серты в директорию `/usr/loca/share/ca-certificates` на каждой машине (обязательно расширение .crt)
2. Выполняем команду `update-ca-certificates`
3. Выполняем команду `openssl verify /usr/local/share/ca-certificates/названиерута`, должно быть ок
4. Чиним файрфокс. Для этого делаем `rm -rf /usr/lib/firefox/libnssckbi.so`
5. Потом делаем `/usr/lib/x86_64-linux-gnu/pkcs11/p11-kit-trust.so /usr/lib/firefox/libnssckbi.so`

## Альты

Сначала создаем примерно такой конфиг в папке `/usr/lib/ssl/misc`. Называем его например `req.cnf`

```
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C=AU
ST=Some-State
OU=OU
CN=mail.wsr.local    #Тут пишем реальный CN домена, для которого будет серт

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]              #Тут обязательно прописываем какие-нибудь альты
DNS.1 = mail.wsr.local
DNS.2 = wsr.local
DNS.3 = www.wsr.local
```

Дальше генерим запрос с помощью вот такой команды

`openssl req -new -sha256 -nodes -out newreq.pem -newkey rsa:2048 -keyout newkey.pem -config req.cnf`

Названия надо соблюсти такие, чтоб CA.pl отработал

Дальше делаем `CA.pl -sign`

И раскидываем серты

