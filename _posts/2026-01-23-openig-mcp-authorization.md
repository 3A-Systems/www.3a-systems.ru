---
layout: blog
title: 'Настройка авторизации доступа к MCP серверу при помощи OpenIG'
description: 'Пошаговая настройка авторизации и ограничения доступа к MCP серверу через OpenIG'
keywords: 'MCP, Model Context Protocol, OpenIG, OpenAM, OpenIdentityPlatform, MCP security, MCP authorization, MCP tools filter, IAM, API security, JSON-RPC, DevOps, Zero Trust'
tags: 
  - openig
---

## Введение

Эта статья является продолжением [статьи](https://github.com/OpenIdentityPlatform/OpenAM/wiki/How-to-Protect-Model-Context-Protocol-(MCP)-Servers-with-OpenAM-and-OpenIG) о защите MCP сервера при помощи стека OpenAM и OpenIG. В предыдущей статье мы добавили аутентификацию для доступа к возможностям MCP сервера. В этой статье мы добавим ограничение доступа MCP клиента к некоторым инструментам MCP сервера.

## Описание проекта

Проект состоит из сервера аутентификации OpenAM, шлюза авторизации OpenIG и демонстрационного MCP сервера timeserver. MCP сервер `timeserver` имеет метод получения текущего времени и метод установки времени. Далее мы ограничим доступ к методу установки времени.

## Настройка доступа к функционалу MCP сервера

Для этого добавим в исходный маршрут к MCP серверу в цепочку фильтров фильтр `McpToolsFilter`.

`10-mcp.json`

```json
...
{
   "name": "McpToolsFilter",
   "type": "ScriptableFilter",
   "config": {
      "type": "application/x-groovy",
      "file": "McpToolsFilter.groovy",
      "args": {
         "deny": []
      }
   }
}
...
```

В параметре `deny` оставим пустой массив. Для тестов временно уберем требование аутентификации через OpenAM. Для этого закомментируйте пока в маршруте фильтры `ProtectedResourceFilter` и `ConditionEnforcementFilter` .

В папку `openig-config/scripts` добавьте скрипт `McpToolsFilter.groovy`

```groovy
import groovy.json.JsonSlurper
import groovy.json.JsonOutput
import org.forgerock.http.protocol.Request
import org.forgerock.http.protocol.Status

def generateMcpErrorResponse(status, entity) {
    def response = new Response()
    response.status = status
    response.headers['Content-Type'] = "application/json"
    response.setEntity(entity)
    return response
}

def filterResponse(requestMethod, response) {

    def slurper = new JsonSlurper()
    def responseObj = slurper.parseText(response.entity.getString())
    
    if(requestMethod == "tools/list") {
        logger.info("denied tools: {}, {}", deny, requestMethod)
        if(responseObj.result.tools) {
            responseObj.result.tools = responseObj.result.tools.findAll{ !deny.contains(it.name) }
        }
        logger.info("filtered response: {}", responseObj)

        def newEntity = JsonOutput.toJson(responseObj)
        response.entity.setString(newEntity)    
    } 
    return response
}

logger.info('request: {}', request.entity)

def slurper = new JsonSlurper()
def requestObj = slurper.parseText(request.entity.getString())
def requestMethod = requestObj.method

if (requestMethod == "tools/call") {
    if(deny.contains(requestObj.params.name)) {
        logger.info("method denied: {}", requestObj.params.name)
        def errorObject = [
            jsonrpc: "2.0",
            id     : requestObj.id,
            error  : [
                code   : -32602,
                message: "Unknown tool: invalid_tool_name",
                data   : "Tool not found: " + requestObj.params.name
            ]
        ]
        return generateMcpErrorResponse(Status.OK, JsonOutput.toJson(errorObject))
    }
}

return next.handle(context, request)
    .then({response -> 
        logger.info('response: {}', response.entity)
        response = filterResponse(requestMethod, response)
        return response
    })
```

Скрипт фильтрует список доступных инструментов указанных в настройке фильтра.

Если клиент пытается вызвать инструмент, который запрещен фильтром, возвращается ошибка с кодом `-32602` в соответствии со спецификацией Model Context Protocol.

Выполним запрос к MCP серверу для получения доступных инструментов.

```bash
 curl -X POST  --location  "http://localhost:8081/mcp" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list",
  "params": {}
}' | json_pp
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   789    0   714  100    75   112k  12102 --:--:-- --:--:-- --:--:--  128k
{
   "id" : 1,
   "jsonrpc" : "2.0",
   "result" : {
  "tools" : [
         {
            "annotations" : {
               "destructiveHint" : true,
               "idempotentHint" : false,
               "openWorldHint" : true,
               "readOnlyHint" : false,
               "title" : ""
            },
            "description" : "Returns current time in ISO 8601 format",
            "inputSchema" : {
               "properties" : {},
               "required" : [],
               "type" : "object"
            },
            "name" : "current_time_service",
            "title" : "current_time_service"
         },
         {
            "annotations" : {
               "destructiveHint" : true,
               "idempotentHint" : false,
               "openWorldHint" : true,
               "readOnlyHint" : false,
               "title" : ""
            },
            "description" : "Sets the current time in ISO 8601 format",
            "inputSchema" : {
               "properties" : {
                  "timeStr" : {
                     "description" : "new server time",
                     "type" : "string"
                  }
               },
               "required" : [
                  "timeStr"
               ],
               "type" : "object"
            },
            "name" : "set_current_time_service",
            "title" : "set_current_time_service"
         }
      ]
   }
}
```

```bash
 curl -X POST  --location  "http://localhost:8081/mcp" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list",
  "params": {}
}' | json_pp
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   789    0   714  100    75   112k  12102 --:--:-- --:--:-- --:--:--  128k
{
   "id" : 1,
   "jsonrpc" : "2.0",
   "result" : {
  "tools" : [
         {
            "annotations" : {
               "destructiveHint" : true,
               "idempotentHint" : false,
               "openWorldHint" : true,
               "readOnlyHint" : false,
               "title" : ""
            },
            "description" : "Returns current time in ISO 8601 format",
            "inputSchema" : {
               "properties" : {},
               "required" : [],
               "type" : "object"
            },
            "name" : "current_time_service",
            "title" : "current_time_service"
         },
         {
            "annotations" : {
               "destructiveHint" : true,
               "idempotentHint" : false,
               "openWorldHint" : true,
               "readOnlyHint" : false,
               "title" : ""
            },
            "description" : "Sets the current time in ISO 8601 format",
            "inputSchema" : {
               "properties" : {
                  "timeStr" : {
                     "description" : "new server time",
                     "type" : "string"
                  }
               },
               "required" : [
                  "timeStr"
               ],
               "type" : "object"
            },
            "name" : "set_current_time_service",
            "title" : "set_current_time_service"
         }
      ]
   }
}
```

Как видно из ответа, MCP сервер предоставляет два инструмента `current_time_service` для получения текущего времени и `set_current_time_service` для установки времени.

`set_current_time_service` является небезопасной операцией. Поэтому давайте запретим ее вызов из MCP клиента.

Добавим `set_current_time_service` в список запрещенных для вызова инструментов в фильтре `McpToolsFilter` . 

Попробуем получить список доступных инструментов:

```json
...
{
   "name": "McpToolsFilter",
   "type": "ScriptableFilter",
   "config": {
      "type": "application/x-groovy",
      "file": "McpToolsFilter.groovy",
      "args": {
         "deny": ["set_current_time_service"]
      }
   }
}
...
```

```bash
curl -X POST  --location  "http://localhost:8081/mcp" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list",
  "params": {}
}' | json_pp
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   416  100   341  100    75  14981   3295 --:--:-- --:--:-- --:--:-- 18909
{
   "id" : 1,
   "jsonrpc" : "2.0",
   "result" : {
      "tools" : [
         {
            "annotations" : {
               "destructiveHint" : true,
               "idempotentHint" : false,
               "openWorldHint" : true,
               "readOnlyHint" : false,
               "title" : ""
            },
            "description" : "Returns current time in ISO 8601 format",
            "inputSchema" : {
               "properties" : {},
               "required" : [],
               "type" : "object"
            },
            "name" : "current_time_service",
            "title" : "current_time_service"
         }
      ]
   }
}
```

Как видно из текста ответа, инструмента `set_current_time_service` больше нет в списке. 

Теперь попробуем вызвать инструмент `set_current_time_service`  напрямую.

```bash
curl -X POST  --location  "http://localhost:8081/mcp" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{
  "jsonrpc": "2.0",
  "id": 9,
  "method": "tools/call",
  "params": {
    "_meta": {
      "progressToken": 9
    },
    "name": "set_current_time_service",
    "arguments": {
      "timeStr": "2026-01-20T10:31:35.903756042Z"
    }
  }
}' | json_pp
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   382  100   142  100   240  17924  30295 --:--:-- --:--:-- --:--:-- 54571
{
   "error" : {
      "code" : -32602,
      "data" : "Tool not found: set_current_time_service",
      "message" : "Unknown tool: invalid_tool_name"
   },
   "id" : 9,
   "jsonrpc" : "2.0"
}
```

Раскомментируйте обратно фильтры `ProtectedResourceFilter` и `ConditionEnforcementFilter` . 

По аналогии, вы можете ограничить доступ к другим инструментам, ресурсам или промптам MCP сервера, а так же добавить, в зависимости от требований вашей организации, политики RBAC, ABAC или более сложные.
Подробнее о настройке OpenIG вы можете почитать в [документации](https://doc.openidentityplatform.org/openig/).