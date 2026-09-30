---
layout: blog
title: 'Защита REST API: авторизация OAuth/OIDC, валидация соответствия OpenAPI/Swagger, контроль уровня обслуживания'
description: 'Пошаговая инструкция по защите REST API с помощью шлюза OpenIG: настройка авторизации OAuth 2.0 через OpenAM, валидация запросов и ответов по спецификации OpenAPI, ограничение частоты запросов (throttling) в Docker Compose.'
keywords: OpenIG, OpenAM, защита REST API, OAuth 2.0, API шлюз, валидация OpenAPI, валидация Swagger, throttling API, ограничение запросов, Spring Pet Clinic, Docker Compose, авторизация API, Bearer token, токен доступа, mass assignment, утечка данных, безопасность API, open source IAM, фильтр запросов, контроль пропускной способности
tags: 
  - openig
  - openam
redirect_from:
  - /blog/2026-03-27-openig-rest-api-security-oauth2-openapi-validation-rate-limiting.md
---

## О чем эта статья

Статья представляет собой пошаговую инструкцию по защите REST сервиса при помощи шлюза с открытым исходным кодом OpenIG. В статье мы сделаем следующее:

1. Развернем демонстрационный REST сервис [Spring Pet Clinic](https://github.com/spring-petclinic/spring-petclinic-rest).
2. Защитим сервис шлюзом OpenIG:
    1. Настроим контроль авторизации доступа по протоколу OAuth 2.0. В качестве OAuth 2.0 сервера  будем использовать [OpenAM](http://github.com/OpenIdentityPlatform/OpenAM).
    2. Настроим валидацию запросов и ответов сервиса на соответствие спецификации [OpenAPI](https://spec.openapis.org/oas/latest.html).
    3. Настроим контроль количества запросов (throttling) для каждого пользователя.

Для демонстрационных целей развернем все сервисы в Docker контейнерах при помощи Docker Compose.

## **Какие угрозы закрывает решение**

Без валидации на шлюзе бэкенд получает любые данные от клиента и возвращает 
клиенту любые данные из своих ответов. Это открывает несколько векторов атак:

- **Mass assignment** — злоумышленник передаёт поля, которых нет в спецификации 
  (`isAdmin: true`, `role: superuser`), и бэкенд может их обработать, если 
  не защищён на уровне кода.
- **Injection через нестандартные поля** — нет валидации типов и форматов, 
  значит можно передавать строки там, где ожидается число, или вставлять 
  спецсимволы в поля без ограничений по паттерну.
- **Утечка данных через ответы** — бэкенд может случайно вернуть поля, 
  которых нет в контракте (внутренние идентификаторы, хэши паролей, 
  служебные метаданные). Валидация ответов это детектирует.
- **Эксплуатация недокументированных эндпоинтов** — запросы к путям, 
  которых нет в спецификации, будут отклонены шлюзом, не доходя до бэкенда.

Перенос этих проверок на шлюз разгружает бэкенд от защитной логики и 
обеспечивает единую точку контроля для всех сервисов за шлюзом.

Полный код решения вы можете скачать по ссылке: [openig-openam-openapi-example](https://github.com/OpenIdentityPlatform/openig-openam-openapi-example)

## Подготовка

Создайте файл `docker-compose.yml` и добавьте в него сервис Spring Pet Clinic:

```yaml
services:
  petclinic:
    image: springcommunity/spring-petclinic-rest:4.0.2
    ports:
      - 9966:9966
```

Запустите контейнер командой `docker compose up`.

После того, как сервис запустится, проверьте, что он работает:

```bash
$ curl http://localhost:9966/petclinic/actuator/health 
{"groups":["liveness","readiness"],"status":"UP"}
```

Скачайте спецификацию OpenAPI на сервис, она нам пригодится позже для валидации запросов и ответов:

```bash
curl -v http://localhost:9966/petclinic/v3/api-docs.yaml -H "Host: petclinic:9966" | grep -v extensions > petclinic.yml
```

## Настройка OpenIG

Добавьте OpenIG в список сервисов в `docker-compose.yml` и закройте порт для сервиса `petclinic`. Теперь все запросы к нему будут идти через OpenIG.

```yaml
services:
  petclinic:
    image: springcommunity/spring-petclinic-rest:4.0.2
  openig:
    image: openidentityplatform/openig:latest
    ports: 
      - 8081:8080
    volumes:
      - ./openig/config:/usr/local/openig-config:ro
    environment:
      CATALINA_OPTS: -Dopenig.base=/usr/local/openig-config -Dpetclinic=http://petclinic:9966

```

В директории с файлом `docker-compose.yml` создайте директорию `openig` в ней создайте 2 директории: `config` и `openapi`.

В директории `config` создайте 2 файла `admin.json` и `config.json`  со следующим содержимым:

`admin.json`

```json
{
  "prefix" : "openig",
  "mode": "PRODUCTION"
}
```

`config.json`

```json
{
  "heap": [
  ],
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [
      ],
      "handler": {
        "type": "Router",
        "name": "_router",
        "capture": "all",
        "config": {
	        "directory": "${system['openig.base']}/config/routes",
          "openApiValidation": {
            "enabled": true,
            "failOnResponseViolation": false
          }
        }
      }
    }
  }
}
```

> **Примечание:** параметр `directory` конфигурации объекта `Router` указывает местоположение файлов маршрута

### Настройка маршрута к сервису Pet Clinic

Теперь добавим маршрут к сервису Spring Pet Clinic.

В директории `config` создайте директорию `routes` и добавьте в нее файл спецификации OpenAPI `petclinic.yml`. 

Запустите OpenIG и проверьте работоспособность маршрута:

```bash
docker compose up
```

```bash
curl -v  --location "http://localhost:8081/petclinic/api/pets"
* Host localhost:8081 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:8081...
* Connected to localhost (::1) port 8081
> GET /petclinic/api/pets HTTP/1.1
> Host: localhost:8081
> User-Agent: curl/8.7.1
> Accept: */*
> 
* Request completely sent off
< HTTP/1.1 200 
< Cache-Control: no-cache, no-store, max-age=0, must-revalidate
< Date: Mon, 23 Mar 2026 12:29:33 GMT
< Expires: 0
< Pragma: no-cache
< Vary: Origin
< Vary: Access-Control-Request-Method
< Vary: Access-Control-Request-Headers
< X-Content-Type-Options: nosniff
< X-Frame-Options: SAMEORIGIN
< X-XSS-Protection: 0
< Content-Type: application/json
< Transfer-Encoding: chunked
< 
* Connection #0 to host localhost left intact
[{"name":"Leo","birthDate":"2010-09-07","type":{"name":"cat","id":1},"id":1,"visits":[],"ownerId":1}
....
```

### Настройка контроля аутентификации

Разверните сервер аутентификации OpenAM.

Добавьте сервис `openam` в `docker-compose.yml`

```yaml
services:
...

  openam:
    image: openidentityplatform/openam
    container_name: openam
    restart: always
    hostname: openam.example.org
    ports:
      - "8080:8080"
    volumes:
      - openam-data:/usr/openam/config

volumes:
  openam-data:
```

Запустите сервис OpenAM.

```bash
docker compose up openam
```

Внесите в файл `hosts` имя хоста для OpenAM. В системах под управлением Windows файл hosts расположен в директории `C:\\Windows/System32/drivers/etc/hosts`, на Linux или Mac OS - в `/etc/hosts`.

```
127.0.0.1    openam.example.org
```

Выполните первоначальную настройку OpenAM:

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

Дождитесь окончания выполнения команды.

Откройте консоль OpenAM по ссылке [http://openam.example.org:8080/openam/console](http://openam.example.org:8080/openam/console). В поля `User Name` и `Password` введите логин и пароль администратора. В данном случае это будут `amadmin` и `passw0rd` соответственно. 

В списке Realm выберите `Top Level Realm`.

![OpenAM Realms](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIG/images/openig-openam-openapi/0-openam-realms.png)

Далее, `Configure OAuth Provider`.

![OpenAM: Configure OAuth Provider](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIG/images/openig-openam-openapi/1-openam-configure-oauth-provider.png)

И выберите пункт `Configure OAuth 2.0`.

![OpenAM: Configure OAuth 2.0](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIG/images/openig-openam-openapi/2-openam-configure-oauth20.png)

В открывшейся форме можно оставить настройки по умолчанию без изменений. Нажмите `Create`.

![OpenAM: Configure OAuth 2.0 Settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIG/images/openig-openam-openapi/3-openam-configure-oauth20-settings.png)

В настройках Realm в меню слева выберите пункт Services и откройте настройки OAuth2 Provider.

![OpenAM Realm Services](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIG/images/openig-openam-openapi/4-openam-realm-services.png)
В настройки `Scopes` и `Default Clients Scopes` добавьте значение `uid`.  

Добавьте клиентское приложения OAuth 2.0

В консоли администратора выберите `Top Level Realm` и в меню слева перейдите `Applications`  → `OAuth 2.0`.

![OpenAM Realm Applications](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIG/images/openig-openam-openapi/5-openam-realm-applications.png)

Создайте новое приложение с именем (client_id) `petstore-app` . Пусть пароль (client_secret) будет `passw0rd`.

![OpenAM New OAuth 2.0 Application](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIG/images/openig-openam-openapi/6-openam-new-oauth20-app.png)

Откройте настройки приложения и добавьте scope `uid` в настройки `Scope(s)`  и `Default Scope(s)`. Сохраните изменения.

Откройте файл маршрута конфигурации `config.json` и в объект `heap` добавьте фильтр `OAuth2ResourceServerFilter`. Этот фильтр не будет пропускать неаутентифицированные запросы. Добавьте фильтр в цепочку фильтров маршрута:

```json
{
  "heap": [
    {
      "name": "OAuth2ResourceServerFilter",
      "type": "OAuth2ResourceServerFilter",
      "config": {
        "requireHttps": false,
        "providerHandler": "ClientHandler",
        "scopes": [
          "uid"
        ],
        "tokenInfoEndpoint": "${system['openam'].concat('/oauth2/tokeninfo')}"
      }
    }
  ],
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [
        "OAuth2ResourceServerFilter"
      ],
      "handler": {
        "type": "Router",
        "name": "_router",
        "capture": "all",
        "config": {
	        "directory": "${system['openig.base']}/config/routes",
          "openApiValidation": {
            "enabled": true,
            "failOnResponseViolation": false
          }
        }
      }
    }
  }
}
```

Перезапустите OpenIG командой:

```bash
docker compose restart openig
```

Проверим неаутенитфицированный запрос:

```bash
curl -v -X GET --location "http://localhost:8081/petclinic/api/pets"
Note: Unnecessary use of -X or --request, GET is already inferred.
* Host localhost:8081 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:8081...
* Connected to localhost (::1) port 8081
> GET /petclinic/api/pets HTTP/1.1
> Host: localhost:8081
> User-Agent: curl/8.7.1
> Accept: */*
> 
* Request completely sent off
< HTTP/1.1 401 
< WWW-Authenticate: Bearer realm="OpenIG"
< Content-Length: 0
< Date: Mon, 23 Mar 2026 07:25:27 GMT
< 
* Connection #0 to host localhost left intact
```

Теперь получим `access_token` в OpenAM для приложения и проверим аутентифицированный запрос:

```bash
curl \
--request POST \
--user "petstore-app:passw0rd" \
--data "grant_type=password&username=demo&password=changeit&scope=uid" \    
http://openam.example.org:8080/openam/oauth2/access_token
{"access_token":"c2270aa6-f1e1-47a2-a27f-3654af2f88d7","scope":"uid","token_type":"Bearer","expires_in":3599}%     
```

```bash
 curl -v -X GET --location "http://localhost:8081/petclinic/api/pets" \
    -H "Authorization: Bearer c2270aa6-f1e1-47a2-a27f-3654af2f88d7"       
Note: Unnecessary use of -X or --request, GET is already inferred.
* Host localhost:8081 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:8081...
* Connected to localhost (::1) port 8081
> GET /petclinic/api/pets HTTP/1.1
> Host: localhost:8081
> User-Agent: curl/8.7.1
> Accept: */*
> Authorization: Bearer c2270aa6-f1e1-47a2-a27f-3654af2f88d7
> 
* Request completely sent off
< HTTP/1.1 200 
< Cache-Control: no-cache, no-store, max-age=0, must-revalidate
< Date: Mon, 23 Mar 2026 07:29:03 GMT
< Expires: 0
< Pragma: no-cache
< Vary: Origin
< Vary: Access-Control-Request-Method
< Vary: Access-Control-Request-Headers
< X-Content-Type-Options: nosniff
< X-Frame-Options: SAMEORIGIN
< X-XSS-Protection: 0
< Content-Type: application/json
< Transfer-Encoding: chunked
< 
* Connection #0 to host localhost left intact
[{"name":"Leo","birthDate":"2010-09-07","type":{"name":"cat","id":1},"id":1,"visits":[],"ownerId":1},
....
```

Более подробно про контроль авторизации расскзано в статье: [https://github.com/OpenIdentityPlatform/OpenAM/wiki/How-to-Add-Authorization-and-Protect-Your-Application-With-OpenAM-and-OpenIG-Stack](https://github.com/OpenIdentityPlatform/OpenAM/wiki/How-to-Add-Authorization-and-Protect-Your-Application-With-OpenAM-and-OpenIG-Stack)

### Валидация запросов и ответов

Проверим валидацию запросов и ответов от сервиса Pet Clinic на соответствие спецификации OpenAPI.

> **Примечание.** Параметр объекта Router `openApiValidation.failOnResponseViolation: false`
означает, что невалидные ответы бэкенда будут **логироваться, но не
блокироваться**. Это безопасный режим для первоначального внедрения:
вы видите отклонения от спецификации ответа сервера.
> 
> 
> После аудита логов и устранения расхождений между кодом и спецификацией
> переключите на `true` . В этом случае ответы, нарушающие спецификацию, не будут
> доходить до клиента.
> 

Перезапустите контейнер OpenIG:

```bash
docker compose restart openig
```

Проверим невалидный запрос обновления питомца:

```bash
curl -v -X PUT --location "http://localhost:8081/petclinic/api/owners/10/pets/12" \
    -H "Content-Type: application/json" \
    -d "{
          \"birthDate\": \"2010-06-24\",
          \"badname\": \"Lucky\",
          \"type\": {
            \"id\": 2,
            \"name\": \"dog\"
          }
        }"
* Host localhost:8081 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:8081...
* Connected to localhost (::1) port 8081
> PUT /petclinic/api/owners/10/pets/12 HTTP/1.1
> Host: localhost:8081
> User-Agent: curl/8.7.1
> Accept: */*
> Content-Type: application/json
> Content-Length: 157
> 
* upload completely sent off: 157 bytes
< HTTP/1.1 400 
< Content-Type: text/plain;charset=UTF-8
< Content-Length: 183
< Date: Mon, 23 Mar 2026 12:34:50 GMT
< Connection: close
< 
* Closing connection
Request validation failed: [ERROR - Object instance has properties which are not allowed by the schema: ["badname"]: [], ERROR - Object has missing required properties (["name"]): []]
```

Проверьте лог OpenIG, в нем аналогичное сообщение ошибки валидации:

```
[http-nio-8080-exec-1] INFO  o.f.o.f.OpenApiValidationFilter - 
  Request validation failed for PUT http://petclinic:9966/petclinic/api/owners/10/pets/12: 
  [ERROR - Object instance has properties which are not allowed by the schema: ["badname"]: [], 
   ERROR - Object has missing required properties (["name"]): []]
```

### Добавление контроля пропускной способности

Ну, и наконец, добавим контроль пропускной способности API, чтобы один и тот же пользователь не превышал допустимое количество запросов к сервису за единицу времени.

Добавьте в файл конфигурации `config.json` в объект `heap` фильтр `ThrottlingFilter`

```json
{
  "heap": [
...
    {
      "type": "ThrottlingFilter",
      "name": "ThrottlingFilter",
      "config": {
        "requestGroupingPolicy": "${context.accessToken.info.uid}",
        "rate": {
          "numberOfRequests": 5,
          "duration": "5 s"
        }
      }
    }
  ],
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [
        "OAuth2ResourceServerFilter",
        "ThrottlingFilter"
      ],
      "handler": {
        "type": "Router",
        "name": "_router",
        "capture": "all",
        "config": {
	        "directory": "${system['openig.base']}/config/routes",
          "openApiValidation": {
            "enabled": true,
            "failOnResponseViolation": false
          }
        }
      }
    }
  }
}
```

И добавьте его в цепочку фильтров.

Обратите внимание на настройку `requestGroupingPolicy`. Настройка позволит группировать запросы для контроля пропускной способности по идентификатору пользователя, полученному из `access_token` переданному в заголовке `Authorization` HTTP запроса.

Отправьте несколько запросов для одного и того же `access_token`. При превышении лимита OpenIG вернет статус 429: Too Many Requests.

```bash
curl -v -X GET --location "http://localhost:8081/petclinic/api/pets" \
    -H "Authorization: Bearer c2270aa6-f1e1-47a2-a27f-3654af2f88d7"
Note: Unnecessary use of -X or --request, GET is already inferred.
* Host localhost:8081 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:8081...
* Connected to localhost (::1) port 8081
> GET /petclinic/api/pets HTTP/1.1
> Host: localhost:8081
> User-Agent: curl/8.7.1
> Accept: */*
> Authorization: Bearer c2270aa6-f1e1-47a2-a27f-3654af2f88d7
> 
* Request completely sent off
< HTTP/1.1 429 
< Retry-After: 1
< Retry-After-Partition: demo
< Retry-After-Rate: 5/5 SECONDS
< Retry-After-Rule: ThrottlingFilter
< Content-Length: 0
< Date: Mon, 23 Mar 2026 07:38:03 GMT
```

Более подробно про настройку контроля пропускной способности рассказано в статье [https://github.com/OpenIdentityPlatform/OpenIG/wiki/How-to-Setup-API-Throughput-Control-(Throttling)](https://github.com/OpenIdentityPlatform/OpenIG/wiki/How-to-Setup-API-Throughput-Control-(Throttling)).

## Заключение

В статье мы настроили контроль запросов и ответов на соответствие спецификации OpenAPI, добавили контроль аутентификации по протоколу OAuth 2.0 и настроили квоты на количество запросов к сервису по учетной записи.

Более подробно о настройке OpenIG вы можете почитать в документации [https://doc.openidentityplatform.org/openig/](https://doc.openidentityplatform.org/openig/).