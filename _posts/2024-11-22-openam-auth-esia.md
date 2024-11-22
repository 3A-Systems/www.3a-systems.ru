---
layout: blog
title: 'Аутентификация в OpenAM через ЕСИА (Госуслуги)'
description: 'В данной статье мы настроим аутентификацию в OpenAM через единую систему идентификации и аутентификации (ЕСИА)'
tags: 
  - openam

---
## Введение

В данной статье мы настроим аутентификацию в [OpenAM](https://github.com/OpenIdentityPlatform/OpenAM) через единую систему идентификации и аутентификации (ЕСИА). Таким образом, пользователи могут аутентифицироваться в OpenAM используя свою учетную запись портала Госуслуг. Для целей тестирования процесс описан для работы с тестовой средой ЕСИА.

## Подготовка

### Регистрация организации на портале Госуслуги

Для того, чтобы ваша организация могла использовать аутентификацию через ЕСИА, вам нужно зарегистрировать организацию на портале Госуслуг. Для этого нужно иметь подтвержденную учетную запись руководителя организации на портале.

После этого нужно зарегистрировать вашу информационную систему на технологическом портале ЕСИА. Для этого надо перейти по ссылке [https://esia.gosuslugi.ru/console/tech](https://esia.gosuslugi.ru/console/tech) и аутентифицироваться с учетной записью руководителя организации. На закладке “Информационные системы”, нажмите кнопку “Добавить систему” и заполните свойства по ссылке. Главное, на что нужно обратить внимание, это мнемоника системы, то есть client_id,  URL системы - перечень разрешенных URL, на которые будет осуществлена переадресация после успешной или неуспешной аутенитфикации в ЕСИА, а также алгоритм формирования электронной подписи - должен быть GOST3410_2012_256. 

Более подробно процесс описан в документе [https://digital.gov.ru/ru/documents/6190/](https://digital.gov.ru/ru/documents/6190/) раздел 3.1.1

### Отправка заявлений на регистрацию системы в Минцифры

После того, как вы зарегистрировали информационную систему (ИС), надо получить сертификат в аккредитованном удостоверяющем центре (Список аккредитованных удостоверяющих центров по ссылке  [https://digital.gov.ru/ru/activity/govservices/certification_authority/](https://digital.gov.ru/ru/activity/govservices/certification_authority/)). 

Алгоритм формирования электронной подписи - ГОСТ Р 34.10-2012. Сертификат должен содержать ОГРН юридического лица, являющегося оператором информационной системы и может быть выпущен на сотрудника юридического лица или на организацию.

После этого, нужно сформировать заявление на подключение к тестовой среде, как описано в [https://digital.gov.ru/ru/documents/4244/](https://digital.gov.ru/ru/documents/4244/) пункт 9 и отправить его на электронный адрес Минцифры.

После того, как ваша система зарегистрирована в тестовой среде, можно приступить к настройке OpenAM.

## Установка OpenAM

Если OpenAM у вас уже установлен, можете пропустить этот раздел. Для демонстрационных целей мы настроим OpenAM в Docker контейнере.

### Настройка сети

Добавьте имя хоста и IP адрес OpenAM в файл `hosts`

```bash
127.0.0.1    openam.example.org
```

В Windows системах файл `hosts` находится по адресу `C:\Windows\System32\drivers\etc\hosts` , в Linux и Mac находится по адресу `/etc/hosts` 

### Установка OpenAM в Docker

Запустите Docker образ OpenAM, смонтировав ключ и сертификат, выданные ранее в УЗ к контейнеру.

```bash
docker run -h openam.example.org -p 8080:8080 --name openam \
 -v ./openam-esia.key:/usr/openam/esia/openam-esia.key:ro \
 -v ./openam-esia.pem:/usr/openam/esia/openam-esia.pem:ro openidentityplatform/openam:latest
```

После того, как сервер OpenAM запущен, выполните первоначальную настройку, запустив следующую команду и дождитесь окончания настройки.

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
COOKIE_DOMAIN=openam.example.org
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

## Настройка OpenAM

### Настройка модуля аутентификации ЕСИА

Откройте консоль администратора OpenAM по адресу [http://openam.example.org:8080/openam](http://openam.example.org:8080/openam) . В поле логин введите значение `amadmin`, в поле пароль введите значение, указанное в настройке `ADMIN_PWD` , в данном случае `passw0rd`.

В открывшейся консоли выберите корневой realm и в меню слева выберите пункт Authentication → Modules. В открывшемся списке нажмите кнопку `Add Module` .

Введите имя модуля (оно может быть любым) и тип модуля - `OAuth 2.0 / OpenID Connect`.

![OpenAM new ESIA module](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/esia-auth/0-openam-esia-module.png)

Нажмите кнопку `Create` . Заполните настройки согласно таблице:

| Настройка | Значение |
| --- | --- |
| **Client Id** | Мнемоника информационной системы, указанная в технологическом портале ЕСИА |
| **Client Secret** | Можно не заполнять, для ЕСИА client secret рассчитывается динамически |
| **Authentication Endpoint URL** | [https://esia-portal1.test.gosuslugi.ru/aas/oauth2/ac](https://esia-portal1.test.gosuslugi.ru/aas/oauth2/ac) |
| **Access Token Endpoint URL** | [https://esia-portal1.test.gosuslugi.ru/aas/oauth2/te](https://esia-portal1.test.gosuslugi.ru/aas/oauth2/te) |
| **User Profile Service URL** | [https://esia-portal1.test.gosuslugi.ru/rs/prns](https://esia-portal1.test.gosuslugi.ru/rs/prns) |
| **Scope** | Scope профиля, для демонстрационных целей укажем `fullname birthdate gender`. Подробнее об описании scope можно ознакомится в документе по ссылке [https://digital.gov.ru/ru/documents/6186/](https://digital.gov.ru/ru/documents/6186/) |
| **OAuth2 Access Token Profile Service Parameter name** | access_token |
| **Proxy URL** | [http://openam.example.org:8080/openam/oauth2c/OAuthProxy.jsp](http://openam.example.org:8080/openam/oauth2c/OAuthProxy.jsp) |
| **Account Provider** | org.forgerock.openam.authentication.modules.common.mapping.DefaultAccountProvider |
| **Account Mapper** | org.forgerock.openam.authentication.modules.common.mapping.JsonAttributeMapper |
| **Account Mapper Configuration** | oid=uid |
| **Attribute Mapper** | org.forgerock.openam.authentication.modules.common.mapping.JsonAttributeMapper |
| **Attribute Mapper Configuration** | oid=uid
remote-json=sn |
| **Custom Properties** |  |
| **esia-key-path** | путь к файлу приватного ключа, например /usr/openam/esia/openam-esia.key |
| **esia-cert-path** | путь к файлу сертификата, например /usr/openam/esia/openam-esia.pem |
| **esia-org-scope** | scope организации, если нужно получить информацию об организации пользователя ЕСИА |
| **esia-org-info-url** | URL получения информации об организации, например [https://esia-portal1.test.gosuslugi.ru/rs/orgs/](https://esia-portal1.test.gosuslugi.ru/rs/orgs/) - для тестовой ЕСИА |

### Настройка цепочки аутентификации ЕСИА

Откройте консоль администратора OpenAM, выберите realm и в меню слева выберите `Authentication → Chains` . Нажмите кнопку `Add Chain` и введите имя цепочки, например, `esia` . Нажмите кнопку  `Create`.

![OpenAM new ESIA auth chain](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/esia-auth/1-openam-esia-chain.png)

Нажмите кнопку `Add a Module` .

![OpenAM ESIA chain module](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/esia-auth/2-openam-esia-chain-module.png)

Добавьте модуль `esia` , `Criteria` установите в `Requisite`. Нажмите кнопку `OK` .

## Проверка решения

Выйдите из консоли администратора OpenAM, и откройте ссылку аутентификации в цепочке ЕСИА. [http://openam.example.org:8080/openam/XUI/?service=esia](http://openam.example.org:8080/openam/XUI/?service=esia). Если все настроено корректно, вас перенаправит на портал аутентификации ЕСИА. Введите учетные данные пользователя. После успешной аутентификации в ЕСИА, ЕСИА запросит согласие на доступ к данным переданным в параметре scope. После принятия согласия на доступ к данным, вас перенаправит в консоль OpenAM с учетными данными пользователя ЕСИА.