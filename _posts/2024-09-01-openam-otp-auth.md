---
layout: blog
title: 'Настройка аутентификации с одноразовым паролем в OpenAM'
description: 'В данной статье мы настроим аутентификацию в OpenAM с использованием одноразовых кодов, сгенерированных от времени - Time-based One-Time Password Algorithm (TOTP,  RFC 6238).'
tags: 
  - openam

---
## Введение

Аутентификация с паролем является, пожалуй, самым распространенным методом аутентификации. Но она не является достаточной надежной. Часто пользователи используют простые пароли или используют  один и тот же пароль для разных сервисов. Таким образом пароль пользователя может быть скомпрометирован. Для увеличения  безопасности в процесс аутентификации добавляют второй фактор. (Two Factor Authentication, 2FA). Второй фактор в аутентификации это дополнительный уровень защиты учетной записи. Помимо логина и пароля для аутентификации нужно ввести код из SMS, ввести биометрические данные, использовать аппаратный токен и так далее. Таким образом, даже если пароль учетной записи будет скомпрометирован, злоумышленник не сможет получит доступ к учетной записи, т.к. при аутентификации требуется пройти еще один уровень защиты.  В данной статье мы настроим аутентификацию в [OpenAM](http://github.com/OpenIdentityPlatform/OpenAM) с использованием одноразовых кодов, сгенерированных от времени - Time-based One-Time Password Algorithm (TOTP,  [RFC 6238](https://tools.ietf.org/html/rfc6238)).

## Настройка OpenAM

### Установка OpenAM

Если вы еще не установили OpenAM, вы можете это сделать, как описано [тут](https://github.com/OpenIdentityPlatform/OpenAM/wiki/TIP:-Quick-OpenAM-Docker-Configuration-From-a-Command-Line).

### Настройка модуля аутентификации

Откройте консоль администратора по ссылке [http://openam.example.org:8080/openam/console](http://openam.example.org:8080/openam/console)

В поле логин введите значение `amadmin` в поле пароль введите пароль администратора, указанный при установке.

Откройте корневой realm, в меню слева выберите Authentication → Modules и нажмите кнопку `Add Module`. В появившейся форме введите имя модуля, например `totp` и тип модуля - `Authenticator (OATH)`. Нажмите кнопку `Create`.

![OpenAM new module](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-2fa/0-openam-new-module.png)
Установите настройку `OATH Algorithm to Use` в `TOTP`**,** в поле `Name of the Issuer` любое не пустое значение, например `OpenAM` и нажмите `Save Changes`.

![OATH module settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-2fa/1-oath-module-settings.png)

### Настройка цепочки регистрации устройства

В консоли администратора в настройках realm в меню слева выберите Authentication → Chains и в открывшемся списке нажмите кнопку `Add Chain`.

Введите имя цепочки `totp-register` и нажмите кнопку `Create`. 

В настройках цепочки  нажмите кнопку `Add a Module` и добавьте созданный модуль аутентификации `totp` как показано на рисунке. Нажмите кнопку `OK` а затем `Save Changes` .

![Devide registration chain](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-2fa/2-device-registration-chain.pngg)

### Настройка цепочки аутентификации

В консоли администратора в настройках realm в меню слева выберите Authentication → Chains и в открывшемся списке нажмите кнопку `Add Chain`.

Введите имя цепочки `totp-login` и нажмите кнопку `Create`. Первым добавьте модуль аутентификации с логином и паролем `DataStore`. Потом добавьте модуль аутентификации с одноразовым кодом `totp` .

Нажмите `Save Changes`

![2FA login chain](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-2fa/3-2fa-login-chain.png)

## Проверка решения

Скачайте на ваше мобильное устройство приложение Microsoft Authenticator или Google Authenticator.

### Подготовка тестового пользователя

В консоли администратора OpenAM перейдите в корневой realm, в меню слева выберите пункт Subjects. Задайте пароль для пользователя `demo`. Для этого выберите его в списке пользователей, и нажмите ссылку Edit в пункте Password. Введите и сохраните новый пароль. После настройки выйдите из консоли администратора.

### Регистрация устройства

Войдите в консоль с учетной записью тестового пользователя. Для этого выйдите из консоли администратора или откройте браузер в режиме “Инкогнито”.  Перейдите по URL [http://openam.example.org:8080/openam/XUI/#login/](http://openam.example.org:8080/openam/XUI/#login/) и войдите в OpenAM с учетной записью `demo`.  После успешной аутентификации откройте в браузере ссылку цепочки аутентификации регистрации устройства. [http://openam.example.org:8080/openam/XUI/#login&service=totp-register](http://openam.example.org:8080/openam/XUI/#login&service=totp-register).

Нажмите кнопку `Register Device`.  В браузере появится QR код. Откройте мобильное приложение и нажмите кнопку добавления аккаунта. Отсканируйте QR код. В мобильное приложение аутентификатора будет добавлена учетная запись пользователя `demo` для OpenAM. 

![QR device registration](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-2fa/4-qr-device-registration.png)

Затем в браузере нажмите кнопку `Login Using Verification Code` . Введите код из мобильного приложения и нажмите кнопку `Submit` . 

![Enter TOTP form](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-2fa/5-enter-totp.png)

Приложение зарегистрировано.

### Аутентификация с одноразовым паролем

Выйдите из консоли OpenAM или откройте браузер в режиме “Инкогнито”. Перейдите по ссылке [http://openam.example.org:8080/openam/XUI/#login&service=totp-login](http://openam.example.org:8080/openam/XUI/#login&service=totp-login).

Введите логин и пароль пользователя `demo`. После ввода логина и пароля OpenAM запросит одноразовый пароль из мобильного приложения.  Откройте мобильное приложение выберите аккаунт пользователя `demo` и введите в браузере одноразовый пароль из мобильного приложения и нажмите кнопку `Submit`. После ввода корректного одноразового пароля аутентификация завершится успешно.