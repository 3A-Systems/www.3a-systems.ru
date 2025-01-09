---
layout: blog
title: 'Аутентификация в OpenAM через ВКонтакте (VK)'
description: 'ВКонтакте (VK) - одна из самых, если на самая, популярная социальная сеть в российском сегменте. И в этой статье мы настроим аутентификацию в OpenAM через VK по протоколу OAuth 2.0'
tags: 
  - openam
---
## Введение

ВКонтакте (VK) - одна из самых, если на самая, популярная социальная сеть в российском сегменте. И в этой статье мы настроим аутентификацию в [OpenAM](http://github.com/OpenIdentityPlatform/OpenAM) через VK по протоколу OAuth 2.0

## Создание и настройка приложения

- Создайте приложение, по инструкции по [ссылке](https://id.vk.com/about/business/go/docs/ru/vkid/latest/vk-id/connection/create-application)
- Добавьте в список платформ платформу Web
- При создании приложения Доверенный redirect URL должен быть в виде `<URI OpenAM>/oauth2c/OAuthProxy.jsp` , например, `https://openam.example.org/openam/oauth2c/OAuthProxy.jsp`

![VKontakte app settings](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-vk/0-vk-app-settings.png)

## Установка и настройка OpenAM

Как запустить OpenAM написано [тут](https://www.3a-systems.ru/blog/2024-11-25-openam-docker-quickstart).

### Настройка OpenAM

Откройте консоль администратора OpenAM по ссылке [https://openam.example.org/openam/XUI](https://openam.example.org/openam/XUI). В поле логин введите значение `amadmin` в поле пароль введите значение пароля, заданное в процессе установки OpenAM. В данном случае - `passw0rd`.

В основном меню перейдите Top Level Realm. 
В меню слева перейдите Authentication → Modules и создайте новый модуль аутентификации `vk`. Тип модуля - OAuth 2.0 / OpenID Connect.

![OpenAM new VK auth module](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-vk/1-openam-new-vk-module.png)

Заполните настройки модуля, согласно таблице:

| Настройка | Значение |
| --- | --- |
| Client Id | ID приложения ВКонтакте |
| Client Secret | Защищенный ключ приложения ВКонтакте |
| Authentication Endpoint URL | [https://oauth.vk.com/authorize](https://oauth.vk.com/authorize) |
| Access Token Endpoint URL | [https://oauth.vk.com/access_token](https://oauth.vk.com/access_token) |
| User Profile Service URL | [https://api.vk.com/method/users.get](https://api.vk.com/method/users.get) |
| Scope | userinfo |
| OAuth2 Access Token Profile Service Parameter name | access_token |
| Proxy URL | Redirect URI, который был указан при создании приложения. [https://openam.example.org/openam/oauth2c/OAuthProxy.jsp](https://openam.example.org/openam/oauth2c/OAuthProxy.jsp) |
| Account Mapper Configuration | id=uid |
| Attribute Mapper Configuration | id=uid last_name=sn first_name=givenName |
| OpenID Connect validation configuration type | client_secret |
| Prompt for password setting and activation code | false |

Нажмите кнопку `Save`

Создайте цепочку аутентификации `vk` . В консоли администратора откройте Top Level Realm. В меню слева перейдите Authentication → Chains и создайте новую цепочку аутентификации. 

## Проверка решения

Выйдите из консоли администратора или откройте браузер в режиме “Инкогнито” и откройте ссылку [https://openam.example.org/openam/XUI/?service=vk](https://openam.example.org/openam/XUI/?service=vk)

Вас перенаправит в форму аутентификации vk, а после -  запрос на доступ к данным. 

![VK user consent](https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-vk/2-vk-consent.png)

После согласия, вы будете перенаправлены обратно в OpenAM с учетными данными пользователя ВКонтакте.

![OpenAM mail.ru user profile](%https://raw.githubusercontent.com/wiki/3A-Systems/OpenAM/images/oauth2-vk/4-openam-vk-profile.png)