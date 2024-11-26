---
layout: blog
title: 'Аутентификация через Яндекс в OpenAM'
description: 'В данной статье мы настроим вход в OpenAM, используя аутентификацию в Яндекс по протоколу OAuth 2.0. Таким образом, ваши пользователи смогут входить в приложения, защищенные OpenAM, используя свои учетные записи Яндекс.'
tags: 
  - openam
---

## Введение

В данной статье мы настроим вход в OpenAM, используя аутентификацию в Яндекс по протоколу [OAuth 2.0](https://oauth.net/2/). Таким образом, ваши пользователи смогут входить в приложения, защищенные OpenAM, используя свои учетные записи Яндекс.

## Создание приложения в Яндекс

Откройте [ссылку](https://oauth.yandex.ru/client/new) создания нового приложения

Заполните нужные данные, как показано на скриншоте ниже

![Яндекс создание приложения, шаг 1](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-yandex/0-yandex-create-app-1.png)

Отметьте данные пользователя Яндекс, которые хотите получить после аутентификации

![Яндекс создание приложения, шаг 2](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-yandex/1-yandex-create-app-2.png)

Заполните URI OpenAM и укажите хост, где будет располагаться кнопка авторизации. В данном случае, любой.

Redirect URI должен быть в формате `<URI OpenAM>/oauth2c/OAuthProxy.jsp` , например, `http://openam.example.org:8080/openam/oauth2c/OAuthProxy.jsp`

![Яндекс создание приложения, шаг 3](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-yandex/2-yandex-create-app-3.png)

Укажите почту для связи

![Яндекс создание приложения, шаг 4](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-yandex/3-yandex-create-app-4.png)

На экране настроек приложения обратите внимания не значения ClientID и Client secret. Они понадобятся при настройке OpenAM.

![Яндекс, настройки приложения](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-yandex/4-yandex-app-settings.png)

## Установка и настройка OpenAM

Как запустить OpenAM написано [тут](https://www.3a-systems.ru/blog/2024-11-25-openam-docker-quickstart).

### Настройка OpenAM

Откройте консоль администратора OpenAM по ссылке [http://openam.example.org:8080/openam/XUI](http://openam.example.org:8080/openam/XUI). В поле логин введите значение `amadmin` в поле пароль введите значение пароля, заданное в процессе установки OpenAM. В данном случае - `passw0rd`.

В основном меню перейдите Top Level Realm. 
В меню слева перейдите Authentication → Modules и создайте новый модуль аутентификации `yandex`. Тип модуля - OAuth 2.0 / OpenID Connect.

![OpenAM новый модуль аутентификации](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-yandex/5-openam-new-auth-module.png)

Заполните настройки модуля, согласно таблице:

| Настройка | Значение |
| --- | --- |
| Client Id | Client ID приложения Яндекс |
| Client Secret | Client Secret приложения Яндекс |
| Authentication Endpoint URL | [https://oauth.yandex.ru/authorize](https://oauth.yandex.ru/authorize) |
| Access Token Endpoint URL | [https://oauth.yandex.ru/token](https://oauth.yandex.ru/token) |
| User Profile Service URL | [https://login.yandex.ru/info](https://login.yandex.ru/info) |
| Scope | login:email |
| OAuth2 Access Token Profile Service Parameter name | access_token |
| Proxy URL | Redirect URI, который был указан при создании приложения Яндекс.
[http://openam.example.org:8080/openam/oauth2c/OAuthProxy.jsp](http://openam.example.org:8080/openam/oauth2c/OAuthProxy.jsp) |
| Account Mapper Configuration | id=uid |
| Attribute Mapper Configuration | id=uid default_email=mail login=cn |
| OpenID Connect validation configuration type | client_secret |
| Prompt for password setting and activation code | false |

Нажмите кнопку `Save`

Создайте цепочку аутентификации.

В консоли администратора перейдите в Top Level Realm. В меню слева перейдите Authentication → Chains и создайте новую цепочку аутентификации `yandex`. Нажмите кнопку `Add a Module` и добавьте созданный модуль аутентификации `yandex`.

![OpenAM цепочка аутентификации Yandex](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-yandex/6-openam-yandex-auth-chain.png)

Нажмите кнопку `Save Changes`.

## Проверка решения

Выйдите из консоли администратора, или откройте окно браузера в режиме “Инкогнито”. 

Перейдите по ссылке аутентификации в цепочке аутентификации Яндекс. [http://openam.example.org:8080/openam/XUI/?service=yandex](http://openam.example.org:8080/openam/XUI/?service=yandex)

Откроется окно аутентификации Яндекса. Войдите удобным для вас способом. 

![Аутенитфикация Яндекс](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-yandex/7-yandex-auth.png)

После успешной аутентификации в Яндекс будет создана учетная запись OpenAM с данными учетной записи Яндекс.

![OpenAM успешная аутенитфикация](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-yandex/8-openam-authenticated.png)
