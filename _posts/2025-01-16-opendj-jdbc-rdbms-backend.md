---
layout: blog
title: 'OpenDJ: Использование реляционной СУБД в качестве LDAP каталога'
description: 'В данной статье мы настроим OpenDJ таким образом, чтобы он использовал базу данных PostgreSQL в качестве хранилища данных.'
tags: 
  - opendj
---

В данной статье мы настроим OpenDJ таким образом, чтобы он использовал базу данных PostgreSQL в качестве хранилища данных.

# Подготовка

Для начала у вас должна быть установлена Java не ниже 1.8 и установлен Docker. В Docker мы развернем образ PostgreSQL командой

```
docker run -it -d -p 5432:5432 -e POSTGRES_DB=database_name -e POSTGRES_PASSWORD=password --name postgres postgres
```

Скачайте дистрибутив OpenDJ по [ссылке](https://github.com/OpenIdentityPlatform/OpenDJ/releases). Версия OpenDJ должна быть не ниже 4.9.0.

```
wget https://github.com/OpenIdentityPlatform/OpenDJ/releases/download/4.9.0/opendj-4.9.0.zip
```

Разархивируйте дистрибутив

```
unzip opendj-4.9.0.zip
```

Запустите команду установки OpenDJ

```
./opendj/setup -h localhost -p 1389 --ldapsPort 1636 --adminConnectorPort 4444 --enableStartTLS --generateSelfSignedCertificate --rootUserDN "cn=Directory Manager" --rootUserPassword password --cli --acceptLicense --no-prompt

Configuring Directory Server ..... Done.
Configuring Certificates ..... Done.
Starting Directory Server ....... Done.

To see basic server configuration status and configuration, you can launch
/home/user/opendj-postgres/opendj/bin/status
```

Обратите внимание на параметры `rootUserDN` и `rootUserPassword`. Это параметры подключения к OpenDJ пользователя с административными правами.

Проверьте статус OpenDJ

```
./opendj/bin/status --bindDN "cn=Directory Manager" --bindPassword password

          --- Server Status ---
Server Run Status:        Started
Open Connections:         1

          --- Server Details ---
Host Name:                MacBook-Pro-Maxim.local
Administrative Users:     cn=Directory Manager
Installation Path:
/home/user/opendj-postgres/opendj
Version:                  OpenDJ Server 4.9.0
Java Version:             21.0.2
Administration Connector: Port 4444 (LDAPS)

          --- Connection Handlers ---
Address:Port : Protocol               : State
-------------:------------------------:---------
--           : LDIF                   : Disabled
0.0.0.0:161  : SNMP                   : Disabled
0.0.0.0:1389 : LDAP (allows StartTLS) : Enabled
0.0.0.0:1636 : LDAPS                  : Enabled
0.0.0.0:1689 : JMX                    : Disabled
0.0.0.0:8080 : HTTP                   : Disabled

          --- Data Sources ---
-No LDAP Databases Found-
```

Как видно из вывода команды, база данных LDAP еще не создана.

# Настройка OpenDJ

Создайте OpenDJ backend с использованием СУБД PostgreSQL

```
./opendj/bin/dsconfig create-backend -h localhost -p 4444 --bindDN "cn=Directory Manager" --bindPassword password --backend-name=userRoot --type jdbc --set base-dn:dc=example,dc=com --set 'db-directory:jdbc:postgresql://localhost:5432/database_name?user=postgres&password=password' --set enabled:true --no-prompt --trustAll
```

В этой команде интерес представляют аргументы `--type`, который должен быть равен `jdbc` для использования реляционной БД и `--set 'db-directory:jdbc:...` — строка подключения к JDBC совместимому источнику данных. 

> СУБД может быть практически любой, для которой есть JDBC совместимый драйвер. Например, вы можете использовать MySQL, MS SQL Server и так далее. Для использования JDBC-совместимой базы данных нужно скачать соотвествующий драйвер, и скопировать его в директорию `./opendj/lib`  и поменять строку подключения к JDBC источнику в аргументе `--set`. Пример строки подключения для MySQL: `db-directory:jdbc:mysql://mysqlhost:3306/database_name?user=mysql&password=password`. Более подробно об этом написано в документации к соответствующему драйверу
> 

Более подробно про параметры команды `dsconfig create-backend` вы можете прочитать по ссылке

[https://doc.openidentityplatform.org/opendj/reference/dsconfig-subcommands-ref#dsconfig-create-backend](https://doc.openidentityplatform.org/opendj/reference/dsconfig-subcommands-ref#dsconfig-create-backend).

# Проверка решения

Для демонстрационных целей создайте и загрузите тестовые данные в OpenDJ

Создание ldif файла с тестовыми данными из шаблона:

```
./opendj/bin/makeldif -o /tmp/test.ldif -c suffix=dc=example,dc=com ./opendj/config/MakeLDIF/example.template                                                                   
Processed 1000 entries
Processed 2000 entries
Processed 3000 entries
Processed 4000 entries
Processed 5000 entries
Processed 6000 entries
Processed 7000 entries
Processed 8000 entries
Processed 9000 entries
Processed 10000 entries
LDIF processing complete. 10002 entries written
```

Загрузка ldif файла в OpenDJ

```
./opendj/bin/ldapmodify --hostname localhost --port 1636 --bindDN "cn=Directory Manager" --bindPassword password --useSsl --trustAll -f /tmp/test.ldif -a
Processing ADD request for dc=example,dc=com
ADD operation successful for DN dc=example,dc=com
Processing ADD request for ou=People,dc=example,dc=com
ADD operation successful for DN ou=People,dc=example,dc=com
Processing ADD request for uid=user.0,ou=People,dc=example,dc=com
ADD operation successful for DN uid=user.0,ou=People,dc=example,dc=com
Processing ADD request for uid=user.1,ou=People,dc=example,dc=com
ADD operation successful for DN uid=user.1,ou=People,dc=example,dc=com
Processing ADD request for uid=user.2,ou=People,dc=example,dc=com
ADD operation successful for DN uid=user.2,ou=People,dc=example,dc=com
....
Processing ADD request for uid=user.9998,ou=People,dc=example,dc=com
ADD operation successful for DN uid=user.9998,ou=People,dc=example,dc=com
Processing ADD request for uid=user.9999,ou=People,dc=example,dc=com
ADD operation successful for DN uid=user.9999,ou=People,dc=example,dc=com
```

Проверьте загруженные данные в OpenDJ:

```
./opendj/bin/ldapsearch  --hostname localhost --port 1389 --bindDN "cn=Directory Manager" --bindPassword password --baseDN "ou=People,dc=example,dc=com" -s one -a always -z 3 "(objectClass=*)" "hasSubordinates" "objectClass"
dn: uid=user.0,ou=People,dc=example,dc=com
hasSubordinates: false
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top

dn: uid=user.1,ou=People,dc=example,dc=com
hasSubordinates: false
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top

dn: uid=user.10,ou=People,dc=example,dc=com
hasSubordinates: false
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top

...
```