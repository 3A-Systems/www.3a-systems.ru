---
layout: blog
title: 'Совет: Быстрая конфигурация OpenAM в Docker контейнере из командной строки'
description: ''
tags: 
  - openam'
description: ''
tags: 
  - openam
---

Пусть имя хоста для OpenAM будет `openam.example.org`
Перед запуском, добавьте имя хоста и IP адрес в файл `hosts`, например `127.0.0.0.1 openam.example.org`

В системах под управлением Windows файл `hosts` расположен в `C:Windows/System32/drivers/etc/hosts`, а в Linux и Mac расположен в `/etc/hosts`.

Далее, запустите Docker контейнер OpenAM. Выполните следующую команду:

```bash
docker run -h openam.example.org -p 8080:8080 --name openam openidentityplatform/openam
```
Нет необходимости конфигурировать OpenAM через пользовательский интерфейс вручную. 
Команда ниже поможет автоматизировать этот процесс:

```bash
 docker exec -w '/usr/openam/ssoconfiguratortools' openam bash -c \
'echo "ACCEPT_LICENSES=true
SERVER_URL=http://openam.example.org:8080
DEPLOYMENT_URI=/$OPENAM_PATH
BASE_DIR=$OPENAM_DATA_DIR
locale=en_US
PLATFORM_LOCALE=en_US
AM_ENC_KEY=
ADMIN_PWD=passw0rd
AMLDAPUSERPASSWD=p@passw0rd
COOKIE_DOMAIN=example.org
ACCEPT_LICENSES=true
DATA_STORE=embedded
DIRECTORY_SSL=SIMPLE
DIRECTORY_SERVER=openam.example.org
DIRECTORY_PORT=50389
DIRECTORY_ADMIN_PORT=4444
DIRECTORY_JMX_PORT=1689
ROOT_SUFFIX=dc=openam,dc=example,dc=org
DS_DIRMGRDN=cn=Directory Manager
DS_DIRMGRPASSWD=passw0rd" > conf.file && java -jar openam-configurator-tool*.jar --file conf.file'
```
