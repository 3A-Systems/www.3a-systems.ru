---
layout: blog
title: 'Аутентификация в 1С через OpenAM по протоколу OAuth2 OIDC'
description: 'В данной статье мы настроим аутентификацию в 1C через OpenAM используя OAuth2/OIDC протокол.'
tags: 
  - openam

---

## Введение

1С поддерживает “из коробки” несколько способов аутентификации - например по логину и паролю и аутентификацию операционной системы. Но иногда этих способов недостаточно для удобства пользователей и удовлетворения требований безопасности. Например, 1С не поддерживает аутентификацию по коду из СМС или по биометрии.

Больше возможностей для управления аутентификацией реализуют специальные решения. Одним из таких решения является [OpenAM](https://github.com/OpenIdentityPlatform/OpenAM).

В данной статье мы настроим аутентификацию в 1C через OpenAM используя OAuth2/OIDC протокол.

## Настройка OpenAM

### Установка OpenAM

Пусть OpenAM располагается на хосте `openam.example.org`. Если у вас уже установлен OpenAM, можете пропустить этот шаг. Самым простым способом развернуть OpenAM можно в Docker контейнере. Перед запуском, добавьте имя хоста и IP адрес в файл `hosts`, например `127.0.0.1 openam.example.org` .  

В Windows системах файл `hosts` находится по адресу `C:\Windows\System32\drivers\etc\hosts` , в Linux и Mac находится по адресу `/etc/hosts` 

После этого запустите Docker  контейнер OpenAM Выполните следующую команду:

```bash
docker run -h openam.example.org -p 8080:8080 --name openam openidentityplatform/openam
```

После того, как сервер запустится, запустите начальную конфигурацию OpenAM. Выполните следующую команду:

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
DS_DIRMGRPASSWD=passw0rd" > conf.file && java -jar openam-configurator-tool*.jar --file conf.file'
```

После успешной конфигурации можно приступить к дальнейшей настройке.

### Настройка OAuth2/OIDC провайдера

Зайдите в консоль администратора по ссылке 

[http://openam.example.org:8080/openam/XUI/#login/](http://openam.example.org:8080/openam/XUI/#login/)

В поле логин введите значение `amadmin`, поле пароль введите значение из параметра `ADMIN_PWD` команды установки, в данном случае `passw0rd`

### Настройка OAuth2/OIDC

Выберите требуемый realm. В разделе Dashboard кликните на элементе Configure OAuth Provider 

![OpenAM Configure OAuth Provider](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-oidc-1c/0-openam-configure-oauth-provider.png)

Затем Configure OpenID Connect

![OpenAM Configure OpenID Connect](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-oidc-1c/1-configure-oidc.png)

В открывшейся форме оставьте все настройки без изменений и нажмите кнопку “Create”

![OpenAM Configure OpenID Connect Options](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-oidc-1c/2-configure-oidc-options.png)

Откройте консоль администратора, перейдите в нужный realm, в меню слева выберите пункт `Services` и выберите в списке OAuth2 Provider

![OpenAM Realm Services](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-oidc-1c/3-openam-realm-services.png)

Найдите настройку `OAuth2 Token Signing Algorithm` и установите значение `RS256`. Для пропуска диалога на согласие доступа к данным можете включить настройку `Allow clients to skip consent`  

Теперь создадим OAuth2/OIDC клиент, который будет использовать SPA приложение для аутентификации.

Зайдите в консоль администратора, выберите требуемый realm, в меню слева выберите пункт Applications и далее OAuth 2.0

В таблице Agents нажмите кнопку New

![OAuth2 OIDC Client List](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-oidc-1c/4-oauth2-oidc-client-list.png)

- Введите Name (client_id) и Password (client_secret) нового приложения. Пусть client_id будет `1c_enterprise`
- Откройте настройки приложения
- Установите Client type в Public
- Добавьте в список Redirection URIs URI вашего приложения 1С. В нашем случае это будет `http://localhost/infobase/authform.html`
- В список scope добавьте значение `openid`, это нужно, чтобы сразу получить идентификатор пользователя из возвращаемого объекта `id_token`.
- Установите настройку `ID Token Signing Algorithm:` в `RS256`
- Установите настройку `Public key selector` в `JWKs_URI`
- Если хотите, чтобы пользователи пропускали окно согласия на доступ к данным, включите чекбокс `Implied consent`

### Настройка CORS

1С для получения `id_token` выполняет кросс-доменные запросы, то есть запросы на домен, на котором развернут OpenAM. Для того, чтобы такие запросы не блокировал браузер, нужно включить поддержку [CORS](https://developer.mozilla.org/ru/docs/Web/HTTP/CORS) в OpenAM. 

Откройте консоль администратора. В верхнем меню выберите пункт Configure → Global Services. 

![OpenAM Global Services](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-oidc-1c/5-openam-global-services.png)

Далее перейдите в CORS Settings и включите поддержку CORS

![OpenAM CORS Settings](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-oidc-1c/6-openam-cors-settings.png)

Убедитесь, что в Accepted Methods  присутствуют методы GET и POST. Сохраните изменения.

### Настройка тестового пользователя

Откройте консоль администратора OpenAM, перейдите в нужный realm, в меню слева выберите пункт Subjects. Задайте пароль для пользователя  `demo`. Для этого выберите его в списке пользователей, и нажмите ссылку Edit в пункте Password, введите и сохраните новый пароль. После настройки выйдите из консоли администратора.

![OpenAM User List](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-oidc-1c/7-openam-user-list.png)

## Настройка 1С

Откройте конфигуратор базы 1С, создайте пользователя 1С c логином `demo` и назначьте ему необходимые права.

Пусть база 1С развернута на локальном веб сервере по URL `http://localhost/infobase` .

Добавьте в файл описания публикации базы`default.vrd` настройки аутентификации по протоколу OpenID Connect:

 
```xml
	<openidconnect>
		<providers>
			<![CDATA[[
			    {
			        "clientconfig": {
			            "loadUserInfo": false,
			            "filterProtocolClaims": false,
			            "response_type": "id_token token",
			            "scope": "openid",
			            "redirect_uri": "http://localhost/infobase/authform.html",
			            "client_id": "1c_enterprise",
			            "authority": "http://openam.example.org:8080/openam/oauth2/"
			        },
			        "authenticationUserPropertyName": "name",
			        "authenticationClaimName": "sub",
			        "discovery": "http://openam.example.org:8080/openam/oauth2/.well-known/openid-configuration",
			        "title": "OIDC (OpenAM)",
			        "name": "openam_oidc"
			    }
		]]]>
		</providers>
		<allowStandardAuthentication>true</allowStandardAuthentication>
	</openidconnect>
```

## Проверка решения

Откройте браузер и откройте базу 1С по URL  `http://localhost/infobase` . Вас перенаправит на аутентификацию OpenAM. Введите логин и пароль пользователя, созданного ранее. 

![OpenAM Demo User Login](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-oidc-1c/8-openam-login-demo.png)

Подтвердите согласие на доступ к данным, если ранее не отключали.

![OpenAM OAuth2 Consent](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-oidc-1c/9-oauth2-consent.png)

Если все настроено корректно, аутентификация в 1С завершится успешно с пользователем `demo`.

