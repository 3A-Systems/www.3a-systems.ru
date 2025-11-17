---
layout: blog
title: Настройка MCP с OpenAM и OpenIG для безопасного доступа
description: 'Как защитить MCP-сервер с помощью сервиса аутенитфикации OpenAM и шлюза авторизации OpenIG с использованием протокола OAuth 2.1'
keywords: 'mcp сервер oauth, защита mcp сервера, model context protocol oauth 2.1, spring ai mcp oauth, openam openig mcp, openam oauth2 mcp, openig oauth2resourceserverfilter, mcp сервер авторизация, spring ai mcp сервер docker, openidentityplatform mcp, как защитить mcp сервер oauth, mcp openam openig туториал, vscode copilot mcp oauth, github copilot mcp сервер, docker compose openam openig mcp, oauth 2.1 для llm агентов, модель контекст протокол безопасность, spring boot mcp oauth2, openig прокси mcp, openam динамическая регистрация клиента mcp, mcp сервер vs code, llm агент oauth защита, openam-openig-mcp-example'
tags: 
  - openam
---

## Введение

Агенты больших языковых моделей (LLM) могут выполнять различные задачи, от написания кода или текстов до бронирования билетов на самолет. Агенты состоят из клиента, с которым взаимодействует пользователь, и сервера, который выполняет требуемые задачи. Взаимодействие между клиентом, сервером и LLM происходит по протоколу [Model Context Protocol (MCP)](https://modelcontextprotocol.io/docs/getting-started/intro).

MCP серверы нередко имеют доступ к чувствительной информации, например, к внутреннему репозиторию исходного кода или к клиентской базе. При этом, не все пользователи должны иметь доступ к этим данным, пусть и через агента. Для защиты от несанкционированного доступа спецификация Model Context Protocol описывает возможность авторизации на основе OAuth 2.1: [https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization).

В статье мы развернем простой MCP сервер, разработанный на базе [Spring AI](https://spring.io/projects/spring-ai) и закроем его шлюзом авторизации [OpenIG](https://github.com/OpenIdentityPlatform/OpenIG). За аутентификацию будет отвечать сервис аутентификации [OpenAM](https://github.com/OpenIdentityPlatform/OpenAM). 

В качестве MCP клиента будем использовать VS Code с расширением GitHub Copilot.

## Описание проекта

Исходный код конфигурации OpenAM, OpenIG и MCP сервера расположен по ссылке: [https://github.com/OpenIdentityPlatform/openam-openig-mcp-example](https://github.com/OpenIdentityPlatform/openam-openig-mcp-example)

Проект состоит из трех сервисов, описанных в файле `docker-compose.yml` 

```yaml
services:
  openig:
    build:
      context: ./openig-docker
      dockerfile: Dockerfile
    container_name: openig
    volumes:
      - ./openig-config:/usr/local/openig-config:ro
    ports:  
      - "8081:8080"
    environment:
      CATALINA_OPTS: -Dopenig.base=/usr/local/openig-config -Dopenam=http://openam.example.org:8080/openam
    networks:
      openam_network:
        aliases:
          - openig.example.org
  
  openam:
    build:
      context: ./openam-docker
      dockerfile: Dockerfile
    container_name: openam
    restart: always
    hostname: openam.example.org
    ports:
      - "8080:8080"
    volumes:
      - openam-data:/usr/openam/config
    networks:
      openam_network:
        aliases:
          - openam.example.org
          
  time-mcp-server:
    build:
      context: ./timeserver
      dockerfile: Dockerfile
    container_name: time-mcp-server
    ports:
      - "8082:8080"
    networks:
      openam_network:
        aliases:
          - timeserver.example.org
networks:
  openam_network:
    driver: bridge

volumes:
  openam-data:
```

## Подготовка к запуску

Для примера, имя хоста OpenAM будет `openam.example.org`, а для OpenIG будет `openig.example.org`. Откройте файл `hosts` и добавьте в него имена хостов и IP адреса, например 

```
127.0.0.1 openam.example.org openig.example.org
```

В системах под управлением Windows файл hosts расположен в директории `C:\Windows/System32/drivers/etc/hosts`, на Linux или Mac OS в `/etc/hosts` .

## MCP Сервер

MCP сервер имеет метод возврата текущего времени в формате ISO 8601.

```java
@Service
public class TimeService {

    @Tool(name = "current_time_service", description = "Returns current time in ISO 8601 format")
    public String getTime() {
        return  Instant.now().toString();
    }
}
```

Более подробно про создание MCP сервера вы можете почитать в [документации](https://docs.spring.io/spring-ai/reference/api/mcp/mcp-server-boot-starter-docs.html) или в [блоге](https://spring.io/blog/2025/09/16/spring-ai-mcp-intro-blog) Spring AI.

Запустите Docker контейнеры OpenAM, OpenIG и MCP сервера командой:

```bash
docker compose up --build
```

Проверьте доступность запущенного MCP сервера командой:

```bash
curl -X POST  --location  "http://localhost:8082/mcp" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{
  "jsonrpc": "2.0",
  "id": 0,
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-06-18",
    "capabilities": {}
  }
}'

{
  "id": 0,
  "jsonrpc": "2.0",
  "result": {
    "capabilities": {
      "completions": {},
      "prompts": {
        "listChanged": false
      },
      "resources": {
        "listChanged": false,
        "subscribe": false
      },
      "tools": {
        "listChanged": false
      }
    },
    "protocolVersion": "2025-03-26",
    "serverInfo": {
      "name": "time-server-mcp",
      "version": "0.0.1"
    }
  }
}
```

Проверим наличие доступных инструментов в MCP сервере:

```bash
curl -X POST  --location  "http://localhost:8082/mcp" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list",
  "params": {}
}' 

{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {
        "name": "current_time_service",
        "description": "Returns current time in ISO 8601 format",
        "inputSchema": {
          "type": "object",
          "properties": {},
          "required": [],
          "additionalProperties": false
        }
      }
    ]
  }
}
```

## Настройка OpenAM

OpenAM будет отвечать за аутентификацию пользователей, выдачу токенов OAuth 2 `access_token` и их валидацию.

Если OpenAM у вас еще не настроен, выполните быструю настройку, выполнив команду:

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

### Настройка OAuth 2 в OpenAM

Откройте консоль OpenAM по ссылке [http://openam.example.org:8080/openam/console](http://openam.example.org:8080/openam/console). В поля `User Name` и `Password` введите логин и пароль администратора. В данном случае это будут `amadmin` и `passw0rd` соответственно. 

В списке Realm выберите `Top Level Realm`.

![OpenAM Realms List](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-mcp/0-openam-realms-list.png)

Далее, `Configure OAuth Provider` .

![OpenAM Configure OAuth Provider](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-mcp/1-openam-configure-oauth-provider.png)

И выберите пункт `Configure OAuth 2.0`.

![OpenAM Configure OAuth 2.0](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-mcp/2-openam-configure-oauth2.png)

В открывшейся форме можно оставить настройки по умолчанию без изменений. Нажмите `Create`.

![OpenAM Configure OAuth 2.0 Step 2](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-mcp/3-openam-configure-oauth2-step-2.png)

В настройках Realm в меню слева выберите пункт Services и откройте настройки OAuth2 Provider.

![OpenAM Realm Services](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-mcp/4-openam-realm-services.png)

В настройки `Scopes` и `Default Clients Scopes` добавьте значение `profile` . Этот scope позволит получать основную информацию о пользователе. Включите опции `Issue Refresh Tokens` и `Issue Refresh Tokens on Refreshing Access Tokens`. А также разрешите динамическую регистрацию клиентов, включив опцию `Allow Open Dynamic Client Registration`. Таким образом, MCP клиент (VS Code) сможет автоматически зарегистрироваться в OpenAM, не требуя дополнительных действий от пользователя.

Подробнее про настройку OpenAM вы можете почитать в [документации](https://doc.openidentityplatform.org/openam/).

## Настройка OpenIG

OpenIG будет отвечать за авторизацию запросов. Он будет проверять валидность выданных OpenAM `access_token`  и проксирование запросов к OpenAM и MCP серверу.

Теперь проверим настройку маршрутов OpenIG для проксирования запросов.

### Проксирование запросов к MCP серверу.

Маршрут будет получать `access_token` выданный OpenAM, переданный в заголовке `Authorization`. Если `access_token` окажется валидным, то пропускать запрос в MCP сервер и возвращать ответ. Если `access_token`  не валиден, OpenIG будет возвращать статус HTTP 401.

`openig-config/config/routes/10-mcp.json`

```json
{
   "name": "${matches(request.uri.path, '^/mcp')}",
   "condition": "${matches(request.uri.path, '^/mcp')}",
   "monitor": true,
   "timer": true,
   "handler": {
      "type": "Chain",
      "config": {
         "filters": [
            {
               "type": "OAuth2ResourceServerFilter",
               "config": {
                  "requireHttps": false,
                  "providerHandler": "ClientHandler", 
                  "scopes": [
                     "profile"
                  ],
                  "tokenInfoEndpoint": "${system['openam'].concat('/oauth2/tokeninfo')}" 
               }
            },
            {
               "type": "ConditionEnforcementFilter",
               "config": {
                  "condition": "${not empty contexts['oauth2']}",
                  "failureHandler": "RequireAuth"
               }
            }
         ],
         "handler": "EndpointHandler"
      }
   },
   "heap": [
      {
         "name": "RequireAuth",
         "type": "StaticResponseHandler",
         "config": {
            "status": 401,
            "headers": {
               "WWW-Authenticate": [
                  "Bearer realm=\"OpenIG\""
               ]
            },
            "entity": "Authentication required"
         }
      },
      {
         "name": "EndpointHandler",
         "type": "DispatchHandler",
         "config": {
            "bindings": [
               {
                  "handler": "ClientHandler",
                  "baseURI": "http://time-mcp-server:8080/mcp"
               }
            ]
         }
      }
   ]
}
```

Маршрут состоит из двух фильтров. Первый фильтр `OAuth2ResourceServerFilter` валидирует `access_token` и, при успехе, записывает данные полученные из `access_token` в контекст запроса. Второй фильтр `ConditionEnforcementFilter` проверяет контекст и при успехе пробрасывает запрос в MCP сервер. В противном случае, возвращает HTTP статус 401.

Выполним неавторизованный запрос к MCP серверу и убедимся, что OpenIG требует авторизацию.

```bash
curl -v http://openig.example.org:8081/mcp
*   Trying 127.0.0.1:8081...
* Connected to openig.example.org (127.0.0.1) port 8081 (#0)
> GET /mcp HTTP/1.1
> Host: openig.example.org:8081
> User-Agent: curl/8.1.2
> Accept: */*
> 
< HTTP/1.1 401 
< WWW-Authenticate: Bearer realm="OpenIG"
< Content-Length: 0
< Date: Mon, 22 Sep 2025 08:00:48 GMT

```

### Проксирование к конечным точкам (endpoint) `.well-known`

Согласно спецификации MCP клиент получает данные о сервере авторизации из конечных точек, расположенных по URL `<MCP server host>/.well-known/*` . Конечные расположены на OpenAM по URL `<OpenAM host>/openam/.well-known` . Маршрут проброса HTTP запросов к MCP на OpenAM выглядит следующим образом:

`openig-config/config/routes/20-well-known.json`

```json
{
  "name": "${matches(request.uri.path, '^/.well-known/.*}",
  "condition": "${matches(request.uri.path, '^/.well-known/.*')}",
  "monitor": true,
  "timer": true,
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [
        {
          "type": "HeaderFilter",
          "config": {
            "messageType": "REQUEST",
            "add": {
              "Host": [
                "${matchingGroups(system['openam'],\"(http|https):\/\/(.[^\/]*)\")[2]}"
              ]
            },
            "remove": [
              "Host",
              "Origin"
            ]
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
            "expression": "${matches(request.uri.path, '^/.well-known/openid-configuration$')}",
            "handler": "ClientHandler",
            "baseURI": "${system['openam'].concat('/oauth2/.well-known/openid-configuration')}"
          }
        ]
      }
    }
  ]
}
```

Фильтр `HeaderFilter` добавляет в HTTP заголовок Host OpenAM, указанный в системном параметре `openam` , в файле `docker-compose.yaml` а handler `EndpointHandler` пробрасывает запрос до конечной точки `/openam/.well-known/openid-configuration`, развернутой в Docker контейнере `openam`

Проверим работу endpoint:

```bash
 curl -v http://openig.example.org:8081/.well-known/openid-configuration
 
 {
   "acr_values_supported" : [],
   "authorization_endpoint" : "http://openam.example.org:8080/openam/oauth2/authorize",
   "check_session_iframe" : "http://openam.example.org:8080/openam/oauth2/connect/checkSession",
   "claims_parameter_supported" : false,
   "claims_supported" : [],
   "device_authorization_endpoint" : "http://openam.example.org:8080/openam/oauth2/device/code",
   "end_session_endpoint" : "http://openam.example.org:8080/openam/oauth2/connect/endSession",
   "id_token_encryption_alg_values_supported" : [
      "RSA-OAEP",
      "RSA-OAEP-256",
      "A128KW",
      "RSA1_5",
      "A256KW",
      "dir",
      "A192KW"
   ],
   "id_token_encryption_enc_values_supported" : [
      "A256GCM",
      "A192GCM",
      "A128GCM",
      "A128CBC-HS256",
      "A192CBC-HS384",
      "A256CBC-HS512"
   ],
   "id_token_signing_alg_values_supported" : [
      "ES384",
      "HS256",
      "HS512",
      "ES256",
      "RS256",
      "HS384",
      "ES512"
   ],
   "issuer" : "http://openam.example.org:8080/openam/oauth2",
   "jwks_uri" : "http://openam.example.org:8080/openam/oauth2/connect/jwk_uri",
   "registration_endpoint" : "http://openam.example.org:8080/openam/oauth2/connect/register",
   "response_types_supported" : [
      "code",
      "code token",
      "token"
   ],
   "scopes_supported" : [],
   "subject_types_supported" : [
      "public"
   ],
   "token_endpoint" : "http://openam.example.org:8080/openam/oauth2/access_token",
   "token_endpoint_auth_methods_supported" : [
      "client_secret_post",
      "private_key_jwt",
      "none",
      "client_secret_basic"
   ],
   "userinfo_endpoint" : "http://openam.example.org:8080/openam/oauth2/userinfo",
   "version" : "3.0"
}
```

Более подробно про настройку OpenIG вы можете почитать в [документации](https://doc.openidentityplatform.org/openig/).

## Настройка VS Code для работы с MCP сервером

У вас должны быть установлены и настроены расширения для работы с Copilot. GitHub Copilot и GitHub Copilot Chat. Как это сделать описано по ссылкe: [https://code.visualstudio.com/docs/copilot/setup](https://code.visualstudio.com/docs/copilot/setup).

Добавьте MCP сервер в VS Code.

Например, для того, чтобы добавить MCP в рабочее пространство  (workspace), создайте файл `mcp.json` в директории `.vscode` вашего рабочего пространства:

 `mcp.json`:

```json
{
  "servers": {
    "time-mcp-server": {
      "type": "http",
      "url": "http://openig.example.org:8081/mcp"
    }
  }
}
```

Другие способы добавления MCP сервера описаны по ссылкe: [https://code.visualstudio.com/docs/copilot/customization/mcp-servers#_add-an-mcp-server](https://code.visualstudio.com/docs/copilot/customization/mcp-servers#_add-an-mcp-server)

В списке расширений VS Code кликните на настройки добавленного MCP сервера и в появившемся меню нажмите `Start Server`.

![VS Code Start MCP Server](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-mcp/5-vscode-mcp-start-server.png)

Разрешите MCP серверу аутентифироваться на хосте OpenIG

![VS Code MCP Authenticate](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-mcp/6-vscode-mcp-authenticate.png)

Откроется окно браузера с аутентификацией 

![OpenAM Login](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-mcp/7-openam-login.png)

Введите логин и пароль тестового пользователя: `demo`  и `changeit` соответственно

Подтвердите доступ к данным для приложения Visual Studio Code. Если вы хотите отключить диалог подтверждения доступа к данным, включите `Allow clients to skip consent` в настройках OAuth2 Provider в OpenAM. 

![OpenAM OAuth2 Consent](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-mcp/8-openam-oauth2-consent.png)

После подтверждения, вас перенаправит обратно в VS Code.

Откройте чат c Github Copilot. Для этого в меню команд выберите **Show and Run Commands**:

![OpenAM Run Commands](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-mcp/9-openam-run-commands.png)

И далее выберите **Chat: New Chat**:

![OpenAM New Chat](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-mcp/10-copilot-new-chat.png)

В открывшемся чате введите вопрос: `What is the current time?` . Сopilot ответит, что у него нет доступа к текущему времени:

![OpenAM Time Request](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-mcp/11-copolot-time-request.png)

Теперь внизу переключите чат на режим агента (Agent) и задайте вопрос повторно

![Copilot Set the Agent Mode](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-mcp/12-copulot-set-agent-mode.png)

Разрешите доступ к функции получения текущего времени в MCP сервере

![Copilot Allow MCP Call](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-mcp/13-copilot-allow-mcp-call.png)

Copilot получит информацию о текущем времени от MCP сервера и вернет корректный ответ.

![Copilot Successful response](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-mcp/14-copilot-successful-response.png)

## Заключение

В этой статье мы продемонстрировали практическую интеграцию OpenAM и OpenIG для обеспечения безопасного доступа к MCP-серверу на основе OAuth 2.1. OpenAM выступает надежным центром аутентификации и авторизации, выдавая и валидируя токены, в то время как OpenIG фильтрует запросы, блокируя несанкционированный доступ и проксируя трафик к защищенным ресурсам. Такой подход минимизирует риски утечек чувствительных данных — от внутренних репозиториев до клиентских баз.

Скачайте исходный код с GitHub, протестируйте конфигурацию и интегрируйте в свои проекты. Для углубленного изучения обратитесь к официальной документации: [OpenAM](https://doc.openidentityplatform.org/openam/) и [OpenIG](https://doc.openidentityplatform.org/openig/).