# Настраиваем CEPH
В минимальной конфигурации CEPH имеет смысл собирать на трех нодах, в примере, это будут машины CA-FS, CA-MAIL, CA-MON

## Требования к стенду
На момент создания CEPH вы должны иметь настроенную сетевую связность, настроенный SSH-сервер между всеми хостами, **одинаковое время!!.**
Для удобства, рекомендую разблокировать пользователя root на Astra Linux и по SSH подключается именно через него. 

В инфраструктутре CEPH, будет устройство-контроллер (в нашем случае CA-FS) и подчиненные устройства CA-MAIL,CA-MON.

**НЕ НАЗЫВАЙТЕ ИМЕНА МАШИН ЧЕРЕЗ БОЛЬШИЕ БУКВЫ! ТОЛЬКО МАЛЕНЬКИЕ!**

Все работы выполняются на CA-FS, так как именно он управляющее устройство для CEPH

## Базовая база 

На машинах CA-FS, CA-MAIL, CA-MON, если нет DNS-сервера,проще всего настроить `/etc/hosts`. Формат:

192.168.1.50 ca-fs
192.168.1.30 ca-mon
192.168.1.20 ca-mail

### Установка ceph-deploy

На CA-FS установите ceph-deploy:
```console
$ sudo apt install ceph-deploy -y
```

### Подготовка SSH-инфраструктуры
На CA-FS из под пользователя root -
```console
$ ssh-keygen
```
```console
$ ssh-copy-id root@ca-fs
```
```console
$ ssh-copy-id root@ca-mon
```
```console
$ ssh-copy-id root@ca-mail
```
После этого выполните проверку, что с CA-FS вы можете попасть на все машины в кластере по SSH без указания пароля, только ключи.

### Установка CEPH-компонентов
На CA-FS из под пользователя root  - 
```console
$ ceph-deploy --username root install --mon --osd --mgr ca-fs ca-mail ca-mon
```

### Сборка кластера CEPH
На CA-FS из под пользователя root  - 
```console
$ ceph-deploy --username root new ca-fs ca-mail ca-mon
```

### Инициализация демона-мониторинга CEPH
На CA-FS из под пользователя root  - 
```console
$ ceph-deploy --username root mon create-initial
```

### Установка менеджера-кластера CEPH
На CA-FS из под пользователя root  - 
```console
$ ceph-deploy --username root mgr create ca-fs ca-mail ca-mon
```

### На этом этапе вам нужно добавить диски к виртуалкам. По 1 диску в 5 ГБ.
Через команду 
```console
$ fdsik -l
```
Сможете точно узнать какое имя получил новый диск.

### Создание OSD (Object Storage Devices) - основное устройство хранения в CEPH
На CA-FS из под пользователя root  - 
```console
$ ceph-deploy --username root osd create --data /dev/sdb ca-fs
```
```console
$ ceph-deploy --username root osd create --data /dev/sdb ca-mail
```
```console
$ ceph-deploy --username root osd create --data /dev/sdb ca-mon
```

### Установка инструментов управления CEPH-cli. Команда устанавливает на хосты инструменты монтирования и работы с CEPH, как клиент. 
```console
$ ceph-deploy --username root install --cli ca-fs ca-mon ca-mail
```

### Окончательная настройка CEPH, перенос конфигурационных файлов в /etc/ceph
```console
$ ceph-deploy --username root admin ca-fs
```

```console
$ ceph-deploy --username root admin ca-mon
```

```console
$ ceph-deploy --username root admin ca-mail
```

## А работает ли???
Введи эту команду, в ответ должен получить весь отчёт о собранном кластере. Если выдает ошибку, повтори команду выше на машине, где не работает

```console
$ ceph -s
```
```console
$ ceph mon stat
```
```console
$ ceph mon dump
```

### Создание пула хранилища
```console
$ ceph osd pool create wsr 128 
```

### Создание пула в формате cephfs
```console
$ ceph osd pool application enable wsr cephfs
```

### Включение WEB-интерфейса для мониторинга 
```console
$ ceph mgr module enable dashboard
```
После включения, на машине где ввели команду (вероятнее всего на CA_FS), откроется порт 7000. Заходите через браузер. 

### Установка MDS (сервера метаданных)
```console
$ ceph-deploy --username root install --mds ca-fs
```
```console
$ ceph-deploy --username root mds create ca-fs
```

### Создание пула для метаданных
```console
$ ceph osd pool create wsr_metadata 64
```
```console
$ ceph fs new cephfs wsr_metadata wsr
```

### Обновления
```console
$ ceph-deploy install --mds hq-sr1 hq-srv2 hq-srv3
```

```console
$ ceph-deploy mds create hq-srv1 hq-srv2 hq-srv3
```

### Готово!

## Как примонтировать кластер к машине?
```console
$ cat ceph.client.admin.keyring | grep key > admin.secret
```
затем в этом файле удалите все лишнее, оставив только ключ, без опций и прочих параметров. Чисто ключ!

Передайте полученный файл на сервер, где планируете монтировать ресурс (например, на сервер NFS)
```console
$ mount -t ceph ca-fs,ca-mon,ca-mail:/ /mnt -o name=admin,secretfile=admin.secret
```
Ресурс будет примонтирован!
Если ресурс не монтируется:
1. Проверьте что на машине есть инструменты работы с CEPH, для монтирования нужен ceph-common. Доступен через APT.
2. Монтировать можно и по IP-адресам, не обязательно по DNS. Проверь работу DNS, если не монтируется.

Для того, чтобы добавить его в автомонтирование в fstab пиши:
```console
$ ca-fs,ca-mon,ca-mail: /mnt ceph name=admin,secretfile=/root/admin.secret,x-systemd.automount,x-systemd.mount-timeout=10 0 0
```
Далее ребут (не забудь перед этим конечно поставить пароль root).
Ресурс, вероятно, примонтируется немногновенно. Это нормально.
