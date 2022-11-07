# Настраиваем OpenVSwitch

## Установка на астру

```
apt install debian-archive-keyring   #Чтоб работали репы debian 9
echo "deb https://mirror.yandex.ru/debian stretch main contrib non-free" >> /etc/apt/sources.list #Добавили репы 9 дебиана
apt update  #Обновили список пакетов
apt install openvswitch-switch #Ставим openvswitch
systemctl enable openvswitch-switch #Добавляем в автозагрузку (По умолчанию там, но на всякий случай)
```

## Работаем с OpenVSwitch

**ВАЖНО: т.к. комутация отдается openvswitch -- на гипервизоре создаем отдельную порт группу под каждый адаптер свича (портгруппы = провода)**

### Работаем с интерфейсами

```
ovs-vsctl add-br BR1 #Добавляем в ovs новый бридж BR1
ovs-vsctl add-port BR1 eth1 # Добавляем в бридж интерфейс eth1. Остальные добавляются по аналогии
ovs-vsctl set port BR1 eth1 tag=10 #Добавляем на интерфейс тегирование (порт во влан)
ovs-vsctl set port BR1 eth1 trunks=10,20,30 #Делаем порт транковым, разрешенные вланы через запятую
```

### Если хочется stp/rstp

```
ovs-vsctl set bridge BR1 stp_enable=true #Включаем stp
ovs-vsctl set bridge BR1 rstp_enable=true #Включаем rstp
```

**Надо включать что-то одно, очевидно**

**Отключается заменой слова true на false**

На астре openvswitch слишком старый, по этому командочки `ovs-appctl stp/show` или `ovs-appctl rstp/show` там нет.

### Если хочется LACP/Статические агрегирование

**Если ты уже добавил интерфейс в бридж -- надо его удалить**

```
ovs-vsctl add-bond BR1 bond0 eth1 eth2 #Добавляем бонд со статическим агрегированием
ovs-vsctl set port BR1 bond0 lacp=active #Включаем lacp
```

**Сделать так надо с двух сторон, очевидно**

```
ovs-appctl bond/show -- проверяем, что все работает
```

Транки настраиваются как на портах, т.е. `ovs-vsctl set port BR1 bond0 trunks=10,20,30`

### Роутер на палочке

Сначала делаем `systemctl mask NetworkManager` и перезагружаемся

Потом

Идем в /etc/network/interfaces

Пишем туда что-то типа

```
auto eth0
iface eth0 inet manual

auto eth0.10
iface eth0.10 inet static
    address 192.168.10.1/24

auto eth1
iface eth1 inet manual

auto eth1.20
iface eth1.20 inet static
    address 192.168.20.1/24
```

Потом `systemctl restart networking` и все работает

### Если что-то не так настроил

```
ovs-vsctl del-port eth1 #Удалить порт
ovs-vsctl del-port bond0 #Удалить бонд
ovs-vsctl del-br BR1 #Удалить бридж
```
