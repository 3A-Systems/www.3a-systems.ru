---
layout: blog
title: Использование LLM в Access Management на примере OpenAM и Spring AI
description: 'В статье мы развернем систему управления доступом, запросим у LLM проанализировать конфигурацию и вернуть рекомендации по ее улучшению.'
keywords: 'OpenAM, LLM, AI, Spring AI, Spring Boot, анализ контроля доступа с помощью LLM, аудит безопасности OpenAM, анализ контроля доступа с помощью LLM, безопасность управления доступом, аудит конфигурации OpenAM'
tags: 
  - openam
---

## Введение

Данная статья является продолжением предыдущей [статьи](https://www.3a-systems.ru/blog/2025-06-05-llm-in-access-management) по применению LLM в системах управления доступом. В конце статьи мы пришли к выводу, что оптимальным использованием LLM будет проведение аудита конфигурации системы управления доступом.

В статье мы развернем систему управления доступом, запросим у LLM проанализировать конфигурацию и вернуть рекомендации по ее улучшению.

В качестве системы управления доступом мы будем использовать решение с открытым исходным кодом [OpenAM](https://github.com/OpenIdentityPlatform/OpenAM) (Open Access Manager) с конфигурацией по умолчанию.

## Установка OpenAM

Развернем OpenAM в Docker контейнере командой

```
docker run -h openam.example.org -p 8080:8080 --name openam openidentityplatform/openam
```

После старта контейнера выполним начальную конфигурацию командой

```
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

После завершения конфигурации, проверим, что OpenAM работает. Вызовем API аутентификации для учетной записи `demo`:

```
curl -X POST \
 --header "X-OpenAM-Username: demo" \
 --header "X-OpenAM-Password: changeit" \
 http://openam.example.org:8080/openam/json/authenticate
{"tokenId":"AQIC5wM2LY4SfczeNbGH-CImBSl6bCnAKM1oxqS110Kkb9I.*AAJTSQACMDEAAlNLABM0MTM4NDQ3MTQyOTI5Njk1MTA3AAJTMQAA*","successUrl":"/openam/console","realm":"/"}
```

## Spring AI приложение для аудита

Для автоматизации аудита разработано приложение на основе [Spring Boot](https://spring.io/projects/spring-boot) и [Spring AI](https://spring.io/projects/spring-ai/).

Приложение получает конфигурацию модулей аутентификации и предлагает рекомендованные настройки, а также анализирует цепочки аутентификации. Затем предлагает рекомендации по оптимизации настроек и рекомендует настроить новые цепочки аутентификации.

Для демонстрационных целей и, чтобы не загромождать статью, приложение будет работать в консольном режиме.

Исходный код приложения расположен по [ссылке](https://github.com/OpenIdentityPlatform/openam-ai-analyzer).

### Быстрый старт

Перед тем, как погружаться с технические детали, проверим, что приложение для аудита работает, а потом уже погрузимся в детали реализации. Для запуска приложения должен быть установлен JDK не ниже 17 версии.

Запустим приложение

```
./mvnw spring-boot:run

2025-06-09T10:21:51.016+03:00  INFO 11080 --- [OpenAM AI Analyzer] [           main] o.o.openam.ai.analyzer.cmd.Runner        : analyzing access modules...
2025-06-09T10:21:51.016+03:00  INFO 11080 --- [OpenAM AI Analyzer] [           main] o.o.o.a.a.s.AccessManagerAnalyzerService : querying OpenAM for a prompt data...
2025-06-09T10:21:51.532+03:00  INFO 11080 --- [OpenAM AI Analyzer] [           main] o.o.o.a.a.s.AccessManagerAnalyzerService : generated client prompt:
SYSTEM: You are an information security expert with 20 years of experience.
USER: I have an access management system with the following modules:
```json
{
  "modules": [
    ...
    {
      "name": "LDAP",
      "settings": {
        "LDAP Connection Heartbeat Interval": 10,
        "Bind User DN": "cn=Directory Manager",
        "LDAP Connection Heartbeat Time Unit": "SECONDS",
        "Return User DN to DataStore": true,
        "Minimum Password Length": "8",
        "Search Scope": "SUBTREE",
        "Primary LDAP Server": [
          "openam.example.org:50389"
        ],
        "Attributes Used to Search for a User to be Authenticated": [
          "uid"
        ],
        "DN to Start User Search": [
          "dc=openam,dc=example,dc=org"
        ],
        "Overwrite User Name in sharedState upon Authentication Success": false,
        "User Search Filter": null,
        "LDAP Behera Password Policy Support": true,
        "Trust All Server Certificates": false,
        "Secondary LDAP Server": [],
        "LDAP Connection Mode": "LDAP",
        "Authentication Level": 0,
        "Attribute Used to Retrieve User Profile": "uid",
        "Bind User Password": null,
        "LDAP operations timeout": 0,
        "User Creation Attributes": [],
        "LDAPS Server Protocol Version": "TLSv1"
      }
    },
    {
      "name": "OATH",
      "settings": {
        "Minimum Secret Key Length": "32",
        "Clock Drift Attribute Name": "",
        "Counter Attribute Name": "",
        "TOTP Time Step Interval": 30,
        "The Shared Secret Provider Class": "org.forgerock.openam.authentication.modules.oath.plugins.DefaultSharedSecretProvider",
        "Add Checksum Digit": "False",
        "Maximum Allowed Clock Drift": 0,
        "Last Login Time Attribute": "",
        "Secret Key Attribute Name": "",
        "OATH Algorithm to Use": "HOTP",
        "One Time Password Length ": "6",
        "TOTP Time Steps": 2,
        "Truncation Offset": -1,
        "HOTP Window Size": 100,
        "Authentication Level": 0
      }
    },
    ...
}
```

Analyze each module option and suggest security and performance improvements.
Consider an optimal tradeoff between security and user experience
Provide a recommended value for each option where possible and there is a difference from provided value
Format the response with proper indentation and consistent structure. The response format:
{ "modules": { <module_name>: {"settings": {"<option>": {"suggested_improvement": <suggested improvement>, "recommended_value": <recommended_value>}}}}}
omit any additional text

2025-06-09T10:21:51.533+03:00  INFO 11080 --- [OpenAM AI Analyzer] [           main] o.o.o.a.a.s.AccessManagerAnalyzerService : querying LLM for an answer...
2025-06-09T10:22:37.441+03:00  INFO 11080 --- [OpenAM AI Analyzer] [           main] o.o.openam.ai.analyzer.cmd.Runner        : modules advice:
{
  "modules" : {
    ...
    "LDAP" : {
      "settings" : {
        "LDAP Connection Heartbeat Interval" : {
          "suggested_improvement" : "Adjust based on network latency and reliability",
          "recommended_value" : "30"
        },
        "Bind User DN" : {
          "suggested_improvement" : "Use a less privileged account for binding",
          "recommended_value" : "cn=readonly,dc=openam,dc=example,dc=org"
        },
        "Minimum Password Length" : {
          "suggested_improvement" : "Increase minimum password length",
          "recommended_value" : "12"
        },
        "Primary LDAP Server" : {
          "suggested_improvement" : "Add failover servers",
          "recommended_value" : [ "openam1.example.org:50389", "openam2.example.org:50389" ]
        },
        "Trust All Server Certificates" : {
          "suggested_improvement" : "Disable to enforce certificate validation",
          "recommended_value" : false
        },
        "LDAP Connection Mode" : {
          "suggested_improvement" : "Use LDAPS for encrypted connections",
          "recommended_value" : "LDAPS"
        },
        "Authentication Level" : {
          "suggested_improvement" : "Increase authentication level for LDAP operations",
          "recommended_value" : "1"
        },
        "LDAPS Server Protocol Version" : {
          "suggested_improvement" : "Use latest TLS version",
          "recommended_value" : "TLSv1.2"
        }
      }
    },
    "OATH" : {
      "settings" : {
        "Minimum Secret Key Length" : {
          "suggested_improvement" : "Increase key length for better security",
          "recommended_value" : "64"
        },
        "TOTP Time Step Interval" : {
          "suggested_improvement" : "Balance between security and usability",
          "recommended_value" : "60"
        },
        "Maximum Allowed Clock Drift" : {
          "suggested_improvement" : "Allow slight clock drift",
          "recommended_value" : "1"
        },
        "OATH Algorithm to Use" : {
          "suggested_improvement" : "Use TOTP instead of HOTP for better security",
          "recommended_value" : "TOTP"
        },
        "One Time Password Length" : {
          "suggested_improvement" : "Increase OTP length",
          "recommended_value" : "8"
        },
        "Authentication Level" : {
          "suggested_improvement" : "Increase authentication level for OATH",
          "recommended_value" : "2"
        }
      }
    },
  }
}
```

Как видно из вывода команды выше (JSON был отформатирован для удобства чтения), приложение получает от OpenAM конфигурацию модулей аутентификации, формирует промпт для анализа конфигурации в LLM, и возвращает результат в JSON формате.

Давайте посмотрим, какие рекомендации по настройке возвращает LLM и можно ли их использовать.

Возьмем для примера модуль аутентификации через LDAP и возьмем рекомендацию по настройке `Bind User DN: cn=Directory Manager` . Рекомендация LLM по этой настройке:

```json
"Bind User DN" : {
  "suggested_improvement" : "Use a less privileged account for binding",
  "recommended_value" : "cn=readonly,dc=openam,dc=example,dc=org"
},
```

LLM рекомендует использовать учетную запись с меньшими привилегями для аутентификации. Действительно, `cn=Directory Manager` имеет административные права, хотя учетной записи с правами только для чтения вполне достаточно для реализации аутентификации.

Рассмотрим еще один пример для модуля OATH - модуль аутентификации при помощи одноразовых паролей. Для настройки `OATH Algorithm to Use: HOTP` рекомендация LLM вернулась следующая:

```json
"OATH Algorithm to Use" : {
  "suggested_improvement" : "Use TOTP instead of HOTP for better security",
  "recommended_value" : "TOTP"
},
```

LLM рекомендует использовать [TOTP](https://en.wikipedia.org/wiki/Time-based_one-time_password) вместо [HOTP](https://en.wikipedia.org/wiki/HOTP). Действительно, алгоритм TOTP (Time-based one-time password**)** для аутентификации при помощи одноразовых паролей пришел на смену HOTP (HMAC-based one-time password), является более надежным и рекомендуется для использования.

То есть, рекомендации LLM при анализе систем управления доступом вполне можно принимать во внимание.

Теперь немного технических деталей. Опишем, как именно приложение формирует промпт для анализа.

### Получение конфигурации OpenAM через API

Приложение вызывает несколько API для получения настроек и их значений из OpenAM. Для простоты, вместо программных вызовов API будем использовать примеры с использованием утилиты [curl](https://curl.se/).

Для начала получим токен аутентификации OpenAM

```
curl -X POST \
 --header "X-OpenAM-Username: amadmin" \
 --header "X-OpenAM-Password: passw0rd" \
 http://openam.example.org:8080/openam/json/authenticate
 
{
   "realm" : "/",
   "successUrl" : "/openam/console",
   "tokenId" : "AQIC5wM2LY4SfcyDgAXiN7z4jGvfcK9CKHghI-BGMriZUGM.*AAJTSQACMDEAAlNLABEyMTc1NDgwMDA5MzUxMTczOQACUzEAAA..*"
}
```

Токен (поле `tokenId`) из полученного ответа будем использовать для получения конфигурации OpenAM.

Получим список модулей аутентификации:

```
curl -H "iPlanetDirectoryPro: AQIC5wM2LY4SfcyDgAXiN7z4jGvfcK9CKHghI-BGMriZUGM.*AAJTSQACMDEAAlNLABEyMTc1NDgwMDA5MzUxMTczOQACUzEAAA..*" \
  -H "Accept: application/json" \
  "http://openam.example.org:8080/openam/json/realms/root/realm-config/authentication/modules?_queryFilter=true"

{
   "pagedResultsCookie" : null,
   "remainingPagedResults" : -1,
   "result" : [
      {
         "_id" : "HOTP",
         "_rev" : "120870935",
         "type" : "hotp",
         "typeDescription" : "HOTP"
      },
      ...
      {
         "_id" : "LDAP",
         "_rev" : "1968417813",
         "type" : "ldap",
         "typeDescription" : "LDAP"
      }
   ],
   "resultCount" : 8,
   "totalPagedResults" : 8,
   "totalPagedResultsPolicy" : "EXACT"
}  
  
```

Для каждого из модулей получим настройки

```
curl -H "iPlanetDirectoryPro: AQIC5wM2LY4SfcyDgAXiN7z4jGvfcK9CKHghI-BGMriZUGM.*AAJTSQACMDEAAlNLABEyMTc1NDgwMDA5MzUxMTczOQACUzEAAA..*" \
  -H "Accept: application/json" \
  "http://openam.example.org:8080/openam/json/realms/root/realm-config/authentication/modules/oath/OATH"
  
{
   "_id" : "OATH",
   "_rev" : "37804103",
   "_type" : {
      "_id" : "oath",
      "collection" : true,
      "name" : "OATH"
   },
   "addChecksum" : "False",
   "authenticationLevel" : 0,
   "forgerock-oath-maximum-clock-drift" : 0,
   "forgerock-oath-observed-clock-drift-attribute-name" : "",
   "forgerock-oath-sharedsecret-implementation-class" : "org.forgerock.openam.authentication.modules.oath.plugins.DefaultSharedSecretProvider",
   "hotpCounterAttribute" : "",
   "hotpWindowSize" : 100,
   "lastLoginTimeAttribute" : "",
   "minimumSecretKeyLength" : "32",
   "oathAlgorithm" : "HOTP",
   "passwordLength" : "6",
   "secretKeyAttribute" : "",
   "stepsInWindow" : 2,
   "timeStepSize" : 30,
   "truncationOffset" : -1
}
```

И для того, чтобы LLM понимала, что каждая настройка обозначает, получим описание настроек из метаданных OpenAM

```
curl -X "POST" \
  -H "iPlanetDirectoryPro: AQIC5wM2LY4SfcyDgAXiN7z4jGvfcK9CKHghI-BGMriZUGM.*AAJTSQACMDEAAlNLABEyMTc1NDgwMDA5MzUxMTczOQACUzEAAA..*" \
  -H "Accept: application/json" \
  "http://openam.example.org:8080/openam/json/realms/root/realm-config/authentication/modules/oath?_action=schema"
{
   "properties" : {
      "addChecksum" : {
         "description" : "This adds a checksum digit to the OTP.<br><br>This adds a digit to the end of the OTP generated to be used as a checksum to verify the OTP was generated correctly. This is in addition to the actual password length. You should only set this if your device supports it.",
         "enum" : [
            "True",
            "False"
         ],
         "exampleValue" : "",
         "options" : {
            "enum_titles" : [
               "Yes",
               "No"
            ]
         },
         "propertyOrder" : 800,
         "required" : true,
         "title" : "Add Checksum Digit",
         "type" : "string"
      },
      "authenticationLevel" : {
         "description" : "The authentication level associated with this module.<br><br>Each authentication module has an authentication level that can be used to indicate the level of security associated with the module; 0 is the lowest (and the default).",
         "exampleValue" : "",
         "propertyOrder" : 100,
         "required" : true,
         "title" : "Authentication Level",
         "type" : "integer"
      },
     ...
      "timeStepSize" : {
         "description" : "The TOTP time step in seconds that the OTP device uses to generate the OTP.<br><br>This is the time interval that one OTP is valid for. For example, if the time step is 30 seconds, then a new OTP will be generated every 30 seconds. This makes a single OTP valid for only 30 seconds.",
         "exampleValue" : "",
         "propertyOrder" : 1000,
         "required" : true,
         "title" : "TOTP Time Step Interval",
         "type" : "integer"
      },
      "truncationOffset" : {
         "description" : "This adds an offset to the generation of the OTP.<br><br>This is an option used by the HOTP algorithm that not all devices support. This should be left default unless you know your device uses a offset.",
         "exampleValue" : "",
         "propertyOrder" : 900,
         "required" : true,
         "title" : "Truncation Offset",
         "type" : "integer"
      }
   },
   "type" : "object"
}

```

Соберем все данные вместе и в результате получим данные для промпта к LLM.

```json
{
  "modules": [
    ...
    {
      "name": "LDAP",
      "settings": {
        "LDAP Connection Heartbeat Interval": 10,
        "Bind User DN": "cn=Directory Manager",
        "LDAP Connection Heartbeat Time Unit": "SECONDS",
        "Return User DN to DataStore": true,
        "Minimum Password Length": "8",
        "Search Scope": "SUBTREE",
        "Primary LDAP Server": [
          "openam.example.org:50389"
        ],
        "Attributes Used to Search for a User to be Authenticated": [
          "uid"
        ],
        "DN to Start User Search": [
          "dc=openam,dc=example,dc=org"
        ],
        "Overwrite User Name in sharedState upon Authentication Success": false,
        "User Search Filter": null,
        "LDAP Behera Password Policy Support": true,
        "Trust All Server Certificates": false,
        "Secondary LDAP Server": [],
        "LDAP Connection Mode": "LDAP",
        "Authentication Level": 0,
        "Attribute Used to Retrieve User Profile": "uid",
        "Bind User Password": null,
        "LDAP operations timeout": 0,
        "User Creation Attributes": [],
        "LDAPS Server Protocol Version": "TLSv1"
      }
    },
    {
      "name": "OATH",
      "settings": {
        "Minimum Secret Key Length": "32",
        "Clock Drift Attribute Name": "",
        "Counter Attribute Name": "",
        "TOTP Time Step Interval": 30,
        "The Shared Secret Provider Class": "org.forgerock.openam.authentication.modules.oath.plugins.DefaultSharedSecretProvider",
        "Add Checksum Digit": "False",
        "Maximum Allowed Clock Drift": 0,
        "Last Login Time Attribute": "",
        "Secret Key Attribute Name": "",
        "OATH Algorithm to Use": "HOTP",
        "One Time Password Length ": "6",
        "TOTP Time Steps": 2,
        "Truncation Offset": -1,
        "HOTP Window Size": 100,
        "Authentication Level": 0
      }
    },
    ...
```

### Запрос рекомендаций от LLM при помощи Spring AI

Сформируем промпт для LLM

Из файла конфигурации `application.yaml` возьмем системный промпт, который даст LLM понять контекст задачи и собственную роль:

```java
var systmMessage = new SystemMessage(promptConfiguration.system())
```

В шаблон пользовательского промпта вставим полученную из OpenAM конфигурацию модулей аутентификации и запросим рекомендации. 

```java
var userTemplate = PromptTemplate.builder()
                .renderer(StTemplateRenderer.builder().startDelimiterToken('<').endDelimiterToken('>').build())
                .template(promptConfiguration.modules().user())
          .build();

var userMessage = userTemplate.render(Map.of("modules", promptModulesJson))
        .concat(System.lineSeparator())
  .concat(promptConfiguration.modules().task());

```

Соберем итоговый промпт для LLM:

```java
var propmt = Prompt.builder().messages(
        new SystemMessage(systmMessage),
        new UserMessage(userMessage)).build();
```

Итоговый промпт вместе с данными из OpenAM:

```
SYSTEM: You are an information security expert with 20 years of experience.
USER: I have an access management system with the following modules:
```json
{
  "modules": [
    ...
    {
      "name": "LDAP",
      "settings": {
        "LDAP Connection Heartbeat Interval": 10,
        "Bind User DN": "cn=Directory Manager",
        "LDAP Connection Heartbeat Time Unit": "SECONDS",
        "Return User DN to DataStore": true,
        "Minimum Password Length": "8",
        "Search Scope": "SUBTREE",
        "Primary LDAP Server": [
          "openam.example.org:50389"
        ],
        "Attributes Used to Search for a User to be Authenticated": [
          "uid"
        ],
        "DN to Start User Search": [
          "dc=openam,dc=example,dc=org"
        ],
        "Overwrite User Name in sharedState upon Authentication Success": false,
        "User Search Filter": null,
        "LDAP Behera Password Policy Support": true,
        "Trust All Server Certificates": false,
        "Secondary LDAP Server": [],
        "LDAP Connection Mode": "LDAP",
        "Authentication Level": 0,
        "Attribute Used to Retrieve User Profile": "uid",
        "Bind User Password": null,
        "LDAP operations timeout": 0,
        "User Creation Attributes": [],
        "LDAPS Server Protocol Version": "TLSv1"
      }
    },
    {
      "name": "OATH",
      "settings": {
        "Minimum Secret Key Length": "32",
        "Clock Drift Attribute Name": "",
        "Counter Attribute Name": "",
        "TOTP Time Step Interval": 30,
        "The Shared Secret Provider Class": "org.forgerock.openam.authentication.modules.oath.plugins.DefaultSharedSecretProvider",
        "Add Checksum Digit": "False",
        "Maximum Allowed Clock Drift": 0,
        "Last Login Time Attribute": "",
        "Secret Key Attribute Name": "",
        "OATH Algorithm to Use": "HOTP",
        "One Time Password Length ": "6",
        "TOTP Time Steps": 2,
        "Truncation Offset": -1,
        "HOTP Window Size": 100,
        "Authentication Level": 0
      }
    },
    ...
}
```

Analyze each module option and suggest security and performance improvements.
Consider an optimal tradeoff between security and user experience.
Provide a recommended value for each option where possible and there is a difference from the provided value.
Format the response with proper indentation and consistent structure. The response format:
{ "modules": { <module_name>: {"settings": {"<option>": {"suggested_improvement": <suggested improvement>, "recommended_value": <recommended_value>}}}}}
omit any additional text

```

Отправим полученный промпт в LLM и выведем в лог полученный результат:

```java
var clientPrompt = chatClient.prompt(prompt).advisors(new SimpleLoggerAdvisor());
var modulesAdvice = clientPrompt.call().entity(Map.class);
logger.info("modules advice:\n{}", objectMapper.writerWithDefaultPrettyPrinter().writeValueAsString(modulesAdvice));
```

## Локальный запуск приложения

Вы можете адаптировать решение для использования в своей инфраструктуре:

Конфигурация приложения осуществляется через файл [`application.yaml`](https://github.com/OpenIdentityPlatform/openam-ai-analyzer/blob/master/src/main/resources/application.yml).

Описание опций приведено в таблице ниже:

| Option | Description |
| --- | --- |
| `spring.ai.openai.base_url` | Исходный адрес API LLM |
| `spring.ai.openai.api-key` | Ключ API модели |
| `spring.ai.openai.chat.options.model` | Вид LLM модели |
| `spring.ai.openai.chat.options.temperature` | Температура. Чем ниже температура, тем более детерминирован ответ от LLM |
| `prompt.system` | Общий системный промпт |
| `prompt.modules.user` | Промпт пользователя для анализа модулей аутентификации |
| `prompt.modules.task` | Промпт задачи для LLM на анализ модулей аутентификации |
| `prompt.flows.user` | Промпт пользователя для анализа цепочек аутентификации |
| `prompt.flows.task` | Промпт задачи для LLM для анализа цепочек аутентификации |
| `openam.url` | URL OpenAM |
| `openam.login` | Логин учетной записи OpenAM |
| `openam.password` | Пароль учетной записи OpenAM |

## Заключение

LLM показала довольно неплохие результаты аудита конфигурации OpenAM. Искусственный интеллект может выявлять уязвимости в конфигурации и предлагает рекомендации, соответствующие современным стандартам информационной безопасности.

В качестве следующих шагов можно расширить приложение для анализа политик авторизации, параметров подключения к внешним источникам данных, а также реализовать на базе разработанного приложения [MCP](https://modelcontextprotocol.io/introduction) сервер для автоматизации конфигурации систем управления доступом через LLM.
