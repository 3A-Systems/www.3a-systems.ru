---
layout: blog
title: 'Управление членством в группах Active Directory в OpenIDM'
description: 'Эта статья является продолжением статьи про управление учетными записями Active Directory через OpenIDM. В этой статье мы настроем IDM таким образом, чтобы добавлять и убирать пользователей из групп Active Directory. '
tags: 
  - openidm
---
## Введение

Эта статья является продолжением [статьи](https://www.3a-systems.ru/blog/2024-08-26-openidm-active-directory) про управление учетными записями Active Directory через OpenIDM. В этой статье мы настроем IDM таким образом, чтобы добавлять и убирать пользователей из групп Active Directory. 

## Настройка Active Directory

В панели управления пользователями Active Directory создайте новую группу. Пусть эта новая группа будет называться `Managers`. В нее мы будем добавлять и удалять учетные записи.

Вот собственно и все. Перейдем к настройке OpenIDM

## Настройка OpenIDM

Будем считать, что у вас уже развернут OpenIDM и настроен коннектор к Active Directory, а так же настроена синхронизация учетных записей OpenIDM в Active Directory из предыдущей [статьи](https://www.3a-systems.ru/blog/2024-08-26-openidm-active-directory). 

### Получение групп в OpenIDM из Active Directory

Чтобы в OpenIDM можно было изменять группы пользователей, нужно синхронизировать информацию о нужных группах Active Directory. В консоли администратора в верхнем меню перейдите Configure → Mappings и создайте новый Mapping групп Active Directory в роли OpenIDM.

![New Group AD -> OpenIDM Role Mpping](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-ad-groups/0-new-group-ad-idm-mapping.png)

Настройте Mapping:

Properties → Attributes Grid:

| Source | Target | Properties |
| --- | --- | --- |
| cn | name |  |
| description | description | default value: no description |
| dn | _id |  |

Association → Reconciliation Query Filters → Source Query установите в `cn eq "Managers"` для того, чтобы не синхронизировать все группы из Active Directory, а только нужную созданную группу.

Behaviors → Policies → Current Policy установите в Default Actions

Сохраните изменения и нажмите кнопку `Reconcile`

![OpenIDM systemAdGroup_managedRole properties](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-ad-groups/1-systemAdGroup_managedRole-properties.png)

После синхронизации в консоли администратора перейдите в верхнем меню Manage → Role и убедитесь, что группа Managers загружена из Active Directory.

![OpenIDM Role List](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-ad-groups/2-openidm-role-list.png)

Теперь нужно настроить синхронизацию из OpenIDM в Active Directory таким образом, чтобы синхронизировались участники группы.

### Настройка синхронизации из OpenIDM в Active Directory

В консоли администратора перейдите в меню Configure → Mappings и создайте новый Mapping Role в group Active Directory.

![New  OpenIDM Role -> Group AD Mpping](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-ad-groups/3-new-role-ad-idm-mapping.png)

При создании установите Linked Mapping в systemAdGroup_managedRole.

Настройте новый Mapping:

Properties → Attributes Grid

| Source | Target | Properties |
| --- | --- | --- |
| _id | dn |  |
|  | member | Transformation Script, см далее |

Active Directory хранит членов группы в атрибуте member, но OpenIDM хранит группы в объекте учетной записи, поэтому для определения DN членов группы нужно использовать скрипт

```jsx
var res = []
//getting role mebmers from OpenIDM
var members = openidm.query("managed/role/" + source._id + "/members", {"_queryFilter": "true"});
if(members.result && members.result.length > 0) {
  for (var i = 0; i < members.result.length; i++) {
    var userId = members.result[i]["_ref"];
    var userInfo = openidm.read(userId);
    //calculate DN from user info
    var userDN = 'CN=' + userInfo.userName + ',CN=Users,DC=example,DC=com'
    res.push(userDN);
  }
}
res
```

Association → Reconciliation Query Filters → Target Query установите в `cn eq "Managers"`

Behaviors → Policies → Current Policy установите в Default Actions

## Проверка решения

Создайте учетную запись в OpenIDM или используйте уже существующую. 

![OpenIDM user](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-ad-groups/4-openidm-user.png)

Синхронизируйте ее используя Mapping `managedUser_systemAdAccount`, чтобы она появилась в Active Directory. 

```
ldapsearch -H ldap://ad.example.org -x -W -D "admin@example.org" -b "dc=example,dc=org" "(sAMAccountName=jdoe)" | grep dn
Enter LDAP Password: 
dn: CN=jdoe,CN=Users,DC=example,DC=org
```

В консоли администратора OpenIDM перейдите Manage → Role, выберите Role Manager и добавьте в нее эту учетную запись.

![OpenIDM Role Members](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-ad-groups/5-openidm-role-members.png)

В консоли администратора OpenIDM перейдите Configure → Mappings. Откройте `managedRole_systemAdGroup` и нажмите Reconcile. После синхронизации пользователь `jdoe` будет принадлежать группе Managers

```
ldapsearch -H ldap://ad.example.org -x -W -D "admin@example.org" -b "DC=example,DC=org" "(sAMAccountName=jdoe)" | grep memberOf
Enter LDAP Password: 
memberOf: CN=Managers,CN=Users,DC=example,DC=org
```
