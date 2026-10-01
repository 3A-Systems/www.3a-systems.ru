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

# Проверяет собранный сайт в _site (или в каталоге из первого аргумента).
# Запускается после jekyll build через bundle exec: Nokogiri приходит с github-pages.
# Ошибки выводятся в формате аннотаций GitHub Actions.
#
# Статьи (blog/YYYY-MM-DD-*.html), блок «Похожие статьи» из _includes/post-footer.html:
# - в .post-related не больше RELATED_MAX ссылок;
# - среди них нет самой статьи и статей из навигации .post-nav.

require "nokogiri"
require "pathname"

ROOT = Pathname.new(File.expand_path("../..", __dir__))
SITE_DIR = File.expand_path(ARGV[0] || File.join(ROOT, "_site"))
POST_FILE = /\A\d{4}-\d{2}-\d{2}-.+\.html\z/
RELATED_MAX = 5

# /blog/x, /blog/x.html, /blog/x/ и https://www.3a-systems.ru/blog/x — одна и та же статья.
def normalize(href)
  href.sub(%r{\Ahttps?://[^/]+}, "").sub(/[?#].*\z/, "").sub(/\.html\z/, "").chomp("/")
end

def check_post(path)
  errors = []
  doc = Nokogiri::HTML(File.read(path, encoding: "utf-8"))

  nav = doc.at_css(".post-nav")
  # Без навигации проверка соседей ничего не проверяет: скорее всего, переименован класс.
  return errors << "нет блока .post-nav" if nav.nil?

  related = doc.css(".post-related a[href]").map { |a| a["href"] }
  if related.size > RELATED_MAX
    errors << "в .post-related #{related.size} ссылок, допустимо не больше #{RELATED_MAX}"
  end

  self_url = "/blog/#{File.basename(path, '.html')}"
  excluded = { normalize(self_url) => "сама статья" }
  nav.css("a[href]").each { |a| excluded[normalize(a["href"])] ||= "статья из .post-nav" }
  related.each do |href|
    reason = excluded[normalize(href)]
    errors << "в .post-related ссылка на #{href} — #{reason}" if reason
  end

  errors
end

blog_dir = File.join(SITE_DIR, "blog")
posts = Dir.exist?(blog_dir) ? Dir.children(blog_dir).grep(POST_FILE).sort : []
if posts.empty?
  puts "::error::в #{SITE_DIR}/blog нет статей: сайт не собран?"
  exit 1
end

failed = 0
posts.each do |name|
  path = File.join(blog_dir, name)
  errors = check_post(path)
  next if errors.empty?

  failed += 1
  file = Pathname.new(path).relative_path_from(ROOT)
  errors.each { |error| puts "::error::#{file}: #{error}" }
end

if failed.zero?
  puts "Статьи в порядке: #{posts.size}"
else
  puts "Статей с ошибками: #{failed} из #{posts.size}"
  exit 1
end
