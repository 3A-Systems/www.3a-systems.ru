# The contents of this file are subject to the terms of the Common Development and
# Distribution License (the License). You may not use this file except in compliance with the
# License.
#
# You can obtain a copy of the License at legal/CDDLv1.0.txt. See the License for the
# specific language governing permission and limitations under the License.
#
# When distributing Covered Software, include this CDDL Header Notice in each file and include
# the License file at legal/CDDLv1.0.txt. If applicable, add the following below the CDDL
# Header, with the fields enclosed by brackets [] replaced by your own identifying
# information: "Portions copyright [year] [name of copyright owner]".
#
# Copyright 2026 3A Systems, LLC.

# Проверяет <head> собранных страниц в _site (или в каталоге из первого аргумента):
# canonical, JSON-LD, ленту RSS и <title>. Запускается через bundle exec: нужен nokogiri из github-pages.
# Ошибки выводятся в формате аннотаций GitHub Actions.

require "date"
require "json"
require "nokogiri"
require "pathname"
require "yaml"

ROOT = Pathname.new(File.expand_path("../..", __dir__))
SITE_DIR = File.expand_path(ARGV[0] || File.join(ROOT, "_site"))
SITE_URL = YAML.safe_load_file(File.join(ROOT, "_config.yml"), permitted_classes: [Date, Time], aliases: true)
               .fetch("url").strip.chomp("/")

# GitHub Pages отдаёт страницу ошибки только по имени 404.html, поэтому её canonical с .html.
HTML_SUFFIX_ALLOWED = %w[404.html].freeze

# Файл в SITE_DIR, который GitHub Pages отдаёт по пути из canonical, или nil.
def resolve(path)
  name = path.delete_prefix("/")
  candidates = name.empty? || name.end_with?("/") ? ["#{name}index.html"] : [name, "#{name}.html", "#{name}/index.html"]
  candidates.find { |candidate| File.file?(File.join(SITE_DIR, candidate)) }
end

def check_canonical(name, doc, errors)
  links = doc.css('link[rel="canonical"]')
  errors << "ожидается один <link rel=\"canonical\">, найдено #{links.size}" unless links.size == 1
  return if links.empty?

  href = links.first["href"].to_s
  return errors << "canonical не на #{SITE_URL}: #{href}" unless href.start_with?("#{SITE_URL}/")

  path = href.delete_prefix(SITE_URL)
  # Сейчас страницы без своего permalink тоже получают URL без .html: так их строит Jekyll
  # при стиле permalink из _config.yml. .html появится, если сменить этот стиль.
  if path.end_with?(".html") && !HTML_SUFFIX_ALLOWED.include?(name)
    errors << "canonical с .html: #{href} (проверьте permalink страницы и в _config.yml)"
  end

  target = resolve(path)
  if target.nil?
    errors << "canonical ведёт на несуществующую страницу: #{href}"
  elsif target != name && doc.at_css('meta[http-equiv="refresh"]').nil?
    # Только страницы-редиректы jekyll-redirect-from указывают canonical на другую страницу.
    errors << "canonical ведёт на другую страницу: #{href} (#{target})"
  end
end

def check_json_ld(doc, errors)
  doc.css('script[type="application/ld+json"]').each.with_index(1) do |script, index|
    data = JSON.parse(script.text)
    unless data.is_a?(Hash) && data.key?("@context") && data.key?("@type")
      errors << "JSON-LD №#{index}: ожидается объект с @context и @type"
    end
  rescue JSON::ParserError
    # Без текста ошибки: он зависит от версии гема json, а Gemfile.lock в репозитории нет.
    errors << "JSON-LD №#{index} не разбирается как JSON"
  end
end

def check(name)
  errors = []
  doc = Nokogiri::HTML(File.read(File.join(SITE_DIR, name), encoding: "utf-8"))

  check_canonical(name, doc, errors)
  check_json_ld(doc, errors)

  feeds = doc.css('link[rel="alternate"][type="application/atom+xml"]').size
  errors << "ссылок на ленту RSS: #{feeds}, ожидается не больше одной" if feeds > 1

  # Только в <head>: у встроенных SVG тоже бывает <title>.
  titles = doc.css("head > title").size
  errors << "ожидается один <title>, найдено #{titles}" unless titles == 1

  errors
end

names = Dir.glob("**/*.html", base: SITE_DIR).sort
abort "::error::нет HTML-страниц в #{SITE_DIR}" if names.empty?

failed = 0
names.each do |name|
  errors = check(name)
  next if errors.empty?

  failed += 1
  file = Pathname.new(File.join(SITE_DIR, name)).relative_path_from(ROOT)
  errors.each { |error| puts "::error file=#{file}::#{error}" }
end

total = names.size
if failed.zero?
  puts "Страницы в порядке: #{total}"
else
  puts "Страниц с ошибками: #{failed} из #{total}"
  exit 1
end
