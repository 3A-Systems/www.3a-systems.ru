---
layout: blog
title: 'Введение в Identity Management с OpenIDM'
description: 'В этой статье мы рассмотрим, что такое Identity Management (IDM) и его основные задачи. А так же рассмотрим решение нескольких типовых задач Identity Management и использованием продукта с открытым исходным кодом OpenIDM. В конце статьи будет обзор основных возможностей OpenIDM.'
tags: 
  - openidm

---
В этой статье мы рассмотрим, что такое Identity Management (IDM) и его основные задачи. А так же рассмотрим решение нескольких типовых задач Identity Management и использованием продукта с открытым исходным кодом [OpenIDM](https://github.com/OpenIdentityPlatform/OpenIDM). В конце статьи будет обзор основных возможностей OpenIDM.

## Введение

В почти любой корпоративной среде пользователь имеет несколько учетных записей. Это может быть доменная учетная запись в Active Directory, запись в службе каталогов [OpenDJ](https://github.com/OpenIdentityPlatform/OpenDJ), учетная запись в 1С, CRM, Git, и так далее. 

Поддержание всех учетных записей в актуальном состоянии является не самой простой задачей. Кроме того, необходимо контролировать политики паролей, блокировать учетные записи на время отпусков и при увольнении, менять роли при переходе с одной должности на другую и это далеко не полный список задач. Конечно, можно поддерживать данные в актуальном состоянии в ручном режиме, но тогда при этом почти неизбежны ошибки, которые могут повлечь проблемы как в простое работы из за недостатка полномочий, так и проблемы в безопасности. Автоматизацией таких процессов управления учетными записями и занимаются продукты Identity Management. Далее мы рассмотрим управление учетными записями при помощи OpenIDM.

## Запуск OpenIDM

### Предварительные требования

Для того, чтобы установить и запустить OpenIDM нужно:

- Unix - подобная ОС (MacOS или Linux) или Windows
- Установленная Java LTS версией от 8 до 21 включительно.
- Если в вашей операционной системе есть брандмауэр, убедитесь, что он разрешает трафик через порты 8080 и 8443 (по умолчанию).

Дистрибутив OpenIDM можно скачать с GitHub по [ссылке](https://github.com/OpenIdentityPlatform/OpenIDM/releases).

Так же вы можете воспользоваться образом [Docker](https://registry.hub.docker.com/r/openidentityplatform/openidm).

### Загрузка и запуск OpenIDM

Из бинарной поставки:

```
$ export VERSION=$(curl -i -o - --silent https://api.github.com/repos/OpenIdentityPlatform/OpenIDM/releases/latest | grep -m1 "\"name\"" | cut -d\" -f4); echo "Last version: $VERSION"
Last version: 6.0.1

$ curl -L https://github.com/OpenIdentityPlatform/OpenIDM/releases/download/$VERSION/openidm-$VERSION.zip --output openidm.zip
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100 92.1M  100 92.1M    0     0  9421k      0  0:00:10  0:00:10 --:--:-- 9926k

$ unzip openidm.zip 
Archive:  openidm.zip
   creating: openidm/
....

$ openidm/startup.sh -p samples/getting-started
Executing openidm/startup.sh...
Using OPENIDM_HOME:   /tmp/openidm
Using PROJECT_HOME:   /tmp/openidm/samples/getting-started
Using OPENIDM_OPTS:   -Dlogback.configurationFile=conf/logging-config.groovy
Using LOGGING_CONFIG: -Djava.util.logging.config.file=/tmp/openidm/samples/getting-started/conf/logging.properties
Using boot properties at /tmp/openidm/samples/getting-started/conf/boot/boot.properties
-> OpenIDM version "6.0.1" (revision: 284a4) 2024-05-23T09:18:27Z master
OpenIDM ready
```

Запуск OpenIDM в Docker контейнере:

```
$ docker run -h idm-01.domain.com -p 8080:8080 -p 8443:8443 --name idm-01 openidentityplatform/openidm -p samples/getting-started
Unable to find image 'openidentityplatform/openidm:latest' locally
latest: Pulling from openidentityplatform/openidm
74ac377868f8: Already exists 
a182a611d05b: Already exists 
e58ce1bd2f23: Already exists 
e1b7fbdee987: Already exists 
4f4fb700ef54: Already exists 
26716adeef7f: Pull complete 
Digest: sha256:6a6df88ca40116de4bba7ddef126a214feee04e7161b0d6f39ff9c9f448cda94
Status: Downloaded newer image for openidentityplatform/openidm:latest
Executing /opt/openidm/startup.sh...
Using OPENIDM_HOME:   /opt/openidm
Using PROJECT_HOME:   /opt/openidm/samples/getting-started
Using OPENIDM_OPTS:   -server -XX:+UseContainerSupport -Dlogback.configurationFile=conf/logging-config.groovy
Using LOGGING_CONFIG: -Djava.util.logging.config.file=/opt/openidm/samples/getting-started/conf/logging.properties
Using boot properties at /opt/openidm/samples/getting-started/conf/boot/boot.properties
ShellTUI: No standard input...exiting.
OpenIDM version "6.0.1" (revision: 284a4) 2024-05-23T09:18:27Z master
OpenIDM ready
```

После того, как OpenIDM запущен, вы сразу можете начать с ним работать. Например, можете зайти в консоль администратора по адресу [http://localhost:8080/admin](http://localhost:8080/admin) или [https://localhost:8443/admin](https://localhost:8443/admin) с логином и паролем `openidm-admin` (не забудьте сменить пароль по умолчанию).

## Демонстрационный пример

### Постановка задачи

Давайте теперь рассмотрим пример. Пусть у отдел HR нанимает на работу сотрудника Jane Sanchez в отдел Engineering и при внесении нового сотрудника в базу данных отдела HR нужно создать учетную запись для этого сотрудника в базе отдела Engineering.

Для демонстрационных целей, в качестве баз данных отделов HR и Engineering мы будем использовать текстовые файлы в [CSV](https://en.wikipedia.org/wiki/Comma-separated_values) формате. 

- [samples/getting-started/data/hr.csv](https://github.com/OpenIdentityPlatform/OpenIDM/blob/master/openidm-zip/src/main/resources/samples/getting-started/data/hr.csv) - файл данных отдела HR
- [samples/getting-started/data/engineering.csv](https://github.com/OpenIdentityPlatform/OpenIDM/blob/master/openidm-zip/src/main/resources/samples/getting-started/data/engineering.csv) - файл данных отдела Engineering.

Вы можете найти эти файлы в бинарной поставке OpenIDM, в подкаталоге: [samples/getting-started](https://github.com/OpenIdentityPlatform/OpenIDM/tree/master/openidm-zip/src/main/resources/samples/getting-started).

> OpenIDM поддерживает разные типы хранилищ учетных записей, но описание их настройки выходит за рамки этой статьи.
> 

Для начала проверим содержимое файлов 

```
cat samples/getting-started/data/hr.csv 
"firstName", "uid", "lastName", "email", "employeeNumber"
"Barbara", "BJENSEN", "Jensen", "bjensen@example.com", "123456"
"Jane", "JSANCHEZ", "Sanchez", "jsanchez@example.com", "234567"
"Steven", "SCARTER", "Carter", "scarter@example.com", "654321"
```

```
cat samples/getting-started/data/engineering.csv
"description", "firstname", "email", "name", "lastname", "telephoneNumber", "roles"
"Created By Engineering", "Barbara", "bjensen@example.com", "bjensen@example.com", "Jensen", "1234567", "openidm-authorized"
"Created By Engineering", "Steven", "scarter@example.com", "scarter@example.com", "Carder", "1234567", "openidm-admin,openidm-authorized"
```

Как вы можете заметить, в файле данных отдела Engineering отсуствует запись для сотрудника Jane Sanchez. Давайте это исправим.

### Согласование учетных записей

Зайдите в консоль администратора, как было описано выше, затем перейдите  **Configure** > **Mappings** > **HumanResources_Engineering** > **Properties** и нажмите кнопку Reconcile.

![OpenIDM  HR Engineering Mapping](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-intro/0-hr-eng-mapping.png)

OpenIDM выполнит согласование учетных записей, и перенесет данные Jane Sanchez в хранилище отдела Engineering, как показано на рисунке ниже. 

![OpenIDM reconcile diargram](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-intro/1-openidm-reconcile-diagram.png)

После согласования проверьте содержимое файла `samples/getting-started/data/engineering.csv` В конце файла вы увидите добавленную ученую запись пользователя Jane Sanchez.

```
cat openidm-zip/target/openidm/samples/getting-started/data/engineering.csv                
"description","firstname","email","name","lastname","telephoneNumber","roles"
"Created By Engineering","Barbara","bjensen@example.com","bjensen@example.com","Jensen","N/A","openidm-authorized"
"Created By Engineering","Steven","scarter@example.com","scarter@example.com","Carter","N/A","openidm-admin,openidm-authorized"
,"Jane","jsanchez@example.com","jsanchez@example.com","Sanchez","N/A","openidm-authorized"
```

OpenIDM умеет сопоставлять атрибуты с различающимися именами. Например, значение атрибута `firstName` отдела HR при согласовании переносится в значение атрибута `firstname` отдела Engineering, как показано на рисунке ниже.

![OpenIDM attributes reconcile diargram](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-intro/2-openidm-attrs-reconcile-diagram.png)

В консоли администратора выберите **Configure → Mappings → HumanResources_Engineering → Properties.** Раскройте таблицу **Attributes Grid**. В поле Sample source введите значение `Sanchez`.  В выпадающем списке выберите `jsanchez@example.com`. В таблице вы увидите, настройки согласования атрибутов из хранилища HR в Engineering.

![OpenIDM attributes reconcile table](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-intro/3-openidm-attrs-reconcile-table.png)

OpenIDM позволяет настраивать согласования, используя файлы конфигурации. Файлы конфигурации для нашего демонстрационного примера находятся в директории `samples/getting-started/conf` с наименованием `provisioner.openicf- *.json`

```
$ samples/getting-started/conf | grep provisioner               
provisioner.openicf-engineering.json
provisioner.openicf-hr.json
```

Эти файлы отвечают за конфигурацию соединения с внешними ресурсами, такими как Active Directory, OpenDJ, реляционными базами данных или файлами `engineering.csv` и `hr.csv`, используемые в данной статье. Дополнительные сведения см. в разделе **Connecting to External Resources** в руководстве [Integrator's Guide](https://github.com/OpenIdentityPlatform/OpenIDM/wiki/Integrator%27s-Guide).

Конфигурация алгоритма синхронизации описана в файле [samples/getting-started/conf/sync.json](https://github.com/OpenIdentityPlatform/OpenIDM/blob/master/openidm-zip/src/main/resources/samples/getting-started/conf/sync.json)

### Установка значений по умолчанию

Рассмотрим еще один пример. Предположим, что отдел Engineering хочет заменить все телефонные номера пользователей одним центральным номером. Установим значение по умолчанию для  центрального номера телефона. Для этого в консоли администратора перейдите **Configure → Mappings → HumanResources_Engineering → Properties.**  В разделе Attributes Grid хранилища Engineering выберите атрибут `telephoneNumber` и на закладке Default Values установите значение по умолчанию. 

![OpenIDM default phone](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-intro/4-openidm-default-phone.png)

Нажмите кнопку `Update` а потом `Save`. OpenIDM изменит содержимое файла  [samples/getting-started/conf/sync.json](https://github.com/OpenIdentityPlatform/OpenIDM/blob/master/openidm-zip/src/main/resources/samples/getting-started/conf/sync.json). 

Нажмите кнопку `Reconcile` и проверьте содержимое файла `engineering.csv` . Как видно в листинге ниже, OpenIDM проставил в файле значение номера телефона по умолчанию:

```
cat openidm-zip/target/openidm/samples/getting-started/data/engineering.csv                
"description","firstname","email","name","lastname","telephoneNumber","roles"
"Created By Engineering","Barbara","bjensen@example.com","bjensen@example.com","Jensen","415-599-1100","openidm-authorized"
"Created By Engineering","Steven","scarter@example.com","scarter@example.com","Carter","415-599-1100","openidm-admin,openidm-authorized"
,"Jane","jsanchez@example.com","jsanchez@example.com","Sanchez","415-599-1100","openidm-authorized"
```

## Что дальше

OpenIDM умеет гораздо больше, чем просто согласовывать данные. В этом разделе вы узнаете о ключевых возможностях OpenIDM, а также найдете ссылки на дополнительную информацию о каждой из них.

### Управление бизнес процессами

В OpenIDM вы можете настраивать сложные бизнес процессы, например, прием на работу, когда  вновь нанятый сотрудник запрашивает доступ к нужным ресурсам, а менеджер подтверждает или отклоняет запрошенные полномочия. 

OpenIDM реализует Activiti Process Engine, который соответствует стандарту Business Process Model and Notation 2.0 (BPMN 2.0).

Для получения дополнительной информации см. раздел **Workflow Samples** в руководстве [Samples Guide](https://github.com/OpenIdentityPlatform/OpenIDM/wiki/Samples-Guide).

### Управление паролями

Пользователи могут централизовано управлять своими паролями через интерфейс самообслуживание OpenIDM. OpenIDM может устанавливать гибкие парольные политики, например:

- Атрибуты, которые не должны входить в состав пароля, например логин или email
- Срок действия пароля
- История паролей для предотвращения повторного использования паролей

Дополнительные сведения см. в разделе **Managing Passwords** в [Integrator's Guide](https://github.com/OpenIdentityPlatform/OpenIDM/wiki/Integrator%27s-Guide).

### Поддержка разных типов хранилищ

OpenIDM поддерживает разные типы хранилищ учетных записей:

- Google Web Applications (см. раздел  **Google Apps Connector** в [Connectors Guide](https://github.com/OpenIdentityPlatform/OpenICF/wiki/Connectors-Guide)).
- Salesforce (см. раздел  **Salesforce Connector** в [Connectors Guide](https://github.com/OpenIdentityPlatform/OpenICF/wiki/Connectors-Guide)).
- Любой LDAPv3-совместимый каталог, включая OpenDJ и Active Directory (см. раздел **Generic LDAP Connector** в [Connectors Guide](https://github.com/OpenIdentityPlatform/OpenICF/wiki/Connectors-Guide)).
- Файлы CSV (см. раздел **CSV File Connector** в [Connectors Guide](https://github.com/OpenIdentityPlatform/OpenICF/wiki/Connectors-Guide)).
- Реляционные базы данных (см. раздел **Database Table Connector** в [Connectors Guide](https://github.com/OpenIdentityPlatform/OpenICF/wiki/Connectors-Guide)).

Если требуемого коннектора нет в списке, вы можете создать свой коннектор на базе скриптового коннектора OpenIDM:

- Для коннекторов, связанных с Microsoft Windows, вы можете использовать PowerShell Connector Toolkit, который может работать с различными службами Microsoft, например Active Directory, SQL Server, Microsoft Exchange, SharePoint, Azure Active Directory, Office 365 и т.д. Дополнительные сведения см. в разделе **PowerShell Connector Toolkit** в [Connectors Guide](https://github.com/OpenIdentityPlatform/OpenICF/wiki/Connectors-Guide).
- Для остальных внешних ресурсов в OpenIDM есть **Groovy Connector Toolkit**, может использовать скрипты на языке [Groovy](https://en.wikipedia.org/wiki/Apache_Groovy)  для работы с практически любым внешним ресурсом. Дополнительную информацию см. в разделе **Groovy Connector Toolkit** в руководстве [Connectors Guide](https://github.com/OpenIdentityPlatform/OpenICF/wiki/Connectors-Guide). Раздел **Samples That Use the Groovy Connector Toolkit to Create Scripted Connectors** в руководстве [Samples Guide](https://github.com/OpenIdentityPlatform/OpenIDM/wiki/Samples-Guide) содержит примеры реализации Groovy Connector.

### Варианты использования

Документация OpenIDM содержит описание примеров различных вариантов использования. Ознакомиться с ними вы можете в разделе **Overview of the OpenIDM Samples** в [Samples Guide](https://github.com/OpenIdentityPlatform/OpenIDM/wiki/Samples-Guide).

Эти примеры содержат пошаговые инструкции по подключению к различным хранилищам данных, настройке поведения продукта с помощью JavaScript и Groovy и администрированию OpenIDM с помощью команд RESTful API.

### Ключевые преимущества

Теперь, когда мы пробежались по основным возможностям OpenIDM, давайте подведем итог и перечислим основные преимущества от внедрения OpenIDM:

- Гибкость настройки - вы можете конфигурировать OpenIDM как в интерфейсе администратора, так и при помощи конфигурационых файлов
- Интерфейс самообслужвания пользователей - пользователи могут самостоятельно менять пароли в соотвествии с установленными политиками пароли, запрашивать требуемые привелегии, менять логин. Процессы можно настраивать на основе [BPMN 2.0](https://en.wikipedia.org/wiki/Business_Process_Model_and_Notation)
- Различные поддерживаемые БД - OpenIDM поддерживает MySQL, Microsoft SQL Server, Oracle Database, IBM DB2 и PostgreSQL в качестве хранилища собственных данных.
- Журналы и аудит - OpenIDM регистрирует все действия пользователей, связанные с изменениями конфигурации и работой с подключенными системами. С помощью журналов можно отслеживать информацию о предоставленных доступах, активности пользователей, аутентификации, изменениях конфигурации, и синхронизации данных.