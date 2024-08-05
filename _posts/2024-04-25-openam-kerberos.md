---
layout: blog
title: 'Настройка Kerberos аутентификации в OpenAM'
description: 'В корпоративном среде пользователи используют, как правило несколько приложений. И в каждом приложении в корпоративной среде необходимо аутентифицироваться. Конечно, можно создавать для каждого приложения свою учетную запись. Но такой подход неудобен и для администраторов системы и для пользователей. Гораздо удобнее входить в приложение под пользователем, который уже аутентифицирован в операционной системе. Для пользователей в домене Windows - таким решением является протокол Kerberos.'
tags: 
  - openam

---

## Введение

В корпоративной среде пользователи используют, как правило несколько приложений. И в каждом приложении в корпоративной среде необходимо аутентифицироваться. Конечно, можно создавать для каждого приложения свою учетную запись. Но такой подход неудобен и для администраторов системы и для пользователей. Гораздо удобнее входить в приложение под пользователем, который уже аутентифицирован в операционной системе. Для пользователей в домене Windows - таким решением является протокол [Kerberos](https://en.wikipedia.org/wiki/Kerberos_(protocol)).

## Предварительные условия

Учетные записи пользователей хранятся в Active Directory под управлением Windows Server. У вас так же должен быть установлен OpenAM. Как быстро установить OpenAM, написано [тут](https://github.com/OpenIdentityPlatform/OpenAM/wiki/TIP:-Quick-OpenAM-Docker-Configuration-From-a-Command-Line).

## Настройка Windows

Создайте в Active Directory учетную запись для аутентификации Kerberos. При создании учетной записи установите чекбоксы `User cannot change password` и `Password never expires enabled` как показано на рисунке ниже.

![Kerberos Account Settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/kerberos/kerberos-account.png)

В свойствах учетной записи на вкладке Account включите чекбокс `This account supports Kerberos AES-256 bit encryption`.

На контроллере домена создайте файл keytab в текущей директории. Для этого выполните команду в терминале Windows:

```powershell
ktpass -out openamKerberos.keytab -princ HTTP/openam.example.com@AD.EXAMPLE.COM -pass +rndPass -maxPass 256 -mapuser openamKerberos -crypto AES256-SHA1 -ptype KRB5_NT_PRINCIPAL
```

In в данной команде в параметре  `-princ`  openam.example.com - имя хоста OpenAM и EXAMPLE.COM - имя домена Active Directory, должно быть в верхнем регистре.

Скопируйте файл`openamKerberos.keytab` в директорию, из которой OpenAM сможет ее прочитать. Откройте на firewall сетевой доступ от OpenAM к контроеллеру домена ad.example.com:88 по протоколам TCP и UDP

Проверьте файл keytab  на машине с OpenAM:

```bash
$ klist -k -t openamKerberos.keytab
Keytab name: FILE:openamKerberos.keytab
KVNO Timestamp Principal
---- ------------------- ------------------------------------------------------
0 01.01.1970 03:00:00 HTTP/openam.example.com@AD.EXAMPLE.COM
```

## Настройка OpenAM

### Создание модуля аутентификации

Откройте консоль администратора OpenAM. В поле логин введите значение `amadmin`, поле пароль введите значение из параметра `ADMIN_PWD` команды установки.

Выберите realm и в меню слева перейдите Authentication → Modules. В списке модулей нажмите кнопку `Add Module` . Введите имя модуля, например `sso` и тип модуля - `Windows Desktop SSO` .

Установите Service Principal как был указан в команде `ktpass`. `Keytab File Name` должен быть путь к файлу `openamKerberos.keytab` инстансе OpenAM.  Установите Kerberos Realm, Kerberos Server Name и Trusted Kerveros realms в соответствии с вашей инфраструктурой.

![SSO Kerberos New Authentication Module](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/kerberos/1-kerberos-module.png)

### Настройка цепочки аутентификации

В консоли администратора выберите нужный realm и в меню выберите пункт Authentication → Chains. Создайте цепочку аутентификации `sso` с созданным модулем `sso`.

![SSO Kerberos Authentication Chain Settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/kerberos/2-kerberos-chain.png)

### **Настройка realm**

Перейдите в раздел Authentication → Chains для realm и на закладке User Profile установите настройку `User Profile` в значение `Ignore`.

![OpenAM Realm User Profile Settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/kerberos/3-openam-realm-auth-settings.png)

Таким образом, вы можете аутентифицироваться по протоколу Kerberos без подключения Active Directory в User Data Store в OpenAM.

## Проверка решения

На Windows машине под аутентифицированным в Active Directory пользователем откройте в браузере url OpenAM  [http://openam.example.com:8080/openam/XUI/#login/&realm=/&service=sso](http://openam.example.com:8080/openam/XUI/#login/&realm=/staff&service=sso)

Если все настроено корректно, OpenAM сразу аутентифицирует вас без запроса учетных данных.