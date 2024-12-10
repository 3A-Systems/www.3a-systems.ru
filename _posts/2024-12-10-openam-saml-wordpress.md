---
layout: blog
title: 'Аутентификация в WordPress через OpenAM по протоколу SAMLv2'
description: 'В этой статье мы настроим вход в WordPress по протоколу SAML используя аутентификацию OpenAM. То есть, при аутентификации в WordPress, пользователи будут перенаправлены в OpenAM и, после аутентификации в OpenAM будут автоматически аутентифицированы в WordPress'
tags: 
  - openam
---

## Введение

[SAMLv2](https://en.wikipedia.org/wiki/SAML_2.0), не смотря на почтенный возраст, является стандартом де факто для [SSO (Single Sign On)](https://en.wikipedia.org/wiki/Single_sign-on) в корпоративной среде. И в этой статье мы настроим вход в WordPress по протоколу SAML используя аутентификацию [OpenAM](http://github.com/OpenIdentityPlatform/OpenAM). То есть, при аутентификации в WordPress, пользователи будут перенаправлены в OpenAM и, после аутентификации в OpenAM будут автоматически аутентифицированы в WordPress. Учитывая гибкость OpenAM в настройке способов аутентификации, вы можете настроить вход в WordPress не только по логину и паролю, но еще, например, используя встроенную аутентификацию Windows (NTLMv2 или Kerberos), добавить второй фактор аутентификации (биометрию или одноразовый код) или даже фотографируя QR код в специальном мобильном приложении.

Вместо WordPress может быть практически любое приложение, которое поддерживает технологию единого входа по протоколу SAMLv2. Настройка OpenAM будет практически идентичной. Отличаться будут только настройки самого приложения.

## Немного терминологии

**Service Provider (SP)** - приложение, сервисы которого будут использовать пользователи после аутентификации. 

**Identity Provider (IdP)** - приложение, которое аутентифицирует пользователей и предоставляет Service Provider информацию об аутентифицированных учетных записей.

В нашем случае Identity Provider это OpenAM, а Service Provider - WordPress.

## Тестовое окружение

Для демонстрационных целей все приложения будут запущены в Docker контейнерах через утилиту Docker Compose.

Добавьте в файл `hosts` имена хоста OpenAM и WordPress `127.0.0.1 openam.example.org wordpress.example.org`  соответственно.

В системах под управлением Windows `hosts` файл находится `C:\Windows\System32\drivers\etc\hosts`. В системах под управлением Linux и Mac - `/etc/hosts`.

Создайте файл `docker-compose.yml` со следующим содержимым

```yaml
services:
  openam:
    image: openidentityplatform/openam:latest
    restart: always
    hostname: openam.example.org
    ports:
      - "8080:8080"
    volumes:
      - openam-data:/usr/openam/config
      - ./openam-config.properties:/usr/openam/openam-config.properties:ro
      - ./openam-init.sh:/usr/local/tomcat/bin/openam-init.sh:ro
    command: |
      bash /usr/local/tomcat/bin/openam-init.sh 
    
  wordpress:
    image: wordpress
    restart: always
    hostname: wordpress.example.org
    ports:
      - 8081:80
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: exampleuser
      WORDPRESS_DB_PASSWORD: examplepass
      WORDPRESS_DB_NAME: exampledb
    volumes:
      - wordpress:/var/www/html

  db:
    image: mysql:8.0
    restart: always
    environment:
      MYSQL_DATABASE: exampledb
      MYSQL_USER: exampleuser
      MYSQL_PASSWORD: examplepass
      MYSQL_RANDOM_ROOT_PASSWORD: '1'
    volumes:
      - db:/var/lib/mysql
  
volumes:
  wordpress:
  db:
  openam-data:

```

Для того, чтобы OpenAM сразу был сконфигурирован при запуске, создайте файл настроек OpenAM `openam-config.properties`

```properties
ACCEPT_LICENSES=true
SERVER_URL=http://openam.example.org:8080
DEPLOYMENT_URI=/openam
BASE_DIR=/usr/openam/config
locale=en_US
PLATFORM_LOCALE=en_US
AM_ENC_KEY=
ADMIN_PWD=passw0rd
AMLDAPUSERPASSWD=p@passw0rd
COOKIE_DOMAIN=openam.example.org
ACCEPT_LICENSES=true
DATA_STORE=embedded
DIRECTORY_SSL=SIMPLE
DIRECTORY_SERVER=openam.example.org
DIRECTORY_PORT=50389
DIRECTORY_ADMIN_PORT=4444
DIRECTORY_JMX_PORT=1689
ROOT_SUFFIX=dc=openam,dc=example,dc=org
DS_DIRMGRDN=cn=Directory Manager
DS_DIRMGRPASSWD=passw0rd
```

и скрипт начальной конфигурации `openam-init.sh`

```bash
#!/bin/bash

/usr/local/tomcat/bin/catalina.sh run &
SERVER_PID=$!

# Wait for OpenAM to respond to isAlive.jsp
until curl -f -s -o /dev/null http://localhost:8080/openam/isAlive.jsp; do
    echo "Waiting for OpenAM to fully initialize..."
    sleep 5
done

if [[ -f /usr/openam/config/boot.json ]]; then
    echo "OpenAM has already been configured."
else
    echo "Setting up OpenAM..."
    java -jar /usr/openam/ssoconfiguratortools/openam-configurator-tool*.jar --file /usr/openam/openam-config.properties
fi

wait $SERVER_PID
```

Запустите контейнеры командой `docker compose up`.

## Настройка WordPress

### Начальная конфигурация WordPress

Если WordPress у вас уже сконфигурирован, можете пропустить этот раздел. Если же нет, откройте в браузере ссылку [http://wordpress.example.org:8081/wp-admin/install.php](http://wordpress.example.org:8081/wp-admin/install.php). Выберите нужный язык и перейдите к настройкам. Заполните настройки, и обязательно запомните сгенерированный пароль. Он понадобится для входа в консоль администратора.

![Начальная настройка WordPress](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-wordpress/0-wordpress-setup-settings.png)

Нажмите кнопку `Install WordPress`.

После окончания конфигурирования перейдите на форму логина и введите логин администратора и пароль, которые были указаны при установке. Откроется консоль администратора.

### Установка плагина для SAMLv2

В консоли администратора выберите пункт Plugins. Нажмите кнопку `Add New Plugin` и установите плагин miniOrange SAML Single Sign On – SSO Login. 

![Плагин WordPress для SAML](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-wordpress/1-wordpress-saml-plugin.png)

После установки активируйте плагин, нажав кнопку Activate в окне плагина. В панели слева появится пункт настроек установленного плагина.

Перейдите в панель настроек плагина в раздел `Service Provider Metadata` и скопируйте оттуда Metadata URL. Замените в нем порт с 8081 на 80 так как OpenAM будет загружать метаданные из соседнего Docker контейнера WordPress, а внутри среды Docker он доступен на 80 порту: `http://wordpress.example.org:80/?option=mosaml_metadata`.

![Метаданные SAML SP WordPress](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-wordpress/2-wordpress-saml-sp-metadata.png)

## Настройка OpenAM

### Создание Hosted Identity Provider

Зайдите в консоль администратора OpenAM по ссылке [http://openam.example.org:8080/openam/XUI/#login/](http://openam.example.org:8080/openam/XUI/#login/). 

Введите логин и пароль администратора OpenAM. В нашем случае это будут `amadmin` и `passw0rd` соотвественно.

В открывшейся консоли откройте `Top Level Realm`, нажмите `Configure SAMLv2 Provider` → `Create Hosted Identity Provider`.

![Создание SAML провайдера в OpenAM](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-wordpress/3-openam-configure-saml-provider.png)

![Создание Hosted Identity Provider в OpenAM](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-wordpress/4-openam-create-hosted-idp.png)

Заполните настройки, как на скриншоте и нажмите кнопку `Configure`.

![Настройки SAML Identity Provider](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-wordpress/5-openam-saml-idp-settings.png)

В консоли администратора перейдите `Top Level Realm` в меню слева выберите `Applications` → `SAML 2.0`

![OpenAM SAML](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-wordpress/6-openam-saml.png)

В разделе `Entity Providers` откройте настройки Identity Provider `http://openam.example.org:8080/openam`. На вкладке `Assertion Content` перейдите в раздел `Name ID Format` → `NameID Value Map` и добавьте значение `urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified=uid`

![OpenAM SAML NameID Value Map](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-wordpress/7-openam-saml-nameid-value-map.png)

Нажмите кнопку `Save`.

### Создание Remote Service Provider

Теперь зарегистрируем WordPress как Remote Service Provider. В консоли администратора OpenAM выберите `Top Level Realm`, далее `Configure SAMLv2 Provider` → `Configure Remote Service Provider`.

![Создание Remote Service Provider в OpenAM](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-wordpress/8-openam-create-remote-sp.png)

Заполните настройки Remote Service Provider, как показано на скриншоте. URL метаданных должен быть из шага настройки плагина SAMLv2 WordPress: `http://wordpress.example.org:80/?option=mosaml_metadata` .

![Настройки SAML Service Provider в OpenAM](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-wordpress/9-openam-saml-sp-settings.png)

## Регистрация в WordPress OpenAM Identity Provider

Вернитесь в консоль администратора WordPress. 

Откройте настройки плагина miniOrange SAML. 

Перейдите на вкладку `Service Provider Setup`. 

В разделе `Configure Service Provider`  перейдите на вкладку `Upload IDP Metadata`. 

Заполните поля, как показано на скриншоте ниже. URL метаданных SAML для OpenAM будет `http://openam.example.org:8080/openam/saml2/jsp/exportmetadata.jsp`

![Настройки SAML Service Provider в WordPress](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-wordpress/10-wordpress-saml-sp-settings.png)

Нажмите кнопку `Fetch Metadata`.

Все, на этом конфигурация завершена.

## Проверка решения

Теперь давайте проверим решение. Выйдите с консоли администратора WordPress, консоли администратора OpenAM или откройте окно браузера в режиме “Инкогнито”. Откройте ссылку [http://wordpress.example.org:8081/wp-admin/](http://wordpress.example.org:8081/wp-admin/). В окне логина появится кнопка входа через OpenAM.

![Вход в WordPress](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-wordpress/11-wordpress-login.png)

Нажмите эту кнопку. Вас перенаправит на аутентификацию OpenAM. Введите имя пользователя `demo` и пароль `changeit`.  Пользователь `demo` создается при начальной установке OpenAM. В продуктивной среде его стоит удалить или сменить пароль по умолчанию.

![Вход в OpenAM](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-wordpress/12-openam-login.png)

Нажмите кнопку `LOG IN`.

Вы будете аутентифицированы в WordPress с учетной записью пользователя `demo`

![Успешная аутентификация пользователя demo в WordPress](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-wordpress/13-wordpress-demo-authenticated.png)