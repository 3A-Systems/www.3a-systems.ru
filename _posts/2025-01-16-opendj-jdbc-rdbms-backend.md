---
layout: blog
title: 'OpenDJ: Использование реляционной СУБД в качестве LDAP каталога'
description: 'В данной статье мы настроим OpenDJ таким образом, чтобы он использовал базу данных PostgreSQL в качестве хранилища данных.'
tags: 
  - opendj
---

В данной статье мы настроим OpenDJ таким образом, чтобы он использовал базу данных PostgreSQL в качестве хранилища данных. 

## Подготовка

Для начала у вас должен быть установлен Docker. Создадим в Docker сеть, по которой будут взаимодействовать PostgreSQL и OpenDJ.

```
docker network create opendj-jdbc

```

В Docker развернем образ PostgreSQL командой

```
docker run -it -d -p 5432:5432 --network opendj-jdbc -e POSTGRES_DB=database_name -e POSTGRES_PASSWORD=password --name postgres postgres

```

Запустите контейнер OpenDJ.

```
docker run --rm -p 1389:1389 -p 1636:1636 -p 4444:4444 --name opendj --network opendj-jdbc \
  -e "BASE_DN_JDBC=dc=acme,dc=org" \
  openidentityplatform/opendj:latest
.....
Server Run Status:        Started
OpenDJ is started

```

В переменной окружения `BASE_DN_JDBC`  указан Base DN для JDBC каталога.

Дождитесь запуска OpenDJ.

## Настройка OpenDJ

Создайте OpenDJ backend с использованием СУБД PostgreSQL

```
docker exec -it opendj sh -c '/opt/opendj/bin/dsconfig create-backend -h localhost -p $ADMIN_PORT --bindDN "$ROOT_USER_DN" --bindPassword "$ROOT_PASSWORD" --backend-name=userRootJdbc --type jdbc --set base-dn:$BASE_DN_JDBC --set "db-directory:jdbc:postgresql://postgres:5432/database_name?user=postgres&password=password" --set enabled:true --no-prompt --trustAll'  

```

В этой команде интерес представляют аргументы `--type`, который должен быть равен `jdbc` для использования реляционной БД и `--set 'db-directory:jdbc:...` — строка подключения к JDBC совместимому источнику данных. 

> СУБД может быть практически любой, для которой есть JDBC совместимый драйвер. По умолчанию поддерживается PostgreSQL, MySQL, MS SQL Server и Oracle.  Для использования любой другой JDBC-совместимой базы данных нужно скачать соотвествующий драйвер, и скопировать его или смонтировать  в директорию `/opt/opendj/lib`  и поменять строку подключения к JDBC источнику в аргументе `--set`. Пример строки подключения для MySQL: `db-directory:jdbc:mysql://mysqlhost:3306/database_name?user=mysql&password=password`. Более подробно об этом написано в документации к соответствующему драйверу

Более подробно про параметры команды `dsconfig create-backend` вы можете прочитать по ссылке:

[https://doc.openidentityplatform.org/opendj/reference/dsconfig-subcommands-ref#dsconfig-create-backend](https://doc.openidentityplatform.org/opendj/reference/dsconfig-subcommands-ref#dsconfig-create-backend).

## Проверка решения

Для демонстрационных целей создайте и загрузите тестовые данные в OpenDJ

Создайте ldif файл с тестовыми данными из шаблона:

```
docker exec -it opendj sh -c '/opt/opendj/bin/makeldif -o /tmp/test.ldif -c suffix=$BASE_DN_JDBC /opt/opendj/data/config/MakeLDIF/example.template'
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
docker exec -it opendj sh -c '/opt/opendj/bin/ldapmodify --hostname localhost --port 1636 --bindDN "$ROOT_USER_DN" --bindPassword "$ROOT_PASSWORD" --useSsl --trustAll -f /tmp/test.ldif -a'
Processing ADD request for dc=acme,dc=org
ADD operation successful for DN dc=acme,dc=org
Processing ADD request for ou=People,dc=acme,dc=org
ADD operation successful for DN ou=People,dc=acme,dc=org
Processing ADD request for uid=user.0,ou=People,dc=acme,dc=org
ADD operation successful for DN uid=user.0,ou=People,dc=acme,dc=org
Processing ADD request for uid=user.1,ou=People,dc=acme,dc=org
ADD operation successful for DN uid=user.1,ou=People,dc=acme,dc=org
Processing ADD request for uid=user.2,ou=People,dc=acme,dc=org
ADD operation successful for DN uid=user.2,ou=People,dc=acme,dc=org
....
Processing ADD request for uid=user.9998,ou=People,dc=acme,dc=org
ADD operation successful for DN uid=user.9998,ou=People,dc=acme,dc=org
Processing ADD request for uid=user.9999,ou=People,dc=acme,dc=org
ADD operation successful for DN uid=user.9999,ou=People,dc=acme,dc=org
```

Проверьте загруженные данные в OpenDJ:

```
docker exec -it opendj sh -c '/opt/opendj/bin/ldapsearch --hostname localhost --port 1389 --bindDN "$ROOT_USER_DN" --bindPassword "$ROOT_PASSWORD" --baseDN "ou=People,$BASE_DN_JDBC" -s one -a always -z 3 "(objectClass=*)" "hasSubordinates" "objectClass"'
dn: uid=user.0,ou=People,dc=acme,dc=org
hasSubordinates: false
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top

dn: uid=user.1,ou=People,dc=acme,dc=org
hasSubordinates: false
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top

dn: uid=user.10,ou=People,dc=acme,dc=org
hasSubordinates: false
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top

...
```