---
layout: blog
title: 'OpenIG: авторизация доступа через OAuth (на примере Яндекс ID)'
description: 'В статье мы настроим авторизацию доступа в приложение через аутентификацию по протоколу OAuth 2.0 на шлюзе с открытым исходным кодом OpenIG'
tags: 
  - openig
---

## Введение

В статье мы настроим авторизацию доступа в приложение через аутентификацию по протоколу OAuth 2.0 на шлюзе с открытым исходным кодом [OpenIG](https://github.com/OpenIdentityPlatform/OpenIG). В качестве сервиса аутентификации будем использовать [Яндекс ID](https://oauth.yandex.ru/).

## Создание приложения Яндекс ID

Создайте приложение Яндекс ID, как описано по [ссылке](https://yandex.ru/dev/id/doc/ru/register-client). 

В запрашиваемых правах выберите “Доступ к адресу электронной почты”.

В список “Redirect URI для веб-сервисов” добавьте URI OpenIG: [http://openig.example.org:8080/app/callback](http://openig.example.org:8080/app/callback)

## Подготовка

Для быстрого развертывания шлюза OpenIG на локальной машине нам понадобится Docker.

Пусть имя хоста для OpenAM будет `openig.example.org` Перед запуском добавьте имя хоста и IP адрес в файл `hosts`, например `127.0.0.0.1 openig.example.org`

В системах под управлением Windows файл `hosts` расположен в `C:\Windows\System32\drivers\etc\hosts`, а в Linux и Mac расположен в `/etc/hosts`.

## Настройка OpenIG

Создайте папку `openig-config` и в ней еще одну одну папку `config`. В папке `config` создайте два файла: `config.json` и `admin.json` со следующим содержимым.

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

`admin.json`:

```json
{
    "prefix": "openig",
    "mode": "PRODUCTION"
}
```

### Тестовое приложение

Создайте маршрут к защищаемоу приложению, запросы к которому будут выполняться через OpenIG. В папке `config` создайте папку маршрутов `routes` . И добавьте в папку маршрут `01-app.json` .

```json
{
  "heap": [],
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [],
      "handler": {
        "name": "EndpointHandler",
        "type": "DispatchHandler",
        "config": {
          "bindings": [
            {
              "handler": "ClientHandler",
              "capture": "all",
              "baseURI": "${system['endpoint.app']}"
            }
          ]
        }
      }
    }
  },
  "condition": "${matches(request.uri.path, '^/app')}"
}
```

Приложение состоит из двух файлов: `index.html` и `main.js`.

`index.html`

```html
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="icon" href="data:," />
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet"
        integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH" crossorigin="anonymous">

</head>
<body>
    <div class="container my-5">
        <div id="alert" class="alert alert-danger" role="alert" style="display: none;">
            
        </div>
        <h1>Test OAuth 2 OpenIG Example</h1>
        <div id="login">
            <div class="col-lg-8 px-0">
                <p class="fs-5">You are not authenticated.<br>Press the Login button to continue.</p>
                <hr class="col-1 my-4">
                <button id="loginButton" type="button" class="btn btn-primary">Login</button>
            </div>
        </div>
        <div id="profile" style="display: none;">
            <div class="col-lg-8 px-0">
                <p class="fs-5">Authenticated with <span id="email">undefined</span></p>
            </div>
        </div>

    </div>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
        integrity="sha384-YvpcrYf0tY3lHB60NNkmXc5s9fDVZLESaAA55NDzOxhy9GkcIdslK1eN7N6jIeHz"
        crossorigin="anonymous"></script>
    <script src="js/main.js"></script>
</body>
</html> 
```

`main.js`

```jsx
// Usage example
window.onload = function () {
    
    function setError(text) {
        const alert =  document.getElementById('alert');
        alert.textContent = text;
        alert.style.display = '';
    }

    document.getElementById('loginButton')?.addEventListener('click', doLogin);

    async function setUserData(userData) {
        document.getElementById('login').style.display = 'none';
        document.getElementById('email').textContent = userData.email;
        document.getElementById('profile').style.display = '';
    }

    async function getUserData(accessToken) {
        try {
            const response = await fetch("/userinfo", {
                headers: {
                    "Authorization": "Bearer " + accessToken,
                  },
            });
            if(response.ok) {
                const userData = await response.json();
                console.log('User data:', userData);
                setUserData(userData);
            } else if (response.status == 403) {
                setError("got http status 403 Forbidden");
            } else if (response.status == 401) {
                setError("got http status 401 Not Authenticated");
            } else {
                setError("got http status " + response.status + " " + response.statusText);
            }
            
        } catch (error) {
            console.error('get user data failed:', error);
            setError("get user data failed: " + error);
        }
    }

    async function doLogin() {
        try {
            const response = await fetch("/oauth?goto=/app", {
                redirect: 'manual'
            });
            if (response.type === "opaqueredirect") {
                window.sessionStorage.setItem("autoLogin", true);
                window.location.href = response.url;
                return;
            }
            const tokenData = await response.json();
            const accessToken = tokenData.access_token;
            console.log('Access Token:', accessToken);
            getUserData(accessToken)

        } catch (error) {
            console.error('Token exchange failed:', error);
            setError('Token exchange failed:' + error);
        }
    }

    if(window.sessionStorage.getItem("autoLogin")) {
        window.sessionStorage.removeItem("autoLogin");
        doLogin();
    }
}
```

Логика приложения довольно проста. При нажатии на кнопку `Login` выполняется запрос к конечной точке получения access_token OpenIG. Конечная точка возвращает `access_token` либо перенаправляет на аутентификацию в Яндекс ID. После аутентификации возвращается `access_token`. 

После получения `access_token` приложение обращается к конечной точке OpenIG. `access_token` передается в заголовке `Authorization` . OpenIG получает информацию об учетной записи и авторизует запрос. Если авторизация успешна, отображает данные пользователя. В противном случае, приложение отображает ошибку аутентификации или авторизации.

### Получение access_token

В папку `config/routes` Добавьте маршрут `02-oauth.json`

`02-oauth.json` :

```json
{
  "heap": [
    {
      "name": "Yandex",
      "type": "Issuer",
      "config": {
        "authorizeEndpoint": "https://oauth.yandex.ru/authorize",
        "tokenEndpoint": "https://oauth.yandex.ru/token"
      }
    },
    {
      "comment": "To reuse client registrations, configure them in the parent route",
      "name": "OAuth2RelyingParty",
      "type": "ClientRegistration",
      "config": {
        "issuer": "Yandex",
        "clientId": "${system['oauth.client_id']}",
        "clientSecret": "${system['oauth.client_secret']}",
        "scopes": [
          "login:email"
        ]
      }
    }
  ],
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [
        {
          "type": "OAuth2ClientFilter",
          "config": {
            "clientEndpoint": "/oauth",
            "defaultLoginGoto": "/app",
            "requireHttps": false,
            "requireLogin": true,
            "target": "${attributes.access_token}",
            "failureHandler": {
              "type": "StaticResponseHandler",
              "config": {
                "status": 500,
                "reason": "Error",
                "entity": "${attributes.access_token}"
              }
            },
            "registrations": "OAuth2RelyingParty"
          }
        }        
      ],
      "handler": {
        "name": "AccessTokenHandler",
        "type":"StaticResponseHandler",
        "config": {
           "status": 200,
           "headers" : {
            "Content-Type" : ["application/json"]
           },
           "entity": "{ \"access_token\": \"${attributes.access_token.access_token}\" }"
        }
      }
    }
  },
  "condition": "${matches(request.uri.path, '^/oauth')}",
  "baseURI": "http://openig.example.org:8080"
}
```

Остановимся на конфигурации маршрута подробнее. Для получения access_token используется [authorization code flow](https://datatracker.ietf.org/doc/html/rfc6749#section-4.1).

Запрос пользователя на конечную точку `/oauth` проходит через фильтр`OAuth2ClientFilter`, который перенаправляет пользователя на сервер Яндекс ID для аутентификации. 

Параметры клиента OAuth 2 настраиваются объектами `Issuer` и `ClientRegistration`  в [heap](https://doc.openidentityplatform.org/openig/reference/required-conf#heap-objects) маршрута.

Для `ClientRegistration` укажите в параметрах `clientId` и `clientSecret` значения из приложения, которое  вы зарегистрировали в Яндекс ID. 

После успешной аутентификации, Яндекс возвращает код для получения `access_token` в  OpenIG. 

`OAuth2ClientFilter` обменивает полученный код на `access_token`. 

`AccessTokenHandler` возвращает JSON объект с полученным `access_token` .

### Аутентификация и авторизация запроса

Создайте маршрут получения информации о пользователе `03-userinfo.json`

```json
{
  "heap": [
    {
      "name": "UnAuthorizedHandler",
      "type": "StaticResponseHandler",
      "config": {
        "status": 403,
        "reason": "Forbidden",
        "headers": {
          "Content-Type": [
            "application/json"
          ]
        },
        "entity": "{\"error\": \"forbidden\" }"
      }
    },
    {
      "name": "UnAuthenticatedHandler",
      "type": "StaticResponseHandler",
      "config": {
        "status": 401,
        "reason": "Unauthenticated",
        "headers": {
          "Content-Type": [
            "application/json"
          ]
        },
        "entity": "{\"error\": \"unauthenticated\" }"
      }
    }
  ],
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [
        {
          "name": "ProtectedResourceFilter",
          "type": "OAuth2ResourceServerFilter",
          "config": {
            "tokenInfoEndpoint": "https://login.yandex.ru/info?format=jwt",
            "accessTokenResolver": {
              "type": "ScriptableAccessTokenResolver",
              "config": {
                "type": "application/x-groovy",
                "file": "ResolveAccessToken.groovy"
              }
            },
            "requireHttps": false,
            "providerHandler": "ClientHandler",
            "scopes": [],
            "cacheExpiration": "2 minutes"
          }
        },
        {
          "name": "AuthenticationFilter",
          "type": "ConditionEnforcementFilter",
          "config": {
            "condition": "${not empty (contexts['oauth2'])}",
            "failureHandler": "UnAuthenticatedHandler"
          }
        },
        {
          "name": "AuthorizationFilter",
          "type": "ConditionEnforcementFilter",
          "config": {
            "condition": "${contains(system['allowedEmails'].split(','), contexts['oauth2'].accessToken.info.email)}",
            "failureHandler": "UnAuthorizedHandler"
          }
        }
      ],
      "handler": {
        "name": "UserInfoHandler",
        "type": "StaticResponseHandler",
        "config": {
          "status": 200,
          "headers": {
            "Content-Type": [
              "application/json"
            ]
          },
          "entity": "{\"email\": \"${contexts['oauth2'].accessToken.info['email']}\", \"balance\": 10000 }"
        }
      }
    }
  },
  "condition": "${matches(request.uri.path, '^/userinfo')}",
  "baseURI": "http://openig.example.org:8080"
}
```

Запрос проходит через `ProtectedResourceFilter`, который получает информацию об аутентифицированной учетной записи от сервиса Яндекс ID по `access_token` переданному в HTTP заголовке `Authorization` и кеширует ее на срок 2 минуты.

Фильтр использует скрипт на языке Groovy для получения данных пользователя по полученному `access_token` `ResolveAccessToken.groovy`. Groovy скрипты создаются в папке `openig-config/scripts`

`ResolveAccessToken.groovy`:

```groovy
import org.forgerock.http.oauth2.AccessTokenInfo
import org.forgerock.json.JsonValue

import org.forgerock.json.jose.builders.JwtBuilderFactory
import org.forgerock.json.jose.jws.SignedJwt

logger.info("getting JWT with user info...")
def httpRequest = new Request()
httpRequest.method = "GET"
httpRequest.uri = config.tokenInfoEndpoint.asString()
httpRequest.headers['Authorization'] = "OAuth " + token
def response = http.send(httpRequest).get(5, java.util.concurrent.TimeUnit.SECONDS)
try {
    if(response.status.code != 200) {
        throw new Exception("error getting user info " + response.status)
    }
    def sjwt = new JwtBuilderFactory().reconstruct(response.entity.string, SignedJwt.class)
    logger.info("sjwt: " + sjwt.getClaimsSet())
    return new AccessTokenInfo(new JsonValue(sjwt.getClaimsSet().getProperties().all), token, new HashSet<>(), sjwt.getClaimsSet().getExpirationTime().getTime() * 1000)
} catch(Exception ex) {
    logger.warn("exception occurred: " + ex + ", response " + response.entity)
    throw ex
} finally {
    response.close()
}
```

Аутентификацию запроса проверяет фильтр `AuthenticationFilter` . Если `access_token` не валиден, то возвращается HTTP статус 401.

Авторизацию запроса проверяет фильтр `AuthorizationFilter` . Он проверяет email в списке допустимых, указанных в системной опции `allowedEmails`. Если проверка успешна, пропускает запрос дальше. В противном случае возвращается ошибка авторизации, HTTP статус 403.

`UserInfoHandler` — конечное приложение, возвращает данные аутентифицированного и авторизованного пользователя. 

Если при помощи OpenIG нужно авторизовать несколько приложений схожим образом, вы можете вынести фильтры в объект `heap` файла `config.json`

Более подробно про настройку OpenIG вы можете почитать в [документации](https://doc.openidentityplatform.org/openig/).

## Проверка

Скачайте код проекта с сайта GitHub по ссылке https://github.com/OpenIdentityPlatform/openig-oauth2-example.

Откройте файл `docker-comose.yaml`. Установите в переменной окружения `CATALINA_OPTS` свойствах сервиса `openig` `-Doauth.client_id` и `-Doauth.client_secret` client_id и client_secret вашего приложения, зарегистрированного в Яндекс ID. В аргументе

`-DallowedEmails` добавьте email, с которым вы будете аутентифицироваться в Яндекс.

Запустите образы Docker OpenIG и защищаемого приложения командой

```
$ docker compose up
```

И дождитесь запуска OpenIG и приложения.

- Откройте в браузере ссылку [http://openig.example.org:8080/app](http://openig.example.org:8080/app).
- Нажмите кнопку `Login`.
- Браузер перенаправит на сервер Яндекса для аутентификации.
- После успешной аутентификации OpenIG перенаправит браузер обратно в приложение.
- Если авторизация прошла успешно и `access_token` валиден, приложение вернет HTTP статус 200. В теле ответа будет email аутентифицированного пользователя, а так же его баланс. Приложение покажет данные аутентифицированного и авторизованного пользователя.
- Если срок действия `access_token` истек или `access_token` был отозван, OpenIG вернет ответ со статусом 401. Приложение покажет сообщение об ошибке.
- Если авторизация неуспешна, то есть email пользователя отсутствует в списке разрешенных, OpenIG вернет ответ с HTTP статусом 403 и приложение покажет сообщение об ошибке.