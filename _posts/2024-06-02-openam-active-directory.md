---
layout: blog
title: 'Настройка аутентификации в приложении через Active Directory с использованием OpenAM'
description: 'В статье мы настроим аутентификацию в OpenAM используя учетные запии Microsoft Active Directory в Spring Boot приложение'
tags: 
  - openam
---

## Введение

Почти каждая организация использует [Active Directory](https://ru.wikipedia.org/wiki/Active_Directory) для управления учетными записями сотрудников. И использование существующих учетных записей для доступа к корпоративным приложениям является хорошей практикой. В данной статье мы настроим аутентификацию в [демонстрационном Spring Boot приложении](https://github.com/OpenIdentityPlatform/spring-security-openam-example) через существующий сервер Active Directory в [OpenAM](https://github.com/OpenIdentityPlatform/OpenAM). 

## Настройка OpenAM

### Установка OpenAM

Пусть OpenAM располагается на хосте `openam.example.org`, Spring Boot приложение располагается на хосте `app.example.org`.

Если у вас уже установлен OpenAM, можете пропустить этот шаг. Самым простым способом развернуть OpenAM можно в Docker контейнере. Перед запуском, добавьте имя хоста и IP адрес в файл `hosts`, например `127.0.0.1 app.example.org openam.example.org` .  

В Windows системах файл `hosts` находится по адресу `C:\Windows\System32\drivers\etc\hosts` , в Linux и Mac находится по адресу `/etc/hosts` .

Создайте сеть в Docker для OpenAM

```bash
docker network create openam
```

После этого запустите Docker  контейнер OpenAM Выполните следующую команду:

```bash
docker run -h openam.example.org -p 8080:8080 --network openam --name openam openidentityplatform/openam
```

После того, как сервер запустится, запустите начальную конфигурацию OpenAM. Выполните следующую команду:

```bash
docker exec -w '/usr/openam/ssoconfiguratortools' openam bash -c \
'echo "ACCEPT_LICENSES=true
SERVER_URL=http://openam.example.org:8080
DEPLOYMENT_URI=/$OPENAM_PATH
BASE_DIR=$OPENAM_DATA_DIR
locale=en_US
PLATFORM_LOCALE=en_US
AM_ENC_KEY=
ADMIN_PWD=passw0rd
AMLDAPUSERPASSWD=p@passw0rd
COOKIE_DOMAIN=example.org
ACCEPT_LICENSES=true
DATA_STORE=embedded
DIRECTORY_SSL=SIMPLE
DIRECTORY_SERVER=openam.example.org
DIRECTORY_PORT=50389
DIRECTORY_ADMIN_PORT=4444
DIRECTORY_JMX_PORT=1689
ROOT_SUFFIX=dc=openam,dc=example,dc=org
DS_DIRMGRDN=cn=Directory Manager
DS_DIRMGRPASSWD=passw0rd" > conf.file && java -jar openam-configurator-tool*.jar --file conf.file'
```

После успешной конфигурации можно приступить к дальнейшей настройке. 

Обратите внимание на параметр `COOKIE_DOMAIN` - cookie сессии аутентификации должна выставляться на общий верхнего уровня для OpenAM и приложения.

### Настройка модуля аутентификации

Зайдите в консоль администратора по ссылке 

[http://openam.example.org:8080/openam/XUI/#login/](http://openam.example.org:8080/openam/XUI/#login/)

В поле логин введите значение `amadmin`, поле пароль введите значение из параметра `ADMIN_PWD` команды установки, в данном случае `passw0rd`

Выберите корневой realm и в меню выберите пункт Authentication → Modules. Создайте новый модуль аутентификации Active Directory.

![OpenAM new Active Directory Module](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-ad-springboot/0-openam-new-ad-module.png)

Заполните настройки модуля согласно таблице

| Настройка | Описание |
| --- | --- |
| Primary Active Directory Server | AD хост и номер порта, например: ad.example.org:389 |
| Users Domain | Домен Active Directory для аутентификации пользователя, например, example.org. Нужно заполнить это свойство, чтобы пользователи не вводили для аутентификации имя в виде user@example.org |
| Bind User DN | Оставьте не заполненным. При пустом значении используется binding аутентификация, и нет необходимости указывать Bind user password, User Search Filter и DN to Start User Search. |

Остальные настройки можно оставить без изменений.

### Настройка цепочки аутентификации

Зайдите в консоль администратора выберите нужный realm и в меню выберите пункт Authentication → Chains. Создайте цепочку аутентификации `activeDirectory` с вновь созданным модулем `activeDirectory`.

![OpenAM Active Directory Authentication Chain](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-ad-springboot/1-openam-ad-auth-chain.png)

### Настройка realm

Перейдите в раздел Authentication → Chains для realm и на закладке User Profile установите настройку `User Profile` в значение `Ignore`.

![OpenAM Realm User Profile Settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-ad-springboot/2-openam-realm-auth-settings.png)

Таким образом, вы можете аутентифицироваться в  Active Directory без подключения Active Directory в User Data Store в OpenAM.

## Подготовка Spring Boot приложения

Рекомендуемым способом является интеграция через Spring Security.

В приложении используется фильтра фильтр, который можно повесить на Spring REST или Web Controller.

Фильтр получает Cookie с идентификатором сессии аутентификации, установленной OpenAM при успешной аутентификации из объекта HttpServletRequest. Затем вызывается API OpenAM для получения пользователя из сессии. Если Cookie не существует или сессия, полученная из cookie не валидна, то пользователь перенаправляется на аутентификацию.

Пример фильтра в листинге ниже:

```java
@Component
public class OpenAmAuthFilter implements Filter {

    final static String OPENAM_URI = "http://openam.example.org:8080/openam";

    final static String OPENAM_COOKIE_NAME = "iPlanetDirectoryPro";

    final static String REDIRECT_URI_TEMPLATE = OPENAM_URI.concat("/XUI#login/&service=activeDirectory&goto=");

    private final String OPENAM_USER_INFO_URI = OPENAM_URI.concat("/json/users?_action=idFromSession");

    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
        HttpServletRequest request = (HttpServletRequest) servletRequest;
        HttpServletResponse response = (HttpServletResponse) servletResponse;

        //reading OpenAM session cookie
        Optional<Cookie> openamCookie = Optional.empty();
        if(request.getCookies() != null) {
            openamCookie = Arrays.stream(request.getCookies())
                    .filter(c -> c.getName().equals(OPENAM_COOKIE_NAME)).findFirst();
        }
        String redirectUri = request.getRequestURL().toString();
        if(openamCookie.isEmpty()) {
            response.sendRedirect(REDIRECT_URI_TEMPLATE  + URLEncoder.encode(redirectUri, StandardCharsets.UTF_8));
        } else {
            //retrieve userID from by session cookie value from OpenAM
            String userId = getUserIdFromSession(openamCookie.get().getValue());
            if (userId == null) {
                response.sendRedirect(REDIRECT_URI_TEMPLATE + URLEncoder.encode(redirectUri, StandardCharsets.UTF_8));
                return;
            }
            request.setAttribute("openam.userId", userId);
            filterChain.doFilter(servletRequest, servletResponse);
        }
    }

    private String getUserIdFromSession(String sessionId) {
        RestTemplate restTemplate = new RestTemplate();
        ParameterizedTypeReference<Map<String, String>> responseType = new ParameterizedTypeReference<>() {};
        HttpHeaders headers = new HttpHeaders();
        headers.add(OPENAM_COOKIE_NAME, sessionId);
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<?> entity = new HttpEntity<>(headers);
        ResponseEntity<Map<String, String>> response
                = restTemplate.exchange(OPENAM_USER_INFO_URI, HttpMethod.POST, entity, responseType);
        Map<String, String> body = response.getBody();
        if (body == null) {
            return null;
        }
        return body.get("id");
    }
}
```

## Проверка решения

Запустим демонстрационное Spring Boot приложение в Docker контейнере

```bash
docker run -h app.example.org -p 8081:8081 --network openam --name spring-security-openam-example openidentityplatform/spring-security-openam-example
```

Выйдете из консоли откройте в браузере ссылку демонстрационного приложения. [http://app.example.org:8081/](http://app.example.org:8081/) Перейдите по ссылке `OpenAM Cookie`.

![Example Spring Boot Application](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-ad-springboot/3-example-spring-boot-application.png)

Фильтр не найдет валидной сессии и перенаправит на аутентификацию OpenAM. Введите учетные данные пользователя из Active Directory. 

![OpenAM Authentication](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-ad-springboot/4-openam-authentication.png)

После успешной аутентификации пользователя перенаправит обратно в приложение. В атрибут `openam.userId` объекта HttpServletRequest будет установлен идентификатор пользователя из Active Directory. 

![Seccuessful Authentication](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-ad-springboot/5-successful-auth.png)
