---
layout: blog
title: 'Настройка сервиса аутентификации OpenAM и шлюза авторизации OpenIG для защиты приложений'
description: 'В этой статье мы настроим централизованную аутентификацию через сервис аутентификации на Open Access Manager (OpenAM) и настроим доступ к приложению через шлюз авторизации Open Identity Gateway (OpenIG), который будет использовать сессию аутентификации OpenAM. В качестве защищаемого приложения будем использовать приложение, разработанное с использованием Spring Boot и Spring Security.'
tags: 
  - openam
  - openig

---

## Введение

Если в организации множество приложений и сервисов, то нет необходимости разрабатывать аутентификацию и авторизацию для каждого сервиса отдельно. Оптимальным подходом является использование централизованного сервиса аутентификации совместно со шлюзом авторизации, который и определяет политики доступа к приложениям.

В этой статье мы настроим централизованную аутентификацию через сервис аутентификации на Open Access Manager ([OpenAM)](https://github.com/OpenIdentityPlatform/OpenAM) и настроим доступ к приложению через шлюз авторизации Open Identity Gateway ([OpenIG](https://github.com/OpenIdentityPlatform/OpenIG)), который будет использовать сессию аутентификации OpenAM. В качестве защищаемого приложения будем использовать приложение, разработанное с использованием Spring Boot и Spring Security. Исходный код приложения располагается на [GitHub](https://github.com/OpenIdentityPlatform/spring-security-openam-example).

Для демонстрационных целей все сервисы запустим в Docker контейнерах. 

Процесс аутентификации и авторизации к защищаемому ресурсу показан на рисунке:

![OpenAM OpenIG auth scheme](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig/openam-openig-auth-scheme.png)

## Запуск демонстрационного приложения

Создайте файл `docker-compose.yaml` и добавьте в него демонстрационное приложение. Пробросьте порт 8081 для проверки работоспособности.

```yaml
services:
  spring-service:
    container_name: spring-service
    image: openidentityplatform/spring-security-openam-example
    restart: always
    ports:
      - "8081:8081"
    environment:
      JAVA_OPTS: -Dspring.profiles.active=jwt
    networks:
      openam_network:
        aliases:
          - spring-service

networks:
  openam_network:
    driver: bridge
```

После того, как приложение запущено, проверим к доступ к API, для которого требуется добавить аутентификацию.

```bash
curl http://localhost:8081/api/protected-jwt | json_pp
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   105    0   105    0     0  12684      0 --:--:-- --:--:-- --:--:-- 13125
{
   "error" : "Unauthorized",
   "path" : "/protected-jwt",
   "status" : 401,
   "timestamp" : "2024-04-16T06:01:25.331+00:00"
}
```

Для успешной аутентификации, в API нужно передать валидный JWT в HTTP заголовке Authorization. За это и будет отвечать связка OpenAM + OpenIG. Потушите пока тестовый сервис командной `docker compose down` 

## Настройка OpenAM

Сначала  настроим сервис аутентификации OpenAM. Он будет отвечать за аутентификацию и конвертацию токена аутентификации в JWT (об этом ниже).

Добавьте имена хостов OpenAM и OpenIG в файл `hosts`, например `127.0.0.1 openam.example.org openig.example.org` .

В Windows системах файл `hosts` находится по адресу `C:\Windows\System32\drivers\etc\hosts` , в Linux и Mac находится по адресу `/etc/hosts` .

Добавьте в файл `docker-compose.yaml` сервис OpenAM:

```yaml
...
  openam:
    image: openidentityplatform/openam:latest
    container_name: openam
    ports:
      - "8080:8080"
    networks:
      openam_network:
        aliases:
          - openam.example.org
...
```

Запустите OpenAM командой `docker compose up openam`. После того, как OpenAM запущен, сконфигурируйте его командой:

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

И дождитесь завершения выполнения.

### Настройка STS

STS (Security Token Service) - сервис конвертации токена OpenAM в JWT. После аутентификации OpenAM возвращает токен аутентификации, который является случайно сгенерированной последовательностью символов. Сервис STS отвечает за конвертацию  токена аутентификации в JWT, который и содержит информацию об аутентифицированном пользователе. Этот сервис и будет использовать OpenIG.

Для настройки STS зайдите в консоль администратора по ссылке

[http://openam.example.org:8080/openam/XUI/#login/](http://openam.example.org:8080/openam/XUI/#login/)

В поле логин введите значение `amadmin`,  в поле пароль введите значение из параметра `ADMIN_PWD` команды установки, в данном случае `passw0rd`

![OpenAM Console Realm](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig/openam-console-realm.png)

Откройте корневой realm, в левом меню нажмите пункт STS и создайте новый инстанс со следующими параметрами:

| Setting | Value |
| --- | --- |
| Supported Token Transforms | OPENAM->OPENIDCONNECT;don't invalidate interim OpenAM session |
| Deployment Url Element | jwt |
| The id of the OpenID Connect Token Provider | https://openam.example.org/openam |
| Client secret | changeme |
| Confirm client secret | changeme |
| The audience for issued tokens | https://openam.example.org/openam |

### Настройка тестового пользователя

В консоли администратора OpenAM перейдите в корневой realm, в меню слева выберите пункт Subjects. Задайте пароль для пользователя `demo`. Для этого выберите его в списке пользователей, и нажмите ссылку Edit в пункте Password. Введите и сохраните новый пароль. После настройки выйдите из консоли администратора.

## Настройка OpenIG

OpenIG отвечает за политики доступа к внутренним сервисам. Он конвертирует токен аутентификации в JWT в сервисе OpenAM и, при успешной авторизации предает передает во внутренние сервисы в заголовке Authorization.

Создайте папку `openig-config` и добавьте в нее 2 файла: `admin.json`

```json
{
    "prefix": "openig",
    "mode": "PRODUCTION"
}
```

и `config.json`

```json
{
    "heap": [],
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

Теперь добавим маршрут, который будет перенаправлять запросы пользователя в демонстрационное приложение, обогащая запрос заголовком Authorization с JWT токеном, полученным из OpenAM.

Создайте папку `openig-config/routes/` и добавьте в нее файл `10-protected.json`. 

```json
{
    "name": "${matches(request.uri.path, '^/api/protected-jwt') || matches(request.uri.path, '^/protected-jwt')}",
    "condition": "${matches(request.uri.path, '^/api/protected-jwt') || matches(request.uri.path, '^/protected-jwt')}",
    "monitor": true,
    "timer": true,
    "handler": {
        "type": "Chain",
        "config": {
            "filters": [
                {
                    "type": "ConditionalFilter",
                    "config": {
                        "condition": "${empty contexts.sts.issuedToken and not empty request.cookies['iPlanetDirectoryPro'][0].value}",
                        "delegate": {
                            "type": "TokenTransformationFilter",
                            "config": {
                                "openamUri": "${system['openam']}",
                                "realm": "/",
                                "instance": "jwt",
                                "from": "OPENAM",
                                "to": "OPENIDCONNECT",
                                "idToken": "${request.cookies['iPlanetDirectoryPro'][0].value}"
                            }
                        }
                    }
                },
                {
                    "type": "ConditionalFilter",
                    "config": {
                        "condition": "${not empty contexts.sts.issuedToken}",
                        "delegate": {
                            "type": "HeaderFilter",
                            "config": {
                                "messageType": "REQUEST",
                                "remove": [
                                    "Authorization",
                                    "JWT"
                                ],
                                "add": {
                                    "Authorization": [
                                        "Bearer ${contexts.sts.issuedToken}"
                                    ]
                                }
                            }
                        }
                    }
                },
                {
                    "type": "ConditionEnforcementFilter",
                    "config": {
                        "condition": "${not empty contexts.sts.issuedToken}",
                        "failureHandler": {
                            "type": "StaticResponseHandler",
                            "config": {
                                "status": 302,
                                "reason": "Found",
                                "headers": {
                                    "Content-Type": [
                                        "application/json"
                                    ],
                                    "Location": [
                                        "${system['openam']}/UI/Login?org=/&goto=${urlEncode(contexts.router.originalUri)}"
                                    ]
                                },
                                "entity": "{ \"Redirect\": \"${system['openam']}/UI/Login?org=/&goto=${urlEncode(contexts.router.originalUri)}\"}"
                            }
                        }
                    }
                }
            ],
            "handler": "EndpointHandler"
        }
    },
    "heap": [
        {
            "name": "EndpointHandler",
            "type": "DispatchHandler",
            "config": {
                "bindings": [
                    {
                        "handler": "ClientHandler",
                        "capture": "all",
                        "baseURI": "${matchingGroups(system['spring-service'],\"((http|https):\/\/(.[^\/]*))\")[1]}"
                    }
                ]
            }
        }
    ]
}
```

Этот маршрут авторизует две конечные точки: API - `/api/protected-jwt` и UI - `/protected-jwt`.

Добавьте сервис OpenIG в `docker-compose.yaml` файл и уберите маппинг портов из сервиса `spring-service`. Теперь этот сервис доступен только через OpenIG.

```yaml
services:
  openam:
    image: openidentityplatform/openam:latest
    container_name: openam
    ports:
      - "8080:8080"
    networks:
      openam_network:
        aliases:
          - openam.example.org
    
  openig:
    image: openidentityplatform/openig:latest
    container_name: openig
    volumes:
      - ./openig-config:/usr/local/openig-config:ro
    environment:
      CATALINA_OPTS: -Dopenig.base=/usr/local/openig-config -Dspring-service=http://spring-service:8081 -Dopenam=http://openam.example.org:8080/openam
    ports:
      - "8081:8080"
    networks:
      openam_network:
        aliases:
          - openig.example.org

  spring-service:
    container_name: spring-service
    image: openidentityplatform/spring-security-openam-example
    restart: always
    # ports:
    #   - "8081:8081"
    environment:
      JAVA_OPTS: -Dspring.profiles.active=jwt
    networks:
      openam_network:
        aliases:
          - spring-service

networks:
  openam_network:
    driver: bridge
```

Запустите OpenIG и тестовое приложение командой `docker compose up openig spring-service`

## Проверка решения

### Проверка авторизации API

Получим токен аутентификации OpenAM для пользователя `demo`:

```bash
curl -X POST -H "X-OpenAM-Username: demo" -H "X-OpenAM-Password: passw0rd" \ 
-H "Content-Type: application/json" -H "Accept-API-Version: resource=2.1" \
http://openam.example.org:8080/openam/json/realms/root/authenticate | json_pp
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   159  100   159    0     0   4197      0 --:--:-- --:--:-- --:--:--  4297
{
   "realm" : "/",
   "successUrl" : "/openam/console",
   "tokenId" : "AQIC5wM2LY4Sfcze3DbBXVSXggTyZNpGfwOoFPLnHwmqLG0.*AAJTSQACMDEAAlNLABM2MTY1Mjg2MzI5Mzc4ODM0MzQ5AAJTMQAA*"
}

```

Вызовем с полученным токеном endpoint `/api/protected-jwt`

```bash
curl  --cookie "iPlanetDirectoryPro=AQIC5wM2LY4Sfcze3DbBXVSXggTyZNpGfwOoFPLnHwmqLG0.*AAJTSQACMDEAAlNLABM2MTY1Mjg2MzI5Mzc4ODM0MzQ5AAJTMQAA*" \
 "http://openig.example.org:8081/api/protected-jwt" | json_pp
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    30    0    30    0     0   1071      0 --:--:-- --:--:-- --:--:--  1111
{
   "method" : "JWT",
   "user" : "demo"
}

```

OpenIG через OpenAM сконвертировал переданный в cookie `iPlanetDirectoryPro` токен аутентификации в JWT и передал этот JWT в демонстрационное приложение `spring-service`. Демонстрационное приложение получило из JWT информацию о пользователе и вернуло успешный ответ.

### Проверка авторизации UI

Выйдите из консоли администратора или откройте браузер в режиме “Инкогнито”

Откройте в браузере URL [http://openig.example.org:8081/protected-jwt](http://openig.example.org:8081/protected-jwt) . OpenIG не найдет cookie с токеном аутентификации и перенаправит браузер на аутентификацию OpenAM. Введите логин `demo` , пароль и нажмите кнопку `Log In`.

![OpenAM demo login](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig/openam-demo-login.png)

После успешной аутентификации шлюз перенаправит запрос к Spring Boot приложение. Получит из http запроса cookie с токеном аутентификации, сконвертирует токен в OpenAM в сервисе STS в JWT и передаст полученный JWT в демонстрационное приложение. Демонстрационное приложение проверит JWT и вернет успешный ответ.

![OpenAM demo login](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig/protected-app.png)

Исходный код демонстрационное приложения располагается по ссылке: https://github.com/OpenIdentityPlatform/spring-security-openam-example

Исходный код конфигурации docker conpose и маршрутов OpenIG для статьи располагается по ссылке https://github.com/OpenIdentityPlatform/openam-openig-springboot-example