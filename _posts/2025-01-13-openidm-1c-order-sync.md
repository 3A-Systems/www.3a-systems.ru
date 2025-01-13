---
layout: blog
title: 'Управление учетными записями из кадровых приказов 1C при помощи OpenIDM'
description: 'В статье рассмотрим случай, когда OpenIDM читает кадровые приказы из 1С, создает учетные записи, назначает им соответствующие роли, а так же удаляет учетные записи при поступлении из 1С соотвествующего кадрового приказа'
tags: 
  - openidm
---

## Введение

Онбординг сотрудников может занимать довольно длительное время, особенно при трудоустройстве в большую компанию. Не раз и не два встречалась ситуация, что новые сотрудники буквально неделями ждут необходимых доступов. Компания теряет деньги, а сотрудники - мотивацию. OpenIDM поможет автоматизировать процесс онбординга и сократить время на выделение доступов. В статье рассмотрим случай, когда OpenIDM читает кадровые приказы из 1С, создает учетные записи и назначает им соответствующие роли. При создании учетной записи, генерирует новый пароль и отправляет на электронную почту. При кадровом переводе - назначает новую роль, а при увольнении - удаляет учетную запись. 

## Подготовка 1С

Для интеграции с OpenIDM будем использовать HTTP сервис, который будет возвращать JSON данные по сотрудникам и кадровым приказам. Данные по сотрудникам нужны для первоначальной синхронизации, а данные по приказам нужны, для того, чтобы выполнять синхронизацию итеративно, не затрагивая все учетные записи.

![HTTP Сервис 1С](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c-sync/0-1c-http-service.png)

Исходный текст HTTP сервиса, разработанного для 1С Бухгалтерия приведен в листинге ниже:
<details>

<summary><code>HTTPIDMСервис</code></summary>
<div markdown=1>

```
    Функция ШаблонURLСотрудникиПолучить(Запрос) 
    	Массив = ПолучитьСписокСотрудниковНаТекущуюДату();
    	СтрокаJSON = ПолучитьJSON(Массив);
    	
    	Ответ = ПолучитьHTTPСервисОтвет();
    	Ответ.УстановитьТелоИзСтроки(СтрокаJSON);
    	
    	Возврат Ответ;
    КонецФункции
    
    Функция ШаблонURLПриказыПолучить(Запрос)  
    	getLatest = Запрос.ПараметрыЗапроса.Получить("getLatest");
    	ПолучитьПоследнийПриказ = getLatest = "true";
    	date = Запрос.ПараметрыЗапроса.Получить("date");
    	ДатаПоследнегоПриказа = Дата("00010101");
    	Если ЗначениеЗаполнено(date) Тогда
    		ДатаПоследнегоПриказа = ПрочитатьДатуJSON(date, ФорматДатыJSON.ISO);	
    	КонецЕсли;
    	                          
    	Массив = ПолучитьСписокПриказов(ПолучитьПоследнийПриказ, ДатаПоследнегоПриказа);
    	СтрокаJSON = ПолучитьJSON(Массив);
    	
    	Ответ = ПолучитьHTTPСервисОтвет();
    	Ответ.УстановитьТелоИзСтроки(СтрокаJSON);
    	
    	Возврат Ответ;
    КонецФункции        
    
    Функция ПолучитьСписокПриказов(ПолучитьПоследнийПриказ, ДатаПоследнегоПриказа) 
    	Запрос = Новый Запрос;                  
    	Лимит = "";
    	Порядок = "";
    	Если ПолучитьПоследнийПриказ Тогда
    		Лимит = " ПЕРВЫЕ 1 ";
    		Порядок = "УБЫВ";
    	КонецЕсли;
    	
    	Запрос.Текст = "ВЫБРАТЬ РАЗРЕШЕННЫЕ " + Лимит + "
    	               |	КадроваяИсторияСотрудников.Период КАК Период,
    	               |	КадроваяИсторияСотрудников.Регистратор КАК Регистратор,
    							   |	КадроваяИсторияСотрудников.ВидСобытия КАК ВидСобытия,
    	               |	КадроваяИсторияСотрудников.Сотрудник.Ссылка КАК СотрудникСсылка,
    	               |	КадроваяИсторияСотрудников.ФизическоеЛицо.Фамилия КАК ФизическоеЛицоФамилия,
    	               |	КадроваяИсторияСотрудников.ФизическоеЛицо.Имя КАК ФизическоеЛицоИмя,
    	               |	КадроваяИсторияСотрудников.ФизическоеЛицо.Отчество КАК ФизическоеЛицоОтчество,
    	               |	КадроваяИсторияСотрудников.Должность КАК Должность
    	               |ИЗ
    	               |	РегистрСведений.КадроваяИсторияСотрудников КАК КадроваяИсторияСотрудников
    							   |ГДЕ    
    							   | Период > &МаксДата
    							   |
    	               |УПОРЯДОЧИТЬ ПО
    	               |	Период " + Порядок;
    	Запрос.Параметры.Вставить("МаксДата", ДатаПоследнегоПриказа);
    	
    	Выборка = Запрос.Выполнить().Выбрать();
        Массив = Новый Массив;
    	Пока Выборка.Следующий() Цикл
    		Структура = Новый Структура("date, type, user, newPosition");
    		Структура.date = Выборка.Период;
    		Структура.type = Строка(Выборка.ВидСобытия);
    		
    		СтруктураПользователь = Новый Структура("uid, name, surname, patronymic");
    		СтруктураПользователь.uid = Строка(Выборка.СотрудникСсылка.УникальныйИдентификатор());  
    		СтруктураПользователь.name = Выборка.ФизическоеЛицоИмя;  
    		СтруктураПользователь.surname = Выборка.ФизическоеЛицоФамилия;  
    		СтруктураПользователь.patronymic = Выборка.ФизическоеЛицоОтчество; 
    		
    		Структура.user = СтруктураПользователь;
    		
    		Если ЗначениеЗаполнено(Выборка.Должность) Тогда
    			Структура.newPosition = Выборка.Должность.Наименование;  
    		Иначе
    			Структура.newPosition = "";  	
    		КонецЕсли;
    		
    		Массив.Добавить(Структура);
    	КонецЦикла;
    	Возврат Массив;	
    
    КонецФункции
    
    Функция ПолучитьСписокСотрудниковНаТекущуюДату() 
    	Запрос = Новый Запрос;
    	Запрос.Текст = "ВЫБРАТЬ РАЗРЕШЕННЫЕ
    	               |	СправочникСотрудники.Ссылка КАК Ссылка,
    	               |	СправочникСотрудники.Код КАК Код,
    	               |	СправочникСотрудники.Наименование КАК Наименование,
    	               |	СправочникСотрудники.ФизическоеЛицо КАК ФизическоеЛицо,
    	               |	СправочникСотрудники.ФизическоеЛицо.Фамилия КАК ФизическоеЛицоФамилия,
    	               |	СправочникСотрудники.ФизическоеЛицо.Имя КАК ФизическоеЛицоИмя,
    	               |	СправочникСотрудники.ФизическоеЛицо.Отчество КАК ФизическоеЛицоОтчество,
    	               |	СправочникСотрудники.ГоловнаяОрганизация КАК ГоловнаяОрганизация,
    	               |	ЕСТЬNULL(КадроваяИсторияСотрудниковИнтервальный.Подразделение, ЗНАЧЕНИЕ(Справочник.ПодразделенияОрганизаций.ПустаяСсылка)) КАК ТекущееПодразделение,
    	               |	ЕСТЬNULL(КадроваяИсторияСотрудниковИнтервальный.Должность, ЗНАЧЕНИЕ(Справочник.Должности.ПустаяСсылка)) КАК ТекущаяДолжность
    	               |ИЗ
    	               |	Справочник.Сотрудники КАК СправочникСотрудники
    	               |		ЛЕВОЕ СОЕДИНЕНИЕ РегистрСведений.КадроваяИсторияСотрудниковИнтервальный КАК КадроваяИсторияСотрудниковИнтервальный
    	               |		ПО СправочникСотрудники.Ссылка = КадроваяИсторияСотрудниковИнтервальный.Сотрудник
    	               |			И (КадроваяИсторияСотрудниковИнтервальный.ДатаНачала В
    	               |				(ВЫБРАТЬ
    	               |					МАКСИМУМ(Т.ДатаНачала)
    	               |				ИЗ
    	               |					РегистрСведений.КадроваяИсторияСотрудниковИнтервальный КАК Т
    	               |				ГДЕ
    	               |					СправочникСотрудники.Ссылка = Т.Сотрудник
    	               |					И &МаксимальнаяДатаНачалоДня МЕЖДУ Т.ДатаНачала И Т.ДатаОкончания))
    	               |ГДЕ
    								 |	СправочникСотрудники.ПометкаУдаления = ЛОЖЬ";
    	Запрос.Параметры.Вставить("МаксимальнаяДатаНачалоДня", ТекущаяДата());
    	
    	Выборка = Запрос.Выполнить().Выбрать(); 
    	Массив = Новый Массив;
    	Пока Выборка.Следующий() Цикл
    		Структура = Новый Структура("uid, name, surname, patronymic, position");
    		Структура.uid = Строка(Выборка.Ссылка.УникальныйИдентификатор());  
    		Структура.name = Выборка.ФизическоеЛицоИмя;  
    		Структура.surname = Выборка.ФизическоеЛицоФамилия;  
    		Структура.patronymic = Выборка.ФизическоеЛицоОтчество;  
    		Если ЗначениеЗаполнено(Выборка.ТекущаяДолжность) Тогда
    			Структура.position = Выборка.ТекущаяДолжность.Наименование;  
    		Иначе
    			Структура.position = "";  	
    		КонецЕсли;
    		
    		Массив.Добавить(Структура);
    	КонецЦикла;
    	Возврат Массив;	
    КонецФункции      
    
    Функция ПолучитьJSON(Данные)
    	ЗаписьJSON = Новый ЗаписьJSON;
    	ЗаписьJSON.УстановитьСтроку();  
    	ЗаписатьJSON(ЗаписьJSON, Данные); 
    	Возврат ЗаписьJSON.Закрыть();
    КонецФункции
    
    Функция ПолучитьHTTPСервисОтвет()  
    	Ответ = Новый HTTPСервисОтвет(200);   
    	Ответ.Заголовки.Вставить("Content-Type","application/json; charset=utf-8");
    	Возврат Ответ;
    КонецФункции
```
</div>
</details>

Создайте в 1С служебную учетную запись, которая будет иметь право читать данные, нужные для сервиса и с которой OpenIDM будет ходить в сервис для получения данных.

Как создавать HTTP сервисы 1С более подробно описано по ссылкам:

[https://infostart.ru/1c/articles/1293341/](https://infostart.ru/1c/articles/1293341/)

[https://infostart.ru/1c/articles/842751/](https://infostart.ru/1c/articles/842751/)

## Настройка OpenIDM.

Если OpenIDM у вас еще не установлен, установите его, как описано в [статье](https://www.3a-systems.ru/blog/2024-08-06-identity-management-and-openidm-intro#%D0%B7%D0%B0%D0%B3%D1%80%D1%83%D0%B7%D0%BA%D0%B0-%D0%B8-%D0%B7%D0%B0%D0%BF%D1%83%D1%81%D0%BA-openidm). 

### Настройка подключения к 1С.

В каталог `conf` OpenIDM добавьте файл конфигурации коннектора к 1С
<details>

<summary><code>provisioner.openicf-scriptedrest.json</code></summary>
<div markdown=1>
    
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
            "password" : "passw0rd",
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
            "searchScriptFileName" : "SearchScript.groovy",
            "syncScriptFileName" : "SyncScript.groovy",
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
                    "surname" : {
                        "type" : "string",
                        "nativeName" : "surname",
                        "nativeType" : "string"
                    },
                    "patronymic" : {
                        "type" : "string",
                        "nativeName" : "patronymic",
                        "nativeType" : "string"
                    },
                    "position" : {
                        "type" : "string",
                        "nativeName" : "position",
                        "nativeType" : "string"
                    }
                }
            }
        }
    }
```
</div>
</details>
    

Измените свойства объекта `configurationProperties`  в соттветствии с настройками подключения к HTTP сервису вашей информационной базы 1С.

В каталог `tools` добавьте скрипты, которые будут обращаться к API 1C:

<details>
<summary><code>CustomizerScript.groovy</code> - скрипт, который отвечает за начальную настройку HTTP клиента</summary>
<div markdown=1>
    
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
</div>
</details>
    
<details>
<summary><code>SearchScript.groovy</code> - получает данные по сотрудникам из 1С</summary>
<div markdown=1>
    
```groovy
    
    import groovyx.net.http.RESTClient
    import org.apache.http.client.HttpClient
    import org.forgerock.openicf.connectors.scriptedrest.ScriptedRESTConfiguration
    import org.forgerock.openicf.misc.scriptedcommon.OperationType
    import org.identityconnectors.common.logging.Log
    import org.identityconnectors.framework.common.objects.Attribute
    import org.identityconnectors.framework.common.objects.AttributeUtil
    import org.identityconnectors.framework.common.objects.Name
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
                    } else if (AttributeUtil.namesEqual(name, "surname")) {
                        return "surname"
                    } else if (AttributeUtil.namesEqual(name, "patronymic")) {
                        return "patronymic"
                    } else {
                        throw new IllegalArgumentException("Unknown field name: ${name}");
                    }
                },
                convertValue : { Attribute value ->
                    if (AttributeUtil.namesEqual(value.name, "position")) {
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
                            attribute 'surname', value?.surname
                            attribute 'name', value?.name
                            attribute 'patronymic', value?.patronymic
                            attribute 'position', value?.position
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
</div>
</details>


<details>
<summary><code>SyncScript.groovy</code> - получает данные по кадровым приказам из 1С</summary>
<div markdown=1>
    
```groovy
    
    import groovyx.net.http.RESTClient
    import org.apache.http.client.HttpClient
    import org.forgerock.openicf.connectors.scriptedrest.ScriptedRESTConfiguration
    import org.forgerock.openicf.misc.scriptedcommon.OperationType
    import org.identityconnectors.common.logging.Log
    import org.identityconnectors.framework.common.objects.ObjectClass
    import org.identityconnectors.framework.common.objects.SyncToken
    
    import static groovyx.net.http.Method.GET
    
    def operation = operation as OperationType
    def configuration = configuration as ScriptedRESTConfiguration
    def httpClient = connection as HttpClient
    def connection = customizedConnection as RESTClient
    def log = log as Log
    def objectClass = objectClass as ObjectClass
    
    log.info("Entering " + operation + " Script");
    
    if (OperationType.GET_LATEST_SYNC_TOKEN.equals(operation)) {
    
        return connection.request(GET) { req ->
            uri.path = '/api/orders'
            uri.query = [
                    getLatest: 'true',
            ]
    
            response.success = { resp, json ->
                def lastToken = 0l
                json.each() { it ->
                    lastToken = it.date
                }
                return new SyncToken(lastToken)
            }
    
            response.failure = { resp, json ->
                throw new ConnectException(json.message)
            }
        }
    
    } else if (OperationType.SYNC.equals(operation)) {
        def token = token as Object
        log.info("Entering SYNC");
        switch (objectClass) {
            case ObjectClass.ACCOUNT:
                return connection.request(GET) { req ->
                    uri.path = '/api/orders'
                    uri.query = [
                            date: "${token}",
                    ]
    
                    response.success = { resp, json ->
                        def lastToken = 0l
                        json.each() { changeLogEntry ->
                            lastToken = changeLogEntry.date
    
                            def user = {
                                uid changeLogEntry.user.uid
                                id changeLogEntry.user.uid
                                attribute 'name', changeLogEntry.user.name
                                attribute 'surname', changeLogEntry.user.surname
                                attribute 'patronymic', changeLogEntry.user.patronymic
                                attribute 'position', changeLogEntry.newPosition?.name
                            }
    
                            handler({
                                syncToken lastToken
                                if ("hire".equals(changeLogEntry.type)) {
                                    CREATE()
                                    object user
                                } else if ("transfer".equals(changeLogEntry.type)) {
                                    CREATE_OR_UPDATE()
                                    object user
                                } else if ("fire".equals(changeLogEntry.type)) {
                                    DELETE()
                                    object {
                                        uid changeLogEntry.user.uid
                                        id changeLogEntry.user.uid
                                        delegate.objectClass(objectClass)
                                    }
                                    return
                                } else {
                                    CREATE_OR_UPDATE()
                                    object user
                                }
                            })
                        }
                        return new SyncToken(lastToken)
                    }
    
                    response.failure = { resp, json ->
                        throw new ConnectException(json.message)
                    }
                }
                break;
    
            case ObjectClass.GROUP:
                throw new IllegalArgumentException("Group sync is not supported");
                break;
        }
    
    } else { // action not implemented
        log.error("Sync script: action '" + operation + "' is not implemented in this script");
    }
    
```
</div>
</details>
    

### Настройка синхронизации

Поместите файл `translit.js` в каталог `script` OpenIDM.

<details>

<summary><code>translit.js</code></summary>
<div markdown=1>

```js
    /*global exports*/
    (function () {
        var translit = function (word) {
    
            var converter = {
                'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd',
                'е': 'e', 'ё': 'e', 'ж': 'zh', 'з': 'z', 'и': 'i',
                'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n',
                'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't',
                'у': 'u', 'ф': 'f', 'х': 'h', 'ц': 'c', 'ч': 'ch',
                'ш': 'sh', 'щ': 'sch', 'ь': '', 'ы': 'y', 'ъ': '',
                'э': 'e', 'ю': 'yu', 'я': 'ya'
            }
            var answer = '';
            word = word.toLowerCase();
            for (var i = 0; i < word.length; ++i) {
                if (converter[word[i]] == undefined) {
                    answer += word[i];
                } else {
                    answer += converter[word[i]];
                }
            }
            return answer;
        }
    
        var generateLogin = function (name, surname) {
            var nameT = translit(name);
            var surnameT = translit(surname);
            return nameT.substring(0, 1) + surnameT;
        }
    
        exports.translit = translit;
        exports.generateLogin = generateLogin;
    
    }());
```
</div>
</details>
    

Функция `generateLogin` скрипта при синхронизации вызывается для автоматической генерации логина и адреса электронной почты.

Поместите файл настроек синхронизации `sync.json` в каталог `conf` OpenIDM.

<details>

<summary><code>sync.json</code></summary>
<div markdown=1>

```json
    {
        "mappings" : [
            {
                "target" : "managed/user",
                "source" : "system/scriptedrest/account",
                "name" : "systemScriptedrestAccount_managedUser",
                "properties" : [
                    {
                        "target" : "mail",
                        "transform" : {
                            "type" : "text/javascript",
                            "globals" : { },
                            "source" : "require('translit').generateLogin(source.name, source.surname) + \"@example.org\""
                        },
                        "source" : ""
                    },
                    {
                        "target" : "sn",
                        "source" : "surname"
                    },
                    {
                        "target" : "givenName",
                        "source" : "name"
                    },
                    {
                        "target" : "userName",
                        "transform" : {
                            "type" : "text/javascript",
                            "globals" : { },
                            "source" : "require('translit').generateLogin(source.name, source.surname)"
                        },
                        "source" : ""
                    },
                    {
                        "target" : "roles",
                        "transform" : {
                            "type" : "text/javascript",
                            "globals" : { },
                            "source" : "/*global openidm*/\nlogger.warn(\"set role {} for {}\", source.position, source.name);\n\nfunction getRoles(position) {\n    if(!position) {\n        return [];\n    }\n    var response = openidm.query(\"managed/role\", {\"_queryFilter\": 'name eq \"' + position + '\"'});\n\n    var roleId;\n    if(!response.result || response.result.length === 0) {\n        response = openidm.create(\"managed/role\", null, {'name': position, 'description' : position});\n        logger.warn(\"got new role response: {}\", response);\n        roleId = response[\"_id\"];\n\n    } else {\n        logger.warn(\"existing role response: {}\", response);\n        roleId = response.result[0][\"_id\"];\n    }\n\n    return [{\n        \"_ref\": \"managed/role/\" + roleId\n    }];\n}\n\ngetRoles(source.position)\n\n\n"
                        },
                        "source" : ""
                    }
                ],
                "policies" : [
                    {
                        "action" : "EXCEPTION",
                        "situation" : "AMBIGUOUS"
                    },
                    {
                        "action" : "DELETE",
                        "situation" : "SOURCE_MISSING"
                    },
                    {
                        "action" : "CREATE",
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
                ],
                "onCreate" : {
                    "type" : "text/javascript",
                    "globals" : { },
                    "source" : "logger.warn(\"generating password for {}\", target);\n// generate random password that aligns with policy requirements\ntarget.password = require(\"crypto\").generateRandomString([\n  { \"rule\": \"UPPERCASE\", \"minimum\": 1 },\n  { \"rule\": \"LOWERCASE\", \"minimum\": 1 },\n  { \"rule\": \"INTEGERS\", \"minimum\": 1 },\n  { \"rule\": \"SPECIAL\", \"minimum\": 0, \"maximum\": 0 }\n], 16);\n\nlogger.warn(\"genered password {}\", target.password);\n\n\nlogger.warn(\"sending email {}\", target.mail);\n\nvar escapedPass = target.password\n  .replace(/&/g, \"&amp;\")\n  .replace(/</g, \"&lt;\")\n  .replace(/>/g, \"&gt;\")\n  .replace(/\"/g, \"&quot;\")\n  .replace(/'/g, \"&#039;\");\n\nvar params =  new Object();\nparams.from = \"openidm@example.org\";\nparams.to = target.mail;\nparams.subject = \"Ваш новый пароль\";\nparams.type = \"text/html\";\nparams.body = \"<html><body><p>Здравствуйте!<br/>Ваш новый пароль \" + escapedPass + \"</p></body></html>\";\n\ntry {\n  openidm.action(\"external/email\", \"send\", params);\n} catch(ex) {\n  logger.error(\"error sending mail: {}\", ex);\n}\n"
                },
                "taskThreads" : 1
            }
        ]
    }
```
</div>
</details>
    

Проверьте настройки синхронизации в консоли администратора OpenIDM. Для этого перейдите в вашем браузере по ссылке [http://localhost:8080/admin](http://localhost:8080/admin). Логин и пароль для администратора по умолчанию `openidm-admin` и `openidm-admin`. В верхнем меню перейдите Configure → Mappings. 

Откройте настройки синхронизации `systemScriptedrestAccount_managedUser`.  
![Настройка синхронизации 1С OpenIDM](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c-sync/1-reconcile-settings.png)


Особый интерес представляет синхронизация полей `mail`, `userName` и `roles` так как они формируются при помощи скриптов. Вы можете посмотреть скрипты на закладке `Transformation Script`:

![Скрипт преобразования поля mail](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c-sync/2-mail-transformation-script.png)

При создании учетной записи для нее генерируется пароль и отправляется по электронной почте. Это так же делается при помощи скрипта в обработчике `onCreate` настроек синхронизации. Чтобы просмотреть текст скрипта, в настройках синхронизации перейдите на закладку `Behaviors` . Далее в раздел `Situational Event Scripts` и откройте обработчик `onCreate` Скрипт будет выглядеть примерно таким образом:

```jsx
logger.warn("generating password for {}", target);
// generate random password that aligns with policy requirements
target.password = require("crypto").generateRandomString([
  { "rule": "UPPERCASE", "minimum": 1 },
  { "rule": "LOWERCASE", "minimum": 1 },
  { "rule": "INTEGERS", "minimum": 1 },
  { "rule": "SPECIAL", "minimum": 0, "maximum": 0 }
], 16);

logger.warn("sending email {}", target.mail);

var escapedPass = target.password
  .replace(/&/g, "&amp;")
  .replace(/</g, "&lt;")
  .replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;")
  .replace(/'/g, "&#039;");

var params =  new Object();
params.from = "openidm@example.org";
params.to = target.mail;
params.subject = "Ваш новый пароль";
params.type = "text/html";
params.body = "<html><body><p>Здравствуйте!<br/>Ваш новый пароль " + escapedPass + "</p></body></html>";

try {
  openidm.action("external/email", "send", params);
} catch(ex) {
  logger.error("error sending mail: {}", ex);
}

```

### Настройка электронной почты

Для демонстрационных целей мы будем использовать тестовый SMTP сервер с открытым исходным кодом https://github.com/maildev/maildev, запущенный в Docker контейнере.

В каталог `conf` OpenIDM поместите файл настройки подключения к SMTP серверу, чтобы OpenIDM мог отправлять сгенерированный пароль по почте.

<details>
<summary><code>external.email.json</code></summary>
<div markdown=1>
    
```json
    {
        "host" : "localhost",
        "port" : "1025",
        "auth" : {
            "enable" : false
        },
        "starttls" : {
            "enable" : false
        },
        "from" : ""
    }
```
</div>
</details>
    

Запустите Docker образ тестового SMTP сервера:

```bash
docker run -p 1080:1080 -p 1025:1025 maildev/maildev
```

Более подробно про настройку отправки почты из OpenIDM вы можете прочитать по [ссылке](https://doc.openidentityplatform.org/openidm/integrators-guide/chap-mail).

## Проверка решения

### Начальная синхронизация

Зайдите в консоль администратора OpenIDM. В верхнем меню перейдите Configure → Mappings. Выберите `systemScriptedrestAccount_managedUser` и нажмите кнопку `Reconcile`. Дождитесь окончания синхронизации.

![Успешная синхронизация](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c-sync/3-reconcile-result.png)

В консоли администратора перейдите в Manage → Users. Вы увидите список учетных записей, загруженных из информационной базы 1С Бухгалтерия. Для каждой записи сгенерирован логин, адрес электронной почты и назначена соответствующая роль. 

![Список пользователей OpenIDM](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c-sync/4-openidm-user-list.png)

Сгенерированный пароль отправлен по электронной почте. Откройте консоль тестового SMTP сервера по адресу [http://localhost:1080/](http://localhost:1080/). Вы увидите отправленные письма для каждой учетной записи.

![Email со сгенерированым паролем](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c-sync/5-mail-new-password.png)

### Синхронизация приказов

Каждый раз синхронизировать все данные из 1С возможно, но, при большом количестве сотрудников не рационально, так как синхронизация будет занимать долгое время и потреблять большое количество вычислительных ресурсов.. Поэтому, далее мы будем синхронизировать только изменения. Изменения в 1С регистрируются при помощи кадровых приказов. Давайте создадим несколько кадровых приказов в 1С и проверим их синхронизацию в OpenIDM.

В консоли администратора OpenIDM в верхнем меню перейдите Configure → Schedules. Создайте новое расписание.

![OpenIDM новое расписание](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c-sync/6-openidm-new-sync.png)

Зайдите в 1С Бухгалтерия и создайте приказ приема на работу сотрудника Иванов Иван Иванович с должностью Кладовщик. Проведите документ.

![1С приказ о приеме на работу](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c-sync/7-1с-hiring-order.png)

Подождите пару минут и откройте список пользователей OpenIDM

Вы увидите, что в консоли появится новый пользователь `iivanov` с ролью Кладовщик 

![Новый пользователь OpenIDM](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c-sync/8-openidm-new-user.png)

Создайте в 1С документ Кадровый перевод. И назначьте в нем сотруднику новую роль “Кассир”. Проведите документ. 

![1С приказ о переводе](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c-sync/9-1c-transfer-order.png)

Подождите пару минут и проверьте роли пользователя `iivanov` OpenIDM.

Ему будет назначена новая роль “Кассир” из 1С.

![OpenIDM новая роль](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c-sync/10-openidm-new-role.png)

Теперь давайте создадим приказ об увольнении сотрудника Создайте и проведите приказ в 1С.

![1С приказ об увольнении](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c-sync/11-1c-fire-order.png)

Дождитесь синхронизации. Пользователь `iivanov` будет удален из списка пользователей OpenIDM.

![OpenIDM пользователь удален](https://raw.githubusercontent.com/wiki/3A-Systems/OpenIDM/images/openidm-1c-sync/12-openidm-user-deleted.png)
