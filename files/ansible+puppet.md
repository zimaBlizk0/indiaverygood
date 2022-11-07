# Небольшая справочная по Ansible и Puppet

## По Ansible
Рекомендую создавать отдельный каталог где ты разместишь:
ansible.cfg
inventory

Файл ansible.cfg имеет вид:
    [default]
    inventory = ./inventory
    host_key_checking = False

Помни, что Ansilbe по-умолчанию подключается по ключам, так что если хочешь можешь прокинуть ключи, а если не хочешь, то можешь указать в inventory пароль в явном виде.
Файл inventory может иметь вид:
    [client] - так ты делишь хосты на группы, может быть полезно если нужно делать один плейбук под разные задачи (или можешь использовать роли, но это чуть сложнее)
    192.168.1.1
    192.168.1.2

    [server]
    192.168.1.10

    [server:vars]  - так можно описать переменные для твоего пула, если требуется, актуально если собираешься подключаться к хостам не по ключам. 
    ansible_ssh_user = Administrator
    ansible_ssh_pass = P@ssw0rd 

Если идея писать пароли в чистом виде тебе не нравится (что логично), то можно воспользоваться ansible-vault
Команда создаст тебе зашифрованный файл -
```console
$ ansible-vault create user.yml
```
Там пропиши такие же переменные, что и в inventory писал(а).
    ansible_ssh_user = Administrator
    ansible_ssh_pass = P@ssw0rd
В плейбуке, к нему обращаться вот так: 
    ---
    - hosts: all
      secrets_file:
        - ./user.yml

## По Puppet
На Astra Linux сначала необходимо убедиться, что у вас подключена английская локализация. 
```console
$ locale -a | grep en_US.utf-8
```
Если её нет, то ввести команды: 
```console
$ echo "en_US.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen
```
```console
$ sudo locale-gen
```

Далее установка самого Puppet.
```console
$ sudo apt install puppetserver
```
Помни, что он запустится только на ВМ с 4+ ГБ ОЗУ.
```console
$ systemctl enable --now puppetserver
```

Помни, что Puppet работает по сертификатам, которые выпускает центр сертификации PuppetCA. Тебе его конфигурить не надо, но стоит настроить автовыдачу по domain-name.
Для этого на сервере идем в файл - 
```console
$ vim /etc/pupeptlabs/puppet/autosign.conf
```
И пиши там твой домен, например: 
```console
$ *.wsr.local
```
Конечно же, после такой настройки у тебя везде на клиентах Puppet должен быть FQDN с wsr.local.

Также, вероятно на Puppet тебе потребуется реализовать механизм отправки файлов через Puppet. Для этого включается отдельная опция fileserver:
```console
$ vim /etc/puppetlabs/puppet/fileserver.conf
```
И там мы пишем:
    [files]
    path /etc/puppetlabs/code/files - именно по этому пути тебе надо будет располагать файлы для пересылки подчиненным хостам
    allow *
После этого не забудь
```console
$ systemctl restart puppetserver
```
Теперь настройка Puppet-agent
```console
$ apt install puppet-agent
```
После установки агента идем в файл
```console
$ vim /etc/puppetlabs/puppet/puppet.conf
```
    [main]
    server = ca-mon.wsr.local -здесь, конечно пиши FQDN своего паппет-сервера

Далее отличная команда которая тебе четко покажет работает все или нет.
С неё и дебажить удобно:

```console
$ puppet agent -tv
```

Если все ок, переходим к настройке веб-интерфейса Foreman.
```console
$ apt install shared-mime-info foreman-installer
```
После установки, погнали: 
```console
$ foreman-installer
```

Система должна сама всё настроить, желательно ставить Puppet на тот хост, где у тебя еще не было ни одного веб-сервиса, а в идеале и не будет.

Если вдруг foreman-installer не поставился, подключи Debian-репозитории.
Изначально Foreman тебе выдумает сложный пароль, сбросить его можно так: 
```console
$ sudo foreman-rake permissions:reset username=admin password=<новый пароль>
```
После этого по https заходи на сайт и будет тебе счастье.
Foreman ренегирует себе простой apache.conf
Прикрутить сюда SSL-сертификат не составит труда, иди в /etc/apache2/
И ищи все что связано с SSLCertificate*
Через grep -ir.

В репозитории на гите также лежат два типовых примера плейбуков и манифестов, чтобы тебе не забыть.

