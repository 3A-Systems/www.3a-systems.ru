---
layout: blog
title: 'Запуск встроенного LDAP на базе OpenDJ в Spring Boot приложении'
description: 'В этой статье мы настроим Spring Boot приложение со встроенным LDAP на базе LDAP сервера с открытым исходным кодом OpenDJ. Это может понадобиться как для тестов, так и для продуктивного использования. Например, для аутентификации через LDAP.'
tags: 
  - opendj

---

## Введение

В этой статье мы настроим Spring Boot приложение со встроенным LDAP на базе LDAP сервера с открытым исходным кодом [OpenDJ](https://github.com/OpenIdentityPlatform/OpenDJ). Это может понадобиться как для тестов, так и для продуктивного использования. Например, для аутентификации через LDAP.

## Создание проекта

Создайте пустой Spring Boot проект при помощи сайта Spring Initializer или вручную. Добавьте зависимость `opendj-embedded` в файл `pom.xml` Spring Boot  приложения

```xml
<dependency>
    <groupId>org.openidentityplatform.opendj</groupId>
    <artifactId>opendj-embedded</artifactId>
    <version>4.6.4</version>
</dependency>
```

Добавьте аргументы совместимости с Java 8 в свойства проекта

```xml
<properties>
		...
    <jvm.compatibility.args>
        --add-exports java.base/sun.security.tools.keytool=ALL-UNNAMED
        --add-exports java.base/sun.security.x509=ALL-UNNAMED
    </jvm.compatibility.args>
</properties>
```

И пропишите эти аргументы в `spring-boot-maven-plugin`:

```xml
<plugin>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-maven-plugin</artifactId>
    <configuration>
        <jvmArguments>${jvm.compatibility.args}</jvmArguments>
    </configuration>
</plugin>
```

Добавьте bean Embedded OpenDJ в ваше Spring Boot приложение.

```java
@Bean
public EmbeddedOpenDJ embeddedOpenDJ() {
    EmbeddedOpenDJ embeddedOpenDJ = new EmbeddedOpenDJ();
    embeddedOpenDJ.run();
    return embeddedOpenDJ;
}
```

В принципе, это все, что нужно для запуска встроенного OpenDJ. Остались нюансы. Давайте рассмотрим, как можно изменить конфигурацию 

### Изменение конфигурации по умолчанию

Создайте новый класс конфигурации, унаследованный от класса `org.openidentityplatform.opendj.embedded.Config` и перегрузите нужные свойства, например, baseDN и пароль администратора:

```java
@Configuration
public class OpenDJConfiguration extends Config {

    @Override
    @Value("${opendj.basedn:dc=example,dc=openidentityplatform,dc=org}")
    public void setBaseDN(String baseDN) {
        super.setBaseDN(baseDN);
    }

    @Override
    @Value("${opendj.adminpwd:passw0rd}")
    public void setAdminPassword(String adminPassword) {
        super.setAdminPassword(adminPassword);
    }
}
```

Добавьте конфигурацию в инициализацию bean `EmbeddedOpenDJ`

```java
@Bean
public EmbeddedOpenDJ embeddedOpenDJ(OpenDJConfiguration configuration) throws IOException, EmbeddedDirectoryServerException {
    EmbeddedOpenDJ embeddedOpenDJ = new EmbeddedOpenDJ(configuration);
    embeddedOpenDJ.run();
    return embeddedOpenDJ;
}
```

### Импорт данных

Для демонстрационных целей импортируем начальные ldif данные из строки.

```java
@Bean
public EmbeddedOpenDJ embeddedOpenDJ(OpenDJConfiguration configuration) throws IOException, EmbeddedDirectoryServerException {
    EmbeddedOpenDJ embeddedOpenDJ = new EmbeddedOpenDJ(configuration);
    embeddedOpenDJ.run();
    String data = """
dn: dc=example,dc=openidentityplatform,dc=org
objectClass: top
objectClass: domain
dc: example

dn: ou=people,dc=example,dc=openidentityplatform,dc=org
objectclass: top
objectclass: organizationalUnit
ou: people

dn: uid=jdoe,ou=people,dc=example,dc=openidentityplatform,dc=org
objectclass: top
objectclass: person
objectclass: organizationalPerson
objectclass: inetOrgPerson
cn: John Doe
sn: John
uid: jdoe
""";
    InputStream inputStream = new ByteArrayInputStream(data.getBytes(StandardCharsets.UTF_8));
    embeddedOpenDJ.importData(inputStream);
    return embeddedOpenDJ;
}
```

При необходимости, вы можете импортировать данные из любого InputStream, например потока чтения файла.

## Проверка

Для проверки работоспособности можно воспользоваться библиотекой `spring-ldap-core` 

Добавьте в проект зависимости для запуска тестов

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.springframework.ldap</groupId>
    <artifactId>spring-ldap-core</artifactId>
    <scope>test</scope>
</dependency>
```

Добавьте опции совместимости в `maven-surefire-plugin`

```xml
<plugin>
    <artifactId>maven-surefire-plugin</artifactId>
    <configuration>
        <argLine>${jvm.compatibility.args}</argLine>
    </configuration>
</plugin>
```

Простой тест, который будет запускать Spring Boot приложение со встроеным OpenDJ аутентифицироваться и искать импортированную запись

```java
@SpringBootTest
class OpenDJEmbeddedApplicationTest {
    @Test
    public void test() {
        LdapContextSource contextSource = new LdapContextSource();
        contextSource.setUrl("ldap://localhost:1389");
        contextSource.setBase("dc=example,dc=openidentityplatform,dc=org");
        contextSource.setUserDn("cn=Directory Manager");
        contextSource.setPassword("passw0rd");
        contextSource.setPooled(true);
        contextSource.afterPropertiesSet();

        LdapTemplate template = new LdapTemplate(contextSource);
        Object user = template.lookup("uid=jdoe,ou=people");
        assertNotNull(user);
    }
}
```