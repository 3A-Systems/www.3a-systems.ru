---
layout: blog
title: 'Настройка OAuth2/OIDC федерации в OpenAM'
description: 'В данном руководстве мы настроим федерацию между двумя инстансами OpenAM по протоколу OAuth2/OIDC. Один инстанс будет являться OAuth2/OIDC сервером (Identity Provider), другой - клиентом (Service Provider). Таким образом, вы можете аутентифицироваться в клиентском инстансе OpenAM (SP) используя учетные данные инстанса OpenAM (IdP) по протоколу OAuth2/OIDC.'
tags: 
  - openam

---

## Введение

В данном руководстве мы настроим федерацию между двумя инстансами OpenAM по протоколу OAuth2/OIDC. Один инстанс будет являться OAuth2/OIDC сервером (Identity Provider), другой - клиентом (Service Provider). Таким образом, вы можете аутентифицироваться в клиентском инстансе OpenAM (SP) используя учетные данные инстанса OpenAM (IdP) по протоколу OAuth2/OIDC.

## Установка инстансов OpenAM

Если у вас уже установлены инстансы OpenAM, можете пропустить этот раздел. Для демонстрационных целей мы установим OpenAM IdP и SP в Docker контейнерах.

### Настройка сети

Добавьте имена хостов и IP адрес в файл `hosts`, 

```bash
127.0.0.1 idp.acme.org sp.mycompany.org
```

В Windows системах файл `hosts` находится по адресу `C:\Windows\System32\drivers\etc\hosts` , в Linux и Mac находится по адресу `/etc/hosts` 

Создайте в Docker сеть для OpenAM

```bash
docker network create openam-oauth
```

### Установка OpenAM IdP

Запустите образ OpenAM

```bash
docker run -h idp.acme.org -p 8080:8080 --network openam-oauth --name openam-idp openidentityplatform/openam
```

После того, как сервер OpenAM запущен, выполните первоначальную настройку, запустив следующую команду и дождитесь окончания настройки.

```bash
docker exec -w '/usr/openam/ssoconfiguratortools' openam-idp bash -c \
'echo "ACCEPT_LICENSES=true
SERVER_URL=http://idp.acme.org:8080
DEPLOYMENT_URI=/$OPENAM_PATH
BASE_DIR=$OPENAM_DATA_DIR
locale=en_US
PLATFORM_LOCALE=en_US
AM_ENC_KEY=
ADMIN_PWD=passw0rd
AMLDAPUSERPASSWD=p@passw0rd
COOKIE_DOMAIN=idp.acme.org
ACCEPT_LICENSES=true
DATA_STORE=embedded
DIRECTORY_SSL=SIMPLE
DIRECTORY_SERVER=idp.acme.org
DIRECTORY_PORT=50389
DIRECTORY_ADMIN_PORT=4444
DIRECTORY_JMX_PORT=1689
ROOT_SUFFIX=dc=openam,dc=example,dc=org
DS_DIRMGRDN=cn=Directory Manager
DS_DIRMGRPASSWD=passw0rd" > conf.file && java -jar openam-configurator-tool*.jar --file conf.file'
```

### Установка OpenAM SP

Запустите образ OpenAM

```bash
docker run -h sp.mycompany.org -p 8081:8080  --network openam-oauth --name openam-sp openidentityplatform/openam
```

После того, как сервер OpenAM запущен, выполните первоначальную настройку, запустив следующую команду и дождитесь окончания настройки.

```bash
docker exec -w '/usr/openam/ssoconfiguratortools' openam-sp bash -c \
'echo "ACCEPT_LICENSES=true
SERVER_URL=http://sp.mycompany.org:8080
DEPLOYMENT_URI=/$OPENAM_PATH
BASE_DIR=$OPENAM_DATA_DIR
locale=en_US
PLATFORM_LOCALE=en_US
AM_ENC_KEY=
ADMIN_PWD=passw0rd
AMLDAPUSERPASSWD=p@passw0rd
COOKIE_DOMAIN=sp.mycompany.org
ACCEPT_LICENSES=true
DATA_STORE=embedded
DIRECTORY_SSL=SIMPLE
DIRECTORY_SERVER=sp.mycompany.org
DIRECTORY_PORT=50389
DIRECTORY_ADMIN_PORT=4444
DIRECTORY_JMX_PORT=1689
ROOT_SUFFIX=dc=openam,dc=example,dc=org
DS_DIRMGRDN=cn=Directory Manager
DS_DIRMGRPASSWD=passw0rd" > conf.file && java -jar openam-configurator-tool*.jar --file conf.file'
```

## Настройка OAuth2/OIDC сервера

Откройте консоль OpenAM, который будет в роли OAuth2/OIDC сервера по адресу [http://idp.acme.org:8080/openam](http://idp.acme.org:8080/openam) . В поле логин введите значение `amadmin`, в поле пароль введите значение, указанное в настройке `ADMIN_PWD` , в данном случае `passw0rd`.

Перейдите в корневой realm и в разделе Dashboard выберите `Configure OAuth Provider`. 

![OpenAM realm overview](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-oauth/0-openam-idp-realm-overview.png)

Далее, `Configure OpenID Connect`.

![OpenAM Configure OpenID Connect](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-oauth/1-openam-configure-openid-connect.png)

Оставьте настройки без изменений и нажмите кнопку `Create` .

![OpenAM OpenID Connect Settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-oauth/2-openam-openidconnect-settings.png)

### Создание клиентского приложения

Откройте консоль администратора OAuth2/OIDC сервера, перйдите в нужный realm и в меню слева выберите пункт `Applications` → `OAuth 2.0` /

![OpenAM create OAuth2 Client](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-oauth/3-openam-applications-oauth2.png)

В открывшемся списке нажмите кнопку `New`

![OpenAM OAuth2 OIDC client list](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-oauth/4-oauth2-oidc-client-list.png)

Заполните поля `Name` (client_id) и `Password` (client_secret). Повторите пароль и нажмите кнопку `Create` .

![OpenAM new OAuth2 client](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-oauth/5-oauth2-new-client.png)

Откройте созданное приложение из списка и заполните настройки

| Redirection URIs | http://sp.mycompany.org:8081/openam/oauth2c/OAuthProxy.jsp |
| --- | --- |
| Scope | openid |
| Token Endpoint Authentication Method | client_secret_post |
| ID Token Signing Algorithm | RS256 |

## Настройка OAuth2/OIDC клиента

### Настройка модуля аутентификации OAuth2/OIDC

Откройте консоль OpenAM, который будет в роли OAuth2/OIDC клиента по адресу [http://openam-sp.example.org:8081/openam](http://openam-sp.example.org:8081/openam). В поле логин введите значение `amadmin`, в поле пароль введите значение, указанное в настройке `ADMIN_PWD` , в данном случае `passw0rd`.

Откройте realm и в меню слева выберите `Authentication` → `Modules` . Нажмите кнопку  `Add Module`.

![Untitled](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-oauth/6-openam-authenticaion-modules.png)

Тип модуля выберите `OAuth2/OpenID Connect`, имя модуля может быть любым, путь оно будет `oauth`.

![OpenAM new module](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-oauth/7-openam-new-module.png)

Нажмите кнопку `Create`.

В списке откройте настройки созданного модуля и заполните настройки:

| Client Id | test_client |
| --- | --- |
| Client Secret | Пароль, указанный при регистрации приложения |
| Authentication Endpoint URL | http://idp.acme.org:8080/openam/oauth2/authorize |
| Access Token Endpoint URL | http://idp.acme.org:8080/openam/oauth2/access_token |
| User Profile Service URL | http://idp.acme.org:8080/openam/oauth2/tokeninfo |
| Scope | openid |
| OAuth2 Access Token Profile Service Parameter name | access_token |
| Proxy URL | http://sp.mycompany.org:8081/openam/oauth2c/OAuthProxy.jsp |
| Account Mapper | org.forgerock.openam.authentication.modules.oidc.JwtAttributeMapper |
| Account Mapper Configuration | sub=uid |
| Attribute Mapper | org.forgerock.openam.authentication.modules.oidc.JwtAttributeMapper |
| Attribute Mapper Configuration | sub=uid |
| Create account if it does not exist | disabled |
| Prompt for password setting and activation code | disabled |
| Map to anonymous user | disabled |
| OpenID Connect validation configuration type | .well-known/openid-configuration_url |
| OpenID Connect validation configuration value | http://idp.acme.org:8080/openam/oauth2/.well-known/openid-configuration |
| Name of OpenID Connect ID Token Issuer | http://idp.acme.org:8080/openam/oauth2 |

### Настройка цепочки аутентификаци OAuth2/OIDC

Откройте консоль администратора OpenAM Service Provider. Выберите realm  и в меню слева перейдите `Authentication` → `Chains`.

![OpenAM Authenticaion Chains](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-oauth/8-openam-authentication-chains.png)

Создайте новую цепочку аутентификации

![OpenAM new authenticaion chain](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-oauth/9-openam-new-auth-chain.png)

Нажмите кнопку `Add a Module`  и добавьте созданный модуль `oauth`. Установите Criteria в значение `Requisite`. Нажмите `OK` и далее `Save Changes` .

![Untitled](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-oauth/10-openam-auth-chain-settings.png)

### Настройка Realm

Перейдите в консоль администратора OpenAM SP. В меню слева перейдите `Authentication` → `Settings` . На закладке  `User Profile` выберите значение `Ignore` . Сохраните изменения.

![OpenAM realm user profile settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-oauth/11-openam-realm-user-profile-settings.png)

## Проверка решения

Перейдите в консоль администратора OpenAM OAuth2/OIDC Server, выберите realm, в разделе Dashboard в меню слева выберите `Subjects` .

Откроется список пользователей. Создайте новую учетную запись `testIdp`

![OpenAM create new user](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-oauth/12-openam-create-new-user.png)

Выйдите из консоли администратора OpenAM OAuth2/OIDC Server и консоли администратора OpenAM OAuth2/OIDC Client или откройте браузер в режиме инкогнито.

Откройте URL аутентификации OAuth2/OIDC Client в цепочке `oauth` [http://sp.mycompany.org:8081/openam/XUI/?service=oauth](http://sp.mycompany.org:8081/openam/XUI/?service=oauth)

Вас перенаправит на аутентификацию на OAuth2/OIDC Server. Введите учетные данные пользователя testIdP.

Подтвердите согласие на доступ к данным пользователя приложения `test_client`

![OpenAM User Consent](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-oauth/13-openam-user-access-consent.png)

После нажатия `Allow` откроется консоль OpenAM OAuth2/OIDC Client с учетными данными пользователя OpenAM OAuth2/OIDC Server.

![OpenAM Authenticated](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-oauth/14-openam-authenticated.png)