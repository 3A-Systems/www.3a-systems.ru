---
layout: blog
title: 'OpenAM и Zero Trust: Подтверждение критичных операций'
description: 'В этой статье мы рассмотрим как реализовать соблюдение принципа Zero Trust Security "never trust, always verify" в системе аутентификации на примере OpenAM и OpenIG'
tags: 
  - openig
  - openam
---

## Введение

Один из принципов нулевого доверия гласит: никогда не доверяй, всегда проверяй (Never trust, always verify). В этой статье мы рассмотрим, как реализовать соблюдение такого принципа в системе аутентификации на примере продуктов с открытым исходным кодом [OpenAM](https://github.com/OpenIdentityPlatform/OpenAM) и [OpenIG](https://github.com/OpenIdentityPlatform/OpenIG). 

Увидеть работу принципа можно на примере банковских приложений. При подтверждении платежа банк почти каждый раз хочет убедиться, что операцию совершаете именно вы, а не злоумышленник. Для этого он отправляет вам одноразовый код на доверенное устройство при помощи PUSH уведомления или номер телефона. 

Как альтернативное решение, можно попросить пользователя подтвердить биометрические данные, например, отпечаток пальца, подключить аппаратный токен или использовать специальное приложение, например Microsoft Authenticator или Google Authenticator.

## Дизайн решения

В решении будет использоваться 3 компонента:

- **Защищаемое приложение** (любое приложение, в нашем случае, простое приложение на Node.JS) в котором будут аутентифицироваться пользователи, с двумя страницами: страница профиля и страница с чувствительными данными.
- **Сервис аутентификации (OpenAM)**:  отвечает за аутентификацию и авторизацию пользователей
- **Шлюз авторизации (OpenIG)**: отправляет запрос в OpenAM на проверку на соответствие политики и, в случае успеха, пропускает запрос к защищаемому приложению. В противном случае, перенаправляет на аутентификацию. При попытке доступа к странице с чувствительной информацией, OpenAM будет проверять, что пользователь аутентифицировался с одноразовыми кодом и со времени последней аутентификации не прошло больше 20 секунд.

В качестве второго фактора аутентификации будут использоваться одноразовые пароли, сгенерированные по [алгоритму TOTP](https://en.wikipedia.org/wiki/Time-based_one-time_password) и мобильное приложение [Microsoft Authenticator](https://support.microsoft.com/en-us/account-billing/download-microsoft-authenticator-351498fc-850a-45da-b7b6-27e523b8702a) или приложение [Google Authenticator](https://support.google.com/accounts/answer/1066447).

## Подготовка

Готовый код решения расположен по ссылке [https://github.com/OpenIdentityPlatform/openam-openig-otp-example](https://github.com/OpenIdentityPlatform/openam-openig-otp-example)

### Подготовка файла hosts

Пусть имя хоста для сервиса аутентификации будет `openam.example.org` , а для шлюза - `openig.example.org` Перед запуском, добавьте имена  хостов и IP адрес в файл `hosts`, например `127.0.0.0.1 openam.example.org openig.example.org` 

В системах под управлением **Windows** файл `hosts` расположен в `C:Windows/System32/drivers/etc/hosts`, а в **Linux** и **Mac** расположен в `/etc/hosts`.

### Приложение аутентификатора

Установите на ваше мобильное устройство приложение [Microsoft Authenticator](https://support.microsoft.com/en-us/account-billing/download-microsoft-authenticator-351498fc-850a-45da-b7b6-27e523b8702a) или [Google Authenticator](https://support.google.com/accounts/answer/1066447).

### Docker Compose

Для простоты все сервисы будут запущены через `docker compose`. 

Создайте пустой файл `docker-compose.yml` и добавьте в него объект `services` 

```yaml
services:

```

## Демонстрационное приложение

Для примера, возьмем простое приложение на Node.JS с двумя URL: 
- **Страница профиля(`/`)** - показывает информацию об учетной записи 
- **Страница с чувствительной информацией(`/sensitive`)** - показывает информацию о банковских счетах и ключах пользвоателя.

Код приложения расположен по [ссылке](https://github.com/OpenIdentityPlatform/openam-openig-otp-example/tree/master/demo-app)

```jsx
const express = require("express");
const app = express();
const port = 3000;

app.set("view engine", "ejs");

app.use((req, res, next) => {
    console.log(req.headers)
    const token = req.headers.authorization;
    if (!token) {
        return res.status(401).send("Unauthorized");
    }
    next()
})

app.get("/", (req, res) => {
    const token = req.headers.authorization;
    const jwtPayload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
    const user = { name: jwtPayload.sub };
    res.render("profile", { user });
});

app.get("/sensitive", (req, res) => {
    const sensitiveData = { bankAccount: "1234-5678-9012-3456", secretKey: "MY_SUPER_SECRET_KEY" };
    res.render("sensitive", { sensitiveData });
});

app.listen(port, () => console.log(`Server running at http://localhost:${port}`));
```

Добавьте в файл `docker-compose.yml` в объект `services` демонстрационное приложение

```yaml
services:
  demo-app:
    build: ./demo-app
    container_name: demo-app
```

Запустите приложение командой `docker compose up -d --build demo-app`

## Настройка сервиса аутенитификации OpenAM

Добавьте в файл `docker-compose.yml` в объект `services` серис OpenAM:

```yaml
services:
...
  openam:
    image: openidentityplatform/openam:latest
    container_name: openam
    hostname: openam.example.org
    ports:
      - "8080:8080"
```
Запустите контейнер OpenAM командой `docker compose up openam`. Дождитесь старта контейнера и выполните начальную установку командой: 


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

Дождитесь окончания установки.

### Настройка MFA в OpenAM

Откройте консоль администратора OpenAM по ссылке [http://openam.example.org:8080/openam](http://openam.example.org:8080/openam). 

Введите логин и пароль администратора. В данном случае, это `amadmin` и `passw0rd` соответственно.

В открывшейся консоли выберите Top Level Realm. В меню слева выберите Authentication → Modules и добавьте новый модуль `totp` с типом `Authenticator (OATH)`

![New TOTP Module.png](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/0-new-totp-module.png)

В настройках выберите **OATH Algorithm to Use: TOTP**, также укажите  **Name of the Issuer**, например, **OpenAM**.Остальные настройки можно оставить без изменений. Сохраните настройки модуля `totp`.

![TOTP module settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/1-totp-module-settings.png)

Далее, настроим цепочку аутентификации

В консоли администратора откройте Top Level Realm, в меню слева перейдите Authentication → Chains и создайте новую цепочку аутентификации `totp`

![New TOTP authentication chain](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/2-new-totp-chain.png)

Добавьте в цепочку созданный модуль `totp` и сохраните изменения.

![TOTP authentication chain settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/3-totp-chain-settings.png)

### Настройка политики авторизации

Теперь перейдем к настройке политики авторизации в OpenAM для конечной точки `/sensitive` демонстрационного приложения. Политика будет настроена таким образом, что от пользователя требуется аутентифицироваться с одноразовым кодом в цепочке аутентификации `totp`, но аутентификация будет действовать только 20 секунд.

Откройте консоль администратора OpenAM. Откройте Top Level Realm. В меню слева выберите Authorization → Policy Sets.  Выберите Default Policy Set. Создайте новую политику `demo-sensitive`.

В качестве типа ресурса выберите  URL и укажите ресурс, как показано в примере на рисунке ниже. Нажмите кнопку Add и затем Create.

![OpenAM new policy](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/4-new-policy.png)

Для созданной политики на закладке Resources разрешите GET и POST запросы.

![Policy Actions](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/5-policy-actions.png)

На закладке Subjects добавьте тип “Authenticated Users”.

![Policy Subjects](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/6-policy-subjects.png)

На закладке Environments добавьте условие Authentication by Module Chain и добавьте цепочку `totp`.

![Policy Environments](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/7-policy-environments.png)

Сохраните изменения. Такая политика будет авторизовывать запросы, аутентифицированные в цепочке `totp`. 

Теперь настроим политику таким образом, что доступ действует только 20 секунд. Такой политики в OpenAM из коробки нет, поэтому мы настроим скрипт политики. Но сначала подготовим OpenAM для работы со временем из скрипта. В верхнем меню в перейдите Configure → Global Services. В открывшемся списке выберите пункт Scripting. Перейдите на закладку Secondary Configuration.

![Configure Scripting](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/8-configure-scripting.png)

Откройте  конфигурацию `POLICY_CONDITION`. На закладке Secondary Configurations выберите EngineConfiguration.

![Scripting Policy Condition](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/9-scripting-policy-condition.png)

В список **Java class whitelist** добавьте `java.time.*` чтобы разрешить Groovy скриптам работать со временем и датой.

Сохраните изменения. В верхнем меню консоли выберите Realms → Top Level Realm и в меню слева выберите пункт Scripts. Создайте новый скрипт Auth Time Policy Condition. 

![New Script](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/10-new-script.png)

Тип скрипта - POLICY_CONDITION.  Язык - Groovy.

![Auth Time Policy Condition](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/11-auth-time-policy-condition.png)

```groovy
import java.time.Instant;
import java.time.temporal.ChronoUnit;

logger.warning("Session: " + session) 
def authInstant = session.getProperty("authInstant")

logger.warning("Auth time expired at1: " + authInstant)

def instant = Instant.parse(authInstant)
def expired = instant.plus(20, ChronoUnit.SECONDS)
if (Instant.now().compareTo(expired) > 0) {
  logger.warning("Auth time expired at: " + expired)   
  authorized = false
} else {
  authorized = true                
}
```

Сохраните изменения политики.

Теперь настроим использование скрипта в политике авторизации.    В меню слева перейдите Authorization → Policy Sets → Default Policy Set → demo-sensitive. 

На закладке Environments добавьте условие с типом Script и значением Auth Time Policy Condition.

![Policy Script](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/12-policy-script.png)

Сохраните изменения.

Теперь настроим использование MFA для пользователя `demo`. Эта учетная запись была создана при установке OpenAM.

### Настройка пользователя OpenAM

Выйдите из консоли администратора, или откройте браузер в режиме “Инкогнито” и перейдите по ссылке [http://openam.example.org:8080/openam/XUI/#login](http://openam.example.org:8080/openam/XUI/#login)

В поле логин и пароль введите `demo` и `changeit` соответственно. Откроется профиль пользователя.

Теперь начните процесс аутентификации в цепочке `totp`. Для этого, откройте ссылку [http://openam.example.org:8080/openam/XUI/#login/&service=totp&ForceAuth=true](http://openam.example.org:8080/openam/XUI/#login/&service=totp&ForceAuth=true)

Откроется окно с предложением зарегистрировать устройство

![OpenAM Register Device](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/13-openam-register-device.png)

Нажмите кнопку **Register Device** для регистрации устройства.

Откроется страница с QR кодом.

![OpenAM QR Code](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/14-openam-qr-code.png)

Откройте приложение аутентификатора на вашем мобильном устройстве и отсканируйте в нем выданный QR код. Нажмите кнопку Login Using Verification Code.

Введите код из мобильного приложения и нажмите кнопку Submit.

![OpenAM verification code](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/15-openam-verification-code.png)

`MFA` для пользователя `demo` настроена

### Настройка конвертации токена аутентификации в JWT

После успешной аутентификации, OpenAM создает сессию и пишет идентификатор сессии, который представляет из себя случайный набор символов, в cookie в браузер. Мы настроим OpenAM, чтобы сторонние приложения, например OpenIG, могли обменивать токен аутентификации на JWT с которым будет проще работать сторонним приложениям.

Откройте консоль администратора OpenAM, как было описано ранее. Выберите **Top Level Realm**. В меню слева выберите **STS**. В открывшемся списке создайте новый инстанс **Rest STS**. Заполните настройки

| **Настройка** | **Значение** |
| --- | --- |
| Supported Token Transforms | OPENAM->OPENIDCONNECT;don't invalidate interim OpenAM session |
| Deployment Url Element | jwt |
| The id of the OpenID Connect Token Provider | [https://openam.example.org/openam](https://openam.example.org/openam) |
| Client secret | changeme |
| Confirm client secret | changeme |
| The audience for issued tokens | [https://openam.example.org/openam](https://openam.example.org/openam) |

Сохраните настройки конвертации инстанса Rest STS.

Подробнее про установку и настройку OpenAM вы можете прочитать в документации:  [https://doc.openidentityplatform.org/openam/](https://doc.openidentityplatform.org/openam/)

## Настройка шлюза авторизации OpenIG

Добавьте сервис OpenIG в файл `docker-compose.yml`

```yaml
services:
...
  openig:
    image: openidentityplatform/openig:latest
    container_name: openig
    hostname: openig.example.org
    volumes:
      - ./openig:/usr/local/openig-config:ro
    environment:
      CATALINA_OPTS: -Dopenig.base=/usr/local/openig-config -Ddemo.app=http://demo-app:3000 -Dopenam=http://openam.example.org:8080/openam
    ports:
      - "8081:8080"
```

Обратите внимание на аргументы в переменной окружения `CATALINA_OPTS`:

- `openig.base` - путь к файлам конфигурации OpenIG
- `demo.app`  - URL демонстрационного приложения, к которому OpenIG проксирует запрос
- `openam` - URL OpenAM, на который OpenIG будет перенаправлять пользователя для аутентификации и получать JWT.

### Общие настройки

Создайте папку `openig-config` и в ней еще одну одну папку `config`. В папке `config` создайте файл `admin.json` со следующим содержимым:

```json
{
    "prefix": "openig",
    "mode": "PRODUCTION"
}
```

В этой же папке создайте файл `config.json`. 

```json
{
  "heap": [
    {
      "name": "EndpointHandler",
      "type": "DispatchHandler",
      "config": {
        "bindings": [
          {
            "handler": "ClientHandler",
            "capture": "all",
            "baseURI": "${system['demo.app']}"
          }
        ]
      }
    }
  ],
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [
        {
          "name": "STSFilter",
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
          "name": "AuthorizationHeaderFilter",
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
          "name": "AuthenticationRedirectionFilter",
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
                    "${system['openam']}/XUI/#login&goto=${urlEncode(contexts.router.originalUri)}"
                  ]
                },
                "entity": "{ \"Redirect\": \"${system['openam']}/XUI/#login&goto=${urlEncode(contexts.router.originalUri)}\"}"
              }
            }
          }
        }
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

В файле `config.json` определена цепочка фильтров для каждого запроса в демонстрационное приложение:

- `STSFilter`  - если в HTTP запросе есть cookie от OpenAM, то фильтр получает по этой cookie JWT, который пишется в контекст для дальнейшего использования
- `AuthorizationHeaderFilter` - добавляет полученный из OpenAM JWT в запрос в заголовок `Authorization` для использования в защищаемом приложении
- `AuthenticationRedirectionFilter` - если JWT нет в контексте запроса, перенаправляет пользователя на аутентификацию в OpenAM.

В объекте `heap` определен обработчик `EndpointHandler` , который проксирует запросы в OpenIG к демонстрационному приложению.

### Настройка маршрутов к демонстрационному приложению

В папке `config` создайте папку `routes` и добавьте маршрут `10-home.json`

```json
{
  "name": "${matches(request.uri.path, '^/$')}",
  "condition": "${matches(request.uri.path, '^/$')}",
  "monitor": true,
  "timer": true,
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [],
      "handler": "EndpointHandler"
    }
  },
  "heap": [
    
  ]
} 
```

Маршрут просто проксирует запросы к демонстрационному приложению, используя `EndpointHandler` , определенный в файле конфигурации `config.json`.

Мы добавим маршрут к URL с чувствительной информацией демонстрационного приложения. Затем настроим для маршрута фильтр таким образом, чтобы он использовал политику авторизации из OpenAM.

Добавьте в папку `routes` маршрут `20-sensitive.json`

```json
{
  "name": "${matches(request.uri.path, '^/sensitive')}",
  "condition": "${matches(request.uri.path, '^/sensitive')}",
  "monitor": true,
  "timer": true,
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [
        {
          "name": "MFAPEPFilter",
          "type": "PolicyEnforcementFilter",
          "config": {
            "openamUrl": "${system['openam']}",
            "pepUsername": "amadmin",
            "pepPassword": "ampassword",
            "ssoTokenSubject": "${request.cookies['iPlanetDirectoryPro'][0].value}",
            "failureHandler": {
              "type": "StaticResponseHandler",
              "config": {
                "status": 403,
                "headers": {
                  "Content-Type": [
                    "application/json"
                  ]
                },
                "entity": "{ \"attributes\": \"${system['openam']}/XUI/#login&service=totp&ForceAuth=true&goto=${urlEncode(contexts.router.originalUri)}\"}"
              }
            }
          },
          "handler": "ClientHandler"
        }
      ],
      "handler": "EndpointHandler"
    }
  },
  "heap": []
}
```

Маршрут использует `MFAPEPFilter` для получения результата политики авторизации из OpenAM. И, если проверка политики не пройдена, перенаправляет на аутентификацию с одноразовым кодом.

Подробнее про установку и настройку OpenIG вы можете прочитать в документации:  [https://doc.openidentityplatform.org/openig/](https://doc.openidentityplatform.org/openig/)

## Проверка решения

Запустите OpenIG командой `docker compose ui openig`.

Выйдите из OpenAM, если вы все еще аутентифицированы.

Откройте URL демонстрационного приложения защищенного OpenIG: [http://openig.example.org:8081/](http://openig.example.org:8081/). Вас перенаправит на аутентификацию в OpenAM. Введите логин и пароль тестового пользователя: `demo` и `changeit`

После аутентификации вас перенаправит на основной экран демонстрационного приложения

![Demo Profile Page](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/16-demo-profile-page.png)

Нажмите на ссылку **Sensitive data**. Вас перенаправит на дополнительную аутентификацию с одноразовым кодом в OpenAM. 

![TOTP Verification](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/17-totp-verification.png)

Введите код из приложения аутентификатора и нажмите кнопку Submit. При успехе, вас перенаправит обратно на страницу с чувствительными данными

![Demo Sensitive Page](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-openig-otp-zts/18-demo-sensitive-page.png)

Подождите 30 секунд и перезагрузите страницу. Вас снова перенаправит на аутентификацию с одноразовым кодом.