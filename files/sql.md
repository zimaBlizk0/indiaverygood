# Отказоустойчивый СУБД

## Сначала устанавливаем etcd на три ноды

**Нужно отсинхронить время, обязательно**

Скачиваем etcd и etcdctl

`wget https://github.com/etcd-io/etcd/releases/download/v3.5.5/etcd-v3.5.5-linux-amd64.tar.gz`

Распаковываем архив и переносим все бинари в `/usr/bin/`, даем им права на выполнение

В `/etc/systemd/system` создаем юнит `etcd.service` с содержимым

```console
[Unit]
Description=etcd service

[Service]
User=root
Type=notify
ExecStart=/usr/bin/etcd \
    --name etcd01  \  #Меняем имя для каждой ноды
    --data-dir /var/lib/etcd \  #Директория должна существовать, владелец -- etcd. Если юзера нет -- добавь.
    --initial-advertise-peer-urls http://nodeip:2380 \  #Сюда вставляем адрес машины, где крутится etcd, меняем для каждой ноды
    --listen-peer-urls http://nodeip:2380 \ 
    --listen-client-urls http://nodeip:2379,http://127.0.0.1:2379  \
    --advertise-client-urls http://nodeip:2379  \
    --initial-cluster-token etcd-cluster-1 \  #одинаковый на всех нодах
    --initial-cluster etcd01=http://node1ip:2380,etcd02=http://node2ip:2380,etcd03=http://node3ip:2380 \ #Меняем адреса на свои, одинаково на всех нодах
    --initial-cluster-state new  \ 
    --enable-v2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Юнит и бинари добавляем на все три ноды, а также:

```console
useradd etcd
mkdir /var/lib/etcd
chown etcd:etcd /var/lib/etcd
systemctl daemon-reload
systemctl enable --now etcd
```

Чтоб проверить, что все работает, делаем

```
export ETCDCTL_API=2
etcdctl cluster-health
```

## Ставим посгрес

Для астры хорошо подходит postgres pro std, по этому ставим его

```
echo "deb http://repo.postgrespro.ru/pgpro-13/astra-orel/2.12 orel main" >> /etc/apt/sources.list   #Добавили репы
wget http://repo.postgrespro.ru/pgpro-13/keys/GPG-KEY-POSTGRESPRO -O- | apt-key add -   #Добаили ключ для репов
apt update && apt install postgrespro-std-13  #Ставим постгрес
systemctl disable --now postgrespro-std-13    #Отключаем постгрес, иначе патрони не взлетит
```

## Ставим patroni

```console
apt install python3-pip
pip install patroni[etcd] psycopg2-binary
```

Устанавливаем сервис patroni

```console
wget https://raw.githubusercontent.com/zalando/patroni/master/extras/startup-scripts/patroni.service
systemctl daemon-reload
```

Пишем конфигу для patroni `/etc/patroni.yml`

```console
scope: postgres
namespace: /postgres/
name: node1    #Разное имя для каждой ноды

restapi:
#Тут айпи ноды 
  listen: 0.0.0.0:8008  
  connect_address: nodeapi:8008

#Пишем адреса всех etcd нод
etcd:
  hosts:
    - etcd01ip:2379
    - etcd02ip:2379
    - etcd03ip:2379

bootstrap:
  dcs:
    ttl: 100
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        wal_keep_segments: 5120
        max_wal_senders: 10
        max_replication_slots: 10
        checkpoint_timeout: 30
  initdb:
    - encoding: UTF8
    - data-checksums
    - locale: en_US.UTF8
  pg_hba:
    - host replication replica node1ip/32 md5
    - host replication replica node2ip/32 md5
    - host replication replica node3ip/32 md5
    - host all all 0.0.0.0 md5
  users:
    replica:
      password: P@ssw0rd
      options:
        - replication
    postgres:
      password: P@ssw0rd
      options:
        - superuser

postgresql:
  listen: 0.0.0.0:6432
  connect_address: nodeip:6432
  data_dir: /data/patroni  #Должна существовать, овнер postgres
  bin_dir: /opt/pgpro/std-13/bin
  pgpass: /tmp/pgpass
  authentication:
    replication:
      username: replica
      password: P@ssw0rd
    superuser:
      username: postgres
      password: P@ssw0rd
  create_replica_methods:
    basebackup:
      checkpoint: 'fast'
  parameters:
    unix_socket_directories: '.'
    max_connections: 100
    max_locks_per_transaction: 1024

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
```

После этого можно ручками проверить, что патрони работает

```console
su - postgres
patroni /etc/patroni.yml
```

Если все работает, делаем `systemctl enable --now patroni`

Проверяем, что все работает: `patronictl -c /etc/patroni.yml list`

## Установка keepalived

```
apt install keepalived
```

Создаем `/etc/keepalived/keepalived.conf` и пишем туда что-то типа

```
vrrp_instance cluster1 {
    state MASTER #На остальных нодах state BACKUP
    interface eth0
    virtual_router_id 10  #Одинаковый на всех нодах
    priority 100  #Самый большой на мастере, на второй ноде чуть поменьше и на третьей еще меньше
    virtual_ipaddress {
        192.168.1.200/24 #Один на все ноды, поменять на свой
    }
}
```

не забываем сделать `systemctl enable --now keepalived`

## Устанавливаем haproxy

```
apt install haproxy
```

Потом идем в /etc/haproxy/haproxy.cfg

```
global
    mode tcp
    #Удаляем все, что связано с https

listen stats
    mode http
    bind *:8088
    stats enable
    stats uri /

frontend PG
    bind *:5432
    default_backend PG_back

backend PG_back
    option httpchk GET /master
    server pg1 node1ip:6432 check port 8008 inter 10s
    server pg2 node2ip:6432 check port 8008 inter 10s
    server pg3 node3ip:6432 check port 8008 inter 10s
```

Не забываем `systemctl enable --now haproxy`

еще можно `haproxy -c -f /etc/haproxy/haproxy.cfg` на всякий

Поздравляю, вы восхитительны.
