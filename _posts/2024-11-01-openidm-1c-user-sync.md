---
layout: blog
title: 'OpenIDM: Синхронизация учетных записей 1С при помощи OpenIDM'
description: 'В данной статье мы настроим синхронизацию учетных записей 1С'
tags: 
  - openidm

---

## О чем эта статья

В данной статье мы настроим синхронизацию учетных записей 1С и [OpenIDM](http://github.com/OpenIdentityPlatform/OpenIDM). Рассмотрим случай, когда учетные записи создаются и меняются на стороне OpenIDM, скажем службой HR. Изменения учетных записей из OpenIDM будут синхроризироваться с 1С. В качестве первичного источника данных пользователей может выступать служба каталогов LDAP, реляционная база данных или даже CSV файл. Но для простоты мы настроим синхронизацию с учетными записями OpenIDM.

В рамках статьи мы разработаем HTTP сервис 1С для управления учетными записями, а также настроим адаптер OpenIDM для работы с этим сервисом и настроим синхронизацию.

## Настройка 1С

Откройте Конфигуратор 1С. Добавьте в конфигурацию 1C новый HTTP сервис Пользователи. Сервис будет возвращать учетные записи пользователей их роли, а так же, будет создавать и изменять и удалять учетные записи.

Установите для сервиса коневой URL `api`. Добавьте шаблон URL Пользователи с шаблоном `/users` и шаблон ПользователиОбновитьУдалить с шаблоном `/users/{userId}`

Добавьте для каждого шаблона методы согласно таблице

| **Шаблон** | **Метод** | **HTTP метод** | **Обработчик** |
| --- | --- | --- | --- |
| Пользователи  | СписокПользователей | GET | ПользователиСписокПользователей |
| Пользователи  | СоздатьПользователя | POST | ПользователиСоздатьПользователя |
| ПользователиОбновитьУдалить | ОбновитьПользователя | PUT | ПользователиОбновитьОбновитьПользователя |
| ПользователиОбновитьУдалить  | ОбновитьПользователя | DELETE | ПользователиОбновитьУдалитьПользователя |

![1C HTTP Service](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c/0-1c-http-service.png)


Листинг модуля сервиса в листинге ниже:
    
```
Функция ПользователиСписокПользователей(Запрос)    
    Пользователи = ПользователиИнформационнойБазы.ПолучитьПользователей();   
    
    Массив = Новый Массив;
    Для Каждого Пользователь из Пользователи Цикл     
        Массив.Добавить(ПользовательИБВСтруктуру(Пользователь));		
    КонецЦикла;
    
    ЗаписьJSON = Новый ЗаписьJSON;
    ЗаписьJSON.УстановитьСтроку();
    ЗаписатьJSON(ЗаписьJSON, Массив); 
    СтрокаJSON = ЗаписьJSON.Закрыть();
    
    Ответ = ПолучитьHTTPСервисОтвет();
    Ответ.УстановитьТелоИзСтроки(СтрокаJSON);
    Возврат Ответ;
КонецФункции                  

Функция ПользователиСоздатьПользователя(Запрос)       
    ТекстЗапроса = Запрос.ПолучитьТелоКакСтроку();     
    ЧтениеJSON = Новый ЧтениеJSON();
    ЧтениеJSON.УстановитьСтроку(ТекстЗапроса);
    СтруктураДанных = ПрочитатьJSON(ЧтениеJSON);	
    
    Пользователь = ПользователиИнформационнойБазы.СоздатьПользователя();
    Пользователь = ПользовательИБИзСтруктуры(Пользователь, СтруктураДанных);
    Пользователь.Записать();
    
    ЗаписьJSON = Новый ЗаписьJSON;
    ЗаписьJSON.УстановитьСтроку();  
    Структура = ПользовательИБВСтруктуру(Пользователь);
    ЗаписатьJSON(ЗаписьJSON, Структура); 
    СтрокаJSON = ЗаписьJSON.Закрыть();
    
    Ответ = ПолучитьHTTPСервисОтвет();
    Ответ.УстановитьТелоИзСтроки(СтрокаJSON);

    Возврат Ответ;
КонецФункции

Функция ПользователиОбновитьОбновитьПользователя(Запрос)
    ТекстЗапроса = Запрос.ПолучитьТелоКакСтроку();     
    ЧтениеJSON = Новый ЧтениеJSON();
    ЧтениеJSON.УстановитьСтроку(ТекстЗапроса);
    СтруктураДанных = ПрочитатьJSON(ЧтениеJSON);
    
    userId = Запрос.ПараметрыURL.Получить("userId");
    
    Идентификатор = Новый УникальныйИдентификатор(userId);
    Пользователь = ПользователиИнформационнойБазы.НайтиПоУникальномуИдентификатору(Идентификатор);
    
    Если Пользователь = Неопределено Тогда
        Возврат ПолучитьHTTPСервисОтветНеНайден();		          		
    КонецЕсли;     
    
    Пользователь = ПользовательИБИзСтруктуры(Пользователь, СтруктураДанных);
    Пользователь.Записать();
    
    
    ЗаписьJSON = Новый ЗаписьJSON;
    ЗаписьJSON.УстановитьСтроку();  
    Структура = ПользовательИБВСтруктуру(Пользователь);
    ЗаписатьJSON(ЗаписьJSON, Структура); 
    СтрокаJSON = ЗаписьJSON.Закрыть();
    
    Ответ = ПолучитьHTTPСервисОтвет();
    Ответ.УстановитьТелоИзСтроки(СтрокаJSON);
    
    
    Возврат Ответ;
КонецФункции

Функция ПользователиОбновитьУдалитьПользователя(Запрос)    
    
    userId = Запрос.ПараметрыURL.Получить("userId");
    
    Идентификатор = Новый УникальныйИдентификатор(userId);
    Пользователь = ПользователиИнформационнойБазы.НайтиПоУникальномуИдентификатору(Идентификатор);
    
    Если Пользователь = Неопределено Тогда
        Возврат ПолучитьHTTPСервисОтветНеНайден();		          		
    КонецЕсли;         
    
    Пользователь.Удалить();
    
    Ответ = ПолучитьHTTPСервисОтвет();
    Возврат Ответ;
КонецФункции     
    
Функция ПользовательИБВСтруктуру(Пользователь) 
    Структура = Новый Структура("uid, name, fullName, roles");
    Структура.uid = Строка(Пользователь.УникальныйИдентификатор);  
    Структура.name = Пользователь.Имя;
    Структура.fullName = Пользователь.ПолноеИмя;
    Роли = Новый Массив;
    Для Каждого Роль из Пользователь.Роли Цикл
        Роли.Добавить(Роль.Имя);
    КонецЦикла;
    
    Структура.roles = Роли;
    Возврат Структура;
КонецФункции

Функция ПользовательИБИзСтруктуры(Пользователь, СтруктураДанных)   
    
    Пользователь.АутентификацияСтандартная = Истина;
    Пользователь.Имя = СтруктураДанных.name;
    Пользователь.ПолноеИмя = СтруктураДанных.fullName;
    Пользователь.Пароль =  СтруктураДанных.password;
    Пользователь.Роли.Очистить();
    Для Каждого role из СтруктураДанных.roles Цикл
        Роль = Метаданные.Роли.Найти(role);
        Пользователь.Роли.Добавить(Роль);	
    КонецЦикла;
    Возврат Пользователь;
КонецФункции

Функция ПолучитьHTTPСервисОтвет()  
    Ответ = Новый HTTPСервисОтвет(200);   
    Ответ.Заголовки.Вставить("Content-Type","application/json; charset=utf-8");
    Возврат Ответ;
КонецФункции

Функция ПолучитьHTTPСервисОтветНеНайден()  
    Ответ = Новый HTTPСервисОтвет(404);   
    Ответ.Заголовки.Вставить("Content-Type","application/json; charset=utf-8");
    Возврат Ответ;
КонецФункции

```
    

Создайте сервисного пользователя для синхронизации данных и добавьте ему права для доступа к HTTP сервису, а так же добавьте управление пользователями. Пусть логин будет `idm` , пароль будет `passw0rd`.

Добавьте так же в метаданные роль “Менеджер” и назначьте ей нужные права. Аналогичную роль мы создадим в OpenIDM.

Опубликуйте созданный HTTP сервис.

Подробное описание создания и развертывания HTTP сервисов выходит за рамки данной статьи. Почитать о них вы можете в статьях:

https://infostart.ru/1c/articles/1293341/

https://infostart.ru/1c/articles/842751/

## Настройка OpenIDM

Скачайте дистрибутив OpenIDM с [GitHub](https://github.com/OpenIdentityPlatform/OpenIDM/releases). Распакуйте архив и перейдите в директорию `openidm`. Запустите OpenIDM командой `./openidm/startup.sh`

Добавьте адаптер к REST сервису. Поместите файл `provisioner.openicf-scriptedrest.json` в папку `conf` каталога OpenIDM. Содержимое будет примерно таким:

`provisioner.openicf-scriptedrest.json`:
    
```json
{
    "name" : "scriptedrest",
    "connectorRef" : {
        "connectorHostRef" : "#LOCAL",
        "connectorName" : "org.forgerock.openicf.connectors.scriptedrest.ScriptedRESTConnector",
        "bundleName" : "org.openidentityplatform.openicf.connectors.groovy-connector",
        "bundleVersion" : "[1.4.0.0,2)"
    },
    "poolConfigOption" : {
        "maxObjects" : 10,
        "maxIdle" : 10,
        "maxWait" : 150000,
        "minEvictableIdleTimeMillis" : 120000,
        "minIdle" : 1
    },
    "operationTimeout" : {
        "CREATE" : -1,
        "UPDATE" : -1,
        "DELETE" : -1,
        "TEST" : -1,
        "SCRIPT_ON_CONNECTOR" : -1,
        "SCRIPT_ON_RESOURCE" : -1,
        "GET" : -1,
        "RESOLVEUSERNAME" : -1,
        "AUTHENTICATE" : -1,
        "SEARCH" : -1,
        "VALIDATE" : -1,
        "SYNC" : -1,
        "SCHEMA" : -1
    },
    "resultsHandlerConfig" : {
        "enableNormalizingResultsHandler" : true,
        "enableFilteredResultsHandler" : true,
        "enableCaseInsensitiveFilter" : false,
        "enableAttributesToGetSearchResultsHandler" : true
    },
    "configurationProperties" : {
        "serviceAddress" : "http://localhost:8090",
        "proxyAddress" : null,
        "username" : "idm",
        "password" : {
            "$crypto" : {
                "type" : "x-simple-encryption",
                "value" : {
                    "cipher" : "AES/CBC/PKCS5Padding",
                    "data" : "sLvu2xdRz0eyhjucysxmcA==",
                    "iv" : "+evCKgF0BCaNA4NfA/VY7Q==",
                    "key" : "openidm-sym-default"
                }
            }
        },
        "defaultAuthMethod" : "BASIC_PREEMPTIVE",
        "defaultRequestHeaders" : [
            null
        ],
        "defaultContentType" : "application/json",
        "scriptExtensions" : [
            "groovy"
        ],
        "sourceEncoding" : "UTF-8",
        "customizerScriptFileName" : "CustomizerScript.groovy",
        "createScriptFileName" : "CreateScript.groovy",
        "deleteScriptFileName" : "DeleteScript.groovy",
        "schemaScriptFileName" : "SchemaScript.groovy",
        "searchScriptFileName" : "SearchScript.groovy",
        "updateScriptFileName" : "UpdateScript.groovy",
        "recompileGroovySource" : false,
        "minimumRecompilationInterval" : 100,
        "debug" : false,
        "verbose" : false,
        "warningLevel" : 1,
        "tolerance" : 10,
        "disabledGlobalASTTransformations" : null,
        "targetDirectory" : null,
        "scriptRoots" : [
            "&{launcher.project.location}/tools"
        ]
    },
    "objectTypes" : {
        "account" : {
            "$schema" : "http://json-schema.org/draft-03/schema",
            "id" : "__ACCOUNT__",
            "type" : "object",
            "nativeType" : "__ACCOUNT__",
            "properties" : {
                "uid" : {
                    "type" : "string",
                    "nativeName" : "__NAME__",
                    "nativeType" : "string",
                    "flags" : [
                        "NOT_UPDATEABLE",
                        "NOT_CREATEABLE"
                    ]
                },
                "name" : {
                    "type" : "string",
                    "nativeName" : "name",
                    "nativeType" : "string",
                    "required" : true
                },
                "fullName" : {
                    "type" : "string",
                    "nativeName" : "fullName",
                    "nativeType" : "string"
                },
                "roles" : {
                    "type" : "array",
                    "items" : {
                        "type" : "string",
                        "nativeType" : "string"
                    },
                    "nativeName" : "roles",
                    "nativeType" : "string"
                },
                "password" : {
                    "type" : "string",
                    "nativeName" : "password",
                    "nativeType" : "JAVA_TYPE_GUARDEDSTRING",
                    "flags" : [
                        "NOT_READABLE",
                        "NOT_RETURNED_BY_DEFAULT"
                    ]
                }
            }
        }
    }
}
```
    

Основные атрибуты конфигурации JSON структуры файла:

- `configurationProperties` - параметры обращения к REST сервису, в данном случае, HTTP (REST) сервис 1С.
    - URL  подключения
    - Имя пользователя
    - Пароль
    - Таймауты операция
- `objectTypes` - структуры данных, которые будут синхронизированы. В данном случае будут синхронизированы учетные записи (ACCOUNT)
- `operationTimeout` - таймауты для операций
- `poolConfigOption` - параметры пула соединений к REST сервису

Теперь добавим скрипты, при помощи которых будем получать и обновлять данные из REST сервиса.

### Конфигурация HTTP клиента

Для начала сконфигурируем HTTP клиент, которые будет обращаться к REST сервису 1С. Конфигурирование осуществляется так же при помощи скрипта на языке Groovy.

Поместите в папку tools каталога OpenIDM скрипт `CustomizerScript.groovy`

`CustomizerScript.groovy`:
    
```groovy
import groovyx.net.http.RESTClient
import groovyx.net.http.StringHashMap
import org.apache.http.HttpHost
import org.apache.http.auth.AuthScope
import org.apache.http.auth.UsernamePasswordCredentials
import org.apache.http.client.ClientProtocolException
import org.apache.http.client.CredentialsProvider
import org.apache.http.client.HttpClient
import org.apache.http.client.config.RequestConfig
import org.apache.http.client.protocol.HttpClientContext
import org.apache.http.conn.routing.HttpRoute
import org.apache.http.impl.auth.BasicScheme
import org.apache.http.impl.client.BasicAuthCache
import org.apache.http.impl.client.BasicCookieStore
import org.apache.http.impl.client.BasicCredentialsProvider
import org.apache.http.impl.client.HttpClientBuilder
import org.apache.http.impl.conn.PoolingHttpClientConnectionManager
import org.forgerock.openicf.connectors.scriptedrest.ScriptedRESTConfiguration
import org.forgerock.openicf.connectors.scriptedrest.ScriptedRESTConfiguration.AuthMethod
import org.identityconnectors.common.security.GuardedString

// must import groovyx.net.http.HTTPBuilder.RequestConfigDelegate
import groovyx.net.http.HTTPBuilder.RequestConfigDelegate

/**
    * A customizer script defines the custom closures to interact with the default implementation and customize it.
    */
customize {
    init { HttpClientBuilder builder ->

        //SETUP: org.apache.http
        def c = delegate as ScriptedRESTConfiguration

        def httpHost = new HttpHost(c.serviceAddress?.host, c.serviceAddress?.port, c.serviceAddress?.scheme);

        PoolingHttpClientConnectionManager cm = new PoolingHttpClientConnectionManager();
        // Increase max total connection to 200
        cm.setMaxTotal(200);
        // Increase default max connection per route to 20
        cm.setDefaultMaxPerRoute(20);
        // Increase max connections for httpHost to 50
        cm.setMaxPerRoute(new HttpRoute(httpHost), 50);

        builder.setConnectionManager(cm)

        // configure timeout on the entire client
        RequestConfig requestConfig = RequestConfig.custom().build();
        builder.setDefaultRequestConfig(requestConfig)

        if (c.proxyAddress != null) {
            builder.setProxy(new HttpHost(c.proxyAddress?.host, c.proxyAddress?.port, c.proxyAddress?.scheme));
        }

        switch (ScriptedRESTConfiguration.AuthMethod.valueOf(c.defaultAuthMethod)) {
            case ScriptedRESTConfiguration.AuthMethod.BASIC_PREEMPTIVE:
            case ScriptedRESTConfiguration.AuthMethod.BASIC:
                // It's part of the http client spec to request the resource anonymously
                // first and respond to the 401 with the Authorization header.
                final CredentialsProvider credentialsProvider = new BasicCredentialsProvider();

                c.password.access(
                        {
                            credentialsProvider.setCredentials(new AuthScope(httpHost.getHostName(), httpHost.getPort()),
                                    new UsernamePasswordCredentials(c.username, new String(it)));
                        } as GuardedString.Accessor
                );

                builder.setDefaultCredentialsProvider(credentialsProvider);
                break;
            case ScriptedRESTConfiguration.AuthMethod.NONE:
                break;
            default:
                throw new IllegalArgumentException();
        }

        c.propertyBag.put(HttpClientContext.COOKIE_STORE, new BasicCookieStore());
    }

    /**
        * This Closure can customize the httpClient and the returning object is injected into the Script Binding.
        */
    decorate { HttpClient httpClient ->

        //SETUP: groovyx.net.http

        def c = delegate as ScriptedRESTConfiguration

        def authCache = null
        if (AuthMethod.valueOf(c.defaultAuthMethod).equals(AuthMethod.BASIC_PREEMPTIVE)){
            authCache = new BasicAuthCache();
            authCache.put(new HttpHost(c.serviceAddress?.host, c.serviceAddress?.port, c.serviceAddress?.scheme), new BasicScheme());

        }

        def cookieStore = c.propertyBag.get(HttpClientContext.COOKIE_STORE)

        RESTClient restClient = new InnerRESTClient(c.serviceAddress, c.defaultContentType, authCache, cookieStore)

        Map<Object, Object> defaultRequestHeaders = new StringHashMap<Object>();
        if (null != c.defaultRequestHeaders) {
            c.defaultRequestHeaders.each {
                if (null != it) {                
                    def kv = it.split('=')
                    assert kv.size() == 2
                    defaultRequestHeaders.put(kv[0], kv[1])
                }
            }
        }

        restClient.setClient(httpClient);
        restClient.setHeaders(defaultRequestHeaders)

        // Return with the decorated instance
        return restClient
    }

}

RequestConfigDelegate blank = null;

class InnerRESTClient extends RESTClient {

    def authCache = null;
    def cookieStore = null;

    InnerRESTClient(Object defaultURI, Object defaultContentType, authCache, cookieStore) throws URISyntaxException {
        super(defaultURI, defaultContentType)
        this.authCache = authCache
        this.cookieStore = cookieStore
    }

    @Override
    protected Object doRequest(
            final RequestConfigDelegate delegate) throws ClientProtocolException, IOException {

        // Add AuthCache to the execution context
        if (null != authCache) {
            //do Preemptive Auth
            delegate.getContext().setAttribute(HttpClientContext.AUTH_CACHE, authCache);
        }
        // Add AuthCache to the execution context
        if (null != cookieStore) {
            //do Preemptive Auth
            delegate.getContext().setAttribute(HttpClientContext.COOKIE_STORE, cookieStore);
        }
        return super.doRequest(delegate)
    }
}
```
    

### Поиск данных

Поместите в папку tools каталога OpenIDM скрипт `SearchScript.groovy` со следующим содержимым.

`SearchScript.groovy`:
    
```groovy
import groovyx.net.http.RESTClient
import org.apache.http.client.HttpClient
import org.forgerock.openicf.connectors.scriptedrest.ScriptedRESTConfiguration
import org.forgerock.openicf.misc.scriptedcommon.OperationType
import org.identityconnectors.common.logging.Log
import org.identityconnectors.framework.common.objects.Attribute
import org.identityconnectors.framework.common.objects.AttributeUtil
import org.identityconnectors.framework.common.objects.ObjectClass
import org.identityconnectors.framework.common.objects.OperationOptions
import org.identityconnectors.framework.common.objects.SearchResult
import org.identityconnectors.framework.common.objects.Uid
import org.identityconnectors.framework.common.objects.filter.Filter

import static groovyx.net.http.Method.GET

// imports used for CREST based REST APIs
import org.forgerock.openicf.misc.crest.CRESTFilterVisitor
import org.forgerock.openicf.misc.crest.VisitorParameter

def operation = operation as OperationType
def configuration = configuration as ScriptedRESTConfiguration
def httpClient = connection as HttpClient
def connection = customizedConnection as RESTClient
def filter = filter as Filter
def log = log as Log
def objectClass = objectClass as ObjectClass
def options = options as OperationOptions
def resultHandler = handler

log.info("Entering " + operation + " Script")

def queryFilter = 'true'
if (filter != null) {
    queryFilter = filter.accept(CRESTFilterVisitor.VISITOR, [
            translateName: { String name ->
                if (AttributeUtil.namesEqual(name, Uid.NAME)) {
                    return "uid"
                } else if (AttributeUtil.namesEqual(name, "name")) {
                    return "name"
                } else if (AttributeUtil.namesEqual(name, "fullName")) {
                    return "fullName"
                } else {
                    throw new IllegalArgumentException("Unknown field name: ${name}");
                }
            },
            convertValue : { Attribute value ->
                if (AttributeUtil.namesEqual(value.name, "members")) {
                    return value.value
                } else {
                    return AttributeUtil.getStringValue(value)
                }
            }] as VisitorParameter).toString();
}
switch (objectClass) {
    case ObjectClass.ACCOUNT:
        def searchResult = connection.request(GET) { req ->
            uri.path = '/api/users'
            uri.query = [
                    _queryFilter: queryFilter
            ]

            response.success = { resp, json ->
                json.each() { value ->
                    resultHandler {
                        uid value.uid
                        id value.uid
                        attribute 'name', value?.name
                        attribute 'fullName', value?.fullName
                        attribute 'roles', value?.roles
                    }
                }
                json
            }
        }

        return new SearchResult()

    case ObjectClass.GROUP:
        throw new IllegalArgumentException("Group sync is not supported");
}

```
    

Скрипт преобразует отправляет GET запрос на HTTP сервис 1С `/api/users` с параметром `_queryFilter`. Получает данные, преобразует каждую запись в структуру, которую потом читает коннектор OpenIDM.

### Создание учетных записей

Поместите в папку tools каталога OpenIDM скрипт `CreateScript.groovy` со следующим содержимым.

`CreateScript.groovy`    
```groovy

import groovy.json.JsonBuilder
import groovyx.net.http.RESTClient
import org.apache.http.client.HttpClient
import org.forgerock.openicf.connectors.scriptedrest.ScriptedRESTConfiguration
import org.forgerock.openicf.misc.scriptedcommon.OperationType
import org.identityconnectors.common.logging.Log
import org.identityconnectors.common.security.SecurityUtil
import org.identityconnectors.framework.common.objects.Attribute
import org.identityconnectors.framework.common.objects.AttributesAccessor
import org.identityconnectors.framework.common.objects.ObjectClass
import org.identityconnectors.framework.common.objects.OperationOptions
import org.identityconnectors.framework.common.objects.Uid

import static groovyx.net.http.ContentType.JSON
import static groovyx.net.http.Method.PUT

def operation = operation as OperationType
def updateAttributes = new AttributesAccessor(attributes as Set<Attribute>)
def configuration = configuration as ScriptedRESTConfiguration
def httpClient = connection as HttpClient
def connection = customizedConnection as RESTClient
def name = id as String
def log = log as Log
def objectClass = objectClass as ObjectClass
def options = options as OperationOptions
def uid = uid as Uid

log.info("Entering " + operation + " Script");

switch (objectClass) {
    case ObjectClass.ACCOUNT:
        def builder = new JsonBuilder()
        builder {}

        builder.content["name"] =  updateAttributes.findString("name")
        builder.content["fullName"] =  updateAttributes.findString("fullName")
        builder.content["roles"] =  updateAttributes.findList("roles")

        if (updateAttributes.hasAttribute("password") && updateAttributes.findGuardedString("password") != null) {
            def pass = SecurityUtil.decrypt(updateAttributes.findGuardedString("password"))
            builder.content["password"] = pass
        }

        return connection.request(PUT, JSON) { req ->
            uri.path = "/api/users/${uid.uidValue}"
            body = builder.toString()
            headers.'If-None-Match' = "*"

            response.success = { resp, json ->
                new Uid(json.uid)
            }
        }

    case ObjectClass.GROUP:
        throw new IllegalArgumentException("Group sync is not supported");
}
return uid
```
    

Скрипт отправляет POST запрос с JSON структурой свойств учетной записи. HTTP сервис 1С создает учетную запись и возвращает идентификатор пользователя.

### Обновление учетных записей

Поместите в папку tools каталога OpenIDM скрипт `UpdateScript.groovy`

`UpdateScript.groovy`
    
```groovy
import groovy.json.JsonBuilder
import groovyx.net.http.RESTClient
import org.apache.http.client.HttpClient
import org.forgerock.openicf.connectors.scriptedrest.ScriptedRESTConfiguration
import org.forgerock.openicf.misc.scriptedcommon.OperationType
import org.identityconnectors.common.logging.Log
import org.identityconnectors.common.security.SecurityUtil
import org.identityconnectors.framework.common.objects.Attribute
import org.identityconnectors.framework.common.objects.AttributesAccessor
import org.identityconnectors.framework.common.objects.ObjectClass
import org.identityconnectors.framework.common.objects.OperationOptions
import org.identityconnectors.framework.common.objects.Uid

import static groovyx.net.http.ContentType.JSON
import static groovyx.net.http.Method.PUT

def operation = operation as OperationType
def updateAttributes = new AttributesAccessor(attributes as Set<Attribute>)
def configuration = configuration as ScriptedRESTConfiguration
def httpClient = connection as HttpClient
def connection = customizedConnection as RESTClient
def name = id as String
def log = log as Log
def objectClass = objectClass as ObjectClass
def options = options as OperationOptions
def uid = uid as Uid

log.info("Entering " + operation + " Script");

switch (objectClass) {
    case ObjectClass.ACCOUNT:
        def builder = new JsonBuilder()
        builder {}

        builder.content["name"] =  updateAttributes.findString("name")
        builder.content["fullName"] =  updateAttributes.findString("fullName")
        builder.content["roles"] =  updateAttributes.findList("roles")

        if (updateAttributes.hasAttribute("password") && updateAttributes.findGuardedString("password") != null) {
            def pass = SecurityUtil.decrypt(updateAttributes.findGuardedString("password"))
            builder.content["password"] = pass
        }

        return connection.request(PUT, JSON) { req ->
            uri.path = "/api/users/${uid.uidValue}"
            body = builder.toString()
            headers.'If-None-Match' = "*"

            response.success = { resp, json ->
                new Uid(json.uid)
            }
        }

    case ObjectClass.GROUP:
        throw new IllegalArgumentException("Group sync is not supported");
}
return uid
```
    

Скрипт практически идентичен `CreateScript.groovy`  за исключением того, что отправляет PUT запрос на endpoint с указанием идентификатора учетной записи пользователя.

### Удаление учетной записи

Скрипт удаления `DeleteScript.groovy` намного короче, чем остальные скрипты

`DeleteScript.groovy`
    
```groovy
import groovyx.net.http.RESTClient
import org.apache.http.client.HttpClient
import org.forgerock.openicf.connectors.scriptedrest.ScriptedRESTConfiguration
import org.forgerock.openicf.misc.scriptedcommon.OperationType
import org.identityconnectors.common.logging.Log
import org.identityconnectors.framework.common.objects.ObjectClass
import org.identityconnectors.framework.common.objects.OperationOptions
import org.identityconnectors.framework.common.objects.Uid

def operation = operation as OperationType
def configuration = configuration as ScriptedRESTConfiguration
def httpClient = connection as HttpClient
def connection = customizedConnection as RESTClient
def log = log as Log
def objectClass = objectClass as ObjectClass
def options = options as OperationOptions
def uid = uid as Uid

log.info("Entering " + operation + " Script");

switch (objectClass) {
    case ObjectClass.ACCOUNT:
        connection.delete(path: '/api/users/' + uid.uidValue);
        break
    case ObjectClass.GROUP:
        throw new IllegalArgumentException("Group sync is not supported");
}

```
    

И, как видно из кода, отправляет DELETE запрос на REST endpoint с указанием идентификатора учетной записи.

### Настройка синхронизации

Добавьте в файл `sync.json` в массив `mappings` объект синхронизации `managedUser_systemScriptedrestAccount`:

`sync.json`
    
```json
{
    "mappings" : [
        {
            "target" : "system/scriptedrest/account",
            "source" : "managed/user",
            "name" : "managedUser_systemScriptedrestAccount",
            "properties" : [
                {
                    "target" : "name",
                    "source" : "userName"
                },
                {
                    "target" : "fullName",
                    "transform" : {
                        "type" : "text/javascript",
                        "globals" : { },
                        "source" : "source.givenName + ' ' + source.sn"
                    },
                    "source" : ""
                },
                {
                    "target" : "roles",
                    "transform" : {
                        "type" : "text/javascript",
                        "globals" : { },
                        "source" : "var i=0;\nvar res = []\nfor (i = 0; i < source.effectiveRoles.length; i++) {\n  var roleId = source.effectiveRoles[i][\"_ref\"];\n  if (roleId != null && roleId.indexOf(\"/\") != -1) {\n    var roleInfo = openidm.read(roleId);\n    logger.warn(\"Role Info : {}\",roleInfo);\t\n    res.push(roleInfo.name);\n  }\n  \n}\nres"
                    },
                    "source" : ""
                },
                {
                    "target" : "password",
                    "source" : "password"
                }
            ],
            "policies" : [
                {
                    "action" : "EXCEPTION",
                    "situation" : "AMBIGUOUS"
                },
                {
                    "action" : "EXCEPTION",
                    "situation" : "SOURCE_MISSING"
                },
                {
                    "action" : "EXCEPTION",
                    "situation" : "MISSING"
                },
                {
                    "action" : "EXCEPTION",
                    "situation" : "FOUND_ALREADY_LINKED"
                },
                {
                    "action" : "DELETE",
                    "situation" : "UNQUALIFIED"
                },
                {
                    "action" : "EXCEPTION",
                    "situation" : "UNASSIGNED"
                },
                {
                    "action" : "EXCEPTION",
                    "situation" : "LINK_ONLY"
                },
                {
                    "action" : "IGNORE",
                    "situation" : "TARGET_IGNORED"
                },
                {
                    "action" : "IGNORE",
                    "situation" : "SOURCE_IGNORED"
                },
                {
                    "action" : "IGNORE",
                    "situation" : "ALL_GONE"
                },
                {
                    "action" : "UPDATE",
                    "situation" : "CONFIRMED"
                },
                {
                    "action" : "UPDATE",
                    "situation" : "FOUND"
                },
                {
                    "action" : "CREATE",
                    "situation" : "ABSENT"
                }
            ]
        }
    ]
}
```
    

## Проверка адаптера

Зайдите в консоль администратора OpenIDM по url `http://localhost:8080/admin` с логином `openidm-admin` и паролем `openidm-admin`.   В консоли перейдите в раздел Manage → User. В открывшемся списке создайте нового пользователя и заполните атрибуты Username, First Name, Last Name

![OpenIDM new user](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c/1-new-user.png)

На закладке `Password` задайте пароль по умолчанию для пользователя и нажмите кнопку `Save`.

Снова откройте карточку пользователя, и, на закладке Provisioning Roles добавьте ему роль “Менджер”. Если роль еще не существует, добавьте ее, нажав на ссылку “Create New Role”

![OpenIDM add role.png](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c/2-add-role.png)

Нажмите кнопку `Add`

Теперь давайте синхронизируем данные.

Передите в раздел Configure → Mappings и для `managedUser_systemScriptedrestAccount` нажмите кнопку `Reconcile`.

![OpenIDM mappings](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c/3-openidm-mappings.png)

Новый пользователь должен быть создан на стороне 1С.

Проверьте его наличие, вызвав API OpenIDM:

```bash
curl -X GET --location "http://localhost:8080/openidm/system/scriptedrest/account?_queryFilter=true" \ 
    -H "X-OpenIDM-Username: openidm-admin" \
    -H "X-OpenIDM-Password: openidm-admin"
    
{
   "result":[
   ...
      {
         "_id":"3ea8017a-0b26-4311-abef-cb147f748059",
         "roles":[
            "Менеджер"
         ],
         "name":"петр",
         "uid":"3ea8017a-0b26-4311-abef-cb147f748059",
         "fullName":"Петр Петров"
      },
   ...
   ],
   "resultCount":3,
   "pagedResultsCookie":null,
   "totalPagedResultsPolicy":"NONE",
   "totalPagedResults":-1,
   "remainingPagedResults":-1
}
```

Откройте приложение Конфигуратор 1С и проверьте, что новый пользователь был создан.

![1C User list](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c/4-1c-user-list.png)

Измените данные пользователя (например, атрибут Last Name) в OpenIDM и заново запустите процесс синхронизации. Вы увидите, что учетная запись с таким идентификатором изменена в 1С.