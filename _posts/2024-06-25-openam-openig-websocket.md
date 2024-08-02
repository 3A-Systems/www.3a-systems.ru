---
layout: blog
title: 'Как защитить WebSocket соединение при помощи OpenAM и OpenIG'
description: 'В этой статье мы добавим авторизацию на WebSocket соединение через OpenIG, используя аутентификацию OpenAM. Для упрощения установки и развертывания сервисов, мы будем использовать Docker и Docker Compose.'
tags: 
  - openam
  - openig

---

Данная статья является продолжением предыдущей статьи [How to Add Authorization and Protect Your Application With OpenAM and OpenIG Stack](https://github.com/OpenIdentityPlatform/OpenAM/wiki/How-to-Add-Authorization-and-Protect-Your-Application-With-OpenAM-and-OpenIG-Stack). Предыдущая статья описывала, как защитить конечные точки приложение, работающие по стандартному HTTP протоколу. В этой статье мы добавим авторизацию на WebSocket соединение через OpenIG, используя аутентификацию OpenAM. Для упрощения установки и развертывания сервисов, мы будем использовать Docker и Docker Compose.

## Демонстрационный WebSocket сервер

Для проверки WebSocket соединения мы будем использовать демонстрационный [echo-server](https://hub.docker.com/r/jmalloc/echo-server). Чтобы запустить сервис в Docker, создайте `docker-compose.yaml` файл и добавьте в него echo-server.

```yaml
services:
  echo-server:
    image: jmalloc/echo-server
    restart: always
    ports:  
        - "8082:8080"
    networks:
      openam_network:
        aliases:
          - echo-server
networks:
  openam_network:
    driver: bridge
```

Выполните команду `docker compose up` и, после того, как сервер будет запущен, вы увидите в консоли сообщение:

```
Echo server listening on port 8080.
```

## Конфигурация OpenIG

Настроим OpenIG таким образом, чтобы шлюз возвращал статическую HTML страницу для работы с WebSocket соединением.

Создайте папку `openig-config` , перейдите в нее и создайте два файла: `admin.json` и `config.json` со следующим содержимым:

`admin.json` :

```json
{
  "prefix" : "openig",
  "mode": "PRODUCTION"
}
```

`config.json` :

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

Добавим в OpenIG статическую HTML страницу с UI для проверки работы с WebSocket. В папке `openig-config` создайте директорию `static` и в ней создайте файл `ws-client.html` со следующим содержимым:

```html
<!DOCTYPE html>
<html lang='en'>
<head>
    <meta charset='UTF-8'>
    <title>WS-Client</title>
    <style>
        #log p {
            margin: 0;
        }
        #log p.error {
            color: red;
        }
    </style>
</head>
<body>
  <div>
    <h1>WS-Client</h1>
      <button id='connect' type='button'>Connect</button>
      &nbsp;
      <button id='send' type='button'>Send Message</button>
      <br>
      <label for='log'>Log:</label>
      <div id='log'></div>
  </div>
  <script>
      const connectBtn = document.getElementById('connect');
      connectBtn.onclick = connect;
      let socket;
      function connect() {
          appendToConsole('connecting...')
          const endpoint = 'ws://' + location.host + '/ws-handler';
          socket = new WebSocket(endpoint);
          socket.onmessage = function(event) {
              appendToConsole('got response message from server: ' + event.data);
          };
          socket.onopen = function () {
              appendToConsole('connected')
          };
          socket.onerror = function (e) {
              appendToConsole('socket error occurred', true);
          }
          socket.onclose = function () {
              appendToConsole('socket connection closed')
          }
      }

      const sendBtn = document.getElementById('send');
      sendBtn.onclick = function () {
          if(socket.readyState !== WebSocket.OPEN) {
              appendToConsole('socket is not open', true);
              return;
          }
          appendToConsole('sending message...');
          try {
              socket.send('Test message');
          } catch (e) {
              appendToConsole('error sending message: ' + e.message, true)
          }
      }

      function appendToConsole(message, error) {
          let className = '';
          if (error) {
              console.error(message);
              className = 'error';
          } else {
              console.log(message);
          }
          const log = document.getElementById('log');
          const p = document.createElement('p');
          p.innerText = message;
          p.className = className;
          log.append(p)
      }
  </script>
</body>
</html> 
```

Добавьте маршруты OpenIG для конечных точек UI и WebSocket. Создайте папку `routes` внутри папки `openig-config`. Внутри папки `routes` создайте два файла маршрута `10-ui.json` для UI и `10-websocket.json` для работы WebSocket, соответственно.

`10-ui.json` :

```json
{
    "name": "${matches(request.uri.path, '^/ui')}",
    "condition": "${matches(request.uri.path, '^/ui')}",
    "monitor": true,
    "timer": true,
    "handler": {
       "type": "Chain",
       "config": {
          "filters": [],
          "handler": "WSClient"
       }
    },
    "heap": [
       {
         "name": "WSClient",
         "type":"StaticResponseHandler",
         "config": {
            "status": 200,
            "entity": "${read(system['openig.base'].concat('/config/static/ws-client.html'))}"
         }
       }
    ]
 }
```

`10-websocket.json`:

```json
{
  "name": "${matches(request.uri.path, '^/ws-handler')}",
  "condition": "${matches(request.uri.path, '^/ws-handler')}",
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
                "${matchingGroups(system['ws.secured'],\"(http|https):\/\/(.[^\/]*)\")[2]}"
              ]
            },
            "remove": [
              "Sec-Websocket-Key",
              "Sec-Websocket-Version",
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
            "handler": "ClientHandler",
            "capture": "all",
            "baseURI": "${system['ws.secured']}"
          }
        ]
      }
    }
  ]
}
```

Обратите внимание, что в маршруте из исходного запроса удаляются HTTP заголовки для корректной установки соединения от инстанса OpenIG до защищаемого сервиса `echo-server` . 

Добавьте сервис OpenIG в файл `docker-compose.yml` :

```yaml
...
    openig:
    image: openidentityplatform/openig:latest
    build: .
    volumes:
      - ./openig-config:/usr/local/openig-config/config:ro
    ports:  
      - "8081:8080"
      - "8000:8000"
    environment:
      CATALINA_OPTS: -Dopenig.base=/usr/local/openig-config -Dsecured=http://echo-server:8080 -Dopenam=http://openam.example.org:8080/openam -Dws.secured=ws://echo-server:8080 -Dorg.openidentityplatform.openig.websocket.ttl=180
    networks:
      openam_network:
        aliases:
          - openig.example.org
...
```

Системные свойства из конфигурации выше:

| Свойство | Описание |
| --- | --- |
| secured | URL HTTP сервиса |
| ws.secured | URL WebSocket сервиса |
| openam | URL OpenAM (настройка будет использована в следующих разделах) |
| org.openidentityplatform.openig.websocket.ttl | Периодичность проверки валидности сессии в секундах |

Запустите сервисы командой `docker compose up` . После того, как Docker контейнеры с OpenIG и echo-server запущены, откройте в браузере URL [http://localhost:8080/ui](http://localhost:8080/ui) . Вы сможете установить WebSocket соединение и все взаимодействие будет происходить через OpenIG.

## Конфигурация OpenAM

Добавим аутентификацию через OpenAM в наш стек. Добавьте сервис OpenAM в файл `docker-compose.yaml`

```yaml
...
  openam:
    image: openidentityplatform/openam
    ports:  
      - "8080:8080"
    networks:
      openam_network:
        aliases:
          - openam.example.org
...

```

Добавьте имена хостов OpenAM и OpenIG в файл `hosts`, например `127.0.0.1 openam.example.org openig.example.org` .

В Windows системах файл `hosts` находится по адресу `C:\Windows\System32\drivers\etc\hosts` , в Linux и Mac находится по адресу `/etc/hosts`.

Запустите сервисы командой `docker compose up` , установите OpenAM, настройе cookie domain и добавьте jwt endpoint как описано в статье  [How to Add Authorization and Protect Your Application With OpenAM and OpenIG Stack](https://github.com/OpenIdentityPlatform/OpenAM/wiki/How-to-Add-Authorization-and-Protect-Your-Application-With-OpenAM-and-OpenIG-Stack#openam-installation) .

Добавьте фильтр валидации токена OpenAM в файл маршрута OpenIG `10-websocket.json`

```json
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
        "status": 401,
        "reason": "Found",
        "headers": {
          "Content-Type": [
            "application/json"
          ],
        },
        "entity": "{ \"Error\": \"Unauthorized\"}"
      }
    }
  }
}
```

Добавленные три фильтра делают следующее: Первый фильтр конвертирует токен OpenAM в JWT и устанавливает его в контекст запроса. Второй фильтр добавляет JWT в запрос к защищаемому сервису. Третий фильтр проверяет, что в контексте запроса есть токен JWT, и, если его нет, возвращает клиенту 401 ошибку.

## Проверка решения

Откройте в браузере URL  [http://openig.example.org:8081/ui](http://openig.example.org:8081/ui) и нажмите кнопку `Connect` . Вы увидите ошибку соединения.

```
Log:
connecting...
socket error occurred
socket connection closed
```

Откройте еще одну вкладку в браузере и откройте URL OpenAM  [http://openam.example.org:8080/openam](http://openam.example.org:8080/openam).  Аутентифицируйтесь в OpenAM. Для входа можете использовать логин `demo` пароль `changeit`. Вернитесь на вкладку с URL [http://openig.example.org:8081/ui](http://openig.example.org:8081/ui) и попробуйте соединиться снова. Вы увидете следующее:

```
connecting...
connected
```

Нажмите кнопку `Send Message` . Вы должны увидеть следующие сообщения:

```
sending message...
got response message from server: Test message
```

Выйдите из OpenAM и вернитесь на вкладку  [http://openig.example.org:8081/ui](http://openig.example.org:8081/ui). Подождите 3 минуты (как указано в настройке `org.openidentityplatform.openig.websocket.ttl`) и попробуйте отправить сообщение снова. Вы увидите:

```
sending message...
socket connection closed
```

![Sample Service WebSocket UI and OpenAM](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIG/images/openam-openig-websocket/sample-service-ws-ui-openam.png)