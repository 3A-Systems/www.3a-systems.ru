---
layout: blog
title: 'OpenDJ: Доступ к LDAP каталогу через REST интерфейс'
description: 'В данной статье мы настроим доступ к LDAP каталогу OpenDJ через REST интерфейс'
tags: 
  - opendj
---

## Подготовка

Убедитесь что у вас установлена Java не ниже версии 1.8

```
$ java -version

openjdk version "22.0.1" 2024-04-16
OpenJDK Runtime Environment Homebrew (build 22.0.1)
OpenJDK 64-Bit Server VM Homebrew (build 22.0.1, mixed mode, sharing)
```

## Установка OpenDJ

Скачайте последнюю версия OpenDJ c GitHub

Получение последней версии OpenDJ

```
export VERSION="$(curl -i -o - --silent https://api.github.com/repos/OpenIdentityPlatform/OpenDJ/releases/latest | grep -m1 "\"name\"" | cut -d\" -f4)" && echo "The latest version: $VERSION"
The latest version: 4.9.0

```

Скачайте и разархивируйте дистрибутив OpenDJ

```
$ curl -L https://github.com/OpenIdentityPlatform/OpenDJ/releases/download/$VERSION/opendj-$VERSION.zip --output opendj.zip

  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100 59.7M  100 59.7M    0     0  6770k      0  0:00:09  0:00:09 --:--:-- 8013k

$ unzip opendj && cd opendj

...
 inflating: opendj/template/config/wordlist.txt  
```

Выполните начальную настройку OpenDJ с демонстрационными данными

```
$ ./setup --sampleData 1000 -h localhost -p 1389 --ldapsPort 1636 --adminConnectorPort 4444 --enableStartTLS --generateSelfSignedCertificate --rootUserDN "cn=Directory Manager" --rootUserPassword password --baseDN dc=example,dc=com --cli --acceptLicense --no-prompt

Configuring Directory Server ..... Done.
Configuring Certificates ..... Done.
Importing Automatically-Generated Data (1000 Entries) ....... Done.
Starting Directory Server ....... Done.

To see basic server configuration status and configuration, you can launch
/private/tmp/opendj/bin/status
```

Установка флага `--sampleData` создает демонстрационные данные. Более подробно о команде настройки вы можете прочитать в документации:

[https://doc.openidentityplatform.org/opendj/reference/admin-tools-ref#setup-1](https://doc.openidentityplatform.org/opendj/reference/admin-tools-ref#setup-1)

## Настройка  OpenDJ

Включите HTTP интерфейс 

```
bin/dsconfig set-connection-handler-prop --hostname localhost --port 4444 --bindDN "cn=Directory Manager" --bindPassword  password --handler-name "HTTP Connection Handler" --set enabled:true --no-prompt --trustAll
```

### Настройка авторизации

Проверье список доступных способов авторизации

```
$ bin/dsconfig list-http-authorization-mechanisms --hostname localhost --port 4444 --bindDN "cn=Directory Manager" --bindPassword password --trustAll

HTTP Authorization Mechanism              : Type
------------------------------------------:--------------------------------------------------------
HTTP Anonymous                            : http-anonymous-authorization-mechanism
HTTP Basic                                : http-basic-authorization-mechanism
HTTP OAuth2 CTS                           : http-oauth2-cts-authorization-mechanism
HTTP OAuth2 File                          : http-oauth2-file-authorization-mechanism
HTTP OAuth2 OpenAM                        : http-oauth2-openam-authorization-mechanism
HTTP OAuth2 Token Introspection (RFC7662) : http-oauth2-token-introspection-authorization-mechanism
```

Проверьте список конечных точек REST API

```
$ bin/dsconfig list-http-endpoints --hostname localhost --port 4444 --bindDN "cn=Directory Manager" --bindPassword password --trustAll

HTTP Endpoint : Type               : enabled
--------------:--------------------:--------
/admin        : admin-endpoint     : true
/api          : rest2ldap-endpoint : true
```

Включите логирование HTTP запросов к OpenDJ

```
$ bin/dsconfig set-log-publisher-prop --hostname localhost --port 4444 --bindDN "cn=Directory Manager" --bindPassword  password --publisher-name "File-Based HTTP Access Logger" --set enabled:true --no-prompt --trustAll
```

Создайте учетную запись пользователя с правами на чтение и запись по REST API

```
$ bin/ldapmodify --port 1389 --bindDN "cn=Directory Manager" --bindPassword password

dn: ou=write-rest,ou=people,dc=example,dc=com
objectClass: top
objectClass: organizationalUnit
ou: write-rest
description: REST administrators

Processing ADD request for ou=write-rest,ou=people,dc=example,dc=com
ADD operation successful for DN ou=write-rest,ou=people,dc=example,dc=com

dn: uid=admin,ou=write-rest,ou=people,dc=example,dc=com
objectClass: top
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
cn: admin
uid: admin
sn: admin
description: REST admin
userPassword: password

Processing ADD request for uid=admin,ou=write-rest,ou=people,dc=example,dc=com
ADD operation successful for DN
uid=admin,ou=write-rest,ou=people,dc=example,dc=com

^C
```

## Проверка REST API

Получим данные учетных записей OpenDJ по HTTP протоколу

```
curl -u "admin:password"  http://localhost:8080/api/users/user.0?_prettyPrint=true
{
  "_id" : "user.0",
  "_rev" : "00000000595bb0ca",
  "_schema" : "frapi:opendj:rest2ldap:user:1.0",
  "_meta" : { },
  "userName" : "user.0@maildomain.net",
  "displayName" : [ "Aaccf Amar" ],
  "name" : {
    "givenName" : "Aaccf",
    "familyName" : "Amar"
  },
  "description" : "This is the description for Aaccf Amar.",
  "contactInformation" : {
    "telephoneNumber" : "+1 685 622 6202",
    "emailAddress" : "user.0@maildomain.net"
  }
```

Чтобы изменить конфигурацию конечной точки REST OpenDJ измените файл конфигурации по умолчанию [config/rest2ldap/endpoints/api/example-v1.json](https://github.com/OpenIdentityPlatform/OpenDJ/blob/master/opendj-server-legacy/resource/config/rest2ldap/endpoints/api/example-v1.json)

Более подробно о REST интерфейсе OpenDJ  вы можете прочитать в документации: [Performing RESTful Operations](https://doc.openidentityplatform.org/opendj/server-dev-guide/chap-rest-operations).
