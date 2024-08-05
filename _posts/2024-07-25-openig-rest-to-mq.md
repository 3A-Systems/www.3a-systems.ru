---
layout: blog
title: 'Интеграция REST и MQ брокеров сообщений через шлюз OpenIG'
description: 'В статье рассмотрены варианты конвертации сообщений из REST в брокер сообщений и обратно, а так же возможные варианты использования такого подхода.'
tags: 
  - openig

---

## Для чего это нужно

Конвертация сообщений между брокером и REST упрощает прием и отправку сообщений без использования нативных протоколов или клиентский приложений брокеров сообщений:

Возможные варианты использования:

- Асинхронное взаимодействие между сервисами. Конвертация REST запросов в сообщения брокера способствует ослаблению связи между сервисами, способствует увеличению производительности и устойчивости к ошибкам
- Сбор логов. Мобильные приложения могут отправлять логи своей работы через REST в брокер сообщений.
- Согласование протоколов. Не все приложения имеют возможность взаимодействия через брокеры сообщений, для их интеграции используется конвертация REST-брокер сообщений.
- Пересечение сегментов. Сегменты предприятия, как правило, разделены и взаимодействуют между собой, используя брокер сообщений.

В статье мы настроим шлюз с открытым исходным кодом OpenIG для конвертации сообщений брокера в REST и обратно. 

## Подготовка к работе

Предположим, у вас уже установлен и настроен OpenIG. Если же нет, то как быстро это сделать, описано в статье [How To Protect Web Services with OpenIG](https://github.com/OpenIdentityPlatform/OpenIG/wiki/How-To-Protect-Web-Services-with-OpenIG).

Вы можете так же использовать демонстрационный проект https://github.com/maximthomas/openig-mb-example как стартовую точку

## Варианты использования

### Отправка HTTP запросов в Apache Kafka

Настройка позволяет получать сообщения по HTTP протоколу и отправлять их в Apache Kafka.

Добавьте в файл конфигурации OpenIG `config.json` в обработчик Kafka producer:

```json
{
  "heap": [
    ...
    {
      "name": "kafka-producer",
      "type": "MQ_Kafka",
      "config": {
        "bootstrap.servers": "kafka:9092",
        "topic.produce": "incoming-messages"
      }
    },
    ...
  ]
} 
```

Важные настройки обработчика:

| Настройка | Описание |
| --- | --- |
| boostrap.server | Список хотсто и портов Apache Kafka, указанные через запятую |
| topic.produce | Топик, в который OpenIG отправляет сообщения |
| topic.consume | Топик, из которого OpenIG читает сообщения |
| uri | Конечная точка маршрута OpenIG |
| method | Метод HTTP, который использует OpenIG для отправки запросов по HTTP |

Добавьте маршрут OpenIG, который получать HTTP запросы и отправлять сообщения в Apache Kafka:

`routes/10-http2kafka.json`:

```json
{
  "name": "${(request.method == 'PUT') and matches(request.uri.path, '^/http2kafka$')}",
  "condition": "${(request.method == 'PUT') and matches(request.uri.path, '^/http2kafka$')}",
  "monitor": true,
  "timer": true,
  "handler": {
    "type": "Chain",
    "config": {
    "filters": [],
      "handler": {
        "type": "DispatchHandler",
        "config": {
          "bindings": [
            {
              "handler": "kafka-consumer"
            }
          ]
        }
      }
    }
  }
```

Примеры файлов конфигурации находятся в проекте в директории `openig/config`

Запустите Docker контейнеры командой

```bash
docker compose -f docker-compose.yml up
```

Создайте топик для Apache Kafka. Пример команды для Docker контейнера:

```bash
docker exec openig-mb-example-kafka-1 kafka-topics.sh --create --topic topic1 --bootstrap-server localhost:9092
```

Отправьте HTTP запрос в OpenIG и проверьте сообщения в созданном топике:

```bash
curl -v -X PUT --data '{"data": "test"}' -H 'Content-Type: application/json' 'http://localhost:8080/http2kafka'
*   Trying 127.0.0.1:8080...
* TCP_NODELAY set
* Connected to localhost (127.0.0.1) port 8080 (#0)
> PUT /http2kafka HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/7.68.0
> Accept: */*
> Content-Type: application/json
> Content-Length: 16
> 
* upload completely sent off: 16 out of 16 bytes
* Mark bundle as not supporting multiuse
< HTTP/1.1 202 Accepted
< Server: Apache-Coyote/1.1
< Content-Length: 0
< Date: Wed, 13 Apr 2022 12:34:03 GMT
< 
* Connection #0 to host localhost left intact
```

```bash
docker exec openig-mb-example-kafka-1 kafka-console-consumer.sh --topic topic1 --from-beginning --bootstrap-server localhost:9092
{"data": "test"}
```

### Отправка сообщений Kafka в HTTP

В следующей конфигурации OpenIG будет получать сообщения и топика `topic2` Apache Kafka и отправлять их на конечную точку HTTP.  

Потушите Docker контейнеры командой

```bash
docker compose -f docker-compose.yml down
```

Добавьте в файл конфигурации обработчик Kafka producer.

`config.json`

```json
{
  "heap": [
    ...
    {
      "name": "kafka-consumer",
      "type": "MQ_Kafka",
      "config": {
        "bootstrap.servers": "kafka:9092",
        "topic.consume": "topic2",
        "method": "POST"
      }
    },
    ...
  ]
}
```

Добавьте в OpenIG маршрут, который будет слушать сообщения из Apache Kafka и перенаправлять их на конечную точку HTTP.

`routes/10-kafka2http.json`

```json
{
  "name": "${(request.method == 'POST') and matches(request.uri.path, '^/kafka2http$')}",
  "condition": "${(request.method == 'POST') and matches(request.uri.path, '^/kafka2http$')}",
  "monitor": true,
  "timer": true,
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [],
      "handler": {
      "type": "DispatchHandler",
        "config": {
          "bindings": [{
              "handler": "ClientHandler",
              "capture": "all",
              "baseURI": "${system['endpoint.api']}"
          }]
        }
      }
    }
  }
}
```

Обратите внимание на свойство `baseURI` . В нем указан URI конечной точки HTTP. Значение берется из системного свойства. указанного в файле `docker-compose.yaml
-Dendpoint.api=http://sample-service:8080` для сервиса OpenIG

Добавьте в Apache Kafka топик `topic2`, из которого OpenIG будет читать сообщения и перенаправлять их на конечную точку HTTP.

```bash
docker exec openig-mb-example-kafka-1 kafka-topics.sh --create --topic topic2 --bootstrap-server localhost:9092
```

Отправим тестовые данные в созданный топик:

```bash
docker exec -it openig-mb-example-kafka-1 kafka-console-producer.sh --topic topic2 --bootstrap-server localhost:9092
>{"data": "test"}
```

В логе сервиса `sample-service`  на конечную точку которого OpenIG перенаправляет сообщения появится запись:

```bash
2024-07-05T08:46:37.540Z DEBUG 1 --- [nio-8080-exec-1] o.s.w.f.CommonsRequestLoggingFilter      : After request [POST /kafka2http, headers=[correlation-id:"8dd45456-433d-42cb-b992-27047ae75ed9", kafka-offset:"0", kafka-timestamp:"1720169196044", kafka-timestamp-date:"Fri Jul 05 08:46:36 UTC 2024", kafka-topic:"topic2", content-length:"16", host:"sample-service:8080", connection:"Keep-Alive", user-agent:"Apache-HttpAsyncClient/4.1.4 (Java/17.0.9)"], payload={"data": "test"}]
```

### Настройка встроенного в OpenIG Apache Kafka

Если в инфраструктуре предприятия нет брокера сообщений, но есть потребность получать и перенаправлять сообщения брокера, то OpenIG предлагает встроенный брокер сообщений. Для использования встроенного Apache Kafka, добавьте в файл конфигурации OpenIG объект `EmbeddedKafka` 

`config.json`

```json
{
  "heap": [
    ...
      {
        "name": "EmbeddedKafka",
        "type": "EmbeddedKafka",
        "config": {
          "zookeper.port": "${system['zookeper.port']}",
          "security.inter.broker.protocol": "${empty system['keystore.location'] ?'PLAINTEXT':'SSL'}",
          "listeners": "${system['kafka.bootstrap']}",
          "advertised.listeners": "${system['kafka.bootstrap']}",
          "ssl.endpoint.identification.algorithm": "",
          "ssl.enabled.protocols":"TLSv1.2",
          "ssl.keystore.location":"${system['keystore.location']}",
          "ssl.keystore.password":"${empty system['keystore.password']?'changeit':system['keystore.password']}",
          "ssl.key.password":"${empty system['key.password']?'changeit':system['key.password']}",
          "ssl.truststore.location":"${system['truststore.location']}",
          "ssl.truststore.password":"${empty system['truststore.password']?'changeit':system['truststore.password']}"			
        },
    ...
  ]
}
```

Важные настройки `EmbeddedKafka`:

| Настройка | Описание |
| --- | --- |
| zookeper.port | Порт Zookeper для встроенного Apache Kafka. Если не установлен, Kafra не запустится |
| listeners | Имена хостов и порты, которые будет слушать встроенный Apache Kafka. |
| advertised.listeners | Имена хостов и порты клиентов встроенного Apache Kafka. |

Добавьте Kafka listener в массив heap OpenIG и создайте маршрут, который будет слушать сообщения Kafka и перенаправлять их на конечную точку HTTP (вы можете так же перенаправлять сообщения на другой брокер).

`config.json`

```json
{
  "heap": [
    ...
      {
      "name": "kafka-consumer",
      "type": "MQ_Kafka",
      "config": {
        "bootstrap.servers": "openig:9092",
        "topic.consume": "topic1",
        "method": "POST",
        "uri": "/kafka2http"
      }
    ...
  ]
}
```

`10-kafka2http.json`

```json
{
  "name": "${(request.method == 'POST') and matches(request.uri.path, '^/kafka2http$')}",
  "condition": "${(request.method == 'POST') and matches(request.uri.path, '^/kafka2http$')}",
  "monitor": true,
  "timer": true,
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [],
      "handler": {
      "type": "DispatchHandler",
        "config": {
          "bindings": [{
              "handler": "ClientHandler",
              "capture": "all",
              "baseURI": "${system['endpoint.api']}"
          }]
        }
      }
    }
  }
```

Запустите OpenIG. Теперь вы можете создать topic и отправлять сообщения в этот topic.

```bash
$ kafka-console-producer.sh --topic topic1 --bootstrap-server localhost:9092
>{"data": "test"}
```

В тестовом сервисе в логе появится сообщение, перенаправленное OpenIG из брокера на конечную точку HTTP.

```
2022-04-21 07:26:14.645 DEBUG 1 --- [nio-8080-exec-6] o.s.w.f.CommonsRequestLoggingFilter      : After request [POST /kafka2http, headers=[kafka-offset:"29", kafka-topic:"topic2", content-length:"16", host:"sample-service:8080", connection:"Keep-Alive", user-agent:"Apache-HttpAsyncClient/4.1.4 (Java/1.8.0_212)"], payload={"data": "test"}]
```

## Интеграция с IBM MQ

### Отправка HTTP запросов в IBM MQ

Следующая настройка позволяет получать сообщения по HTTP протоколу и отправлять их в topic IBM MQ:

Добавьте обработчик IBM MQ Consumer в heap в файл конфигурации OpenIG:

`config.json`

```json
{
  "heap": [
    ...
    {
      "name": "mq-producer",
      "type": "MQ_IBM",
      "config": {
        "XMSC_WMQ_CONNECTION_NAME_LIST":"mq(1414)",
        "XMSC_WMQ_CHANNEL":"DEV.APP.SVRCONN",
        "XMSC_WMQ_QUEUE_MANAGER":"QM1",
        "XMSC_USERID":"app",
        "XMSC_PASSWORD":"passw0rd",
        "topic.produce": "DEV.QUEUE.1"
      }
    },
    ...
  ]
}
```

Важные настройки IBM MQ:

| Setting | Name |
| --- | --- |
| XMSC_WMQ_CONNECTION_NAME_LIST | Адреса брокеров IBM MQ в формате списка именов хостов и портов, указанные через запятую |
| XMSC_WMQ_CHANNEL | Имя канала IBM MQ, используется для соединения |
| XMSC_USERID | Имя пользователя IBM MQ |
| XMSC_PASSWORD | Пароль пользователя IBM MQ |
| topic.produce | Топик, в который OpenIG должен слать сообщения |
| topic.consume | Топик, из кторого OpenIG читает сообщения |
| uri | Конечная точка OpenIG  |
| method | Метод HTTP, который OpenIG использует для отправки запросов на конечную точку HTTP |

Добавьте маршрут OpenIG в папку `routes` для обработки HTTP запросов.

`10-http2mq.json`

```json
{
  "name": "${(request.method == 'PUT') and matches(request.uri.path, '^/http2mq$')}",
  "condition": "${(request.method == 'PUT') and matches(request.uri.path, '^/http2mq$')}",
  "monitor": true,
  "timer": true,
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [],
      "handler": {
        "type": "DispatchHandler",
        "config": {
          "bindings": [
            {
              "handler": "mq-producer"
            }
          ]
        }
      }
    }
  }
}
```

Отправьте HTTP запрос в OpenIG и проверьте полученное сообщение в топике `DEV.QUEUE.1` IBM MQ:

```bash
$ curl -v -X PUT --data '{"data": "test"}' -H 'Content-Type: application/json' 'http://localhost:8080/http2mq'
*   Trying 127.0.0.1:8080...
* TCP_NODELAY set
* Connected to localhost (127.0.0.1) port 8080 (#0)
> PUT /http2mq HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/7.68.0
> Accept: */*
> Content-Type: application/json
> Content-Length: 16
> 
* upload completely sent off: 16 out of 16 bytes
* Mark bundle as not supporting multiuse
< HTTP/1.1 202 Accepted
< Server: Apache-Coyote/1.1
< Content-Length: 0
< Date: Wed, 13 Apr 2022 12:34:03 GMT
< 
* Connection #0 to host localhost left intact
```

Откройте консоль IBM MQ по адресу  [https://localhost:9443/ibmmq/console/](https://localhost:9443/ibmmq/console/#/). В топике `DEV.QUEUE.1` вы увидите полученное сообщение:

![IBM MQ DEV.QUEUE1](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIG/images/openig-message-brokers/ibm-mq-console-queue1.png)

### Отправка сообщений IBM MQ на конечную точку HTTP

Добавьте IBM MQ cosumer в heap в файл конфигурации OpenIG `config.json`.

```json
{
  "heap": [
    ...
    {
      "name": "mq-consumer",
      "type": "MQ_IBM",
      "config": {
        "XMSC_WMQ_CONNECTION_NAME_LIST":"mq(1414)",
        "XMSC_WMQ_CHANNEL":"DEV.APP.SVRCONN",
        "XMSC_WMQ_QUEUE_MANAGER":"QM1",
        "XMSC_USERID":"app",
        "XMSC_PASSWORD":"passw0rd",
        "topic.consume": "DEV.QUEUE.2",
        "uri": "/mq2http",
        "method": "POST"
      }
    }
    ...
  ]
}
```

Добавьте маршрут OpenIG в папку `routes` для обработки сообщений IBM MQ:

`10-mq2http.json`

```json
{
  "name": "${(request.method == 'POST') and matches(request.uri.path, '^/mq2http$')}",
  "condition": "${(request.method == 'POST') and matches(request.uri.path, '^/mq2http$')}",
  "monitor": true,
  "timer": true,
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [],
      "handler": {
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
    }
  }
}
```

Зайдите в консоль IBM MQ и отправьте сообщение в топик `DEV.QUEUE.2`

![IBM MQ DEV.QUEUE1](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIG/images/openig-message-brokers/ibm-mq-console-create-message.png)

В логе сервиса `sample-servive` вы увидите следующее сообщение:

```
2022-04-21 08:32:35.007 DEBUG 1 --- [nio-8080-exec-1] o.s.w.f.CommonsRequestLoggingFilter      : After request [POST /mq2http, headers=[jms_ibm_character_set:"UTF-8", jms_ibm_encoding:"273", jms_ibm_format:"MQSTR", jms_ibm_msgtype:"8", jms_ibm_putappltype:"6", jms_ibm_putdate:"20220421", jms_ibm_puttime:"08323434", jmsxappid:"com.ibm.mq.webconsole", jmsxdeliverycount:"1", jmsxuserid:"unknown", content-length:"16", host:"sample-service:8080", connection:"Keep-Alive", user-agent:"Apache-HttpAsyncClient/4.1.4 (Java/1.8.0_212)"], payload={"data": "test"}]
```