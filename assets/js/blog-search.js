/*
 * The contents of this file are subject to the terms of the Common Development and
 * Distribution License (the License). You may not use this file except in compliance with the
 * License.
 *
 * You can obtain a copy of the License at legal/CDDLv1.0.txt. See the License for the
 * specific language governing permission and limitations under the License.
 *
 * When distributing Covered Software, include this CDDL Header Notice in each file and include
 * the License file at legal/CDDLv1.0.txt. If applicable, add the following below the CDDL
 * Header, with the fields enclosed by brackets [] replaced by your own identifying
 * information: "Portions copyright [year] [name of copyright owner]".
 *
 * Copyright 2026 3A Systems, LLC.
 */

// Поиск по статьям блога. Индекс /search.json собирается Jekyll из _posts и загружается
// при первом вводе. Статья находится, если каждое слово запроса встречается в заголовке,
// описании, ключевых словах, тегах или начале текста; выше — совпадения в заголовке.
// На странице тега (data-tag у поля поиска) ищутся только статьи с этим тегом.
(function () {
    var container = document.getElementById('blog-search');
    var input = document.getElementById('blog-search-input');
    var results = document.getElementById('blog-search-results');
    var posts = document.getElementById('blog-posts');
    if (!container || !input || !results || !posts || !window.fetch) {
        return;
    }
    container.classList.remove('d-none');

    var tag = input.getAttribute('data-tag');
    // Названия продуктов для бейджей берутся из ссылок фильтра /blog/tag/<тег>/
    var productNames = {};
    document.querySelectorAll('.blog-filter a[href^="/blog/tag/"]').forEach(function (link) {
        productNames[link.getAttribute('href').split('/')[3]] = link.textContent.trim();
    });
    var index = null;
    var loading = null;
    var timer = null;

    // «ё» = «е»; «1C», набранное в латинской раскладке, = «1С»: в статьях встречаются оба написания
    function normalize(text) {
        return (text || '').toString().toLowerCase().replace(/ё/g, 'е').replace(/\b1c\b/g, '1с');
    }

    function loadIndex() {
        if (!loading) {
            loading = fetch(input.getAttribute('data-index'))
                .then(function (response) { return response.json(); })
                .then(function (data) {
                    index = data.filter(function (post) {
                        return !tag || (post.tags || []).indexOf(tag) !== -1;
                    }).map(function (post) {
                        var keywords = Array.isArray(post.keywords) ? post.keywords.join(' ') : post.keywords;
                        return {
                            post: post,
                            title: normalize(post.title),
                            meta: normalize([post.description, keywords, (post.tags || []).join(' ')].join(' ')),
                            content: normalize(post.content)
                        };
                    });
                    return index;
                });
        }
        return loading;
    }

    function score(entry, words) {
        var total = 0;
        for (var i = 0; i < words.length; i++) {
            var word = words[i];
            if (entry.title.indexOf(word) !== -1) {
                total += 3;
            } else if (entry.meta.indexOf(word) !== -1) {
                total += 2;
            } else if (entry.content.indexOf(word) !== -1) {
                total += 1;
            } else {
                return 0;
            }
        }
        return total;
    }

    function element(tag, className, text) {
        var node = document.createElement(tag);
        if (className) {
            node.className = className;
        }
        if (text) {
            node.textContent = text;
        }
        return node;
    }

    function render(found) {
        results.textContent = '';
        results.appendChild(element('p', 'text-muted', found.length
            ? 'Найдено статей: ' + found.length
            : 'Ничего не найдено. Попробуйте другие слова.'));
        found.forEach(function (post) {
            var card = element('div', 'card mb-3');
            var body = element('div', 'card-body');
            var heading = element('h4');
            var link = element('a', 'blogpost', post.title);
            link.href = post.url;
            heading.appendChild(link);
            body.appendChild(heading);
            var meta = element('p', 'd-flex flex-wrap align-items-center gap-2');
            meta.appendChild(element('span', 'me-1', post.date));
            (post.tags || []).forEach(function (postTag) {
                if (productNames[postTag]) {
                    var badge = element('a', 'badge text-bg-primary text-decoration-none', productNames[postTag]);
                    badge.href = '/blog/tag/' + postTag + '/';
                    meta.appendChild(badge);
                }
            });
            body.appendChild(meta);
            if (post.description) {
                body.appendChild(element('p', null, post.description));
            }
            card.appendChild(body);
            results.appendChild(card);
        });
    }

    function updateUrl(query) {
        if (!window.history || !window.URL) {
            return;
        }
        var url = new URL(window.location.href);
        if (query) {
            url.searchParams.set('q', query);
        } else {
            url.searchParams.delete('q');
        }
        window.history.replaceState(null, '', url.toString());
    }

    function search() {
        var query = input.value.trim();
        updateUrl(query);
        var words = normalize(query).split(/\s+/).filter(Boolean);
        if (!words.length) {
            results.classList.add('d-none');
            posts.classList.remove('d-none');
            return;
        }
        loadIndex().then(function () {
            if (input.value.trim() !== query) {
                return;
            }
            var found = index
                .map(function (entry, position) {
                    return { post: entry.post, score: score(entry, words), position: position };
                })
                .filter(function (item) { return item.score > 0; })
                .sort(function (a, b) { return b.score - a.score || a.position - b.position; })
                .map(function (item) { return item.post; });
            render(found);
            posts.classList.add('d-none');
            results.classList.remove('d-none');
        }).catch(function () {
            if (input.value.trim() !== query) {
                return;
            }
            results.textContent = '';
            results.appendChild(element('p', 'text-danger', 'Не удалось загрузить поиск. Обновите страницу.'));
            results.classList.remove('d-none');
        });
    }

    input.addEventListener('input', function () {
        clearTimeout(timer);
        timer = setTimeout(search, 200);
    });

    var initial = new URLSearchParams(window.location.search).get('q');
    if (initial) {
        input.value = initial;
        search();
    }
})();
