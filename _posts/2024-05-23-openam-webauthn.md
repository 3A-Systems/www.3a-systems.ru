---
layout: blog
title: 'Настройка аутентификации по протоколу WebAuthn в OpenAM'
description: 'WebAuthn - протокол, разработанный консорциумом W3C и FIDO Alliance для аутентификации без паролей. Используя WebAuthn, можно аутентифицироваться, используя биометрию мобильного телефона или ноутбука. Можно так же использовать аутентификацию при помощи аппаратных USB токенов. В данной статье мы настроим вход по протоколу WebAuthn в OpenAM'
tags: 
  - openam

---

## Введение

[WebAuthn](https://en.wikipedia.org/wiki/WebAuthn) - протокол, разработанный консорциумом W3C и FIDO Alliance для аутентификации без паролей. Используя WebAuthn, можно аутенитфицироваться, используя биометрию мобильного телефона или ноутбука. Можно так же использовать аутентификацию при помощи аппаратных USB токенов. 

Если кратко, то WebAuthn использует взаимную аутентификацию, используя алгоритмы ассиметричного шифрования и обмен сообщениями, зашифрованными публичными ключами (passkeys). Поэтому, еще одним важным достойством WebAuthn является устойчивость к фишингу. Более подробно со стандартом можно ознакомиться по ссылкам [https://www.w3.org/TR/webauthn-3/](https://www.w3.org/TR/webauthn-3/). 

### Поддержка браузерами

WebAuthn поддерживает большинство современных браузеров - Google Chrome, Mozilla Fireforx (частичная поддержка), Apple Safari, Microsoft Edge, в том числе и мобильные версии браузеров. Актуальная информация о поддержке браузерами и устройствами WebAuthn находится по ссылке [https://caniuse.com/?search=webauthn](https://caniuse.com/?search=webauthn)

### Поддержка устройствами

Passkeys, созданные на iPhone, iPad или Mac могут быть использованы на том же самом устройстве или на iPhone, iPad или Mac с одинаковым AppleID. Синхронизация ключей происходит автоматически. 

Passkeys, созданные на Android могут быть использованы на устройствах Android с той же самой учетной записью Google. Синхронизация ключей автоматическая.

Полее подробно по ссылке [https://passkeys.dev/device-support/](https://passkeys.dev/device-support/)

## Установка OpenAM

Т.к. WebAuthn в браузере работает только по протоколу HTTPS или на домене localhost, то для демонстрационных целей мы развернем OpenAM в Docker контейнере на localhost. 

Создайте сеть в Docker для OpenAM

```bash
docker network create openam
```

После этого запустите Docker  контейнер OpenAM Выполните следующую команду:

```bash
docker run -p 8080:8080 --network openam --name openam openidentityplatform/openam
```

После того, как сервер запустится, запустите начальную конфигурацию OpenAM. Выполните следующую команду:

```bash
docker exec -w '/usr/openam/ssoconfiguratortools' openam bash -c \
'echo "ACCEPT_LICENSES=true
SERVER_URL=http://localhost:8080
DEPLOYMENT_URI=/$OPENAM_PATH
BASE_DIR=$OPENAM_DATA_DIR
locale=en_US
PLATFORM_LOCALE=en_US
AM_ENC_KEY=
ADMIN_PWD=passw0rd
AMLDAPUSERPASSWD=p@passw0rd
COOKIE_DOMAIN=localhost
ACCEPT_LICENSES=true
DATA_STORE=embedded
DIRECTORY_SSL=SIMPLE
DIRECTORY_SERVER=localhost
DIRECTORY_PORT=50389
DIRECTORY_ADMIN_PORT=4444
DIRECTORY_JMX_PORT=1689
ROOT_SUFFIX=dc=openam,dc=example,dc=org
DS_DIRMGRDN=cn=Directory Manager
DS_DIRMGRPASSWD=passw0rd" > conf.file && java -jar openam-configurator-tool*.jar --file conf.file'
```

После успешной конфигурации можно приступить к дальнейшей настройке. Настроим цепочки регистрации и аутентификации по протоколу WebAuthn.

## Настройка регистрации WebAuthn

### Настройка модуля аутентификации

Зайдите в консоль администратора по ссылке 

[http://localhost:8080/openam/XUI/#login/](http://localhost:8080/openam/XUI/#login/)

В поле логин введите значение `amadmin`, поле пароль введите значение из параметра `ADMIN_PWD` команды установки, в данном случае `passw0rd`

Выберите корневой realm и в меню выберите пункт Authentication → Modules. Создайте новый модуль аутентификации WebAuthn Registration

![OpenAM Create WebAuthn Registration Authentication Module](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/webauthn/0-webauthn-registration-new-module.png)

Настройки модуля по умолчанию можно оставить без изменений.

![OpenAM  WebAuthn Registration Authentication Module Settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/webauthn/1-webauthn-registration-module.png)

### Настройка цепочки аутентификации

Зайдите в консоль администратора выберите нужный realm и в меню выберите пункт Authentication → Chains. Создайте цепочку аутентификации `webauthn-registration` с  созданным модулем `webauthn-registration`.

![OpenAM  WebAuthn Registration Authentication Chain](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/webauthn/2-webauthn-registration-chain.png)

## Настройка аутентификации по WebAuthn

### Настройка модуля аутентификации

В консоли администратора выберите корневой realm и в меню выберите пункт Authentication → Modules. Создайте новый модуль аутентификации WebAuthn Authentication.

![OpenAM Create WebAuthn Authentication Module](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/webauthn/3-webauthn-authentication-new-module.png)

Настройки модуля по умолчанию можно оставить без изменений

![OpenAM WebAuthn Authentication Module Settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/webauthn/4-webauthn-authentication-module.png)

### Настройка цепочки аутентификации

Зайдите в консоль администратора выберите нужный realm и в меню выберите пункт Authentication → Chains. Создайте цепочку аутентификации `webauthn-authentication` с  созданным модулем `webauthn-authentication`.

![OpenAM  WebAuthn Authentication Chain](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/webauthn/5-webauthn-authentication-chain.png)

## Проверка решения

Выйдите из консоли администратора OpenAM или откройте браузер в режиме “Инкогнито” и войдите по ссылке [http://localhost:8080/openam/XUI/#login](http://localhost:8080/openam/XUI/#login) с учетными данными пользователя `demo` 

В поле логин введите `demo` в поле пароль введите `changeit` . 

### Регистрация

Для демонстрационных целей будем использовать встроенный в браузер эмулятор WebAuthn. Как его включить, описано по ссылке [https://developer.chrome.com/docs/devtools/webauthn](https://developer.chrome.com/docs/devtools/webauthn)

Добавьте виртуальный аутентификатор, с поддержкой резидентных ключей (Supports resident keys) и верификацией пользователя (Supports user verification).

![WebAuthn New Chrome Authenticator](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/webauthn/6-webauthn-chrome-new-authenticator.png)

Откройте цепочку аутентификации по ссылке [http://localhost:8080/openam/XUI/#login&service=webauthn-registration](http://localhost:8080/openam/XUI/#login&service=webauthn-registration) и нажмите кнопку `Register`. 

![WebAuthn New Chrome Authenticator](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/webauthn/7-webauthn-registration.png)

Вас сразу перенаправит обратно в консоль, а в инструментах разработчика для аутентификатора вы увидите зарегистрированные учетные данные для пользователя demo.

![WebAuthn Chrome Authenticator Credentials](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/webauthn/8-webauthn-authenticator-credentials.png)

### Проверка аутентификации

В коносоли под пользвоателем`demo` нажмите на иконку пользователя и выберите Logout

![OpenAM Logout](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/webauthn/9-openam-demo-logout.png)

Перейдите по ссылке [http://localhost:8080/openam/XUI/#login&service=webauthn-authentication](http://localhost:8080/openam/XUI/#login&service=webauthn-authentication) и нажмите кнопку `Log In`. Появится окно с выбором учетной записи. Выберите `demo` и нажмите кнопку `Continue`. Вас аутентифицирует с учетной записью `demo` 

![Authenticator Account Selection](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/webauthn/10-account-selection.png)

Выберите `demo` и нажмите кнопку `Continue` вас аутентифицирует с учетной записью `demop`