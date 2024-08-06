---
layout: blog
title: 'Аутентификация в SPA приложении через OpenAM используя OAuth2/OIDC'
description: 'Данная статья будет полезна разработчикам браузерных (SPA) приложений, которые хотят настроить аутентификацию пользователей. Для аутентификации будет использоваться OAuth2/OIDC протокол c PKCE. В качестве сервера аутентификации будет использоваться сервер управления аутентификации OpenAM'
tags: 
  - openam

---
Данная статья будет полезна разработчикам браузерных (SPA) приложений, которые хотят настроить аутентификацию пользователей. Для аутентификации будет использоваться [OAuth2/OIDC протокол c PKCE](https://oauth.net/2/pkce/). В качестве сервера аутентификации будет использоваться OpenAM.

## Настройка OpenAM

### Установка OpenAM

Пусть OpenAM располагается на хосте `openam.example.org`. Если у вас уже установлен OpenAM, можете пропустить этот шаг. Самым простым способом развернуть OpenAM можно в Docker контейнере. Перед запуском, добавьте имя хоста и IP адрес в файл `hosts`, например `127.0.0.1 openam.example.org` .  

В Windows системах файл `hosts` находится по адресу `C:\Windows\System32\drivers\etc\hosts` , в Linux и Mac находится по адресу `/etc/hosts` 

После этого запустите Docker  контейнер OpenAM Выполните следующую команду:

```bash
docker run -h openam.example.org -p 8080:8080 --name openam openidentityplatform/openam
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
COOKIE_DOMAIN=openam.example.org
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

### Настройка OAuth2/OIDC провайдера

Зайдите в консоль администратора по ссылке 

[http://openam.example.org:8080/openam/XUI/#login/](http://openam.example.org:8080/openam/XUI/#login/)

В поле логин введите значение `amadmin`, поле пароль введите значение из параметра `ADMIN_PWD` команды установки, в данном случае `passw0rd`

### Настройка OAuth2/OIDC

Выберите требуемый realm. В разделе Dashboard кликните на элементе Configure OAuth Provider 

![OpenAM Configure OAuth2 Provider](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-spa-oauth2/0-configure-oauth2-provider.png)

Затем Configure OpenID Connect

![OpenAM Configure OpenID Connect](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-spa-oauth2/1-configure-openid-connect.png)

В открывшейся форме оставьте все настройки без изменений и нажмите кнопку “Create”

![OpenAM Configure OpenID Connect Properties](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-spa-oauth2/2-configure-openid-connect-props.png)

Теперь создадим OAuth2/OIDC клиент, который будет использовать SPA приложение для аутентификации.

Зайдите в консоль администратора, выберите требуемый realm, в меню слева выберите пункт Applications и далее OAuth 2.0

В таблице Agents нажмите кнопку New

![OpenAM Agents Table](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-spa-oauth2/3-agents-table.png)

- Введите Name (client_id) и Password (client_secret) нового приложения
- Откройте настройки приложения
- Установите Client type в Public
- Добавьте в список Redirection URIs URI вашего SPA приложения. В нашем случае это будет [http://localhost:5173/](http://localhost:5173/)
- В список scope добавьте значение `openid`, это нужно, чтобы сразу получить идентификатор пользователя из возвращаемого объекта `id_token`.
- Token Endpoint Authentication Method установите `client_secret_post`

### Настройка CORS

SPA для получения access_token и id_token выполняет кросс-доменные запросы. Для того, чтобы данные запросы не блокировал браузер, нужно включить поддержку [CORS](https://developer.mozilla.org/ru/docs/Web/HTTP/CORS) в OpenAM. 

Откройте консоль администратора. В верхнем меню выберите пункт Configure → Global Services. 

![OpenAM Global Services](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-spa-oauth2/4-global-services.png)

Далее перейдите в CORS Settings и включите поддержку CORS

![OpenAM CORS settings](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-spa-oauth2/5-cors-settings.png)

Нажмите Save Changes

## Пример SPA приложения на React

В качестве примера будем использовать приложение, написанное на React. Для упрощения не будем проверять валидность параметра state, корректность подписи возвращаемого id_token и т.д. В продуктивном окружении настоятельно рекомендуем это сделать.

Создайте нового приложение, выполнив в консоле команду:

```bash
npm create vite@latest react-openam-example -- --template react
```

Добавьте в зависимости библиотеку CryptoJS. Она будет нужна для генерации code_challenge.

```bash
cd react-openam-example
npm install crypto-js
```

Замените содержимое файла react-openam-example/src/App.jsx следующим кодом:

```jsx
import { useEffect, useState } from 'react'

import CryptoJS from 'crypto-js';

import './App.css'

const OPENAM_URL = "http://openam.example.org:8080/openam";
const OAUTH2_ENDPOINT = OPENAM_URL + "/oauth2";
const OAUTH2_AUTHORIZE_ENDPOINT = OAUTH2_ENDPOINT + "/authorize";
const OAUTH2_TOKEN_ENDPOINT = OAUTH2_ENDPOINT + "/access_token";
const CLIENT_ID = "test_client";
const SCOPE = "openid";

function App() {

  const [user, setUser] = useState("");

  //TODO should be randomly generated, saved and then restored in production evironment
  const codeVerifier = "a116cb8c-5a1e-4918-a164-255ae3d8f1b1"; 

  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    const code = params.get('code')
    if(!code) {
      return;
    }
    getToken(code)
  }, [])

  const getToken = async (code) => {
    const resp = await fetch(OAUTH2_TOKEN_ENDPOINT, {
      method: "POST",
      mode: "cors",
      cache: "no-cache", 
      credentials: "include", 
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      redirect: "follow", 
      referrerPolicy: "no-referrer", 
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        client_id: CLIENT_ID,
        code_verifier: codeVerifier,
        code: code,
        redirect_uri: window.location.origin
      }),
    });
    if(resp.ok) {
      const accessToken = await resp.json()
      //TODO verify id_token signature
      const idToken = accessToken['id_token'];
      const parts = idToken.split('.')
      const payload = parts[1];
      const jsonPayload = JSON.parse(atob(payload));
      const sub = jsonPayload["sub"]
      setUser(sub)
      console.log(sub, "authenticated")
    } else {
      console.log(resp.status)
    }
  }
  

  const authOpenAM = () => {
    const state = "state";
    const codeChallenge = CryptoJS.SHA256(codeVerifier).toString(CryptoJS.enc.Base64url);
    console.log(codeChallenge);
    const queryString = "?redirect_uri=" + encodeURIComponent(window.location.origin) +
    "&client_id=" + CLIENT_ID +
    "&response_type=code" +
    "&state=" + state +
    "&scope=" + encodeURIComponent(SCOPE) +
    "&code_challenge=" + codeChallenge +
    "&code_challenge_method=S256";
    window.location = OAUTH2_AUTHORIZE_ENDPOINT + queryString;
  }

  const getComponent = () => {
    if (!user) {
      return <>
      <div>
        <h1>Not authenticated</h1>
      </div>
      <button onClick={authOpenAM}>Login</button>
    </>
    } else {
      return <h1>User {user} authenticated</h1>
    }
  }
  return getComponent()
}

export default App

```

## Проверка решения

Запустите SPA командой

```bash
npm run dev
```

Откройте приложение в браузере перейдя по URL [http://localhost:5173/](http://localhost:5173/)

![SPA not authenticated](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-spa-oauth2/7-spa-no-authenticated.png)

Нажмите кнопку Login. Вас перенаправит на аутентификацию в OpenAM. Введите логин пользователя `demo` и пароль `changeit`. 

![OpenAM demo user authentication](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-spa-oauth2/8-demo-user-authentication.png)

Подтвердите согласие на доступ к данным

![OpenAM demo user consent](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-spa-oauth2/9-user-consent.png)

После этого браузер перенаправит обратно в приложение и успешно аутентифицирует пользователя: Если все настроено корректно, SPA приложение отобразит сообщение об успешной аутентификации:

![SPA user demo authenticated](https://raw.githubusercontent.com/wiki/OpenIdentityPlatform/OpenAM/images/openam-spa-oauth2/10-spa-demo-user-authenticated.png)