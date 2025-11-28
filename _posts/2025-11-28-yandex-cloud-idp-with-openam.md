---
layout: blog
title: 'Настройка аутентификации в OpenAM через Yandex Cloud по протоколу SAML'
description: 'Пошаговая инструкция по настройке SAML 2.0 федерации: Yandex Cloud как Identity Provider (IdP) + OpenAM / Open Identity Platform как Service Provider (SP).'
keywords: 'настройка SAML Yandex Cloud, OpenAM Yandex Cloud, Yandex Cloud IdP SAML, OpenAM как SP, Open Identity Platform SAML, единый вход Yandex Cloud OpenAM, SAML 2.0 Yandex Cloud, федерация OpenAM Yandex, OpenAM Docker установка, Yandex Cloud SSO интеграция, OpenAM внешний IdP, автоподвязка пользователей OpenAM, OpenAM SAML tutorial русский, Yandex Cloud пул пользователей SAML, OpenIG SSO Yandex, OpenAM realm настройка SAML, Yandex Cloud сертификат в OpenAM, OpenAM автофедерация'
tags: 
  - openam
---

# Настройка аутентификации в OpenAM через Yandex Cloud по протоколу SAML

## Введение

В статье мы настроим аутентификацию в OpenAM с использованием учетных записей пользователей через Yandex Cloud. Таким образом, вы сможете настроить аутентификацию в ваши корпоративные приложения через OpenAM используя Yandex Cloud как Identity Provider (IdP), а OpenAM как Service Provider (SP).

## Настройка Yandex Cloud

1. Перейдите в сервис [Yandex Cloud Organization](https://org.cloud.yandex.ru/)
2. Откройте вкладку **Identity Hub**
3. На панели слева выберите раздел [Приложения](https://center.yandex.cloud/organization/apps)
4. Нажмите кнопку **Создать приложение**
5. Выберите тип приложения SAML (Security Assertion Markup Language)
6. Введите имя приложения, например **openam-saml**
7. Нажмите кнопку **Создать приложение**

    ![Yandex Cloud Create New App](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/yandex-cloud-idp-saml/0-yandex-cloud-new-app.pngg)

После создания приложения, откройте его настройки и нажмите кнопку **Скачать сертификат.** Он понадобится нам для последующей настройки OpenAM.

### Настройка Service Provider

1. Откройте настройки Yandex приложения **openam-saml** и установите настройки:
    1. **SP Entity ID:** `http://localhost:8080/openam` 
    2. **ACS URL:** `http://localhost:8080/openam/Consumer/metaAlias/sp`
2. Сохраните изменения

![Yandex Cloud Application Settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/yandex-cloud-idp-saml/1-yandex-cloud-app-settings.png)

### Добавление пользователей

Добавьте пул пользователей:

1. В разделе **Identity Hub** в меню слева выберите **Пулы пользователей**
2. Нажмите кнопку **Создать пул пользователей**
3. Введите данные пула и нажмите **Создать пул пользователей**

    ![Yandex Clound New User Pool](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/yandex-cloud-idp-saml/2-yandex-cloud-new-user-pool.png)

Добавьте пользователя в пул

1. В разделе **Identity Hub** в меню слева выберите **Пользователи**
2. Нажмите кнопку **Добавить пользователя** 
3. Во всплывающем меню выберите **Создать нового пользователя**
4. Запомните пароль, он понадобится для входа в OpenAM
5. Введите данные пользователя и нажмите **Добавить пользователя**

    ![Yandex Cloud New User](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/yandex-cloud-idp-saml/3-yandex-cloud-new-user.png)

## Настройка OpenAM

### Установка OpenAM

Для простоты, разверните OpenAM в Docker контейнере командой

```bash
docker run -p 8080:8080 --name openam openidentityplatform/openam
```

И выполните первоначальную настройку

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

Добавьте сертификат, скачанный ранее для созданного приложения Yandex Cloud в keystore OpenAM.

Для этого скопируйте сертификат в контейнер

```bash
docker cp openam-saml.cer openam:/usr/openam/config/openam
```

Пароль для keystore находится в файле `/usr/openam/config/openam/.storepass`

Посмотреть его можно командой

```bash
docker exec openam bash -c 'cat /usr/openam/config/openam/.storepass'
```

Импортируйте сертификат в keystore OpenAM

```bash
docker exec -it -w '/usr/openam/config/openam' openam bash -c 'keytool -importcert \
        -alias "yandex-cloud-cert" \
        -keystore keystore.jceks \
        -storetype JCEKS \
        -file openam-saml.cer'
```

Введите пароль и подтвердите, что сертификат является доверенным.

Перезапустите контейнер OpenAM

```bash
docker restart openam
```

### Настройка Realm

Войдите в консоль администратора по адресу [http://localhost:8080/openam](http://localhost:8080/openam/). Используйте логин `amadmin`  и пароль `passw0rd` соотвественно.

1. Откройте **Top Level Realm.** 
2. В меню слева перейдите **Authentication → Settings**
3. Перейдите на закладку **User Profile** и установите настройку **User Profile** в **Ignore**.
4. Нажмите **Save Changes.**
    
    ![OpenAM Realm Settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/yandex-cloud-idp-saml/4-openam-realm-settings.png)

### Настройка Service Provider

1. В консоли администратора выберите **Top Level Realm**
2. На панели **Common Tasks** нажмите **Configure SAMLv2 Provider**
3. Далее **Create Hosted Service Provider**
4. Введите любое наименование **Circle Of Trust**, например, `openam-yandex` и нажмите **Configure.**

    ![OpenAM Realm Settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/yandex-cloud-idp-saml/4-openam-realm-settings.png)

5. OpenAM предложит настроить Remote Identity Provider. Нажмите Yes.

    ![OpenAM Configure IDP Request](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/yandex-cloud-idp-saml/6-openam-configure-idp-request.png)

### Настройка Identity Provider

1. Введите URL метаданных из настроек приложения Yandex и нажмите Configure

    ![OpenAM Configure Remote IDP](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/yandex-cloud-idp-saml/7-openam-remote-idp.png)

2. Снова откройте Top Level Realm
3. На панели слева перейдите **Applications → SAML 2.0**
4. В списке **Entity Providers** откройте **http://localhost:8080/openam**
5. На закладке **Assertion Content** найдите раздел **Authentication Context**
6. Установите настройку **Default Authentication Context** в значение `Password`
7. В таблице **Authentication Context** отметьте значения `Password` и `Password Protected Password` 
8. Нажмите **Save**
9. Перейдите на закладку **Assertion Processing**
10. В разделе **Attribute Mapper** установите настройку **Attribute Map**: `emailaddress=mail`
11. В разделе **Auto Federation** включите чекбокс Enabled и установите Attribute в значение `emailaddress` 
12. Нажмите **Save**
13. Перейдите на закладку **Services**
14. В разделе **SP Service Attributes** в таблице **Assertion Consumer Service** отметьте значение `HTTP-POST`

    ![OpenAM Assertion Consumer Service](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/yandex-cloud-idp-saml/8-openam-assertion-consumer-service.png)

15. Нажмите **Save**

## Проверка решения

1. Выйдите из консоли администратора, консоли Yandex или откройте браузер в режиме Инкогнито.
2. Перейдите по ссылке аутентификации: [http://localhost:8080/openam/spssoinit?metaAlias=/sp&idpEntityID=https%3A%2F%2Fauth.yandex.cloud%2Fsaml%2Fek0pduu9hrclvnque14v&RelayState=http%3A%2F%2Flocalhost%3A8080%2Fopenam](http://localhost:8080/openam/spssoinit?metaAlias=/sp&idpEntityID=https%3A%2F%2Fauth.yandex.cloud%2Fsaml%2Fek0pduu9hrclvnque14v&RelayState=http%3A%2F%2Flocalhost%3A8080%2Fopenam) 
3. Откроется окно аутентификации Yandex Cloud.
4. В поле почты для входа введите идентификатор пользователя: `demo-saml@openam-saml.idp.yandexcloud.net`  и нажмите →
5. В поле пароль введите соответствующий пароль для учетной записи
6. Нажмите →

    ![Yandex Cloud Authentication](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/yandex-cloud-idp-saml/9-yandex-cloud-auth.png)

7. После успешной аутенитфикации вас перенаправит в консоль OpenAM с учетными данными Yandex Cloud

    ![OpenAM User Profile](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/yandex-cloud-idp-saml/10-openam-user-profile.png)

## Что дальше

Для использования на продуктиве OpenAM должен быть развернут с использованием безопасного подключения по протоколу SSL, например на хосте и с использованием FQDN, например https://openam.example.org/openam. 

Далее, вы можете использовать шлюз авторизации OpenIG для настройки единого входа (SSO) в ваши приложения.

Более подробно о настройке OpenAM и OpenIG вы можете ознакомиться на сайте с документацией [https://doc.openidentityplatform.org/openam](https://doc.openidentityplatform.org/openam) и [https://doc.openidentityplatform.org/openig](https://doc.openidentityplatform.org/openig)