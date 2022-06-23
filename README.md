# Инициализация системы. Systemd.
Выполнить следующие задания и подготовить развёртывание результата выполнения с использованием Vagrant и Vagrant shell provisioner (или Ansible, на Ваше усмотрение):

- Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/sysconfig).

- Из репозитория epel установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi).

- Дополнить unit-файл httpd (он же apache) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами.

- 4*. Скачать демо-версию Atlassian Jira и переписать основной скрипт запуска на unit-файл.

# Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/sysconfig).
Создаем файл с конфигурацией для сервиса (из него будут браться переменные). Ключевое слово будет ddmwebapi:
```
[root@yarkozloff ~]# cat /etc/sysconfig/watchlog
# Configuration file for my watchdog service
# Place it to /etc/sysconfig
# File and word in that file that we will be monit
WORD="ddmwebapi"
LOG=/var/log/w3clog.log
```
Создаем лог /var/log/w3clog.log Пишем скрипт.
```
[root@yarkozloff ~]# cat /opt/watchlog.sh
#!/bin/bash
WORD=$1
LOG=$2
DATE='date'
if grep $WORD $LOG &> /dev/null
then
        logger "$DATE: OMG, im search ddmwebapi, Master!"
else
        exit 0
fi
```
Команда logger отправляет лог в системный журнал Создадим Юнит для сервиса:
```
[root@yarkozloff ~]# cat /etc/systemd/system/watchlog.service
[Unit]
Description=My watchlog service
[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
```
Создаем юнит для таймера:
```
[root@yarkozloff ~]# cat /etc/systemd/system/watchlog.timer
[Unit]
Description=Run watchlog script every 30 second
[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service
[Install]
WantedBy=multi-user.target
```
Запускаем таймер:
```
[root@yarkozloff ~]# systemctl start watchlog.timer
```
Ничего не пишется. Смотрим статус watchlog.service:
```
[root@yarkozloff ~]# systemctl status watchlog.service
● watchlog.service - My watchlog service
   Loaded: loaded (/etc/systemd/system/watchlog.service; static; vendor preset: disabled)
   Active: failed (Result: exit-code) since Sat 2022-05-21 23:59:09 CEST; 22s ago
  Process: 21029 ExecStart=/opt/watchlog.sh $WORD $LOG (code=exited, status=203/EXEC)
```
Смотрим journalctl -xe:
```
May 22 00:18:44 yarkozloff.ru systemd[1]: Starting My watchlog service...
-- Subject: Unit watchlog.service has begun start-up
-- Defined-By: systemd
-- Support: http://lists.freedesktop.org/mailman/listinfo/systemd-devel
--
-- Unit watchlog.service has begun starting up.
May 22 00:18:44 yarkozloff.ru systemd[7977]: Failed at step EXEC spawning /opt/watchlog.sh: Permission denied
-- Subject: Process /opt/watchlog.sh could not be executed
```
Правим правишки:
```
chmod +x /opt/watchlog.sh
```
Убедимся в результате:
```
[root@yarkozloff ~]# tail -f /var/log/messages
May 22 00:26:57 yarkozloff systemd: Started My watchlog service.
May 22 00:27:41 yarkozloff systemd: Starting My watchlog service...
May 22 00:27:41 yarkozloff root: date: OMG, im search ddmwebapi, Master!
May 22 00:27:41 yarkozloff systemd: Started My watchlog service.
May 22 00:28:13 yarkozloff systemd: Starting My watchlog service...
May 22 00:28:13 yarkozloff root: date: OMG, im search ddmwebapi, Master!
May 22 00:28:13 yarkozloff systemd: Started My watchlog service.
May 22 00:28:43 yarkozloff systemd: Starting My watchlog service...
May 22 00:28:43 yarkozloff root: date: OMG, im search ddmwebapi, Master!
May 22 00:28:43 yarkozloff systemd: Started My watchlog service.
May 22 00:29:43 yarkozloff systemd: Starting My watchlog service...
May 22 00:29:43 yarkozloff root: date: OMG, im search ddmwebapi, Master!
May 22 00:29:43 yarkozloff systemd: Started My watchlog service.
```
Успех. Остаётся собрать всё это дело в Playbook для Ansible и запровиженить машину. Для тестирования сделал vagrant destroy и vagrant up:
```
     unitserver: Running ansible-playbook...

PLAY [Install monitorlog by 30sec] *********************************************

TASK [Gathering Facts] *********************************************************
ok: [unitserver]

TASK [copy test log] ***********************************************************
changed: [unitserver]

TASK [create watchlog keyword config] ******************************************
changed: [unitserver]

TASK [create watchlog search script by keyword] ********************************
changed: [unitserver]

TASK [create watchlog service] *************************************************
changed: [unitserver]

TASK [create watchlog timer] ***************************************************
changed: [unitserver]

TASK [permission for watchlog.sh] **********************************************
changed: [unitserver]

TASK [enable and start watchlog timer] *****************************************
changed: [unitserver]

TASK [enable and start watchlog service] ***************************************
changed: [unitserver]

PLAY RECAP *********************************************************************
unitserver                 : ok=9    changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
Подключаемся проверяем:
```
Last login: Wed Jun 22 21:02:50 2022 from 10.0.2.2
[vagrant@unitserver ~]$ sudo -i
[root@unitserver ~]# tail -f /var/log/messages
Jun 22 21:02:51 localhost ansible-ansible.builtin.systemd: Invoked with no_block=False force=None name=watchlog.service daemon_reexec=False enabled=True daemon_reload=False state=started masked=None scope=system
Jun 22 21:02:51 localhost systemd: Starting My watchlog service...
Jun 22 21:02:51 localhost root: Wed Jun 22 21:02:51 UTC 2022: OMG, Invalid API Log, Master!
Jun 22 21:02:51 localhost systemd: Started My watchlog service.
Jun 22 21:02:51 localhost systemd-logind: Removed session 2.
Jun 22 21:03:25 localhost systemd: Starting My watchlog service...
Jun 22 21:03:25 localhost systemd: Started Session 5 of user vagrant.
Jun 22 21:03:25 localhost systemd-logind: New session 5 of user vagrant.
Jun 22 21:03:25 localhost root: Wed Jun 22 21:03:25 UTC 2022: OMG, Invalid API Log, Master!
Jun 22 21:03:25 localhost systemd: Started My watchlog service.
Jun 22 21:03:51 localhost systemd-logind: Removed session 4.
Jun 22 21:04:13 localhost systemd: Starting My watchlog service...
Jun 22 21:04:13 localhost root: Wed Jun 22 21:04:13 UTC 2022: OMG, Invalid API Log, Master!
Jun 22 21:04:13 localhost systemd: Started My watchlog service.
```
Из репозитория epel установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi).
Устанавливаем spawn-fcgi и необходимые для него пакеты:
```
[root@yarkozloff ~]# yum install epel-release -y && yum install spawn-fcgi php php-cli
```
Раскоментируем строки:
```
[root@yarkozloff ~]# cat /etc/sysconfig/spawn-fcgi
# You must set some working options before the "spawn-fcgi" service will work.
# If SOCKET points to a file, then this file is cleaned up by the init script.
#
# See spawn-fcgi(1) for all possible options.
#
# Example :
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -P /var/run/spawn-fcgi.pid -- /usr/bin/php-cgi"
```
Юнит файл:
```
[root@yarkozloff ~]#  cat /etc/systemd/system/spawn-fcgi.service
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target
[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process
[Install]
WantedBy=multi-user.target
```
Проверка работы службы:
```
[root@yarkozloff ~]# systemctl start spawn-fcgi
[root@yarkozloff ~]# systemctl status spawn-fcgi
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
   Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor preset: disabled)
   Active: active (running) since Sun 2022-05-22 00:36:30 CEST; 2min 5s ago
 Main PID: 8490 (php-cgi)
   CGroup: /system.slice/spawn-fcgi.service
           ├─8490 /usr/bin/php-cgi
           ├─8491 /usr/bin/php-cgi
...
...
```
Успех. Остаётся собрать всё это дело в Playbook для Ansible и запровиженить машину. Для тестирования сделал vagrant destroy и vagrant up:
```
    unitserver: Running ansible-playbook...

PLAY [Install spawn-fcgi from the epel repository and rewrite the init script to a unit file] ***

TASK [Gathering Facts] *********************************************************
ok: [unitserver]

TASK [install packages] ********************************************************
changed: [unitserver] => (item=epel-release)
changed: [unitserver] => (item=spawn-fcgi)
changed: [unitserver] => (item=php)
ok: [unitserver] => (item=php-cli)

TASK [uncomment spawn-fcgi config 1step] ***************************************
changed: [unitserver]

TASK [uncomment spawn-fcgi config 2step] ***************************************
changed: [unitserver]

TASK [unit file for spawn-fcgi.service] ****************************************
changed: [unitserver]

TASK [start spawn-fcgi.service] ************************************************
changed: [unitserver]

PLAY RECAP *********************************************************************
unitserver                 : ok=6    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
Подключаемся проверяем:
```
root@yarkozloff:/otus/units# vagrant ssh
Last login: Wed Jun 22 22:00:14 2022 from 10.0.2.2
[vagrant@unitserver ~]$ sudo -i
[root@unitserver ~]# systemctl status spawn-fcgi
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
   Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; enabled; vendor preset: disabled)
   Active: active (running) since Wed 2022-06-22 22:00:15 UTC; 1min 11s ago
 Main PID: 4413 (php-cgi)
   CGroup: /system.slice/spawn-fcgi.service
           ├─4413 /usr/bin/php-cgi
           ├─4424 /usr/bin/php-cgi
           ├─4425 /usr/bin/php-cgi
           ...
           ...
```
## Дополнить unit-файл httpd (он же apache) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами.
Для запуска нескольких экземпляров будет использоваться шаблон(%I). Для этого создаем файл /usr/lib/systemd/system/httpd@.service и укажем там шаблон %I:
```
[root@yarkozloff /]# cat /usr/lib/systemd/system/httpd@.service
[Unit]
Description=The Apache HTTP Server %I
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/httpd-%I
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
ExecStop=/bin/kill -WINCH ${MAINPID}
# We want systemd to give httpd some time to finish gracefully, but still want
# it to kill httpd after TimeoutStopSec if something went wrong during the
# graceful stop. Normally, Systemd sends SIGTERM signal right after the
# ExecStop, which would kill httpd. We are sending useless SIGCONT here to give
# httpd time to finish.
KillSignal=SIGCONT
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```
В самом файле окружения (которых будет два) задается опция для запуска веб-сервера с необходимым конфигурационным файлом:
```
[root@yarkozloff ~]# cat /etc/sysconfig/httpd-first
OPTIONS=-f conf/first.conf
[root@yarkozloff ~]# cat /etc/sysconfig/httpd-second
OPTIONS=-f conf/second.conf
```
Также укажем опции Listen и PidFile, уникальные для каждого конфига. Сами конфиги располагаются по пути /etc/httpd/conf/ То есть копируем оригинальный httpd.conf и заменяем значение Listen, и добавляем PidFile:
```
[root@yarkozloff /]# cat /etc/httpd/conf/first.conf | grep Listen
# Listen: Allows you to bind Apache to specific IP addresses and/or
# Change this to Listen on specific IP addresses as shown below to
#Listen 12.34.56.78:80
Listen 8081
[root@yarkozloff /]# cat /etc/httpd/conf/first.conf | grep PidFile
# least PidFile.
PidFile /var/run/httpd-first.pid

[root@yarkozloff /]# cat /etc/httpd/conf/second.conf | grep Listen
# Listen: Allows you to bind Apache to specific IP addresses and/or
# Change this to Listen on specific IP addresses as shown below to
#Listen 12.34.56.78:80
Listen 8082
[root@yarkozloff /]# cat /etc/httpd/conf/second.conf | grep PidFile
# least PidFile.
PidFile /var/run/httpd-second.pid
```
Запускаем экземпляры:
```
[root@yarkozloff /]# systemctl start httpd@first.service
[root@yarkozloff /]# systemctl start httpd@second.service
```
Для проверки, послушаем порты:
```
[root@yarkozloff /]# ss -tnulp | grep httpd
tcp    LISTEN     0      128    [::]:80                 [::]:*                   users:(("httpd",pid=18226,fd=4),("httpd",pid=18225,fd=4),("httpd",pid=18224,fd=4),("httpd",pid=18223,fd=4),("httpd",pid=18222,fd=4),("httpd",pid=18221,fd=4))
tcp    LISTEN     0      128    [::]:8081               [::]:*                   users:(("httpd",pid=18725,fd=4),("httpd",pid=18724,fd=4),("httpd",pid=18723,fd=4),("httpd",pid=18722,fd=4),("httpd",pid=18721,fd=4),("httpd",pid=18720,fd=4))
tcp    LISTEN     0      128    [::]:8082               [::]:*                   users:(("httpd",pid=18741,fd=4),("httpd",pid=18740,fd=4),("httpd",pid=18739,fd=4),("httpd",pid=18738,fd=4),("httpd",pid=18737,fd=4),("httpd",pid=18736,fd=4))
```
Успех. Остаётся собрать всё это дело в Playbook для Ansible и запровиженить машину. Для тестирования сделал vagrant destroy и vagrant up:
```
   unitserver: Running ansible-playbook...

PLAY [run multiple httpd instances] ********************************************

TASK [Gathering Facts] *********************************************************
ok: [unitserver]

TASK [install packages] ********************************************************
changed: [unitserver]

TASK [copy file httpd@.service] ************************************************
changed: [unitserver]

TASK [copy file httpd-first] ***************************************************
changed: [unitserver]

TASK [copy file httpd-second] **************************************************
changed: [unitserver]

TASK [copy file first.conf] ****************************************************
changed: [unitserver]

TASK [copy file second.conf] ***************************************************
changed: [unitserver]

TASK [selinux portd 8081] ******************************************************
changed: [unitserver]

TASK [selinux permissive] ******************************************************
changed: [unitserver]

TASK [start httpd service] *****************************************************
changed: [unitserver]

TASK [start httpd first service] ***********************************************
changed: [unitserver]

TASK [start httpd second service] **********************************************
changed: [unitserver]

PLAY RECAP *********************************************************************
unitserver                 : ok=12   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
Подключаемся проверяем:
```
root@yarkozloff:/otus/units# vagrant ssh
Last login: Thu Jun 23 00:19:35 2022 from 10.0.2.2
[vagrant@unitserver ~]$ sudo -i
[root@unitserver ~]# ss -tnulp | grep httpd
tcp    LISTEN     0      128    [::]:80                 [::]:*                   users:(("httpd",pid=4302,fd=4),("httpd",pid=4301,fd=4),("httpd",pid=4300,fd=4),("httpd",pid=4299,fd=4),("httpd",pid=4298,fd=4),("httpd",pid=4296,fd=4))
tcp    LISTEN     0      128    [::]:8081               [::]:*                   users:(("httpd",pid=4400,fd=4),("httpd",pid=4399,fd=4),("httpd",pid=4398,fd=4),("httpd",pid=4397,fd=4),("httpd",pid=4396,fd=4),("httpd",pid=4394,fd=4))
tcp    LISTEN     0      128    [::]:8082           
