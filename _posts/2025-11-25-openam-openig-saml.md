---
layout: blog
title: 'Настройка SSO: OpenIG как SAML Service Provider для OpenAM'
description: 'Пошаговое руководство по настройке OpenIG как Service Provider (SP) и прокси для OpenAM (IdP). Узнайте, как добавить корпоративную SAML-аутентификацию к любому приложению, используя Docker.'
keywords: 'SAML 2.0, Single Sign-On, SSO, OpenIG, OpenAM, Identity Provider, Service Provider, IdP, SP, Fedlet, аутентификация, корпоративная безопасность, управление доступом, прокси, Docker, SAML настройка, OpenIG настройка, OpenAM настройка, защита приложений'
tags: 
  - openam
  - openig
---

## Введение

Протокол SAML 2.0 является стандартом для Single Sign-On (SSO) в корпоративной среде. В этом руководстве мы покажем, как использовать OpenIG в качестве прокси и Service Provider, чтобы легко добавить SAML-аутентификацию к любому вашему приложению без изменения его кода.

## Подготовка

1. Для простоты развертывания сервисов мы будем использовать их образы Docker. Таким образом, Docker должен быть у вас установлен.
2. Внесите в файл `hosts` имена хостов для OpenAM и OpenIG. В системах под управлением Windows файл hosts расположен в директории `C:\Windows/System32/drivers/etc/hosts`, на Linux или Mac OS - в `/etc/hosts`.
    
    ```
    127.0.0.1    openam.example.org openig.example.org
    ```
    

## **Настройка OpenAM**

### **Установка OpenAM**

Разверните контейнер OpenAM командой

```bash
docker run -h openam.example.org -p 8080:8080 --name openam openidentityplatform/openam
```

И выполните первоначальную настройку:

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

### Настройка OpenAM Identity Provider

1. Зайдите в консоль администратора по ссылке [http://openam.example.org:8080/openam](http://openam.example.org:8080/openam) . С логином `amadmin` и паролем `passw0rd`.
2. Выберите Top Level Realm
3. Перейдите **Create SAMLv2 Providers →** **Create Hosted Identity Provider**
4. Установите Metadata Name: `openam`
5. В настройке Signing Key выберите `test`
6. Введите имя Circle of Trust, например, `cot`
7. В разделе Attribute Mapping добавьте mapping uid → uid, mail → mail
8. Нажмите **Configure**

### Настройка Fedlet OpenAM

1. Откройте консоль администратора
2. Выберите Top Level Realm
3. Перейдите **Create Fedlet Configuration**
4. Введите имя fedlet в поле Name, например, openig.
5. Установите настройку **Destination URL of the Service Provider which will include the Fedlet,** в значение URL, который будет указывать на OpenIG: `http://openig.example.org:8081/saml`
6. В разделе Attribute Mapping добавьте mapping uid → uid, mail → mail
7. Нажмите **Create**
    
    Настройки Fedlet будут сохранены в контейнере в директории `/usr/openam/config/myfedlets/openig/Fedlet.zip`
    
    Скопируйте настройки на хост командой:
    
    ```bash
    docker cp openam:/usr/openam/config/myfedlets/openig/Fedlet.zip .
    ```
    

### Подготовка тестового пользователя

1. Откройте консоль администратора
2. Выберите Top Level Realm
3. В панели слева выберите пункт Subjects
4. В списке учетных записей откройте учетную запись `demo`
5. В поле Email Address введите `demo@example.org` или другой корректный адрес
6. Нажмите **Save**

## Настройка OpenIG

### Подготовка файлов конфигурации OpenIG

1. Создайте директорию для файлов конфигурации OpenIG `openig-saml`
2. Добавьте в нее директорию `config`
3. В директории `config` создайте файл `admin.json` и `config.json`:
    
    `admin.json`:
    
    ```json
    {
      "prefix" : "openig",
      "mode": "PRODUCTION"
    }
    ```
    
    `config.json`:
    
    ```json
    {
      "heap": [
        {
          "name": "JwtSession",
          "type": "JwtSession"
        },
        {
          "name": "capture",
          "type": "CaptureDecorator",
          "config": {
            "captureEntity": true,
            "_captureContext": true
          }
        }
      ],
      "handler": {
        "type": "Chain",
        "config": {
          "filters": [],
          "handler": {
            "type": "Router",
            "name": "_router",
            "capture": "all"
          }
        }
      }
    }
    ```
    
4. В директорию `config` добавьте директорию для маршрутов `routes`
5. Добавьте в директорию `routes` маршрут по умолчанию `99-default.json`. OpenIG по этому маршруту будет отдавать статический контент и не будет требовать аутентификацию:
    
    ```json
    {
      "handler": {
        "type": "DispatchHandler",
        "config": {
          "bindings": [
            {
              "handler": {
                "type": "StaticResponseHandler",
                "config": {
                  "status": 200,
                  "reason": "OK",
                  "entity":
    "<!doctype html>
    <html>
    <head>
      <title>Home</title>
      <meta charset='UTF-8'>
    </head>
    <body>
      <h1><a href='/app'>Login</a></h1>   
    </body>
    </html>"
                }
              }
            }
          ]
        }
      },
      "session": "JwtSession"
    }
    ```
    
6. Запустите Docker контейнер OpenIG командой. Обратите внимание на смонтированную директорию `/app-saml`
    
    ```bash
    docker run -h openig.example.org -p 8081:8080 --name openig \
      -v ./app-saml:/usr/local/app-saml:ro \
      -e "CATALINA_OPTS=-Dopenig.base=/usr/local/app-saml" \
      openidentityplatform/openig
    ```
    
7. Проверьте работу приложения:
    
    ```bash
    $ curl -v http://openig.example.org:8081
    *   Trying 127.0.0.1:8081...
    * Connected to openig.example.org (127.0.0.1) port 8081 (#0)
    > GET / HTTP/1.1
    > Host: openig.example.org:8081
    > User-Agent: curl/7.81.0
    > Accept: */*
    > 
    * Mark bundle as not supporting multiuse
    < HTTP/1.1 200 
    < Content-Length: 146
    < Date: Mon, 24 Nov 2025 12:46:56 GMT
    < 
    <!doctype html>
    <html>
    <head>
      <title>Home</title>
      <meta charset='UTF-8'>
    </head>
    <body>
      <h1><a href='/app'>Login</a></h1>   
    </body>
    ```
    
8. Остановите контейнер OpenIG
    
    ```bash
    docker stop openig | xargs docker rm
    ```
    

### Настройка SAML Fedlet в OpenIG

1. В директории `openig-saml` создайте директорию `SAML`
2. Скопируйте в нее содержимое архива Fedlet.zip, который вы получили из OpenAM
    
    ```bash
    unzip Fedlet.zip
    cp conf/* app-saml/SAML/
    ```
    
3. Создайте маршрут получения учетных данных из assertions SAML `05-saml.json`
    
    ```json
    {
      "handler": {
        "type": "SamlFederationHandler",
        "config": {
          "assertionMapping": {
            "uid": "uid",
            "mail": "mail"
          },
          "redirectURI": "/app"
        }
      },
      "condition": "${matches(request.uri.path, '^/saml')}",
      "session": "JwtSession"
    }
    ```
    
4. Создайте маршрут приложения, требующего аутентификации SAML `05-app.json`:
    
    ```json
    {
      "handler": {
        "type": "DispatchHandler",
        "config": {
          "bindings": [
            {
              "condition": "${empty session.uid}",
              "handler": {
                "type": "StaticResponseHandler",
                "config": {
                  "status": 302,
                  "reason": "Found",
                  "headers": {
                    "Location": [
                      "http://openig.example.org:8081/saml/SPInitiatedSSO"
                    ]
                  }
                }
              }
            },
            {
              "handler": {
              "handler": {
                "type": "StaticResponseHandler",
                "config": {
                  "status": 200,
                  "reason": "OK",
                  "entity":
    "<!doctype html>
    <html>
    <head>
      <title>OpenID Connect Discovery</title>
      <meta charset='UTF-8'>
    </head>
    <body>
      <h1>User: ${session.uid}, email: ${session.mail} </h1>            
    </body>
    </html>"
                }
              }
            }
            }
          ]
        }
      },
      "condition": "${matches(request.uri.path, '^/app')}",
      "session": "JwtSession"
    }
    ```
    
5. Запустите контейнер OpenIG:
    
    ```bash
    docker run -h openig.example.org -p 8081:8080 --name openig \
      -v ./app-saml:/usr/local/app-saml:ro \
      -e "CATALINA_OPTS=-Dopenig.base=/usr/local/app-saml" \
      openidentityplatform/openig
    ```
    

## Проверка решения

1. Выйдите из консоли OpenAM или откройте браузер в режиме “Инкогнито”
2. Откройте ссылку приложения OpenIG, не требующего аутентификации: [http://openig.example.org:8081/](http://openig.example.org:8081/). 
    
    ![OpenIG Application Login](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-saml/0-openig-application-login.png)
    
3. Перейдите по ссылке `Login`.
4. Откроется форма аутентификации OpenAM
5. Введите учетные данные пользователя demo. Логин: `demo`, пароль: `changeit` и нажмите кнопку **Login**.
    
    ![OpenAM Login](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-saml/1-openam-login.png)
    
6. Вас перенаправит в приложение с учетными данными пользоваателя demo:
    
    ![OpenIG Logged In](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-saml/2-openig-logged-in.png)
    

## Заключение.

Мы успешно настроили OpenIG как Service Provider и реализовали аутентификацию SAML 2.0 через OpenAM. Теперь вы можете использовать этот подход для защиты любых приложений в вашей инфраструктуре. Следующим шагом может стать настройка Log Out.

Более подробно о настройке OpenAM и OpenIG вы можете почитать в документации:

- [https://doc.openidentityplatform.org/openam](https://doc.openidentityplatform.org/openam/)
- [http://doc.openidentityplatform.org/openig](http://doc.openidentityplatform.org/openig)