---
layout: blog
title: 'Настройка OpenIDM для синхронизации между Active Directory и OpenDJ'
description: 'В этой статье мы настроим синхронизацию между Active Directory и OpenDJ в обе стороны. Таким образом изменения, внесенные в Active Directory, будут синхронизированы в OpenDJ и наоборот, изменения в OpenDJ будут синхронизированы с Active Directory.'
tags: 
  - openidm
---

## Введение

В этой статье мы настроим синхронизацию между Active Directory и OpenDJ в обе стороны. Таким образом изменения, внесенные в Active Directory, будут синхронизированы в OpenDJ и наоборот, изменения в OpenDJ будут синхронизированы с Active Directory.

## Настройка OpenIDM

Развертывание OpenIDM описано в [документации](https://doc.openidentityplatform.org/openidm/install-guide/). Предполагается, что OpenIDM у вас уже развернут и готов к настройке.

## Настройка источников данных

### Настройка Active Directory

Скачайте с GitHub файл подключения к Active Directory [provisioner.openicf-adldap.json](https://raw.githubusercontent.com/OpenIdentityPlatform/OpenIDM/refs/heads/master/openidm-zip/src/main/resources/samples/provisioners/provisioner.openicf-adldap.json) и скопируйте его в каталог `conf` OpenIDM

Поменяйте свойства в соответствии с настройками вашего сервера Active Directory:

| Настройка | Описание |
| --- | --- |
| host | Имя хоста/IP адрес сервера AD |
| port | Порт подключения (по умолчанию 389) |
| ssl | По умолчанию SSL не используется |
| principal | DN учетной записи, подключающейся к AD, например `"CN=Administrator,CN=Users,DC=example,DC=com"` |
| credentials | Пароль учетной записи |
| baseContexts | Список DN, содержащих учетные записи для синхронизации, например, `["CN=Users,DC=Example,DC=com"]` |
| baseContextsToSynchronize | Значение, идентичное `baseContexts` |
| accountSearchFilter | Фильтр для поиска учетных записей |
| accountSynchronizationFilter | Фильтр для синхронизации учетных записей. |

### Настройка OpenDJ

Если у вас не установлен OpenDJ, установите его, как описано в [документации](https://doc.openidentityplatform.org/opendj/install-guide).

Скачайте с GitHub файл с тестовыми данными [Example.ldif](https://raw.githubusercontent.com/OpenIdentityPlatform/OpenIDM/refs/heads/master/openidm-zip/src/main/resources/samples/internal-common/data/Example.ldif)

Выполните первоначальную настройку OpenDJ и импортируйте в него данные командой

```
 cd /path/to/opendj
 
 ./setup --cli \
--hostname localhost \
--ldapPort 1389 \
--rootUserDN "cn=Directory Manager" \
--rootUserPassword password \
--adminConnectorPort 4444 \
--baseDN dc=com \
--ldifFile /path/to/Example.ldif \
--acceptLicense \
--no-prompt
...
Configuring Directory Server ..... Done.
Creating Base Entry dc=com ..... Done.
Starting Directory Server ....... Done.
...
```

Скачайте с GitHub файл конфигурации подключения к OpenDJ [provisioner.openicf-ldap.json](https://raw.githubusercontent.com/OpenIdentityPlatform/OpenIDM/refs/heads/master/openidm-zip/src/main/resources/samples/provisioners/provisioner.openicf-ldap.json) и скопируйте его в каталог `conf` OpenIDM. 

Файл можно оставить без изменений, он уже настроен в соответствии с параметрами подключения к OpenDJ по умолчанию.

## Настройка синхронизации Active Directory → OpenDJ

Откройте консоль администратора OpenIDM по ссылке [http://localhost:8080/admin](http://localhost:8080/admin). Введите в поля логин и пароль значение `openidm-admin`.  В верхнем меню откройте Configure → Mappings и создайте Mapping ad → user как показано на рисунке ниже.

![AD -> managed user mapping](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad-dj/0-ad-user-mapping.png)

Откройте созданный Mapping **systemAdAccounts_managedUser** и на закладке Properties настройте соответствия полей как показано в таблице

| **Source** | **Target** |
| --- | --- |
| cn | cn |
| description | description |
| givenName | givenName |
| mail | mail |
| sn | sn |
| telephoneNumber | telephoneNumber |
| smAccountName | userName |

На закладке Behaviors настройте поведение при различных ситуациях синхронизации.

| **Situation** | **Action** |
| --- | --- |
| Ambiguous | Ignore |
| Source Missing | Delete |
| Missing | Ignore |
| Found Already Linked  | Exception |
| Unqualified | Delete |
| Unassigned | Ignore |
| Link Only | Exception |
| Target Ignored  | Ignore |
| Source Ignored | Ignore |
| All Gone | Ignore |
| Confirmed | Update |
| Found | Ignore |
| Absent | Create |

Сохраните изменения.

На закладке Mappings создайте еще один  Mapping как показано на рисунке ниже

![Managed User -> OpenDJ mapping](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad-dj/1-user-dj-mapping.png)

Откройте настройки созданного mapping **managedUser_systemLdapAccounts** и на закладке Properties настройте соответствия полей как указано в таблице ниже:

| **Source** | **Target** | **Transformation scrip**t | **Conditional updates** |
| --- | --- | --- | --- |
| userName | uid |  |  |
| sn | sn |  |  |
|  | cn | `source.cn || (source.givenName + ' ' + source.sn)` |  |
| givenName | givenName |  |  |
| mail | mail |  |  |
| description | description |  |  |
| telephoneNumber | telephoneNumber |  | `object.telephoneNumber !== undefined && object.telephoneNumber !== null && object.telephoneNumber !== ''` |

Для поля `description` укажите значение по умолчанию `Created in OpenIDM`

На закладке Behaviors настройте поведение при различных ситуациях синхронизации:

| **Sutiation** | **Action** |
| --- | --- |
| Ambiguous | Ignore |
| Source Missing | Delete |
| Missing | Ignore |
| Found Already Linked | Exception |
| Unqualified | Delete |
| Unassigned | Ignore |
| Link Only | Exception |
| Target Ignored | Ignore |
| Source Ignored | Ignore |
| All Gone | Ignore |
| Confirmed | Update |
| Found | Update |
| Absent | Create |

На этой же закладке в разделе **Situational Event Scripts** добавьте скрипт для события onCreate.

```jsx
target.dn = 'uid=' + source.userName + ',ou=People,dc=example,dc=com';
```

## Настройка синхронизации OpenDJ → Active Directory

Создайте синхронизацию OpenDJ → Managed User

![OpenDJ -> Managed User Mapping](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad-dj/2-dj-user-mapping.png)

В поле Linked mapping выберите **managedUser_systemLdapAccounts.**

Откройте созданный Mapping **systemLdapAccount_managedUser** и на закладке Properties настройте соответствия полей как показано в таблице

| **Source** | **Target** |
| --- | --- |
| mail | mail |
| sn | sn |
| givenName | givenName |
| uid | userName |
| telephoneNumber | telephoneNumber |

На закладке Behaviors настройте поведение.

| **Situation** | **Action** |
| --- | --- |
| Ambiguous | Ignore |
| Source Missing | Delete |
| Missing | Ignore |
| Found Already Linked | Exception |
| Unqualified | Delete |
| Unassigned | Ignore |
| Link Only | Exception |
| Target Ignored | Ignore |
| Source Ignored | Ignore |
| All Gone | Ignore |
| Confirmed | Update |
| Found | Ignore |
| Absent | Create |

Создайте Mapping Managed User → Active Directory

![Managed User -> Active Directory Mapping](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad-dj/3-user-ad-mapping.png)

В поле Linked mapping выберите **systemAdAccounts_managedUser.**

В созданном Mapping **managedUser_systemAdAccount** настройте соответствие:

| Source | Target | Transformation Script |
| --- | --- | --- |
| userName | dn | `'CN=' + source + ',CN=Users,DC=example,DC=org'` |
| givenName | givenName |  |
| sn | sn |  |
|  | cn | `source.displayName || (source.givenName + ' ' + source.sn)` |
| description | description |  |
| telephoneNumber | telephoneNumber |  |
| userName | sAMAccountName |  |

На закладке Behaviors настройте поведение аналогично шагу выше.

## Проверка решения

### Синхронизация Active Directory → OpenDJ

В консоли администратора выберите Mapping **systemAdAccounts_managedUser** и нажмите кнопку Reconcile.

![systemAdAccounts_managedUser Reconcilation](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad-dj/4-systemAdAccounts_managedUser-recon.png)

В консоли администратора перейдите в список Manage → User. В списке пользователей появятся учетные записи из Active Directory

![Managed User List AD](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad-dj/5-manged-user-list-ad.png)

В консоли администратора выберите Mapping **managedUser_systemLdapAccounts** и нажмите кнопку Reconcile. После успешной синхронизации в OpenDJ появятся созданные в Managed Users записи из Active Directory.

Проверьте наличие учетной записи командой

```
./opendj/bin/ldapsearch -p 1389 -b dc=example,dc=com  "(uid=aduser)" uid
dn: uid=aduser,ou=People,dc=example,dc=com
uid: aduser
```

### Синхронизация OpenDJ → Active Directory

В консоли администратора в разделе Configure → Mappings выберите Mapping  **systemLdapAccount_managedUser.** И нажмите кнопку Reconcile. 

Перейдите в раздел Manage → User. 

В списке пользователей появятся учетные записи из OpenDJ

![Managed User List Active Directiry and OpenDJ](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenIDM/images/openidm-ad-dj/6-managed-user-list-ad-dj.png)

Далее выберите Mapping **managedUser_systemAdAccount** и нажмите Reconcile. 

После успешной синхронизации в Active Directory появятся учетные записи из OpenDJ.

Проверьте их наличие командой

```
ldapsearch -H ldap://ad.example.com -x -W -D "admin@example.com" -b "dc=example,dc=com" "(sAMAccountName=bjensen)" | grep dn
Enter LDAP Password: 
dn: CN=bjensen,CN=Users,DC=example,DC=org
```