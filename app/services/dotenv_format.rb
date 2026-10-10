# Reads and writes the .env file format.
module DotenvFormat
  ParseError = Class.new(StandardError)
  BARE = %r{\A[A-Za-z0-9_@%+=:,./-]*\z}
  LINE = /\A(?:export\s+)?(?<name>[A-Za-z_][A-Za-z0-9_.-]*)\s*=\s*(?<rest>.*)\z/

  # { "NAME" => "value" } as text. Values are quoted only when they need to be,
  # and so that a shell or dotenv reads back exactly what was stored.
  def self.dump(pairs)
    pairs.map { |name, value| "#{name}=#{quote(value)}\n" }.join
  end

  def self.quote(value)
    value = value.to_s

    if value.match?(BARE) then value
    elsif !value.include?("'") && !value.include?("\n") then "'#{value}'"
    else %("#{value.gsub(/[\\"$`]/) { |char| "\\#{char}" }.gsub("\n", '\n')}")
    end
  end

  # Text as { "NAME" => "value" }. Blank lines and comments are skipped.
  def self.parse(text)
    text.to_s.each_line(chomp: true).with_index(1).each_with_object({}) do |(line, number), pairs|
      line = line.strip
      next if line.empty? || line.start_with?("#")

      match = LINE.match(line) or raise ParseError, "line #{number} is not NAME=value"
      pairs[match[:name]] = unquote(match[:rest].strip, number)
    end
  end

  def self.unquote(raw, number)
    case raw[0]
    when "'"
      closing = raw.index("'", 1) or raise ParseError, "line #{number} has an unclosed quote"
      raw[1...closing]
    when '"'
      body = raw[/\A"((?:[^"\\]|\\.)*)"/, 1] or raise ParseError, "line #{number} has an unclosed quote"
      body.gsub(/\\(.)/) { $1 == "n" ? "\n" : $1 }
    else
      raw.sub(/\s+#.*\z/, "")
    end
  end
  private_class_method :unquote
end
