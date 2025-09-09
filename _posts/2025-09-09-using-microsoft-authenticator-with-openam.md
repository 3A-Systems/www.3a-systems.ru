---
layout: blog
title: Использование Microsoft Authenticator совместно с OpenAM
description: 'Пошаговая инструкция по настройке двухфакторной аутентификации (2FA) в OpenAM с использованием Microsoft Authenticator и TOTP для повышения безопасности.'
keywords: 'OpenAM, Microsoft Authenticator, двухфакторная аутентификация, 2FA, TOTP, одноразовые пароли, настройка OpenAM, интеграция OpenAM, безопасность учетных записей, модуль аутентификации, цепочка аутентификации, Google Authenticator, OpenAM TOTP, аутентификация по QR-коду, настройка 2FA, Open Identity Platform, push-уведомления, защита доступа, мультифакторная аутентификация, Docker OpenAM'
tags: 
  - openam
---

# Использование Microsoft Authenticator совместно с OpenAM

Статья предназначена для технических специалистов или архитекторов систем безопасности, которые хотят внедрить второй фактор аутентификации (2FA) в систему управления доступом для повышения безопасности учетных записей пользователей.

Добавление второго фактора существенно усложняет задачу компрометации учетных записей для злоумышленников.

## Используемый стек

**OpenAM** - система управления доступом с открытым исходным кодом. Предназначена для централизованного управления аутентификацией, авторизацией и учетными записями пользователей. 

**Microsoft Authenticator** - мобильное приложение, предназначенное для использования в качестве дополнительного фактора аутентификации. Поддерживает PUSH уведомления, одноразовые пароли (TOTP), биометрическую аутентификацию.

В статье мы развернем OpenAM, настроим модули и цепочки аутентификации для использования совместно с Microsoft Authenticator или Google Authenticator и покажем как использовать.

Будем использовать аутентификацию с помощью одноразовых паролей, сгенерированных по протоколу TOTP (time based one-time password). Такие пароли не нужно отправлять на клиентское устройство через SMS или PUSH уведомления. Они генерируются по определенному криптографическому алгоритму непосредственно на устройстве.

## Установка OpenAM

Если у вас еще не установлен OpenAM, вы можете развернуть Docker контейнер, как описано по [адресу](https://github.com/OpenIdentityPlatform/OpenAM/wiki/TIP%3A-Quick-OpenAM-Docker-Configuration-From-a-Command-Line).

## Настройка OpenAM

Мы настроим модуль и цепочку аутентификации.

Модуль аутентификации в OpenAM отвечает за определенный способ аутентификации. Это может быть аутентификация с логином и паролем, по протоколу Kerberos или с использованием биометрии.
Модули можно выстраивать в цепочки. Таким образом, вы можете выстраивать цепочки из модулей, чтобы аутентифицировать пользователей в несколько этапов или разными способами. Например, если не прошла бесшовная аутентификация по протоколу Kerberos, запросить у пользователя его логин и пароль.

### Настройка модуля аутентификации

Откройте консоль администратора по ссылке [http://openam.example.org:8080/openam/console](http://openam.example.org:8080/openam/console)

В поле логин введите значение `amadmin` в поле пароль введите пароль администратора, указанный при установке.

Откройте корневой realm, в меню слева выберите Authentication → Modules и нажмите кнопку `Add Module`. В появившейся форме введите имя модуля, например `totp` и тип модуля - `Authenticator (OATH)`. Нажмите кнопку `Create`.

![OpenAM new TOTP module](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/ms-authenticator/0-openam-new-totp-module.png)

Установите настройку `OATH Algorithm to Use` в `TOTP`, в поле `Name of the Issuer` любое не пустое значение, например `OpenAM` и нажмите `Save Changes`.

![OpenAM TOTP module settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/ms-authenticator/1-openam-totp-module-settings.png)

### Настройка цепочки регистрации устройства

Цепочка регистрации нужна для того, чтобы аутентифицированный пользователь мог подключить себе аутентификацию при помощи Microsoft Authenticator.

В консоли администратора в настройках realm в меню слева выберите Authentication → Chains и в открывшемся списке нажмите кнопку `Add Chain`.

Введите имя цепочки `totp-register` и нажмите кнопку `Create`.

В настройках цепочки нажмите кнопку `Add a Module` и добавьте созданный модуль аутентификации `totp` как показано на рисунке. Нажмите кнопку `OK`, а затем `Save Changes`

![OpenAM TOTP registration chain](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/ms-authenticator/2-openam-totp-registration-chain.png)

### Настройка цепочки аутентификации

В этой цепочке мы уже настроим аутентификацию таким образом, чтобы после аутентификации с логином и паролем пользователь вводил одноразовый код из мобильного приложения Microsoft Authenticator.

В консоли администратора в настройках realm в меню слева выберите Authentication → Chains и в открывшемся списке нажмите кнопку `Add Chain`.

Введите имя цепочки `totp-login` и нажмите кнопку `Create`. Первым добавьте модуль аутентификации с логином и паролем `DataStore`. Потом добавьте модуль аутентификации с одноразовым кодом `totp` .

Нажмите `Save Changes`

![OpenAM TOTP authentication chain](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/ms-authenticator/3-openam-totp-authentication-chain.png)

## Настройка Microsoft Authenticator.

Скачайте приложение [Microsoft Authenticator](https://www.microsoft.com/en/security/mobile-authenticator-app) из магазина приложений, подходящего для вашего устройства.

### Регистрация устройства

Войдите в консоль с учетной записью тестового пользователя. Для этого выйдите из консоли администратора или откройте браузер в режиме “Инкогнито”. Перейдите по ссылке [http://openam.example.org:8080/openam/XUI/#login/](http://openam.example.org:8080/openam/XUI/#login/) и войдите в OpenAM с учетной записью `demo`. Пароль по умолчанию `changeit`. 

После успешной аутентификации откройте в браузере ссылку цепочки регистрации устройства. [http://openam.example.org:8080/openam/XUI/#login&service=totp-register](http://openam.example.org:8080/openam/XUI/#login&service=totp-register).

![OpenAM register a device](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/ms-authenticator/4-openam-register-device.png)

Откройте приложение Microsoft Authenticator, нажмите кнопку `Add account`

![Microsoft Authenticator Add account](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/ms-authenticator/5-ms-authenticator-add-account.png)


Выберите `Other account`

![Microsoft Authenticator Other account](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/ms-authenticator/6-ms-authenticator-other-account.png)

Вам будет предложено сканировать QR код. Сканируйте его с экрана браузера с OpenAM. После сканирования в приложение Microsoft Authenticator будет добавлена учетная запись OpenAM. 

![Microsoft Authenticator Account List](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/ms-authenticator/7-ms-authenticator-account-list.png)

Откройте добавленную учетную запись. Вам будет показан одноразовый пароль.

![Microsoft Authenticator One-Time Password](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/ms-authenticator/8-ms-authenticator-otp.png)

В браузере нажмите кнопку `Login Using Verification Code`. 

Введите одноразовый пароль из мобильного приложения и нажмите кнопку `Submit`.

### Аутентификация с одноразовым паролем

Выйдите из консоли OpenAM или откройте браузер в режиме “Инкогнито”. Перейдите по ссылке [http://openam.example.org:8080/openam/XUI/#login&service=totp-login](http://openam.example.org:8080/openam/XUI/#login&service=totp-login).

Введите логин и пароль пользователя `demo`. После ввода логина и пароля OpenAM запросит одноразовый пароль из мобильного приложения. Откройте мобильное приложение выберите аккаунт пользователя `demo` и введите в браузере одноразовый пароль из мобильного приложения и нажмите кнопку `Submit`. После ввода корректного одноразового пароля аутентификация будет успешно завершена.