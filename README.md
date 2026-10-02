# www.3a-systems.ru

Исходный код сайта [https://www.3a-systems.ru/](https://www.3a-systems.ru/) — ООО «ТриА Системз»: продукты Open Identity Platform (OpenDJ, OpenAM, OpenIG, OpenIDM), услуги, прайс-лист и блог.

Сайт собирается [Jekyll](https://jekyllrb.com/) и публикуется через GitHub Pages из ветки `master`: после мержа в `master` сайт обновляется автоматически. На каждый pull request и push в `master` [GitHub Actions](.github/workflows/build.yml) собирает сайт и проверяет статьи, `<head>` страниц (canonical, JSON-LD) и ссылки.

## Локальный запуск

Нужен Ruby той же версии, что у GitHub Pages ([pages.github.com/versions.json](https://pages.github.com/versions.json)), сейчас 3.3.

```bash
bundle install
bundle exec jekyll serve
```

Сайт откроется на <http://localhost:4000>. При изменении файлов сайт пересобирается автоматически.

Без локального Ruby можно запустить в Docker:

```bash
docker run --rm -it -p 4000:4000 -v "$PWD":/site -w /site ruby:3.3.4 \
  bash -c 'bundle install && bundle exec jekyll serve --host 0.0.0.0'
```

Перед pull request полезно прогнать те же проверки, что и в CI:

```bash
ruby .github/scripts/check-posts.rb
ruby .github/scripts/check-posts.rb .github/scripts/test-posts | diff -u .github/scripts/test-posts.expected -
bundle exec jekyll build
bundle exec ruby .github/scripts/check-head.rb
LC_ALL=C bundle exec ruby .github/scripts/check-head.rb .github/scripts/test-head | diff -u .github/scripts/test-head.expected -
gem install html-proofer -v '~> 5.0'
htmlproofer _site --disable-external --no-enforce-https --allow-missing-href \
  --swap-urls '^https\://www\.3a-systems\.ru:'
```

## Структура

| Путь | Что там |
|---|---|
| `_config.yml` | Настройки сайта: название, описание, URL, плагины |
| `_layouts/` | Шаблоны страниц: `main` — общий, `blog` — статья |
| `_includes/` | Фрагменты: `head.html`, `product.html` (страница продукта), `partners-carousel.html`, текст EULA |
| `_data/products.yml` | Продукты для главной и меню |
| `_data/about.yml` | Пункты блока «О компании» |
| `_data/experience.yml` | Клиенты для страницы «Опыт» и карусели логотипов |
| `_posts/` | Статьи блога |
| `_sass/`, `assets/` | Стили, скрипты, изображения |
| `openam.md`, `opendj.md`, `openig.md`, `openidm.md` | Страницы продуктов (данные во front matter, разметка в `_includes/product.html`) |
| `openam/`, `opendj/`, `openig/`, `openidm/` | Лицензионные соглашения PRO-редакций |
| `fips/` | Документы о государственной регистрации программ для ЭВМ |
| `blog/index.html` | Список статей с пагинацией |

## Как добавить статью

1. Создайте файл `_posts/YYYY-MM-DD-slug.md`:
   - дата — дата публикации, она же попадает в URL;
   - `slug` — только строчные латинские буквы, цифры и дефисы;
   - одно расширение `.md` (не `.md.md`).

   Статья будет доступна по адресу `/blog/YYYY-MM-DD-slug`.

2. Заполните front matter:

   ```yaml
   ---
   layout: blog
   title: 'Заголовок статьи'
   description: 'Одно-два предложения о статье: показываются в списке статей и в поисковой выдаче.'
   keywords: 'OpenAM, SSO, ключевые слова через запятую'
   tags:
     - openam
   ---
   ```

   | Поле | Обязательно | Описание |
   |---|---|---|
   | `layout` | да | Всегда `blog` |
   | `title` | да | Заголовок статьи |
   | `description` | да | Анонс для списка статей и мета-тега `description` |
   | `tags` | да | Продукты, к которым относится статья: `openam`, `opendj`, `openig`, `openidm`. По ним статья попадает в блок «О продукте» на странице продукта |
   | `keywords` | желательно | Ключевые слова для мета-тега `keywords` |

   Обязательные поля и имя файла проверяет `.github/scripts/check-posts.rb`, в том числе в CI. Если меняете правила проверки, добавьте пример в `.github/scripts/test-posts/` и обновите ожидаемый вывод в `.github/scripts/test-posts.expected`.

3. Изображения к статьям кладутся в wiki соответствующего репозитория [OpenIdentityPlatform](https://github.com/OpenIdentityPlatform) и подключаются по ссылке `https://raw.githubusercontent.com/wiki/...`.

4. Ссылки на внешние сайты указывайте полностью, с `https://`: ссылка вида `github.com/...` без схемы считается относительной и ведёт на несуществующую страницу сайта.

## Как добавить клиента в «Опыт»

Добавьте запись в `_data/experience.yml` и положите логотип в `assets/img/partners/`:

```yaml
- name: 'Название компании'
  link: 'https://example.ru/'
  logo: '/assets/img/partners/example.svg'
  category: 'отрасль или вид деятельности'
```

Клиент появится на странице «Опыт» и в карусели логотипов внизу страниц.

## Лицензия

Контент сайта © ООО «ТриА Системз». Продукты Open Identity Platform распространяются под лицензией [CDDL](https://github.com/OpenIdentityPlatform/OpenAM/blob/master/LICENSE.md).

Скрипты и настройки CI в `.github/` распространяются под лицензией CDDL v1.0, текст — [`legal/CDDLv1.0.txt`](legal/CDDLv1.0.txt).
