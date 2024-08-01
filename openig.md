---
layout: main
title: 'OpenIG: Identity Management'
description: 'Управление учетными данными в различных источниках. Позволяет
    синхронизировать, трансформировать, согласовывать учетные данные
    пользователей, прав доступа, устройств, сертификатов и прочих объектов из
    различных источников (Active Directory, LDAP, SQL, SSH, 1C и т.д.)'


product:
    logo: logo-ig-lg-long.png
    features:
        - 'Интернет шлюз (реверсивный прокси) контроля доступа к UI и API.'
        - 'Позволяет организовывать защищенный доступ к веб приложениям и API путем решения задач маршрутизации, аутентификации, авторизации, федерации и расширения профиля.'
        - 'Поддерживает открытые стандарты аутентификации и федерации: OAuth, OpenID Connect, SAML. Позволяет безопасно настроить функцию Replay password для унаследованных систем и производить изменение контента “на лету”.'
        - 'Эволюция: Forgerock/Open Identity Platform OpenIG'   
    
    articles:     
        - title: 'Как защитить веб сервисы при помощи шлюза OpenIG'
          url: 'https://habr.com/ru/articles/823212/'
        - title: 'Настройка сервиса аутентификации OpenAM и шлюза авторизации OpenIG для защиты приложений'
          url: 'https://habr.com/ru/articles/808431/'
        - title: 'Контроль пропускной способности (троттлинг) API c помощью шлюза авторизации OpenIG'
          url: 'https://habr.com/ru/articles/828826/'
        - title: 'Как защитить WebSocket соединение при помощи OpenAM и OpenIG'
          url: 'https://habr.com/ru/articles/823872/'
        - title: 'Интеграция REST и MQ брокеров сообщений через шлюз OpenIG'
          url: 'https://habr.com/ru/articles/828832/'
---
{% include product.html %}