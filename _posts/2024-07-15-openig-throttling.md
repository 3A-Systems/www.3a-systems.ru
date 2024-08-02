---
layout: blog
title: 'Контроль пропускной способности (троттлинг) API c помощью шлюза авторизации OpenIG'
description: 'Эта статья является продолжением серии статей о защите веб сервисов при помощи шлюза с открытым исходным кодом OpenIG. В этой статье мы рассмотрим, как защитить сервисы, ограничив количество запросов за определенный интервал времени.'
tags: 
  - openig

---
Эта статья является продолжением [серии](https://github.com/OpenIdentityPlatform/OpenIG/wiki/How-To-Protect-Web-Services-with-OpenIG) [статей](https://github.com/OpenIdentityPlatform/OpenIG/wiki/How-to-Protect-WebSocket-Connection-with-OpenAM-and-OpenIG) о защите веб сервисов при помощи шлюза с открытым исходным кодом [OpenIG](https://github.com/OpenIdentityPlatform/OpenIG). В этой статье мы рассмотрим, как защитить сервисы, ограничив количество запросов за определенное время времени.

## Введение

Для чего нужно ограничивать количество запросов? Опытные коллеги могут пропустить этот раздел и сразу перейти к разделу настройки. 

- **Борьба с [DDoS](https://en.wikipedia.org/wiki/Denial-of-service_attack#Distributed_DoS) атаками.** DDoS атаки - одни из самых распространенных. Цель атаки - перегрузить атакуемый сервис большим количеством запросов. Сервис не успевает обработать все запросы, время отклика растет, и сервис просто перестает отвечать. Аналогичная ситуация возможна при неожиданном наплыве клиентов на сервис, что очень похоже на DDoS атаку.
- **Контроль соглашения об уровне обслуживания.** Допустим, организация предоставляет API с разными уровнями обслуживания. Например, обычный клиент может осуществлять 10 вызовов API в минуту, а премиальный клиент до 1000.
- **Предотвращение “слива” базы данных**. Например, при обычной работе сотрудник может запрашивать данные по 5 клиентам в минуту, и если он превышает этот лимит, то такое поведение похоже на попытку скачивания всей базы. Ограничение количества вызовов помогает предотвратить такую атаку.

## Демонстрационный проект

Для демонстрационных целей клонируйте проект командой

```bash
git clone -b features/throttling https://github.com/maximthomas/openig-protect-ws.git
```

И запустить его командой 

```bash
docker compose up
```

### Краткое описание демо проекта

В файле `docker-compose.yaml` описано 2 сервиса - OpenIG и демонстрационной сервис sample-service, который защищен OpenIG. 

В демонстрационном сервисе две конечные точки - корневая `/`, доступ к которой имеют все пользователи и `/secure` доступ к которой имеют только аутентифицированные пользователи.

К этим конечным точкам в OpenIG прописаны маршруты `openig-config/config/routes/10-api.json` и `openig-config/config/routes/20-secure.json` соотвественно.

Для авторизации в `/secure` используется JWT, подписанный приватным ключом `openig-config/keys/private_key.pem` .  

Фильтр `ScriptableFilter` при помощи скрипта `openig-config/scripts/groovy/jwt.groovy` разбирает JWT, проверяет подпись публичным ключом `openig-config/config/config.json` и пишет в контекст claims `role` и `sub`. 

В файле `openig-config/config/config.json` описаны фильтры, которые срабатывают для всех маршрутов, а так же определены фильтры, которые могут быть использованы в произвольных маршрутах.

Подробнее настройка была описана в [статье](https://github.com/OpenIdentityPlatform/OpenIG/wiki/How-To-Protect-Web-Services-with-OpenIG)

## Настройка ограничения запросов

### Базовая настройка

Теперь, когда у вас запущен OpenIG и защищаемый сервис, добавим в маршрут фильтр, который ограничивает все не аутентифицированные запросы к сервису с ограничением - не более 5 запросов в 5 секунд.

Откройте файл маршрута `10-api.json` в директории `openig-config/config/routes` и добавьте в цепочку фильтров фильтр  с типом `ThrottlingFilter` .

Атрибуты `numberOfRequests` и `duration` объекта `rate` определяют лимит запросов за период времени соотвественно.

`10-api.json`

```json
{
  "name": "${matches(request.uri.path, '^/$')}",
  "condition": "${matches(request.uri.path, '^/$')}",
  "monitor": true,
  "timer": true,
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [
        {
          "type": "ThrottlingFilter",
          "name": "simple-throttling",
          "config": {
            "requestGroupingPolicy": "",
            "rate": {
              "numberOfRequests": 5,
              "duration": "5 s"
            }
          }
        },
...       
```

### Ограничения запросов с группировкой.

DDoS атаки ведутся только с фиксированного набора IP адресов. И для обеспечения нормальной работы пользователей можно ограничить количество запросов для каждого IP адреса. 

Добавим в атрибут `requestGroupingPolicy`  фильтра `ThrottlingFilter` IP адрес запроса:

```json
{
  "type": "ThrottlingFilter",
  "name": "simple-throttling",
  "config": {
    "requestGroupingPolicy": "${(not empty request.headers['X-Real-Ip'][0])?request.headers['X-Real-Ip'][0]:contexts.client.remoteAddress}",
    "rate": {
      "numberOfRequests": 5,
      "duration": "5 s"
    }
  }
},
```

В выражении из листинга выше, OpenIG проверяет сначала значение заголовка, `X-Real-Ip` (этот заголовок может выставлять балансировщик нагрузки), и если оно не пустое, использует его, если же пустое, использует IP адрес запроса.

Проверим настройку, выполнив команду curl несколько раз

```bash
for i in `seq 7`; \
 do curl --trace-time -v -H "Content-Type: application/json" -H "Accept: application/json" --data '{"test": "test"}' http://localhost:8080; \
done 2>&1 | grep '< HTTP'
15:55:44.207986 < HTTP/1.1 200 
15:55:45.237957 < HTTP/1.1 200 
15:55:45.278702 < HTTP/1.1 200 
15:55:45.319421 < HTTP/1.1 200 
15:55:45.352789 < HTTP/1.1 200 
15:55:45.376685 < HTTP/1.1 429 
15:55:45.395739 < HTTP/1.1 429 
```

По выводу команды curl видно, что на запросы, начиная с шестого OpenIG возвращает HTTP статус 429. 

Пример полного ответа:

```bash
15:56:09.535261 < HTTP/1.1 429 
15:56:09.535302 < Retry-After: 1
15:56:09.535330 < Retry-After-Partition: 10.1.1.5
15:56:09.535357 < Retry-After-Rate: 5/5 SECONDS
15:56:09.535384 < Retry-After-Rule: simple-throttling
...
```

Обратите внимание на заголовки, которые возвращает `ThrottlingFilter` при превышении лимита:

| Заголовок | Описание |
| --- | --- |
| Retry-After | Количество секунд, которое необходимо ждать до следующего запроса |
| Retry-After-Partition | Значение группировки, по которой ведется подсчет частоты запросов |
| Retry-After-Rate | Допустимая частота запросов |
| Retry-After-Rule | Имя фильтра OpenIG |

### Ограничения по значению атрибута

Теперь настроим ограничение более гибко. Установим ограничения для аутентифицированных пользователей на конечную точку `/secure`. Ограничение будет работать индивидуально для каждого пользователя, аналогично IP адресу из примера выше.  Ограничения будут сгруппированы по значению JWT claim`sub`. Обычные пользователи могут отправлять максимум 5 запросов за 10 секунд, а пользователи с ролью `supervisor`, которым нужен существенно большей объем данных - могут отправлять до 10 запросов за 10 секунд. Значение свойства будет браться из claim JWT  `role` в скрипте `jwt.groovy`.

Добавим в маршрут `20-secure.json` фильтр `ThrottlingFilter` после фильтра `ScriptableFilter`, который разбирает JWT.

```json
{
  "type": "ThrottlingFilter",
  "name": "auth-users-throttling",
  "config": {
    "requestGroupingPolicy": "${attributes['sub']}",
    "throttlingRatePolicy": {
      "type": "MappedThrottlingPolicy",
      "config": {
        "throttlingRateMapper": "${attributes['role']}",
        "throttlingRatesMapping": {
          "supervisor": {
            "numberOfRequests": 10,
            "duration": "5 s"
          }
        },
        "defaultRate": {
          "numberOfRequests": 5,
          "duration": "5 s"
        }
      }
    }
  }
}
```

Вместо объекта `rate` добавим `throttlingRatePolicy` с типом `MappedThrottlingPolicy`

Таким образом для JWT с ролью `supervisor` допустимо 10 запросов за 10 секунд, для всех остальных - 5 запросов.

Проверим ограничения для обычного пользователя:

```bash
export OPENAM_JWT=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzYW1wbGUtc2VydmljZSIsInN1YiI6IjEyMzQ1Njc4OTAiLCJuYW1lIjoiSm9obiBEb2UiLCJyb2xlIjoibWFuYWdlciIsImlhdCI6MTUxNjIzOTAyMiwiZXhwIjoxNzI2MjM5MDIyfQ.bhzhwj2cY1iYbpx7Mzbukfi1jOCvWP-Pdd9dm3hf7lZDDuokNVDUXU3jvHial4QN-bOTSNCUKVy907hokcVeQaFwbiYoZs485Kr230Z0y9MU6zbDe8yQp68-71TDgJGIZ78YYOKvJTrzCWgWgE_Py1DskG_ViSxfGFlETpFQa056Rk2bty-9iuc_Cx5_Wr6RCcJTG6WYRrBtdWGIFxljEjxSAcJYmGPPA8dHHORDOnmka2OAjWURnsqbz50aI_SrWpnqp4i2eXVA1b5QD5rlsgc_QAqJptghrijBlRPhasTk1N-kXE8Ozboa0FwGfIRr7gNiG-3if7INZe2R5NUCmjlAlywcSfOunWuSzY8tLGTHV2swnQPP8lBXwVJcS5nJMqBNIbcLcFWHk3ryvvtf-LYty_jAY8v1zDe9-DwFPWI0rry8fmiZj7yhAnvX5EHZHvSQtp_zyPpVWvOXFPwasI0jdKoxhWvyJpbmw-D95J5CgJAMfkrWPDQKVt3ipebwnMJStA3xAPPyl28mTBYhJrT6gzIOS3DseoVKK4adn34ZrQi2Hm-wyUtbdulopK739MKM73NYgoFXSJeVUqcy4iw3-In5XmOhdRnUL50TSiaNBbkys8iK7r00HD3kI3CH0GfaPdrcgRgaFXKmVDhX-tEaPJYcuEUTHfQAxWwMdiw 
for i in `seq 7`; \
 do curl --trace-time -v GET -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer ${OPENAM_JWT}" http://localhost:8080/secure; \
done 2>&1 | grep '< HTTP'
15:57:33.514169 < HTTP/1.1 200 
15:57:33.545997 < HTTP/1.1 200 
15:57:33.580583 < HTTP/1.1 200 
15:57:33.615292 < HTTP/1.1 200 
15:57:33.647661 < HTTP/1.1 200 
15:57:33.672396 < HTTP/1.1 429 
15:57:33.696753 < HTTP/1.1 429 
```

Ограничения для супервизора:

```bash
export OPENAM_JWT_SUPERVISOR=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzYW1wbGUtc2VydmljZSIsInN1YiI6IjEyMzQ1Njc4OTAiLCJuYW1lIjoiSm9obiBEb2UiLCJyb2xlIjoic3VwZXJ2aXNvciIsImlhdCI6MTUxNjIzOTAyMiwiZXhwIjoxNzI2MjM5MDIyfQ.ccigmz0n1gP1fIe0HP5jMAjHWKkD1cwAViGfSapfVZ86GxKY9wkOWegYABmDyEXWwHWAcwFFFu1ZF7JYRiBmci87cRj5MSbw6Mrb1M_8rZj6aP9y9qTyWY80PtMJw6Udcn_wqvfCeMlKLlaItnUYc6-bth1rb_tJNd9FxDcpMZt-5q1uMGfeEPWsyF4a81kSFmNr2aD4rp8ftpLv6VoObkEdYmwkn9aRKLAxNjD9Ze8rdKQBgCk_rR3hTzURyPO_2QZsLDfpPMQx0O3Qbx9x_4om5D_hlrBOdNp6k435J1ZT2sllaJaP_HEQSGgWAwS1I9me9jwfIuA-Fhcxa6si7P0MlSX7Bj6Zki492RBvw2dsspnDZ_BOiVFteMYorS2KZoahQyYtxPubZSdCNqJ3fG8qX3zDj1EESS2srFQrF6baZfpJMHUNMCO_2QSioBBi8ffatG2snwHLQKiTr2TD-YqBx_rU3BGV3wGa9bXSAaTJCvn9x8Id_ie8x5xfaZXJL0r0gunj1LZuYKsNjo4VMMTn-pu5UZtttg9s30OozCEzvC5fM3LXDR2R_klanvFWWQlDabiF1kUnzQuSD9uj37pnbHgv0NOG3RePO0hujqelmj5HVzEE-h6ULKeUKJAxNZ9otMJb25RpQr_cZvIX3UPzFbLqbI7hyfzjZP6258Q

for i in `seq 12`; \
 do curl --trace-time -v GET -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer ${OPENAM_JWT_SUPERVISOR}" http://localhost:8080/secure; \
done 2>&1 | grep '< HTTP'
15:58:05.830975 < HTTP/1.1 200 
15:58:05.860576 < HTTP/1.1 200 
15:58:05.890634 < HTTP/1.1 200 
15:58:05.922926 < HTTP/1.1 200 
15:58:05.957944 < HTTP/1.1 200 
15:58:05.986881 < HTTP/1.1 200 
15:58:05.019237 < HTTP/1.1 200 
15:58:05.051065 < HTTP/1.1 200 
15:58:05.084710 < HTTP/1.1 200 
15:58:05.114731 < HTTP/1.1 200 
15:58:05.140818 < HTTP/1.1 429 
15:58:05.165421 < HTTP/1.1 429 
```