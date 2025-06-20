---
layout: blog
title: Использование больших языковых моделей (LLM) в Access Management
description: 'В статье мы разберемся, как можно применить LLM к управлению доступом для повышения эффективности и стоит ли.'
keywords: 'Искусственный интеллект,Большие языковые модели,Управление доступом,Кибербезопасность,Аутентификация,Авторизация,Мониторинг систем,Аудит доступа,Галлюцинации ИИ,Машинное обучение'
---

## Введение

Хайп вокруг нейросетей, особенно больших языковых моделей (LLM), пока не утихает.

Как в свое время было с хайпом на блокчейн многие техноэнтузиасты начинают применять  подход “решение в поисках проблемы”. То есть, искать применение нейросетей ко всем задачам подряд.  

Это объясняется двумя причинами:

- Повысить шансы привлечение инвестиций, добавив суффикс AI к названию своего проекта.
- Экспериментировать с новыми технологиями всегда интересно.

[Access Management](https://en.wikipedia.org/wiki/Access_management) (управление доступом) не исключение. Растущее количество атак и их разнообразие требуют искать новые подходы к управлению доступом для повышения его эффективности и устойчивости к атакам. 

В данной статье мы разберемся, как можно применить LLM к управлению доступом для повышения эффективности и стоит ли.

При подготовке этой статьи мне не удалось найти реальные практически примеры использования и LLM в Access Management в более-менее известных компаниях. Возможно, это объясняется тем, что большие модели - технология относительно новая и их внедрение сопряжено с определенными рисками. Либо, измеримые результаты еще не были достигнуты и поэтому их нет в публичном доступе.  Поэтому статья носит, скорее, аналитический характер. 

## Исходные данные

Сначала определим задачи, стоящие перед системами управления доступом, потом выделим основные свойства LLM, и, возможно, найдем пересечение.

Спойлер (так оно есть, иначе этой статьи не было бы).

Ключевые задачи Access Management:

- Аутентификация и авторизация
- Мониторинг
- Аудит

Свойства LLM

- Способность анализировать большие объемы данных и высокий уровень экспертности
- Высокое потребление вычислительных ресурсов
- Риск генерации некорректных ответов (”галлюцинации”)

## Применение LLM к задачам Access Management

### Аутентификация и авторизация

Система управления доступом должна определить, кто именно входит в систему (аутентификация) и стоит ли предоставлять доступ к тому или иному ресурсу (авторизация). Для повышения безопасности система аутентификации может запросить дополнительный фактор, например, биометрические данные или одноразовый пароль. 

Давайте разберемся, возможно ли применить LLM к аутентификации и авторизации.

- Способность анализировать большие объемы данных - применимо с ограничениями. В процессе авторизации и аутентификации собранный объем данных относительно небольшой. Например, это могут быть данные самого пользователя при условии успешной аутентификации, время с последней успешной аутентификации, время с последней неуспешной аутентификации, использует ли пользователь VPN, и т.д. Наберется, в лучшем случае, около 100 признаков. LLM способна обработать на порядки больше признаков, поэтому, в данном случае, ее использование является избыточным.
- Высокое потребление вычислительных ресурсов - не применимо. В больших организациях количество запросов в систему аутентификации и авторизации исчисляется тысячами в час. При использовании LLM потребление вычислительных ресурсов возрастет в разы. Проще говоря, LLM может не справиться с нагрузкой и вся система управления доступом перестанет работать.
- Галлюцинации - если же все таки компания приняла, упомянутые выше, выделила вычислительные ресурсы на LLM и подключила ее к процессу аутентификации, всегда существует риск получения от LLM некорректного ответа. Таким образом, пользователю, имеющему право доступа, может быть отказано, а злоумышленник, наоборот, сможет получить доступ.

**Вывод**: стандартные методики авторизации доступа на основе ролей или атрибутов (RBAC или ABAP) более прозрачны для последующего аудита. Выяснить, почему нейросеть приняла то или иное решение по предоставлению доступа практически невозможно из-за большого количества промежуточных вычислений. Аналогично, при аутентификации: алгоритм вычисления критерия запроса от пользователя второго фактора или, наоборот, бесшовной аутентификации (когда пользователя сразу пускает в систему без запроса учетных данных) должен быть прозрачным для аудита. Этого можно достичь напрямую, используя атрибуты аутентификации (например, новое устройство пользователя) или использовать совокупность атрибутов для анализа более простыми алгоритмами машинного обучения - например, линейными алгоритмами или деревьями решений.

### Мониторинг

При мониторинге системы управления доступом, как и любой другой системы, критичным является выявление аномалий. Например, появление большого количества ошибок в логах, частая генерация и отправка одноразовых паролей или аномально большое количество запросов к системе хранения данных пользователей или клиентов.

- Способность анализировать большие объемы данных - применимо. В процессе мониторинга непрерывно генерируются большие объемы данных. LLM может их получать и анализировать на предмет аномальных событий.
- Высокое потребление вычислительных ресурсов - применимо с ограничениями. LLM не сможет анализировать события в режиме реального времени, поэтому выявление аномалий будет выполнятся, скорее постфактум.
- Галлюцинации - при анализе возможны некорректные ответы, поэтому потенциально все аномальные события должен анализировать инженер по безопасности. Также есть риск пропуска аномальных событий.

**Вывод:** анализ событий системы управления доступом на предмет аномалий при помощи больших моделей, возможен, но не в реальном времени. Оптимальным решением будет использование совокупности методов. В реальном времени события могут анализировать просты алгоритмы машинного обучения, а подозрительные события отправляться в LLM и специалисту по безопасности для последующего анализа.

### Аудит

Система управления доступом должна проходить периодический аудит. Задача аудита - выявлять потенциально проблемные места в конфигурации аутентификации, политиках доступа и даже самого аудита. Например, в процессе аудита могут быть выявлены политики, которые не используются пользователями или политики с избыточным доступом. Еще одна задача аудита - анализ системы управления доступом на соответствие стандартам регуляторов.

- Способность анализировать большие объемы данных - применимо. LLM может выступать как эксперт по безопасности и проводить аудит конфигурации системы управления доступом, выявлять возможные проблемные места и предлагать решения для их устранения. Это может существенно облегчить работу аналитиков безопасности.
- Высокое потребление вычислительных ресурсов - влияние не существенное, так как аудит проводится относительно редко, а время ответа от LLM не существенно.
- Галлюцинации - результат аудита обязательно проходит через аналитиков по безопасности, что снижает риски некорректной конфигурации.

**Вывод**: LLM довольно неплохо подходят для выполнения периодических задач аудита, т.к. могут легко проанализировать большие объемы данных, выявить закономерности, степень соответствия стандартам и проблемные места гораздо эффективнее человека. Аудит может проводиться быстрее по времени и с гораздо больше частотой. 

Для уменьшения риска возникновения ошибок, результат аудита должен быть проверен специалистом.

Дополнительно для уменьшения ошибок можно внедрить дообучение модели, а так же использовать [Retrieval Augmented Generation](https://en.wikipedia.org/wiki/Retrieval-augmented_generation) для извлечения информации из, например, актуальных стандартов безопасности.

## Вместо вывода

Алгоритмы машинного обучения, включая LLM, могут повысить безопасность систем управления доступом, но требуют разумного подхода. Для аутентификации и мониторинга лучше использовать легковесные алгоритмы, а LLM применять для аудита и аналитики. В будущем, с развитием оптимизированных моделей, их использование станет более доступным. А что думаете вы?

- Могут ли LLM стать стандартом в кибербезопасности? Или их применение пока слишком дорого и рискованно?
- Используете ли вы ИИ в системах управления доступом? Какие инструменты оказались наиболее эффективными?
- Какие задачи в кибербезопасности, на ваш взгляд, лучше доверить LLM, а какие — традиционным методам?
- Поделитесь своим опытом, идеями или вопросами в комментариях. Давайте вместе разберем, как сделать управление доступом безопаснее и эффективнее с помощью ИИ.