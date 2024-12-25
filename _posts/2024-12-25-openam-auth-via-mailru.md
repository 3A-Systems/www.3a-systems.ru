---
layout: blog
title: 'Аутентификация в OpenAM через Mail.ru'
description: 'В данной статье мы настроим вход в OpenAM, используя аутентификацию в Mail.ru по протоколу OAuth 2.0. Таким образом, ваши пользователи смогут входить в приложения, защищенные OpenAM, используя свои учетные записи Mail.ru.'
tags: 
  - openam
---
## Введение

[Mail.ru](http://Mail.ru) - один из самых популярных сервисов электронной почты в России. Ежемесячная аудитория составляет более 50 млн пользователей. Поэтому ваши пользователи могут использовать свои учетные данные в [mail.ru](http://mail.ru) для аутентификации через [OpenAM](https://github.com/OpenIdentityPlatform/OpenAM).

## Создание и настройка приложения

У вас должен быть зарегистрированный почтовый ящик на mail.ru

- Перейдите по ссылке управления приложениями  [https://o2.mail.ru/app/](https://o2.mail.ru/app/).
- Нажмите кнопку “Создать приложение”
- Укажите имя приложения
- При, желании вы можете загрузить изображение вашего приложения
- redirect_uri должен быть в формате `<URI OpenAM>/oauth2c/OAuthProxy.jsp` , например, `http://openam.example.org:8080/openam/oauth2c/OAuthProxy.jsp`
- Нажмите кнопку “Подключить сайт”

![Mail.ru application settings](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-mailru/0-mailru-app-settings.png)

- На странице редактирования приложения вы увидите Client Id и Client Secret. Они понадобятся вам при настройке OpenAM.
- Убедитесь, что в разделе “Платформы” установлен чекбокс “Web”.

![Mail.ru edit application](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-mailru/1-mailru-app-edit.png)

## Установка и настройка OpenAM

Как запустить OpenAM написано [тут](https://www.3a-systems.ru/blog/2024-11-25-openam-docker-quickstart).

### Настройка OpenAM

Откройте консоль администратора OpenAM по ссылке [http://openam.example.org:8080/openam/XUI](http://openam.example.org:8080/openam/XUI). В поле логин введите значение `amadmin` в поле пароль введите значение пароля, заданное в процессе установки OpenAM. В данном случае - `passw0rd`.

В основном меню перейдите Top Level Realm. 
В меню слева перейдите Authentication → Modules и создайте новый модуль аутентификации `mailru`. Тип модуля - OAuth 2.0 / OpenID Connect.

![OpenAM new Mail.ru authentication module](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-mailru/2-openam-new-mailru-module.png)

Заполните настройки модуля, согласно таблице:

| Настройка | Значение |
| --- | --- |
| Client Id | Client ID приложения mail.ru |
| Client Secret | Client Secret приложения mail.ru |
| Authentication Endpoint URL | [https://oauth.mail.ru/login](https://oauth.mail.ru/login) |
| Access Token Endpoint URL | [https://oauth.mail.ru/token](https://oauth.mail.ru/token) |
| User Profile Service URL | [https://oauth.mail.ru/userinfo](https://oauth.mail.ru/userinfo) |
| Scope | email |
| OAuth2 Access Token Profile Service Parameter name | access_token |
| Proxy URL | Redirect URI, который был указан при создании приложения. [http://openam.example.org:8080/openam/oauth2c/OAuthProxy.jsp](http://openam.example.org:8080/openam/oauth2c/OAuthProxy.jsp) |
| Account Mapper Configuration | id=uid email=mail |
| Attribute Mapper Configuration | id=uid email=mail last_name=sn first_name=givenName |
| OpenID Connect validation configuration type | client_secret |
| Prompt for password setting and activation code | false |

Нажмите кнопку `Save`

Создайте цепочку аутентификации `mailru` . В консоли администратора откройте Top Level Realm. В меню слева перейдите Authentication → Chains и создайте новую цепочку аутентификации. 

![OpenAM Mail.ru authentication chain](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-mailru/3-openam-mailru-chain.png)

## Проверка решения

Выйдите из консоли администратора или откройте браузер в режиме “Инкогнито” и откройте ссылку [http://openam.example.org:8080/openam/XUI/?service=mailru](http://openam.example.org:8080/openam/XUI/?service=ok)

Вас перенаправит в форму аутентификации mail.ru, а после -  запрос на доступ к данным. 

![Mail.ru user consent](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-mailru/4-mailru-consent.png)

После согласия, вы будете перенаправлены обратно в OpenAM с учетными данными пользователя mail.ru.

![OpenAM mail.ru user profile](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-mailru/5-openam-mailru-profile.png)