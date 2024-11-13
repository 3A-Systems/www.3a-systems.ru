---
layout: blog
title: 'OpenIDM: А ваш IDM умеет играть в шахматы?'
description: 'В данной статье мы настроим рабочий процесс игры в шахматы между пользователями'
tags: 
  - openidm

---

## Введение

[OpenIDM](http://github.com/OpenIdentityPlatform/OpenIDM) управляет жизненным циклом учетных записей в организации. Автоматизирует процессы приема на работу, администрирования, управления привилегиями, увольнения. Может синхронизировать изменения в учетных записях во множестве корпоративных систем. 

В OpenIDM возможно настраивать произвольные процессы (workflow) в соответствии с нотацией [BPMN2](https://en.wikipedia.org/wiki/BPMN), а так же создавать произвольный интерфейс пользователя в соответствии с нуждами организации.

Но настроить какой-нибудь типовой процесс было бы скучно, тем, более возможности OpenIDM позволяют это сделать максимально гибко. И в этой статье в качестве примера мы рассмотрим рабочий процесс игры в шахматы.

## Запуск OpenIDM

### Из бинарной поставки

Выполните последовательно следующие команды:

Получить последнюю версию OpenIDM

```bash
$ export VERSION=$(curl -i -o - --silent https://api.github.com/repos/OpenIdentityPlatform/OpenIDM/releases/latest | grep -m1 "\"name\"" | cut -d\" -f4); echo "Last version: $VERSION"
Last version: 6.2.3
```

Загрузить бинарную поставку OpenIDM

```bash
$ curl -L https://github.com/OpenIdentityPlatform/OpenIDM/releases/download/$VERSION/openidm-$VERSION.zip --output openidm.zip
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100 92.1M  100 92.1M    0     0  9421k      0  0:00:10  0:00:10 --:--:-- 9926k
```

Разархивировать бинарную поставку OpenIDM

```bash
$ unzip openidm.zip 
Archive:  openidm.zip
   creating: openidm/
....
```

Запустить OpenIDM

```bash
$ openidm/startup.sh -p samples/workflow
Executing openidm/startup.sh...
Using OPENIDM_HOME:   /tmp/openidm
Using PROJECT_HOME:   /tmp/openidm/samples/getting-started
Using OPENIDM_OPTS:   -Dlogback.configurationFile=conf/logging-config.groovy
Using LOGGING_CONFIG: -Djava.util.logging.config.file=/tmp/openidm/samples/getting-started/conf/logging.properties
Using boot properties at /tmp/openidm/samples/getting-started/conf/boot/boot.properties
-> OpenIDM version "6.2.3" (revision: 284a4) 2024-11-11T09:18:27Z master
OpenIDM ready
```

### Из образа Docker

```bash
$ docker run -h idm-01.domain.com -p 8080:8080 -p 8443:8443 --name idm-01 openidentityplatform/openidm -p samples/workflow
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
OpenIDM version "6.2.3" (revision: 284a4) 2024-11-11T09:18:27Z master
OpenIDM ready
```

## Начальная настройка OpenIDM

Откройте консоль администратора OpenIDM по ссылке [http://localhost:8080/admin](http://localhost:8080/admin). Введите логин и пароль администратора. По умолчанию логин `openidm-admin`, пароль `openidm-admin`.

В основном меню перейдите Manage → Processes. Далее перейдите на закладку Definitions. И убедитесь, что в списке есть процесс `Start a Game of Chess!`.

![OpenIDM Workflow Processes](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-chess/0-workflow-processes.png)

Вы можете посмотреть, как выглядит рабочий процесс, кликнув на него.

![OpenIDM Workflow Chess Process](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-chess/1-chess-process.png)

Теперь давайте создадим пользователя, с которым администратор будет играть в шахматы.

В консоли администратора в основном меню перейдите Manage → User. Создайте учетную запись. Пусть, для примера, это будет учетная запись с логином `jdoe`.

![New User](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-chess/2-new-user.png)

Перейдите на закладку пароль и введите пароль для учетной записи. Нажмите кнопку `Save`.

![New User Password](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-chess/3-new-user-password.png)

## Игра в шахматы

Зайдите в консоль с учетной записью `openidm-admin` по ссылке  [http://localhost:8080](http://localhost:8080/admin). На экране Dashboard в разделе Processes будет пункт `Start a Game of Chess!`. Нажмите на ссылку `Details` Появится шахматная доска. Нажмите кнопку `Start`. Будет создана новая игра. Вы можете назначить игру на себя и играть с самим собой или подождать, когда кто-нибудь из пользователей примет ваше приглашение к игре.

![New Chess Game](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-chess/4-new-chess-game.png)

Откройте другой браузер или новое окно в режиме инкогнито и войдите с учетной записью `jdoe`.

На странице Dashboard вы увидите приглашение к игре. Назначьте игру на себя, сделайте первый ход и нажмите кнопку `Complete`. 

![Chess John Doe Turn](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-chess/5-chess-jdoe-turn.png)

Задача исчезнет из списка. Теперь перейдите в окно с аутентифицированным пользователем `openidm-admin` и обновите список задач.  Вам будет предложено сделать ответный ход. Сделайте ход и нажмите кнопку `Complete`. Теперь перейдите снова в окно с пользователем `jdoe`. Для пользователя появится новая задача с предложением сделать свой ход. Таким образом, пользователи OpenIDM могут играть между собой в шахматы.

![image.png](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-chess/6-chess-admin-turn.png)

## Немного технических деталей

Теперь давайте разберем, как это устроено. Workflow в формате BPMN хранится в каталоге `samples/workflow/workflow` в архиве `chess.bar` Посмотреть его вы можете при помощи команды.

```bash
$ unzip -p samples/workflow/workflow/chess.bar chess.bpmn20.xml | less
```

В этом же архиве хранится и интерфейс пользователя - шахматная доска.

```bash
unzip -p samples/workflow/workflow/chess.bar chessboard.xhtml | less
```

По аналогии вы можете создать свой workflow и интерфейс пользователя. После создайте bar архив командой

```bash
$ jar cvf chess.bar your-bpmn.xml your-ui.xhtml
```

И поместите его в каталог `workflow` OpenIDM.

Более подробно про настройку рабочих процессов вы можете прочитать в документации к OpenIG [здесь](https://doc.openidentityplatform.org/openidm/integrators-guide/chap-workflow) и [здесь](https://doc.openidentityplatform.org/openidm/samples-guide/chap-workflow-samples).