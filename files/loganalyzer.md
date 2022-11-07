# Loganalyzer и rsyslog

## rsyslog

Сначала ставим и настраиваем postgresql

Потом ставим пакет `rsyslog-pgsql`. В визарде протыкиваем свои параметры от СУБД

Перезапускаем rsyslog и убеждаемся, что он работает

```
psql -u user -h host
\c loganalyzer
select * from systemevents; #Должны увидеть логи
```

Если все норм -- прикручиваем loganalyzer

## Loganalyzer

Скачиваем архив с лог аналайзером и ставим mysql

`apt install mysql-server`

Создаем базу данных в mysql

```
mysql -u root -p
create database loganalyzer
```

распаковываем архив с loganalyzer куда-нибудь в /opt/loganalyzer и импортируем базу данных

```
tar xvf loganalyzer-xxx.tar.gz
mv loganalyzer-xxx /opt/loganalyzer
cd /opt/loganalyzer/src/include
cat db_template.txt | mysql -u root -p loganalyzer
cat db_updatevxx.txt | mysql -u root -p loganalyzer
mysql  -u root -p loganalyzer
alter table systemevents add processid int null default 0;
```

Идем в `/opt/loganalyzer/src`

```
touch config.php
chmod 666 config.php
```

Теперь создаем виртуалхост на веб сервере, корнем указываем `/opt/loganalyzer/src`

Заходим на веб морду логаналайзера, протыкиваем визард
