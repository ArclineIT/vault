require "test_helper"

class DotenvFormatTest < ActiveSupport::TestCase
  test "writes values bare, single-quoted or double-quoted as needed" do
    text = DotenvFormat.dump("PLAIN" => "abc123", "URL" => "https://example.com/a?b=1", "SPACES" => "two words", "DOLLAR" => "pa$$word",
                             "QUOTE" => "it's", "MULTI" => "line1\nline2", "EMPTY" => "")

    assert_equal <<~ENV, text
      PLAIN=abc123
      URL='https://example.com/a?b=1'
      SPACES='two words'
      DOLLAR='pa$$word'
      QUOTE="it's"
      MULTI="line1\\nline2"
      EMPTY=
    ENV
  end

  test "whatever is written reads back exactly" do
    values = { "A" => "plain", "B" => "two words", "C" => "it's \"quoted\" $HOME `cmd` \\ back\nnext", "D" => "", "E" => " padded ", "F" => "#not-a-comment", "G" => "a=b=c" }

    assert_equal values, DotenvFormat.parse(DotenvFormat.dump(values))
  end

  test "reads hand-written files" do
    parsed = DotenvFormat.parse(<<~ENV)
      # database
      DATABASE_URL=postgres://u:p@host/db

      export API_KEY = "abc\\ndef"
      SINGLE='raw $HOME \\n'
      INLINE=value # trailing comment
      HASH=abc#def
      my.dotted-name=1
    ENV

    assert_equal({ "DATABASE_URL" => "postgres://u:p@host/db", "API_KEY" => "abc\ndef", "SINGLE" => 'raw $HOME \n', "INLINE" => "value",
                   "HASH" => "abc#def", "my.dotted-name" => "1" }, parsed)
  end

  test "reports the line that cannot be read" do
    assert_equal "line 2 is not NAME=value", assert_raises(DotenvFormat::ParseError) { DotenvFormat.parse("A=1\njust some words\n") }.message
    assert_equal "line 1 has an unclosed quote", assert_raises(DotenvFormat::ParseError) { DotenvFormat.parse(%(A="oops\n)) }.message
    assert_raises(DotenvFormat::ParseError) { DotenvFormat.parse("1BAD=x") }
    assert_equal({}, DotenvFormat.parse(nil))
  end
end
