---
layout: blog
title: 'Аутентификация по протоколу SAML с помощью OpenAM на примере Yandex Cloud'
description: 'В данной статье описывается, как настроить вход по технологии единого входа (SSO) по протоколу SAML в Yandex Cloud через Access Management платформу с открытым исходным кодом OpenAM.'
tags: 
  - openam
---

## Подготовка

Для настройки SAML аутентификации требуется

1. Платформа Docker и запущенный Docker Engine
2. Локально запущенный инстанс OpenAM. Для запуска OpenAM выполните команду:

```bash
docker run -h openam.example.org -p 8080:8080 --name openam openidentityplatform/openam
```

Подробное описание установки и первоначальной настройки OpenAM по [ссылке](https://github.com/OpenIdentityPlatform/OpenAM/wiki/Quick-Start-Guide) 

## Настройка федерации в OpenAM

### Создание и настройка Identity Provider в OpenAM

1. Откройте консоль администратора
2. Перейдите в нужный realm
3. Выберите в разделе Common Tasks **Configure SAMLv2 Provider**

![OpenAM Realm Common Tasks](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-yandex-cloud/realm-common-tasks.png)

4. Далее **Create Hosted Identity Provider**

![Configure SAML v2 Provider](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-yandex-cloud/configure-saml-provider.png)

5. Выберите ключ для подписи (для демонстрационных целей будем использовать **test**), введите имя круга доверия а также свяжите атрибуты пользователей Yandex Cloud Organization c OpenAM. Для демонстрационных целей пользователи будут связаны по email.

![Configure SAML Identity Provider](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-yandex-cloud/configure-saml-identity-provider.png)

6. Нажмите кнопку Configure.

### Настройка связи пользователей OpenAM

1. Откройте консоль администратора
2. Выберите требуемый  realm
3. В меню слева выберите раздел Applications и перейдите в SAML 2.0
4. В списке Entity Providers выберите провайдера `http://openam.example.org:8080/openam`
5. На закладке Assertion Content в разделе **NameID Format** в список **NameID Value Map** добавьте элемент `urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified=mail`
6. Нажмите Save

### Создание пользователей OpenAM

1. Откройте консоль администратора
2. Выберите требуемый realm
3. Создайте пользователя и заполните у него атрибут Email Address

## **Создание и настройка федерации в Yandex Cloud Organization**

### Перейдите в сервис [Yandex Cloud Organization](https://org.cloud.yandex.ru/).

1. На панели слева выберите раздел [Федерации](https://org.cloud.yandex.ru/federations) .
2. Нажмите кнопку **Создать федерацию**.
3. Задайте имя федерации. Имя должно быть уникальным в каталоге.
4. При необходимости добавьте описание.
5. В поле **Время жизни cookie** укажите время, в течение которого браузер не будет требовать у пользователя повторной аутентификации.
6. В поле **IdP Issuer** вставьте ссылку: `http://openam.example.org:8080/openam`
7. В поле **Ссылка на страницу для входа в IdP** вставьте ссылку: `http://openam.example.org:8080/openam/SSORedirect/metaAlias/idp`
8. Включите опцию **Автоматически создавать пользователей**, чтобы автоматически добавлять пользователя в организацию после аутентификации. Если опция отключена, федеративных пользователей потребуется [добавить вручную](https://cloud.yandex.ru/docs/organization/operations/add-account#add-user-sso).
    
    Автоматически федеративный пользователь создается только при первом входе пользователя в облако. Если вы удалили пользователя из федерации, вернуть его туда можно будет только вручную.
    
9. Включите опцию **Принудительная повторная аутентификация (ForceAuthn) в IdP**, чтобы задать значение `true` для параметра [ForceAuthn](https://cloud.yandex.ru/docs/organization/api-ref/Federation/) в запросе аутентификации SAML. При включении этой опции IdP-провайдер запрашивает у пользователя аутентификацию по истечении сессии в Yandex Cloud.
10. Нажмите кнопку **Создать федерацию**.

![Yandex Cloud New Federation](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-yandex-cloud/05-yandex-cloud-new-federation.png)

## **Добавьте сертификаты**

При аутентификации у сервиса Cloud Organization должна быть возможность проверить сертификат IdP-сервера. Для этого добавьте сертификат в федерацию:

1. Откройте ссылку OpenAM `http://openam.example.org:8080/openam/saml2/jsp/exportmetadata.jsp`

и скопируйте значение тега ds:X509Certificate

2. Сохраните сертификат в текстовом файле с расширением `.cer` в следующем формате:

```bash
----BEGIN CERTIFICATE-----
<значение ds:X509Certificate>
----END CERTIFICATE-----
```

3. На панели слева выберите раздел [Федерации](https://org.cloud.yandex.ru/federations) .
4. Нажмите имя федерации, для которой нужно добавить сертификат.
5. Внизу страницы нажмите кнопку **Добавить сертификат**.
6. Введите название и описание сертификата.
7. Выберите способ добавления сертификата:
    - Чтобы добавить сертификат в виде файла, нажмите **Выбрать файл** и укажите путь к нему.
    - Чтобы вставить скопированное содержимое сертификата, выберите способ **Текст** и вставьте содержимое.
8. Нажмите кнопку **Добавить**.

# Создание и настройка Service Provider в OpenAM

## Создайте файл метаданных для OpenAM

Создайте файл `metadata.xml`со следующим содержимым, где ID_федерации - идентификатор федерации из консоли [Yandex Cloud Organization](https://org.cloud.yandex.ru), раздела [Федерации](https://org.cloud.yandex.ru/federations)

```xml
<?xml version="1.0" encoding="UTF-8"?><md:EntityDescriptor xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata" entityID="https://console.cloud.yandex.ru/federations/<ID_федерации>">
    <md:SPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
        <md:AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://console.cloud.yandex.ru/federations/<ID_федерации>" index="1"/>
    </md:SPSSODescriptor>
</md:EntityDescriptor>
```

## Создание Service Provider в OpenAM

1. Откройте консоль администратора
2. Перейдите в нужный realm
3. Выберите в разделе Common Tasks **Configure SAMLv2 Provider**
4. Далее **Configure Remote Service Provider**

![SAML Remote Service Provider](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-yandex-cloud/saml-remote-service-provider.png)

1. В качестве метаданных загрузите созданный на предыдущем этапе файл `metadata.xml`
2. Выберите существующий Circle Of Trust, созданный на этапе **Создание и настройка Identity Provider в OpenAM**
3. Нажмите Configure

## **Добавление пользователей в Yandex Cloud Organization**

Если при [создании федерации](https://cloud.yandex.ru/docs/organization/tutorials/federations/integration-keycloak#yc-settings) вы не включили опцию **Автоматически создавать пользователей**, федеративных пользователей нужно добавить в организацию вручную.

Для этого вам понадобятся пользовательские Name ID. Их возвращает IdP-сервер вместе с ответом об успешной аутентификации.

При включенной опции **Автоматически создавать пользователей** в федерацию будут добавляться только пользователи, впервые аутентифицирующиеся в облаке. Повторное добавление федеративного пользователя после его удаления из федерации возможно только вручную.

1. [Войдите в аккаунт](https://passport.yandex.ru/) администратора или владельца организации.
2. Перейдите в сервис [Yandex Cloud Organization](https://org.cloud.yandex.ru/).
3. На панели слева выберите раздел [Пользователи](https://org.cloud.yandex.ru/users) .
4. В правом верхнем углу нажмите  → **Добавить федеративных пользователей**.
5. Выберите федерацию, из которой необходимо добавить пользователей.
6. Введите email адреса пользователей из OpenAM
7. Нажмите кнопку **Добавить**. Пользователи будут подключены к организации.

![Yandex Cloud Add Users](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-yandex-cloud/06-yandex-cloud-add-users.png)

![Yandex Cloud Add Users List](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/saml-yandex-cloud/07-yandex-cloud-add-users-list.png)

# **Проверка аутентификации**

Когда вы закончили настройку SSO, протестируйте, что все работает:

1. Откройте браузер в гостевом режиме или режиме инкогнито.
2. Перейдите по URL для входа в консоль:
    
    `https://console.cloud.yandex.ru/federations/<ID_федерации>`
    
3. Учетные данные пользователя OpenAM аутентификации и нажмите кнопку Login.

После успешной аутентификации IdP-сервер перенаправит вас по URL `https://console.cloud.yandex.ru/federations/<ID_федерации>`, который вы указали файле метаданных для Service Provider в настройках OpenAM, а после — на главную страницу [консоли управления](https://console.cloud.yandex.ru/). В правом верхнем углу вы сможете увидеть, что вошли в консоль от имени федеративного пользователя.