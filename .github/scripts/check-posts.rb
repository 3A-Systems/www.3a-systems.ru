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

# Проверяет имена файлов и front matter статей в _posts (или в каталоге из первого аргумента).
# Ошибки выводятся в формате аннотаций GitHub Actions.

require "date"
require "pathname"
require "yaml"

ROOT = Pathname.new(File.expand_path("../..", __dir__))
POSTS_DIR = File.expand_path(ARGV[0] || File.join(ROOT, "_posts"))
FILE_NAME = /\A(\d{4}-\d{2}-\d{2})-[a-z0-9]+(?:-[a-z0-9]+)*\.md\z/
ALLOWED_TAGS = %w[openam opendj openig openidm].freeze
REQUIRED_TEXT = %w[title description].freeze

def blank?(value)
  value.nil? || value.to_s.strip.empty?
end

def check(path)
  errors = []
  name = File.basename(path)

  match = FILE_NAME.match(name)
  if match.nil?
    errors << "имя файла должно быть вида YYYY-MM-DD-slug.md (строчные латинские буквы, цифры и дефисы)"
  else
    begin
      Date.iso8601(match[1])
    rescue Date::Error
      errors << "некорректная дата в имени файла: #{match[1]}"
    end
  end

  # Как Jekyll: BOM допускается, front matter закрывается строкой --- или ...
  content = File.read(path, encoding: "bom|utf-8")
  front_matter = content[/\A---\s*\n(.*?)^(?:---|\.\.\.)\s*$/m, 1]
  return errors << "нет front matter" if front_matter.nil?

  begin
    data = YAML.safe_load(front_matter, permitted_classes: [Date, Time], aliases: true) || {}
    raise Psych::Exception, "ожидается набор полей, получено #{data.class}" unless data.is_a?(Hash)
  rescue Psych::Exception => e
    return errors << "front matter не разбирается как YAML: #{e.message}"
  end

  errors << "layout должен быть blog" unless data["layout"] == "blog"
  REQUIRED_TEXT.each { |key| errors << "пустое поле #{key}" if blank?(data[key]) }

  tags = data["tags"]
  if !tags.is_a?(Array) || tags.empty?
    errors << "нужен непустой список tags (#{ALLOWED_TAGS.join(', ')})"
  else
    unknown = tags.map(&:to_s) - ALLOWED_TAGS
    errors << "неизвестные tags: #{unknown.join(', ')} (допустимы #{ALLOWED_TAGS.join(', ')})" unless unknown.empty?
  end

  errors
end

# Как Jekyll: статьи читаются и из подкаталогов, файлы и каталоги на точку пропускаются.
names = Dir.glob("**/*", base: POSTS_DIR).select { |name| File.file?(File.join(POSTS_DIR, name)) }.sort
failed = 0
names.each do |name|
  path = File.join(POSTS_DIR, name)
  errors = check(path)
  next if errors.empty?

  failed += 1
  file = Pathname.new(path).relative_path_from(ROOT)
  errors.each { |error| puts "::error file=#{file}::#{error}" }
end

total = names.size
if failed.zero?
  puts "Статьи в порядке: #{total}"
else
  puts "Статей с ошибками: #{failed} из #{total}"
  exit 1
end
