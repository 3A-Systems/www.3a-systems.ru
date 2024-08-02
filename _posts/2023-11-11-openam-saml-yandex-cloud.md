---
layout: blog
title: 'Аутентификация по протоколу SAML с помощью OpenAM на примере Yandex Cloud'
description: 'В данной статье описывается, как настроить вход по технологии единого входа (SSO) по протоколу SAML в Yandex Cloud через Access Management платформу с открытым исходным кодом OpenAM.'
---

# Введение

В данном руководстве мы настроим федерацию между двумя инстансами OpenAM. Один инстанс будет Identity Provider (IdP), другой - Service Provider (SP). Таким образом вы можете аутентифицироваться в инстансе OpenAM (SP) используя учетные данные другого инстанса - OpenAM (IdP). 

# Установка инстансов OpenAM

Если у вас уже установлены инстансы OpenAM, можете пропустить этот раздел. Для демонстрационных целей мы установим OpenAM IdP и SP в Docker контейнерах.

## Настройка сети

Добавьте имена хостов и IP адрес в файл `hosts`, 

```bash
127.0.0.1 idp.acme.org sp.mycompany.org
```

В Windows системах файл `hosts` находится по адресу `C:\Windows\System32\drivers\etc\hosts` , в Linux и Mac находится по адресу `/etc/hosts` 

Создайте в Docker сеть для OpenAM

```bash
docker network create openam-saml
```

## Установка OpenAM IdP

Запустите образ OpenAM

```bash
docker run -h idp.acme.org -p 8080:8080 --network openam-saml --name openam-idp openidentityplatform/openam
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

## Установка OpenAM SP

Запустите образ OpenAM

```bash
docker run -h sp.mycompany.org -p 8081:8080  --network openam-saml --name openam-sp openidentityplatform/openam
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

# Настройка Identity Provider и Service Provider

## Настройка Hosted Identity Provider

Откройте консоль OpenAM, который будет в роли Identity Provider по адресу [http://idp.acme.org:8080/openam](http://idp.acme.org:8080/openam) . В поле логин введите значение `amadmin`, в поле пароль введите значение, указанное в настройке `ADMIN_PWD` , в данном случае `passw0rd`.

Перейдите в корневой realm и в разделе Dashboard выберите `Configure SAMLv2 Provider`.

![OpenAM realm overview](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/0-openam-idp-realm-overview.png)

Далее `Create Hosted Identity Provider` 

![OpenAM Create Hosted Identity Provider](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/1-openam-create-hosted-idp.png)

В настройке `Signing Key` для демонстрационных целей выберите `test` , введите значение круга доверия `Circle of Trust`  , оно может быть любым. И добавьте сопоставление атрибутов по атрибуту `uid` в настройку `Attribute Mapping` .

![Hosted identity provider settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/2-openam-hosted-idp-settings.png)

Нажмите кнопку `Configure` , далее OpenAM предложит настроить Remote Service Provider. Так как он у нас еще не настроен, нажмите кнопку `Finish` 

## Настройка Hosted Service Provider

Откройте новую вкладку браузера и откройте консоль OpenAM Service Provider по URL [http://sp.mycompany.org:8081/openam](http://sp.mycompany.org:8081/openam) . В поле логин введите значение `amadmin`. В поле пароль введите значение, указанное в настройке `ADMIN_PWD` , в данном случае `passw0rd`. Перейдите в корневой realm и в разделе Dashboard выберите `Configure SAMLv2 Provider`. Далее `Create Hosted Service Provider`.

![OpenAM create hosted service provider](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/3-openam-create-hosted-sp.png)

Введите имя круга доверия, остальные настройки можете оставить без изменений. 

![OpenAM hosted service provider settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/4-openam-hosted-sp-settings.png)

Нажмите кнопку `Configure`.

![Create remote identity provider promts](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/4-remote-idp-prompt.png)

Появится предложение настроить remote identity provider. Так как мы уже настроили Identity Provider на предыдущем шаге, то можно нажать `Yes` . Откроется окно настройки remote identity provider. 

## Настройка Remote Identity Provider

Выберите местоположение метаданных identity provider -  URL. В поле введите URL метаданных identity provider.

[http://idp.acme.org:8080/openam/saml2/jsp/exportmetadata.jsp](http://idp.acme.org:8080/openam/saml2/jsp/exportmetadata.jsp)

![OpenAM remote identity provider settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/6-openam-idp-settings.png)

Нажмите `Configure` . Появится сообщение об успешной конфигурации remote identity provider.

## Настройка сопоставления пользователей

Откройте консоль администратора OpenAM SP, в разделе Dashboard в меню слева передите в раздел  `Applications` → `SAML 2.0`

![OpenAM goto saml](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/7-openam-sp-goto-saml.png)

Откроется окно настройки SAML федерации. Перейдите `Entity Providers` → [`http://sp.mycompany.org:8081/openam`](http://sp.mycompany.org:8081/openam)

![OpenAM SP circle of trust configuration](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/8-openam-sp-circle-of-trunt.png)

В открывшемся окне передите на закладку `Assertions Processing` . Включите автоматическую федерацию по атрибуту `uid`.

![OpenAM SAML Auto Federation](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/9-openam-sp-auto-federation.png)

Нажмите кнопку `Save`

## Настройка Realm для Service Provider

Перейдите в консоль администратора OpenAM SP. В меню слева перейдите `Authentication` → `Settings` . На закладке  `User Profile` выберите значение `Ignore` . Сохраните изменения.

![OpenAM realm user profile settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/10-openam-realm-user-profile.png)


## Настройка Remote Service Provider

Передите в консоль администратора OpenAM IdP [`http://openam-idp.example.org:8080/openam`](http://openam-idp.example.org:8080/openam). Откройте корневой realm и в разделе Dashboard выберите   `Configure SAMLv2 Provider` , далее `Configure Remote Service Provider`

![OpenAM configure remote service provider](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/11-openam-configure-remote-sp.png)

Добавьте URL метаданных service provider [http://sp.mycompany.org:8080/openam/saml2/jsp/exportmetadata.jsp](http://openam-sp.example.org:8080/openam/saml2/jsp/exportmetadata.jsp) . Обратите внимание, что порт OpenAM Service Provider - `8080`, т.к. инстансы OpenAM находятся в одной сети OpenAM IdP соединяется с контейнером SP по порту 8080. 

![OpenAM remote service provider settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/12-openam-remote-sp-settings.png)

Нажмите кнопку `Configure` появится сообщение об успешном создании remote service provider.

# Создание учетной записи

Перейдите в консоль администратора OpenAM IdP, выберите realm, в разделе Dashboard в меню слева выберите `Subjects` .

Откроется список пользователей. Создайте новую учетную запись `testIdp`

![OpenAM new account creation](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/13-openam-new-account.png)

# Проверка решения

Выйдете из обеих консолей OpenAM и откройте в браузере ссылку инициализации аутентификации Service Provider. [http://sp.mycompany.org:8081/openam/spssoinit?metaAlias=/sp&idpEntityID=http%3A//idp.acme.org%3A8080/openam&RelayState=http%3A//sp.mycompany.org%3A8081/openam](http://sp.mycompany.org:8081/openam/spssoinit?metaAlias=/sp&idpEntityID=http%3A//idp.acme.org%3A8080/openam&RelayState=http%3A//sp.mycompany.org%3A8081/openam)

Вас перенаправит на аутентификацию в Identitiy Provider. Введите учетные данные пользователя `testIdP`

![OpenAM sign in](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/14-openam-sign-in.png)

После успешной аутентификации откроется консоль SP с аутентифицированным пользователем  `testIdP` 

![OpenAM authenticated](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-saml/15-openam-authenticated.png)