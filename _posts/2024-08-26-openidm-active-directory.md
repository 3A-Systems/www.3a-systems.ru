---
layout: blog
title: 'OpenIDM: Управление учетными записями Active Directory'
description: 'В данной статье мы настроим управление учетными записями Active Directory из OpenIDM.'
tags: 
  - openidm

---

## Введение

В данной статье мы настроим управление учетными записями Active Directory из OpenIDM. Рассмотрим типовой сценарий, когда служба HR оформляет на работу нового сотрудника, вносит его учетные данные в систему управления учетными записями (IDM) и из этой системы данные должны импортироваться в основной каталог. Как правило, это Active Directory.

## Настройка OpenIDM

Как быстро развернуть OpenIDM было описано в этой [статье](https://github.com/3A-Systems/OpenIDM/wiki/%D0%92%D0%B2%D0%B5%D0%B4%D0%B5%D0%BD%D0%B8%D0%B5-%D0%B2-Identity-Management-%D1%81-OpenIDM). Поэтому, будем считать, что OpenIDM у вас уже развернут.

### Настройка коннектора Active Directory.

Из каталога [samples/provisioners](https://github.com/OpenIdentityPlatform/OpenIDM/tree/master/openidm-zip/src/main/resources/samples/provisioners) поставки OpenIDM возьмите файл `provisioner.openicf-adldap.json` и скопируйте его в каталог установки openidm/conf
Измените значения конфигурации в соотвествии с вашим окружением:

Перейдите в консоль администратора Configure -> Connectors. В открывшемся списке выберите AD LDAP Connector и установите настройки согласно таблице 

![OpenID LDAP Active Directory Connector.png](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad/0-openidm-ad-connector.png)

| Настройка | Описание | Пример значения |
| --- | --- | --- |
| host | Имя хоста с AD | ad.example.org |
| port | Порт подключения к AD | 636 |
| ssl | Использование зашифрованного соединения | true |
| principal | Имя учетной записи, под которой будут осуществляться операции с AD | DOMAIN/Administrator |
| credentials | Пароль учетной записи (строка, после сохранения значение будет зашифровано) |  |
| baseContexts | Список стартовых точек LDAP для поиска учетных записей | CN=Users,DC=example,DC=org |
| baseContextsToSynchronize | Список стартовых точек LDAP для поиска учетных записей для синхронизации | CN=Users,DC=example,DC=org |
| accountSearchFilter | Фильтр, отбирающий учетные записи пользователей | (objectClass=user) |
| accountSynchronizationFilter | Фильтр, отбирающий учетные записи пользователейе для синхронизации | (objectClass=user) |
| groupSearchFilter | Фильтр, отбирающий группы | (objectClass=group) |
| groupSynchronizationFilter | Фильтр, отбирающий группы для синхронизации | (objectClass=group) |

Для синхронизации паролей из OpenIDM в Active Directory необходимо, чтобы подключение было по защищенному протоколу. Для установки защищенного соединения, сохраните сертификат из Active Directory командой:

```bash
openssl s_client -showcerts -connect ad.example.org:636 </dev/null 2>/dev/null|openssl x509 -outform PEM > ad_cert.pem
```

И загрузите сертификат в trust store OpenIDM командой:

```bash
keytool -import -alias openidm-ad -file ad_cert.pem -storetype JKS -keystore truststore
```

Trust store находится в каталоге дистрибутива OpenIDM в каталоге [openidm/security](https://github.com/OpenIdentityPlatform/OpenIDM/tree/master/openidm-zip/src/main/resources/security). Пароль для trust store по умолчанию - `changeit`

Так же для синхронизации паролей из OpenIDM добавьте в файл конфигурации коннектора Active Directory `provisioner.openicf-adldap.json` в объект account поле `password` после поля `whenCreated`. 

```json
"password" : {
    "type" : "string",
    "nativeName" : "__PASSWORD__",
    "nativeType" : "JAVA_TYPE_GUARDEDSTRING",
    "flags" : [
        "NOT_READABLE",
        "NOT_RETURNED_BY_DEFAULT"
    ]
}
```

### Проверка настройки Active Directory

В UI в настройках коннектора  AD вверху справа нажмите кнопку с тремя точками и выберите пункт Data (account). Появится список учетных записей Active Directory

![OpenIDM Active Directory Connector Data Account](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad/1-openidm-ad-data-account.png)

![OpenIDM Active Directory Connector Data Account List](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad/2-openidm-ad-data-account-list.png)

### Настройка синхронизации учетных записей OpenIDM и Active Directory.

В консоли администратора перейдите Configure → Mappings. Нажмите кнопку New Mapping.

![OpenIDM Mappings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad/3-openidm-mappings.png)

В source resource добавьте Managed Object → user. В target resource добавьте Connectors → ad. 

![OpenIDM User AD Mapping](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad/4-openidm-user-ad-mapping.png)

И нажмите кнопку Create mapping

В консоли администратора перейдите Configure → Mappings → managedUser_systemAdAccount

В Attributes Grid настройте сопоставление атрибутов согласно таблице

| Источник | Приемник | Trasnformation script | Conditional updates |
| --- | --- | --- | --- |
| userName | dn | `'CN=' + source + ',CN=Users,DC=ds,DC=gazprombank,DC=ru'` |  |
| givenName | givenName |  |  |
| sn | sn |  |  |
|  | cn | `source.displayName || (source.givenName + ' ' + [source.sn](http://source.sn/));` |  |
| description | description |  | `!!object.description` |
| telephoneNumber | telephoneNumber |  | `!!object.telephoneNumber` |
| userName | sAMAccountName |  |  |
| password | password |  |  |

На закладке Behaviors в разделе Policies выберите Default Actions и нажмите Save

### Отправка пароля по Email

В OpenIDM есть возможность генерировать случайный пароль и отправлять его на email. Для настройки в консоли администратора перейдите Configure → System Preferences → Email. Введите настройки SMTP сервера и нажмите кнопку Save

![OpenIDM Email SMPT Settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad/5-openidm-email-settings.png)

## Проверка решения

### Создание учетной записи

Теперь, когда мы настроили подключение к Active Directory и синхронизацию между учетными записями OpenIDM и AD, давайте проверим работу решения. В консоли администратора перейдите Manage → User и создайте новую учетную запись, нажав кнопку  New User. Заполните атрибуты нового пользователя и нажмите кнопку SaveУ

![OpenIDM new IDM user](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad/6-openidm-new-idmuser.png)

Учетную запись так же можно создать при помощи REST API OpenIDM

```bash
curl 'http://localhost:8080/openidm/managed/user?_action=create' \
 -H 'X-OpenIDM-Username: openidm-admin' \
 -H 'X-OpenIDM-Password: openidm-admin' \
 -H 'Content-Type: application/json' \
 --data-raw '{"mail":"jdoe@example.org","sn":"John","givenName":"Doe","telephoneNumber":"+7(999)123-45-67","userName":"idmUser"}' | json_pp

  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   357    0   242  100   115   1340    637 --:--:-- --:--:-- --:--:--  2063
{
   "_id" : "a250eb09-28a1-4fab-b338-e729986f38ec",
   "_rev" : "2",
   "accountStatus" : "active",
   "effectiveAssignments" : [],
   "effectiveRoles" : [],
   "givenName" : "Doe",
   "mail" : "jdoe@example.org",
   "sn" : "John",
   "telephoneNumber" : "+7(999)123-45-67",
   "userName" : "idmUser"
}

```

Проверить наличие созданной учетной записи можно так же при помощи GET запроса к API

```bash
curl 'http://localhost:8080/openidm/managed/user?_queryFilter=true' \
 -H 'X-OpenIDM-Username: openidm-admin' \
 -H 'X-OpenIDM-Password: openidm-admin' | json_pp
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   380    0   380    0     0  25112      0 --:--:-- --:--:-- --:--:-- 47500
{
   "pagedResultsCookie" : null,
   "remainingPagedResults" : -1,
   "result" : [
      {
         "_id" : "a250eb09-28a1-4fab-b338-e729986f38ec",
         "_rev" : "2",
         "accountStatus" : "active",
         "effectiveAssignments" : [],
         "effectiveRoles" : [],
         "givenName" : "Doe",
         "mail" : "jdoe@example.org",
         "sn" : "John",
         "telephoneNumber" : "+7(999)123-45-67",
         "userName" : "idmUser"
      }
   ],
   "resultCount" : 1,
   "totalPagedResults" : -1,
   "totalPagedResultsPolicy" : "NONE"
}

```

Учетная запись OpenIDM будет синхронизирована в Active Directory автоматически

Проверьте ее наличие в AD командой

```
ldapsearch -H ldap://ad.example.org.ru -x -W -D "admin@example.org" -b "dc=example,dc=org" "(sAMAccountName=idmUser)" | grep dn
Enter LDAP Password: 
dn: CN=idmUser,CN=Users,DC=example,DC=org
```

### Отправка пароля по Email

Если вы хотите установить пароль случайный пароль для Active Directory, перейдите на закладку Password и нажмите на кнопку Email Random Password.

![OpenIDM Email Random Password](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad/7-openidm-email-random-password.png)
Или при помощи POST запроса к API

```bash
curl 'http://localhost:8080/openidm/managed/user/a250eb09-28a1-4fab-b338-e729986f38ec?_action=resetPassword' \
 -X 'POST' \
 -H 'X-OpenIDM-Username: openidm-admin' \
 -H 'X-OpenIDM-Password: openidm-admin' | json_pp
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   242    0   242    0     0    100      0 --:--:--  0:00:02 --:--:--   101
{
   "_id" : "a250eb09-28a1-4fab-b338-e729986f38ec",
   "_rev" : "4",
   "accountStatus" : "active",
   "effectiveAssignments" : [],
   "effectiveRoles" : [],
   "givenName" : "Doe",
   "mail" : "jdoe@example.org",
   "sn" : "John",
   "telephoneNumber" : "+7(999)123-45-67",
   "userName" : "idmUser"
}

```

Будет сгенерирован новый пароль и отправлен пользователю на Email. Этот же пароль будет установлен для входа в Active Directory.

### Удаление учетной записи

В консоли администратора перейдите Manage → User. Выберите учетную запись и нажмите Delete.

![OpenIDM Delete Account](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad/8-openidm-delete-account.png)

Во всплывающем диалоге нажмите кнопку Ок. 

При помощи DELETE запроса к OpenIDM API:

```bash
curl 'http://localhost:8080/openidm/managed/user/a250eb09-28a1-4fab-b338-e729986f38ec' \
 -X 'DELETE' \
 -H 'X-OpenIDM-Username: openidm-admin' \
 -H 'X-OpenIDM-Password: openidm-admin' | json_pp
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   242    0   242    0     0    756      0 --:--:-- --:--:-- --:--:--   773
{
   "_id" : "a250eb09-28a1-4fab-b338-e729986f38ec",
   "_rev" : "4",
   "accountStatus" : "active",
   "effectiveAssignments" : [],
   "effectiveRoles" : [],
   "givenName" : "Doe",
   "mail" : "jdoe@example.org",
   "sn" : "John",
   "telephoneNumber" : "+7(999)123-45-67",
   "userName" : "idmUser"
}
```

Проверим удаление учетной записи OpenIDM через REST API

```bash
curl 'http://localhost:8080/openidm/managed/user?_queryFilter=true' \
 -H 'X-OpenIDM-Username: openidm-admin' \
 -H 'X-OpenIDM-Password: openidm-admin' | json_pp
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   138    0   138    0     0   7306      0 --:--:-- --:--:-- --:--:-- 11500
{
   "pagedResultsCookie" : null,
   "remainingPagedResults" : -1,
   "result" : [],
   "resultCount" : 0,
   "totalPagedResults" : -1,
   "totalPagedResultsPolicy" : "NONE"
}
```

Проверьте наличие учетной записи в Active Directory командой:

```
ldapsearch -H ldap://ad.example.org.ru -x -W -D "admin@example.org" -b "dc=example,dc=org" "(sAMAccountName=idmUser)" | grep dn | wc -l
Enter LDAP Password: 
0
```

 Как видно из вывода команды, учетная запись была удалена из AD.