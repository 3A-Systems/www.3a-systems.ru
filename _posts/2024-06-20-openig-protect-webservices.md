---
layout: blog
title: 'Как защитить веб сервисы при помощи шлюза OpenIG'
description: 'Обеспечение безопасности веб сервисов — одна из важных частей процесса разработки. Если если в инфраструктуре несколько сервисов, то каждый из них должен быть должным образом защищен. Если реализовывать проверки политик безопасности в каждом сервисе, то затраты на разработку и поддержку таких сервисов существенно возрастают. При этом не избежать дублирования кода и ошибок разработки. Поэтому, управление защитой сервисов должно быть централизованным. Далее мы рассмотрим, как организовать централизованную защиту приложений на примере API-шлюза с открытым исходным кодом OpenIG, а так же добавим проверку авторизации доступа с JWT токеном'
tags: 
  - openig

---

Обеспечение безопасности веб сервисов — одна из важных частей процесса разработки. Если если в инфраструктуре несколько сервисов, то каждый из них должен быть должным образом защищен. Если реализовывать проверки политик безопасности в каждом сервисе, то затраты на разработку и поддержку таких сервисов существенно возрастают. При этом не избежать дублирования кода и ошибок разработки. Поэтому, управление защитой сервисов должно быть централизованным. Далее мы рассмотрим, как организовать централизованную защиту приложений на примере API-шлюза с открытым исходным кодом [OpenIG](https://github.com/OpenIdentityPlatform/OpenIG), а так же добавим проверку авторизации доступа с JWT токеном

Исходный код для статьи https://github.com/maximthomas/openig-protect-ws/

# Демонстрационный сервис

Пусть у нас есть сервис, разработанный на Spring Boot, с двумя endpoint `/` — публичной и `/secure` — приватной, доступ к которой могут иметь только аутентифицированные пользователи.

Пример сервиса:

```java
package org.openidentityplatform.sampleservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.servlet.http.HttpServletRequest;
import java.util.Collections;
import java.util.Map;

@SpringBootApplication
public class SampleServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(SampleServiceApplication.class, args);
    }

    @RestController
    public class IndexController {
        @RequestMapping("/")
        public Map<String, String> index() {
            return Collections.singletonMap("hello", "world");
        }

        @RequestMapping("/secure")
        public Map<String, String> secure(HttpServletRequest request) {
            return Collections.singletonMap("hello", request.getHeader("X-Auth-Username"));
        }
    }
}
```

## Запуск демонстрационного сервиса

Создайте `docker-compose.yaml` файл и добавьте в него демонстрационный сервис:

```yaml
services:
  sample-service:
		image: maximthomas/sample-service
    restart: always
```

Демонстрационный сервис будет работать без доступа из внешней сети. Далее мы добавим Docker контейнер со шлюзом OpenIG, который будет валидировать запросы и проксировать их до демонстрационного сервиса

# Настройка OpenIG

Создайте директорию с конфигурацией OpenIG - `openig-config` в этой папке создайте еще одну директорию `config` . В папке `openig-config/config` создайте 2 файла конфигурации:

`admin.json`

```json
{
  "prefix" : "openig",
  "mode": "PRODUCTION"
}
```

 и `config.json`

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
        "capture": "all"
      }
    }
  }
}
```

Добавьте сервис OpenIG в файл `docker-compose.yaml` Смонтируйте папку конфигурации `openig-config` к Docker контейнеру OpenIG. Значение системной опции  `-Dopenig.base` должно указывать на смонтированную в контейнере директорию.

```yaml
services:
  sample-service:
    build:
      context: ./sample-service
    restart: always

  #OpenIG service
  openig:
    image: openidentityplatform/openig:latest
    restart: always
    volumes:
      - ./openig-config:/usr/local/openig-config
    environment:
      #OpenIG options
      CATALINA_OPTS: -Dopenig.base=/usr/local/openig-config
    ports:
      - "8080:8080"
```

## Проксирование запросов к сервису

Настроим проксирование запросов через OpenIG к демонстрационному сервису. Добавьте системную настройку `-Dendpoint.api`. Она будет указывать на URL демонстрационного сервиса и будет использоваться в настройках маршрутов OpenIG. Вы, конечно, можете прописать конечные точки непосредственно в маршруте, но, использование системных опций является рекомендуемым подходом.

`docker-compose.yaml`:

```yaml
...
  openig:
    image: openidentityplatform/openig:latest
    restart: always
    volumes:
      - ./openig-config:/usr/local/openig-config
    environment:
      #OpenIG options
      CATALINA_OPTS: -Dopenig.base=/usr/local/openig-config -Dendpoint.api=http://sample-service:8080/
    ports:
      - "8080:808
```

 Добавьте маршрут, который будет проксировать запросы на сервис. Создайте папку `routes` с маршрутами в директории  `openig-config/config/`. И добавьте в нее файл конфигурации маршрута

`10-api.json`

```json
{
  "name": "${matches(request.uri.path, '^/')}",
  "condition": "${matches(request.uri.path, '^/')}",
  "monitor": true,
  "timer": true,
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [

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
            "baseURI": "${system['endpoint.api']}"
          }
        ]
      }
    }
  ]
}
```

Такой маршрут проксирует все запросы на демонстрационный сервис из возвращает ответы без каких либо проверок.

Добавьте маршрут по умолчанию, который будет возвращать 404 статус на все остальные запросы

`99-default.json`:

```json
{
  "name": "99-default",
  "handler": {
    "type": "StaticResponseHandler",
    "config": {
      "status": 404,
      "reason": "Not Found",
      "headers": {
        "Content-Type": [ "application/json" ]
      },
      "entity": "{ \"error\": \"Not Found\"}"
    }
  },
  "audit": "/404"
}
```

Запустим демо сервис и OpenIG в Docker контейнерах:

```bash
docker-compose up
```

После запуска проверим работоспособность

```bash
curl -v -X GET http://localhost:8080/
Note: Unnecessary use of -X or --request, GET is already inferred.
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Connected to localhost (127.0.0.1) port 8080 (#0)
> GET / HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/7.58.0
> Accept: */*
>
< HTTP/1.1 200 OK
< Server: Apache-Coyote/1.1
< Date: Wed, 24 Apr 2019 15:06:17 GMT
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
<
* Connection #0 to host localhost left intact
{"hello":"world"}

curl -v -X GET http://localhost:8080/secure
Note: Unnecessary use of -X or --request, GET is already inferred.
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Connected to localhost (127.0.0.1) port 8080 (#0)
> GET /secure HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/7.58.0
> Accept: */*
>
< HTTP/1.1 200 OK
< Server: Apache-Coyote/1.1
< Date: Wed, 24 Apr 2019 15:04:49 GMT
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
<
* Connection #0 to host localhost left intact
{"name":null}
```

После настройки проксирования запросов, давайте обеспечим безопасность демонстрационного сервиса

# Защита сервиса

Для примера возьмем [рекомендации OWASP](https://github.com/OWASP/CheatSheetSeries/blob/master/cheatsheets/REST_Security_Cheat_Sheet.md) по защите REST сервисов. 

## Ограничение методов HTTP

Добавим возможность пропускать к сервису только GET и POST запросы. Добавим в маршрут `10-api.json` фильтр `SwitchFilter`

```json
{
  "name": "${matches(request.uri.path, '^/')}",
  "condition": "${matches(request.uri.path, '^/')}",
  "monitor": true,
  "timer": true,
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [
        {
          "type": "SwitchFilter",
          "config": {
            "onRequest": [
              {
                "condition": "${request.method != 'POST' and request.method != 'GET'}",
                "handler": {
                  "type": "StaticResponseHandler",
                  "config": {
                    "status": 405,
                    "reason": "Method not allowed",
                    "headers": {
                      "Content-Type": [
                        "application/json"
                      ]
                    },
                    "entity": "{ \"error\": \"Method not allowed\"}"
                  }
                }
              }
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
            "baseURI": "${system['endpoint.api']}"
          }
        ]
      }
    }
  ]
}
```

Проверим, что если запрос не GET и не POST шлюз вернет статус 405:

```bash
$ curl -v -X PUT http://localhost:8080/
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Connected to localhost (127.0.0.1) port 8080 (#0)
> PUT / HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/7.58.0
> Accept: */*
>
< HTTP/1.1 405 Method Not Allowed
< Server: Apache-Coyote/1.1
< Content-Type: application/json
< Content-Length: 32
< Date: Wed, 24 Apr 2019 15:13:04 GMT
<
* Connection #0 to host localhost left intact
{ "error": "Method not allowed"}

```

## Проверка заголовка запроса Content-Type

Пусть для демонстрационного сервиса будут допустимы `POST` запросы только с `Content-Type: application/json` . Для этого добавьте в `SwitchFilter` проверку заголовка `Content-Type`

`10-api.json`:

```json
...
      {
          "type": "SwitchFilter",
          "config": {
            "onRequest": [
              {
                "condition": "${request.method != 'POST' and request.method != 'GET'}",
                "handler": {
                  "type": "StaticResponseHandler",
                  "config": {
                    "status": 405,
                    "reason": "Method not allowed",
                    "headers": {
                      "Content-Type": [
                        "application/json"
                      ]
                    },
                    "entity": "{ \"error\": \"Method not allowed\"}"
                  }
                }
              },
              {
                "condition": "${request.method == 'POST' and request.headers['Content-Type'][0].split(';')[0] != 'application/json'}",
                "handler": {
                  "type": "StaticResponseHandler",
                  "config": {
                    "status": 415,
                    "reason": "Unsupported Media Type",
                    "headers": {
                      "Content-Type": [ "application/json" ]
                    },
                    "entity": "{ \"error\": \"Unsupported Media Type\"}"
                  }
                }
              }
            ]
          }
        }
...        
```

Проверим, что ограничение работает для `Content-Type: application/xml`

```bash
$ curl -v -X POST -H 'Content-Type: application/xml' http://localhost:8080/
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Connected to localhost (127.0.0.1) port 8080 (#0)
> POST / HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/7.58.0
> Accept: */*
> Content-Type: application/xml
>
< HTTP/1.1 415 Unsupported Media Type
< Server: Apache-Coyote/1.1
< Content-Type: application/json
< Content-Length: 36
< Date: Wed, 24 Apr 2019 15:21:04 GMT
<
* Connection #0 to host localhost left intact
{ "error": "Unsupported Media Type"}
```

## Проверка совпадения заголовков Accept запроса и Content-Type ответа

Значение заголовка `Content-Type` ответа должно совпадать со значением заголовка `Accept` запроса. Добавьте условие проверки в объект `config` фильтра `SwitchFilter` маршрута:

`10-api.json`:

```json
...
          "onResponse" : [
              {
                "condition" : "${response.headers['Content-Type'][0].split(';')[0] != request.headers['Accept'][0].split(';')[0] }",
                "handler": {
                  "type": "StaticResponseHandler",
                  "config": {
                    "status": 406,
                    "reason": "Not Acceptable",
                    "headers": {
                      "Content-Type": [ "application/json" ]
                    },
                    "entity": "{ \"error\": \"Not Acceptable\"}"
                  }
                }
              }
            ]
...            

```

Проверим запрос с заголовком `Accept: application/xml`

```json
curl -v -X POST -H 'Content-Type: application/json' -H 'Accept: application/xml'  http://localhost:8080/
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Connected to localhost (127.0.0.1) port 8080 (#0)
> POST / HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/7.58.0
> Content-Type: application/json
> Accept: application/xml
>
< HTTP/1.1 406 Not Acceptable
< Server: Apache-Coyote/1.1
< Content-Type: application/json
< Content-Length: 28
< Date: Wed, 24 Apr 2019 15:28:54 GMT
<
* Connection #0 to host localhost left intact
{ "error": "Not Acceptable"}
```

## Добавление заголовков безопасности **X-Frame-Options и X-Content-Type-Options**

OpenIG должен возвращать клиенту заголовки `X-Frame-Options: deny` и `X-Content-Type-Options: nosniff`, чтобы предотвратить MIME sniffing, XSS и drag'n drop clickjacking атаки. Для этого добавьте `HeaderFilter` в цепочку фильтров после `SwitchFilter`:

`10-api.json`:

```json
{
  "type": "HeaderFilter",
  "comment": "Add security headers to response",
  "config": {
    "messageType": "response",
    "add": {
      "X-Frame-Options": [ "deny" ],
      "X-Content-Type-Options": [ "nosniff" ]
    }
  }
}
```

Проверим заголовки ответа:

```bash
curl -v -X POST -H 'Content-Type: application/json' -H 'Accept: application/json'  http://localhost:8080/
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Connected to localhost (127.0.0.1) port 8080 (#0)
> POST / HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/7.58.0
> Content-Type: application/json
> Accept: application/json
>
< HTTP/1.1 200 OK
< Server: Apache-Coyote/1.1
< Date: Wed, 24 Apr 2019 15:31:31 GMT
< X-Content-Type-Options: nosniff
< X-Frame-Options: deny
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
<
* Connection #0 to host localhost left intact
{"hello":"world"}
```

# Проверка аутентификации и авторизации

Если вам нужно защитить сервис от не аутентифицированного доступа, нет необходимости реализовывать проверку аутентификации для каждого сервиса. Вы можете проверить доступ непосредственно на OpenIG. И если запрос аутентифицирован, обогатить запрос заголовком информацией об учетной записи. Например, сервис аутентификации возвращает клиенту подписанный [JSON Web Token](https://en.wikipedia.org/wiki/JSON_Web_Token) (JWT) и шлюз использует переданный клиентом JWT для авторизации доступа к сервису. В конфигурации OpenIG лежит публичный ключ и OpenIG проверяет подпись JWT с этим ключом, для того, чтобы удостовериться в подлинности JWT.

Сгенерируйте пару ключей

Публичный 

```bash
openssl genrsa -out private_key.pem 4096
```

И приватный 

```bash
openssl rsa -pubout -in private_key.pem -out public_key.pem
```

Уже сгенерированные ключи лежат в GitHub репозитории [https://github.com/maximthomas/openig-protect-ws/tree/master/openig-config/keys](https://github.com/maximthomas/openig-protect-ws/tree/master/openig-config/keys)

Сгенерируйте JWT при помощи сайта [https://jwt.io](https://jwt.io/) и сгенерированного приватного ключа `private_key.pem`

Пример JWT:

```bash
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzYW1wbGUtc2VydmljZSIsInN1YiI6IjEyMzQ1Njc4OTAiLCJuYW1lIjoiSm9obiBEb2UiLCJyb2xlIjoibWFuYWdlciIsImlhdCI6MTUxNjIzOTAyMiwiZXhwIjoxNzI2MjM5MDIyfQ.bhzhwj2cY1iYbpx7Mzbukfi1jOCvWP-Pdd9dm3hf7lZDDuokNVDUXU3jvHial4QN-bOTSNCUKVy907hokcVeQaFwbiYoZs485Kr230Z0y9MU6zbDe8yQp68-71TDgJGIZ78YYOKvJTrzCWgWgE_Py1DskG_ViSxfGFlETpFQa056Rk2bty-9iuc_Cx5_Wr6RCcJTG6WYRrBtdWGIFxljEjxSAcJYmGPPA8dHHORDOnmka2OAjWURnsqbz50aI_SrWpnqp4i2eXVA1b5QD5rlsgc_QAqJptghrijBlRPhasTk1N-kXE8Ozboa0FwGfIRr7gNiG-3if7INZe2R5NUCmjlAlywcSfOunWuSzY8tLGTHV2swnQPP8lBXwVJcS5nJMqBNIbcLcFWHk3ryvvtf-LYty_jAY8v1zDe9-DwFPWI0rry8fmiZj7yhAnvX5EHZHvSQtp_zyPpVWvOXFPwasI0jdKoxhWvyJpbmw-D95J5CgJAMfkrWPDQKVt3ipebwnMJStA3xAPPyl28mTBYhJrT6gzIOS3DseoVKK4adn34ZrQi2Hm-wyUtbdulopK739MKM73NYgoFXSJeVUqcy4iw3-In5XmOhdRnUL50TSiaNBbkys8iK7r00HD3kI3CH0GfaPdrcgRgaFXKmVDhX-tEaPJYcuEUTHfQAxWwMdiw
```

## Проверка JWT в OpenIG

Добавим проверку аутентификации для конечно точки `/secured` демонстрационного сервиса. Для этого добавим еще один `SwitchFilter` , который, в свою очередь, вызовет обработчик`Chain` если целевая конечная точка является `secured` . Добавьте в обработчик `Chain` фильтр `ScriptableFilter` , который будет проверять валидность JWT и обогащать запрос идентификатором учетной записи из JWT.

`10-api.json`:

```json
...
        {
          "type": "SwitchFilter",
          "config": {
            "onRequest": [
              {
                "condition": "${matches(request.uri.path, '^/secure')}",
                "handler": {
                  "type": "Chain",
                  "config": {
                    "filters": [
                      {
                        "type": "ScriptableFilter",
                        "config": {
                          "type": "application/x-groovy",
                          "file": "jwt.groovy",
                          "args": {
                            "iss": {
                              "sample-service": "${read('/usr/local/openig-config/keys/public_key.pem')}"
                            }
                          }
                        }
                      }
                    ],
                    "handler": "EndpointHandler"
                  }
                }
              }
            ]
          }
        }
...        
```

Добавьте файл `jwt.groovy` в папку  `/openig-config/scripts/groovy/` . Скрипт проверяет подпись, и, если подпись верна, проверяет срок истечения JWT.  Если JWT валиден, скрипт обогащает запрос заголовком `X-Auth-Username` из поля `name` полезной нагрузки JWT. В противном случае возвращается 401 статус HTTP.

`jwt.groovy`:

```groovy
import java.security.KeyFactory
import org.forgerock.json.jose.builders.JwtBuilderFactory
import org.forgerock.json.jose.jws.SignedJwt
import org.forgerock.json.jose.jws.SigningManager
import org.forgerock.http.protocol.Status
import java.security.spec.X509EncodedKeySpec

//extract jwt from request header
def jwt = request.headers['Authorization']?.firstValue

if (jwt!=null && jwt.startsWith("Bearer eyJ")) {
    jwt=jwt.replace("Bearer ", "")

    try {
        //parse jwt
        def sjwt=new JwtBuilderFactory().reconstruct(jwt, SignedJwt.class)

        //verify jwt signature
        if (!sjwt.verify(new SigningManager().newRsaSigningHandler(getKey(sjwt.getClaimsSet())))) {
            throw new Exception("invalid signature")
        }

        //check jwt expiration
        if ((sjwt.getClaimsSet().getExpirationTime()!=null && sjwt.getClaimsSet().getExpirationTime().before(new Date()))) {
            throw new Exception("signature expired "+sjwt.getClaimsSet().getExpirationTime())
        }

        //add name from JWT claim to header
        request.headers.put('X-Auth-Username', sjwt.getClaimsSet().getClaim("name"))

        return next.handle(new org.forgerock.openig.openam.StsContext(context, jwt), request)
    } catch(Exception e) {
        e.printStackTrace();
        return getErrorResponse(Status.UNAUTHORIZED, e.getMessage())
    }
} else {
    //returns 401 status if JWT not present in request
    return getErrorResponse(Status.UNAUTHORIZED, "Not Authenticated")
}

return next.handle(context, request)

def getErrorResponse(status, message) {
    def response = new Response()
    response.status = status
    response.headers['Content-Type'] = "application/json"
    response.setEntity("{'error' : '" + message + "'}")
    return response
}

def getKey(claims) {
    def pem=iss[claims.getIssuer()]
    if (pem != null) {
        def pemReplaced = pem.replaceFirst("(?m)(?s)^---*BEGIN.*---*\$(.*)^---*END.*---*\$.*", "\$1")
        byte[] encoded = Base64.getMimeDecoder().decode(pemReplaced)
        def kf = KeyFactory.getInstance("RSA")
        def pubKey = kf.generatePublic(new X509EncodedKeySpec(encoded))
        println 'got pub key' + pubKey
        return pubKey
    }

    throw new Exception('Unknown issuer')
}

```

Проверим запрос c валидным JWT:

```bash
curl -v GET -H 'Content-Type: application/json' -H 'Accept: application/json' -H 'Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzYW1wbGUtc2VydmljZSIsInN1YiI6IjEyMzQ1Njc4OTAiLCJuYW1lIjoiSm9obiBEb2UiLCJyb2xlIjoibWFuYWdlciIsImlhdCI6MTUxNjIzOTAyMiwiZXhwIjoxNzI2MjM5MDIyfQ.bhzhwj2cY1iYbpx7Mzbukfi1jOCvWP-Pdd9dm3hf7lZDDuokNVDUXU3jvHial4QN-bOTSNCUKVy907hokcVeQaFwbiYoZs485Kr230Z0y9MU6zbDe8yQp68-71TDgJGIZ78YYOKvJTrzCWgWgE_Py1DskG_ViSxfGFlETpFQa056Rk2bty-9iuc_Cx5_Wr6RCcJTG6WYRrBtdWGIFxljEjxSAcJYmGPPA8dHHORDOnmka2OAjWURnsqbz50aI_SrWpnqp4i2eXVA1b5QD5rlsgc_QAqJptghrijBlRPhasTk1N-kXE8Ozboa0FwGfIRr7gNiG-3if7INZe2R5NUCmjlAlywcSfOunWuSzY8tLGTHV2swnQPP8lBXwVJcS5nJMqBNIbcLcFWHk3ryvvtf-LYty_jAY8v1zDe9-DwFPWI0rry8fmiZj7yhAnvX5EHZHvSQtp_zyPpVWvOXFPwasI0jdKoxhWvyJpbmw-D95J5CgJAMfkrWPDQKVt3ipebwnMJStA3xAPPyl28mTBYhJrT6gzIOS3DseoVKK4adn34ZrQi2Hm-wyUtbdulopK739MKM73NYgoFXSJeVUqcy4iw3-In5XmOhdRnUL50TSiaNBbkys8iK7r00HD3kI3CH0GfaPdrcgRgaFXKmVDhX-tEaPJYcuEUTHfQAxWwMdiw' http://localhost:8080/secure 
* Could not resolve host: GET
* Closing connection 0
curl: (6) Could not resolve host: GET
*   Trying 127.0.0.1:8080...
* Connected to localhost (127.0.0.1) port 8080 (#1)
> GET /secure HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/8.1.2
> Content-Type: application/json
> Accept: application/json
> Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzYW1wbGUtc2VydmljZSIsInN1YiI6IjEyMzQ1Njc4OTAiLCJuYW1lIjoiSm9obiBEb2UiLCJyb2xlIjoibWFuYWdlciIsImlhdCI6MTUxNjIzOTAyMiwiZXhwIjoxNzI2MjM5MDIyfQ.bhzhwj2cY1iYbpx7Mzbukfi1jOCvWP-Pdd9dm3hf7lZDDuokNVDUXU3jvHial4QN-bOTSNCUKVy907hokcVeQaFwbiYoZs485Kr230Z0y9MU6zbDe8yQp68-71TDgJGIZ78YYOKvJTrzCWgWgE_Py1DskG_ViSxfGFlETpFQa056Rk2bty-9iuc_Cx5_Wr6RCcJTG6WYRrBtdWGIFxljEjxSAcJYmGPPA8dHHORDOnmka2OAjWURnsqbz50aI_SrWpnqp4i2eXVA1b5QD5rlsgc_QAqJptghrijBlRPhasTk1N-kXE8Ozboa0FwGfIRr7gNiG-3if7INZe2R5NUCmjlAlywcSfOunWuSzY8tLGTHV2swnQPP8lBXwVJcS5nJMqBNIbcLcFWHk3ryvvtf-LYty_jAY8v1zDe9-DwFPWI0rry8fmiZj7yhAnvX5EHZHvSQtp_zyPpVWvOXFPwasI0jdKoxhWvyJpbmw-D95J5CgJAMfkrWPDQKVt3ipebwnMJStA3xAPPyl28mTBYhJrT6gzIOS3DseoVKK4adn34ZrQi2Hm-wyUtbdulopK739MKM73NYgoFXSJeVUqcy4iw3-In5XmOhdRnUL50TSiaNBbkys8iK7r00HD3kI3CH0GfaPdrcgRgaFXKmVDhX-tEaPJYcuEUTHfQAxWwMdiw
> 
< HTTP/1.1 200 
< Date: Wed, 19 Jun 2024 08:59:06 GMT
< X-Content-Type-Options: nosniff
< X-Frame-Options: deny
< Content-Type: application/json
< Transfer-Encoding: chunked
< 
* Connection #1 to host localhost left intact
{"hello":"John Doe"}
```

Запрос без JWT:

```bash
curl -v GET -H 'Content-Type: application/json' -H 'Accept: application/json'  http://localhost:8080/secure
* Could not resolve host: GET
* Closing connection 0
curl: (6) Could not resolve host: GET
*   Trying 127.0.0.1:8080...
* Connected to localhost (127.0.0.1) port 8080 (#1)
> GET /secure HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/8.1.2
> Content-Type: application/json
> Accept: application/json
> 
< HTTP/1.1 401 
< X-Content-Type-Options: nosniff
< X-Frame-Options: deny
< Content-Type: application/json
< Content-Length: 31
< Date: Wed, 19 Jun 2024 08:59:43 GMT
< 
* Connection #1 to host localhost left intact
{'error' : 'Not Authenticated'}
```

## Проверка авторизации

Настроим OpenIG таким образом, чтобы он авторизовывал доступ доступ только пользователям с ролью `manager` . Роль будем брать claim JWT `role`. Если в JWT роль отсутствует или отлична от `manager`, вернем HTTP статус 403 Forbidden.

Добавим в маршрут в фильтр `ScriptableFilter` параметр `allowedRole`, чтобы можно было устанавливать допустимую роль в маршруте, не меняя скрипт.

```json
...
{
  "type": "ScriptableFilter",
  "config": {
    "type": "application/x-groovy",
    "file": "jwt.groovy",
    "args": {
      "iss": {
        "sample-service": "${read('/usr/local/openig-config/keys/public_key.pem')}"                              
      },
      "allowedRole": "manager"
    }
  }
}
...
```

Добавим в `jwt.groovy` проверку роли после проверки срока действия:

```groovy
//check jwt expiration
if ((sjwt.getClaimsSet().getExpirationTime()!=null && sjwt.getClaimsSet().getExpirationTime().before(new Date()))) {
    throw new Exception("signature expired "+sjwt.getClaimsSet().getExpirationTime())
}

//check role
 if (!sjwt.getClaimsSet().keys().contains("role") 
    || !allowedRole.equals(sjwt.getClaimsSet().getClaim("role", String.class))) {
     return getErrorResponse(Status.FORBIDDEN, "Forbidden")            
}
```

Проверим запрос с валидным JWT

```bash
curl -v GET -H 'Content-Type: application/json' -H 'Accept: application/json' -H 'Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzYW1wbGUtc2VydmljZSIsInN1YiI6IjEyMzQ1Njc4OTAiLCJuYW1lIjoiSm9obiBEb2UiLCJyb2xlIjoibWFuYWdlciIsImlhdCI6MTUxNjIzOTAyMiwiZXhwIjoxNzI2MjM5MDIyfQ.bhzhwj2cY1iYbpx7Mzbukfi1jOCvWP-Pdd9dm3hf7lZDDuokNVDUXU3jvHial4QN-bOTSNCUKVy907hokcVeQaFwbiYoZs485Kr230Z0y9MU6zbDe8yQp68-71TDgJGIZ78YYOKvJTrzCWgWgE_Py1DskG_ViSxfGFlETpFQa056Rk2bty-9iuc_Cx5_Wr6RCcJTG6WYRrBtdWGIFxljEjxSAcJYmGPPA8dHHORDOnmka2OAjWURnsqbz50aI_SrWpnqp4i2eXVA1b5QD5rlsgc_QAqJptghrijBlRPhasTk1N-kXE8Ozboa0FwGfIRr7gNiG-3if7INZe2R5NUCmjlAlywcSfOunWuSzY8tLGTHV2swnQPP8lBXwVJcS5nJMqBNIbcLcFWHk3ryvvtf-LYty_jAY8v1zDe9-DwFPWI0rry8fmiZj7yhAnvX5EHZHvSQtp_zyPpVWvOXFPwasI0jdKoxhWvyJpbmw-D95J5CgJAMfkrWPDQKVt3ipebwnMJStA3xAPPyl28mTBYhJrT6gzIOS3DseoVKK4adn34ZrQi2Hm-wyUtbdulopK739MKM73NYgoFXSJeVUqcy4iw3-In5XmOhdRnUL50TSiaNBbkys8iK7r00HD3kI3CH0GfaPdrcgRgaFXKmVDhX-tEaPJYcuEUTHfQAxWwMdiw' http://localhost:8080/secure
* Could not resolve host: GET
* Closing connection 0
curl: (6) Could not resolve host: GET
*   Trying 127.0.0.1:8080...
* Connected to localhost (127.0.0.1) port 8080 (#1)
> GET /secure HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/8.1.2
> Content-Type: application/json
> Accept: application/json
> Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzYW1wbGUtc2VydmljZSIsInN1YiI6IjEyMzQ1Njc4OTAiLCJuYW1lIjoiSm9obiBEb2UiLCJyb2xlIjoibWFuYWdlciIsImlhdCI6MTUxNjIzOTAyMiwiZXhwIjoxNzI2MjM5MDIyfQ.bhzhwj2cY1iYbpx7Mzbukfi1jOCvWP-Pdd9dm3hf7lZDDuokNVDUXU3jvHial4QN-bOTSNCUKVy907hokcVeQaFwbiYoZs485Kr230Z0y9MU6zbDe8yQp68-71TDgJGIZ78YYOKvJTrzCWgWgE_Py1DskG_ViSxfGFlETpFQa056Rk2bty-9iuc_Cx5_Wr6RCcJTG6WYRrBtdWGIFxljEjxSAcJYmGPPA8dHHORDOnmka2OAjWURnsqbz50aI_SrWpnqp4i2eXVA1b5QD5rlsgc_QAqJptghrijBlRPhasTk1N-kXE8Ozboa0FwGfIRr7gNiG-3if7INZe2R5NUCmjlAlywcSfOunWuSzY8tLGTHV2swnQPP8lBXwVJcS5nJMqBNIbcLcFWHk3ryvvtf-LYty_jAY8v1zDe9-DwFPWI0rry8fmiZj7yhAnvX5EHZHvSQtp_zyPpVWvOXFPwasI0jdKoxhWvyJpbmw-D95J5CgJAMfkrWPDQKVt3ipebwnMJStA3xAPPyl28mTBYhJrT6gzIOS3DseoVKK4adn34ZrQi2Hm-wyUtbdulopK739MKM73NYgoFXSJeVUqcy4iw3-In5XmOhdRnUL50TSiaNBbkys8iK7r00HD3kI3CH0GfaPdrcgRgaFXKmVDhX-tEaPJYcuEUTHfQAxWwMdiw
> 
< HTTP/1.1 200 
< Date: Wed, 19 Jun 2024 09:05:31 GMT
< X-Content-Type-Options: nosniff
< X-Frame-Options: deny
< Content-Type: application/json
< Transfer-Encoding: chunked
< 
* Connection #1 to host localhost left intact
{"hello":"John Doe"}%  
```

Проверим запрос с JWT с ролью, отличной от `manager`

```bash
curl -v -H 'Content-Type: application/json' -H 'Accept: application/json' -H 'Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzYW1wbGUtc2VydmljZSIsInN1YiI6IjEyMzQ1Njc4OTAiLCJuYW1lIjoiSm9obiBEb2UiLCJyb2xlIjoiYmFkIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE3MjYyMzkwMjJ9.UezPgiGOcbp9CMM7hkrbvFsPmFIOnPnph5n60wF9jEWfGAIpS3dgBYvsprsVx0iZaUfhj2GTTLXhQUKrEM08n6jhUBSlwQ22LYBEHhBY57-AwtUhFZVJL8En00tc3HTGLV_El55PyvJvuLRbQ_fZB7rfp27OMPS0y2ciehz21_90TGKvUWUUGJgqDvRPchSKdO7LVa97oigGUp8vi7XiutMxopMLoms63f7FbasbIxMfgEFa48cuJTTcmk7genlPpMX8CBeBUjVriK0452uYdONvSFllqX2rdHwi7idKV-wB0qeUdNq2MDgcVqTrztxRQ8_ezoZVMnn3OLzuSABSpHKtPM3G3uVctY2X408zwOqe86BFvahT1eyBsEmrtszaIL-REy6vy-6P8JJ7iZdD720F1h3VyXj7PWNQiA-v3TumBLpRiML4Clb0SmqpB2iIvPhAz2-ob1w9BBxbvES6n95JEvFDlsv0JqOpvs-ZqQeR1pL7ML0RDR6ZR7xMWE6iVC4hlHEyX5Ufi6CBvkzVLVSnbIPyIBSBc4bzDzqdRkgt139bEdD-htrKWFmGkJKl_yvNcW_rYCkeMmb60km389XUtpiBoSc5CmKkcxrjsarvEMRh-AkIqB5R7Hz0KVKFdp1Hlzj4v1CQKK8eM4Poiq0NoO9IgHFJtgZKMosD7Qc
' http://localhost:8080/secure
*   Trying 127.0.0.1:8080...
* Connected to localhost (127.0.0.1) port 8080 (#0)
> GET /secure HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/8.1.2
> Content-Type: application/json
> Accept: application/json
> Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzYW1wbGUtc2VydmljZSIsInN1YiI6IjEyMzQ1Njc4OTAiLCJuYW1lIjoiSm9obiBEb2UiLCJyb2xlIjoiYmFkIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE3MjYyMzkwMjJ9.UezPgiGOcbp9CMM7hkrbvFsPmFIOnPnph5n60wF9jEWfGAIpS3dgBYvsprsVx0iZaUfhj2GTTLXhQUKrEM08n6jhUBSlwQ22LYBEHhBY57-AwtUhFZVJL8En00tc3HTGLV_El55PyvJvuLRbQ_fZB7rfp27OMPS0y2ciehz21_90TGKvUWUUGJgqDvRPchSKdO7LVa97oigGUp8vi7XiutMxopMLoms63f7FbasbIxMfgEFa48cuJTTcmk7genlPpMX8CBeBUjVriK0452uYdONvSFllqX2rdHwi7idKV-wB0qeUdNq2MDgcVqTrztxRQ8_ezoZVMnn3OLzuSABSpHKtPM3G3uVctY2X408zwOqe86BFvahT1eyBsEmrtszaIL-REy6vy-6P8JJ7iZdD720F1h3VyXj7PWNQiA-v3TumBLpRiML4Clb0SmqpB2iIvPhAz2-ob1w9BBxbvES6n95JEvFDlsv0JqOpvs-ZqQeR1pL7ML0RDR6ZR7xMWE6iVC4hlHEyX5Ufi6CBvkzVLVSnbIPyIBSBc4bzDzqdRkgt139bEdD-htrKWFmGkJKl_yvNcW_rYCkeMmb60km389XUtpiBoSc5CmKkcxrjsarvEMRh-AkIqB5R7Hz0KVKFdp1Hlzj4v1CQKK8eM4Poiq0NoO9IgHFJtgZKMosD7Qc
> 
> 
< HTTP/1.1 403 
< X-Content-Type-Options: nosniff
< X-Frame-Options: deny
< Content-Type: application/json
< Content-Length: 23
< Date: Wed, 19 Jun 2024 09:06:32 GMT
< 
* Connection #0 to host localhost left intact
{'error' : 'Forbidden'}%  
```