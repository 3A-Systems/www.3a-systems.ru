---
layout: blog
title: 'OpenDJ: быстрый масштабируемый LDAP на базе Apache Cassandra'
description: 'В одном из популярных open-source LDAP каталогов OpenDJ, начиная с версии 4.6.1 появилась возможность использовать Apache Cassandra или ScyllaDB в качестве хранилища данных. Это позволяет использовать преимущества производительности и масштабируемости колоночных NoSQL БД по сравнению с классическими LDAP каталогами. В данной статье мы развернем инстанс OpenDJ на базе Apache Cassandra.'
tags: 
  - opendj

---

## Введение

LDAP-совместимые службы каталогов — широко распространенный отраслевой стандарт и удобное решение для хранения идентификационных данных. LDAP службы наиболее часто используются в: 

- управлении учетным данными пользователей предприятия
- управлении устройствами IoT
- управлении машинами и оборудованием

В одном из популярных open-source LDAP каталогов [OpenDJ](https://github.com/OpenIdentityPlatform/OpenDJ), начиная с версии 4.6.1 появилась возможность использовать Apache Cassandra или ScyllaDB в качестве хранилища данных. Использование колоночных NoSQL баз данных дает несколько важных преимущество по сравнению с классическими LDAP:

| Функциональность | Классический LDAP | LDAP на базе колоночных NoSQL БД |
| --- | --- | --- |
| Чтение | ❌ Нагрузка чтения одной ноды ограничена производительностью ноды | ✅ Нагрузка чтения с одной ноды не ограничена производительностью одной ноды. Нагрузка распределяется в соотвествии с уровнем репликации. |
| Запись | ❌ Нагрузка синхронизации записи обрабатывается на всех нодах | ✅ Нагрузка синхронизации записи обрабатывается на нодах с требуемым уровнем репликации |
| Репликация | ❌ Отказ репликации может привести перевод остальных нод в режим read-only | ✅ Отказ ноды не приводит к остановке в соотвествии с уровнем репликации  |
| Балансировка | ❌ Требуется отдельный балансировщик для распределения нагрузки между нодами | ✅ Нагрузка распределяется автоматически между нодами на основании заданного уровня репликации |
| Количество записей | ❌ До 6 млн | ✅ Неограничено |

Более подробно о преимуществах можно почитать вот тут: [https://www.datastax.com/blog/exploring-common-apache-cassandra-use-cases](https://www.datastax.com/blog/exploring-common-apache-cassandra-use-cases)

## Настройка экземпляра OpenDJ

Перейдем к практике. Настроим OpenDJ с Apache Cassandra в Docker контейнерах

1. Создайте сеть Docker, чтобы OpenDJ и Apache Cassandra могли общаться между собой.

```bash
docker network create -d bridge opendj-cassandra
```

1. Запустите образ Docker Apache Cassandra и пробросьте порт для доступа с машины-хоста. 

```bash
docker run --rm -it -p 9042:9042 --network=opendj-cassandra --name cassandra cassandra
```

Для демонстрационных целей мы не будем монтировать разделы Docker к хосту и контейнер с Apache Cassandra будет сразу удален после остановки.

1. Установите настройки подключения к Apache Cassandra в переменную окружения **`OPENDJ_JAVA_ARGS`**

```bash
export OPENDJ_JAVA_ARGS="-server -Ddatastax-java-driver.basic.contact-points.0=cassandra:9042 -Ddatastax-java-driver.basic.load-balancing-policy.local-datacenter=datacenter1"
```

1. Установите тип бэкенда для нового инстанса OpenDJ и добавьте создание тестовых данных

```bash
export OPENDJ_ADD_BASE_ENTRY="--backendType cas --sampleData 5000"
```

Обратите внимание на параметр `--backendType` его значение установлено в `cas` , означает, что OpenDJ будет использовать Apache Cassandra или ScyllaDB в качестве хранилища данных.

1. Запустите Docker контейнер OpenDJ

```bash
docker run --rm -p 1389:1389 -p 1636:1636 -p 4444:4444 --network=opendj-cassandra \
    --env OPENDJ_JAVA_ARGS=$OPENDJ_JAVA_ARGS --env ADD_BASE_ENTRY=$OPENDJ_ADD_BASE_ENTRY \
    --name opendj openidentityplatform/opendj:latest
```

После успешного запуска OpenDJ выведет в консоль

```bash
Server Run Status:        Started
OpenDJ is started
```

### Проверка

Подключитесь к инстансу OpenDJ, используя любой из клиентов LDAP, например, [Apache Directory Studio](https://www.notion.so/published-OpenAM-Active-Directory-bcca59b1bbd846a28f8a434ac9254263?pvs=21).

В Apache Directory Studio создайте новое подключение с такими настройками

- User name: `cn=Directory Manager`
- Password: `password`
- Host: `localhost`
- Port: `1389`

После подключения к OpenDJ, вы увидите в консоли созданные тестовые записи.