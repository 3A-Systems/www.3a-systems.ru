---
layout: blog
title: 'Аутентификация через Одноклассники в OpenAM'
description: 'OpenAM умеет аутентифицировать пользователей через различных OAuth 2.0 провайдеров. И Одноклассники не исключение. Пусть этот сервис не пользуется большой популярностью среди близких к IT людям, но им могут пользоваться большинство ваших клиентов. Поэтому в данной статье мы настроим вход через этот сервис.'
tags: 
  - openam
---

## Введение

[OpenAM](http://github.com/OpenIdentityPlatform/OpenAM) умеет аутентифицировать пользователей через различных OAuth 2.0 провайдеров. И Одноклассники не исключение. Пусть этот сервис не пользуется большой популярностью среди близких к IT людям, но им могут пользоваться большинство ваших клиентов. Поэтому в данной статье мы настроим вход через этот сервис.

## Создание и настройка приложения

Создайте приложение, как описано в документации [https://apiok.ru/dev/app/create](https://apiok.ru/dev/app/create)

В разделе “Настройки внешнего приложения” укажите URL вашего сайта и список разрешенных redirect_uri. Аналогичный redirect_uri должен быть указан в OpenAM при дальнейшей настройке.

redirect_uri должен быть в формате `<URI OpenAM>/oauth2c/OAuthProxy.jsp` , например, `http://openam.example.org:8080/openam/oauth2c/OAuthProxy.jsp`

![OK redirect_uri settings](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-ok/0-redirect_uri-settings.png)

## Установка и настройка OpenAM

Как запустить OpenAM написано [тут](https://www.3a-systems.ru/blog/2024-11-25-openam-docker-quickstart).

### Настройка OpenAM

Откройте консоль администратора OpenAM по ссылке [http://openam.example.org:8080/openam/XUI](http://openam.example.org:8080/openam/XUI). В поле логин введите значение `amadmin` в поле пароль введите значение пароля, заданное в процессе установки OpenAM. В данном случае - `passw0rd`.

В основном меню перейдите Top Level Realm. 
В меню слева перейдите Authentication → Modules и создайте новый модуль аутентификации `ok`. Тип модуля - OAuth 2.0 / OpenID Connect.

![OpenAM new OAuth 2.0 OK module](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-ok/1-openam-new-oauth2-ok-module.png)

Заполните настройки модуля, согласно таблице:

| Настройка | Значение |
| --- | --- |
| Client Id | Application ID приложения Одноклассники |
| Client Secret | Секретный ключ приложения Одноклассники |
| Authentication Endpoint URL | [https://connect.ok.ru/oauth/authorize](https://connect.ok.ru/oauth/authorize) |
| Access Token Endpoint URL | [https://api.ok.ru/oauth/token.do](https://api.ok.ru/oauth/token.do) |
| User Profile Service URL | [https://api.ok.ru/api/users/getCurrentUser](https://api.ok.ru/api/users/getCurrentUser) |
| Scope | VALUABLE_ACCESS |
| OAuth2 Access Token Profile Service Parameter name | access_token |
| Proxy URL | Redirect URI, который был указан при создании приложения. [http://openam.example.org:8080/openam/oauth2c/OAuthProxy.jsp](http://openam.example.org:8080/openam/oauth2c/OAuthProxy.jsp) |
| Account Mapper Configuration | uid=uid |
| Attribute Mapper Configuration | first_name=givenName last_name=sn uid=uid |
| OpenID Connect validation configuration type | client_secret |
| Prompt for password setting and activation code | false |

Нажмите кнопку `Save`

Создайте цепочку аутентификации `ok` . В консоли администратора откройте Top Level Realm. В меню слева перейдите Authentication → Chains и создайте новую цепочку аутентификации. 

![OpenAM Odnoklassniki chain](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-ok/2-openam-ok-chain.png)

## Проверка решения

Выйдите из консоли администратора или откройте браузер в режиме “Инкогнито” и откройте ссылку [http://openam.example.org:8080/openam/XUI/?service=ok](http://openam.example.org:8080/openam/XUI/?service=ok)

Вас перенаправит в форму аутентификации Одноклассников, а после -  запрос на доступ к данным. 

![Odnoklassniki consent](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-ok/3-ok-consent.png)

После согласия, вы будете перенаправлены обратно в OpenAM с учетными данными пользователя Одноклассников.

![OpenAM Odnoklassniki profiles](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-ok/4-openam-ok-profile.png)