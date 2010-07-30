require 'test/unit'
require 'java'

$CLASSPATH << 'dist/jmeta-runtime.jar' << 'build'

class TestParsing < Test::Unit::TestCase
  java_import 'jmeta.SyntaxError'
  java_import 'jmeta.BaseParser'
  java_import 'test.MirahParser'

  def parse(text)
    MirahParser.new.parse(text)
  end

  def assert_parse(expected, text)
    assert_equal(expected, MirahParser.print_r(parse(text)))
  end

  def assert_fails(text)
    begin
      fail("Should raise syntax error, but got #{parse text}")
    rescue SyntaxError
      # ok
    end
  end

  def test_fixnum
    assert_parse("[Script, [Fixnum, 0]]", '0')
    assert_parse("[Script, [Fixnum, 100]]", '1_0_0')
    assert_parse("[Script, [Fixnum, 15]]", '0xF')
    assert_parse("[Script, [Fixnum, 15]]", '0Xf')
    assert_parse("[Script, [Fixnum, 15]]", '017')
    assert_parse("[Script, [Fixnum, 15]]", '0o17')
    assert_parse("[Script, [Fixnum, 15]]", '0b1111')
    assert_parse("[Script, [Fixnum, 15]]", '0d15')
    assert_fails "0_"
    assert_fails "0X"
    assert_fails "0b1_"
    assert_fails "0d_1"
  end

  def test_statements
    code = <<EOF
1
  2
        
3  


EOF
    assert_parse("[Script, [Body, [Fixnum, 1], [Fixnum, 2], [Fixnum, 3]]]", code)
    assert_parse("[Script, [Body, [Fixnum, 1], [Fixnum, 2]]]", "1; 2")
    ast = parse(code)
    assert_equal(1, ast[1].children[0].start_position.line)
    assert_equal(1, ast[1].children[0].start_position.col)
    assert_equal(1, ast[1].children[0].end_position.line)
    assert_equal(2, ast[1].children[0].end_position.col)
    assert_equal(2, ast[1].children[1].start_position.line)
    assert_equal(3, ast[1].children[1].start_position.col)
    assert_equal(2, ast[1].children[1].end_position.line)
    assert_equal(4, ast[1].children[1].end_position.col)
    assert_equal(4, ast[1].children[2].start_position.line)
    assert_equal(1, ast[1].children[2].start_position.col)
    assert_equal(4, ast[1].children[2].end_position.line)
    assert_equal(2, ast[1].children[2].end_position.col)
  end

  def test_symbol
    assert_parse("[Script, [Symbol, foo]]", ':foo')
    assert_parse("[Script, [Symbol, bar]]", ':bar')
    assert_parse("[Script, [Symbol, @bar]]", ':@bar')
    assert_parse("[Script, [Symbol, @@cbar]]", ':@@cbar')
    assert_fails(":")
  end

  def test_variable
    assert_parse("[Script, [True]]", 'true')
    assert_parse("[Script, [False]]", 'false')
    assert_parse("[Script, [Nil]]", 'nil')
    assert_parse("[Script, [Self]]", 'self')
    assert_parse("[Script, [InstVar, foo]]", '@foo')
    assert_parse("[Script, [InstVar, bar]]", '@bar')
    assert_parse("[Script, [ClassVar, cfoo]]", '@@cfoo')
    assert_parse("[Script, [ClassVar, cbar]]", '@@cbar')
    assert_parse("[Script, [Identifier, a]]", 'a')
    assert_parse("[Script, [Identifier, b]]", 'b')
    assert_parse("[Script, [Constant, A]]", 'A')
    assert_parse("[Script, [Constant, B]]", 'B')
    assert_parse("[Script, [FCall, B!]]", 'B!')
    assert_parse("[Script, [FCall, def?]]", 'def?')
    assert_fails("BEGIN")
    assert_fails("until")
    assert_fails("def!=")
  end

  def test_float
    assert_parse("[Script, [Float, 0.0]]", "0e1")
    assert_parse("[Script, [Float, 10.0]]", "1e0_1")
    assert_parse("[Script, [Float, 20.0]]", "0_2e0_1")
    assert_parse("[Script, [Float, 22.2]]", "0_2.2_2e0_1")
    assert_fails("3.E0")
    assert_fails("1.")
  end

  def test_strings
    assert_parse("[Script, [Character, 97]]", "?a")
    assert_parse("[Script, [Character, 65]]", "?A")
    assert_parse("[Script, [Character, 63]]", "??")
    assert_parse("[Script, [Character, 8364]]", "?â‚¬")
    assert_parse("[Script, [Character, 119648]]", "?í ´í½ ")
    assert_parse("[Script, [Character, 10]]", "?\\n")
    assert_parse("[Script, [Character, 32]]", "?\\s")
    assert_parse("[Script, [Character, 13]]", "?\\r")
    assert_parse("[Script, [Character, 9]]", "?\\t")
    assert_parse("[Script, [Character, 11]]", "?\\v")
    assert_parse("[Script, [Character, 12]]", "?\\f")
    assert_parse("[Script, [Character, 8]]", "?\\b")
    assert_parse("[Script, [Character, 7]]", "?\\a")
    assert_parse("[Script, [Character, 27]]", "?\\e")
    assert_parse("[Script, [Character, 10]]", "?\\012")
    assert_parse("[Script, [Character, 18]]", "?\\x12")
    assert_parse("[Script, [Character, 8364]]", "?\\u20ac")
    assert_parse("[Script, [Character, 119648]]", "?\\U0001d360")
    assert_parse("[Script, [Character, 91]]", "?\\[")
    assert_fails("?aa")
    assert_parse("[Script, [String, ]]", "''")
    assert_parse("[Script, [String, a]]", "'a'")
    assert_parse("[Script, [String, \\'\\n]]", "'\\\\\\'\\n'")
    assert_fails("'")
    assert_fails("'\\'")
  end

  def test_dquote_strings
    assert_parse("[Script, [String, ]]", '""')
    assert_parse("[Script, [String, a]]", '"a"')
    assert_parse("[Script, [String, \"]]", '"\\""')
    assert_parse(
      "[Script, [DString, [String, a ], [EvString, [InstVar, b]], [String,  c]]]",
      '"a #@b c"')
    assert_parse(
      "[Script, [DString, [String, a ], [EvString, [ClassVar, b]], [String,  c]]]",
      '"a #@@b c"')
    assert_parse(
      "[Script, [DString, [String, a], [EvString, [Identifier, b]], [String, c]]]",
      '"a#{b}c"')
    assert_parse(
      "[Script, [DString, [String, a], [EvString, [String, b]], [String, c]]]",
      '"a#{"b"}c"')
    assert_parse(
      "[Script, [DString, [EvString, null]]]",
      '"#{}"')
    assert_fails('"')
    assert_fails('"\"')
    assert_fails('"#@"')
    assert_fails('"#{"')
  end

  def test_heredocs
    assert_parse("[Script, [String, a\n]]", "<<'A'\na\nA\n")
    assert_parse("[Script, [String, ]]", "<<'A'\nA\n")
    assert_parse("[Script, [String, a\n  A\n]]", "<<'A'\na\n  A\nA\n")
    assert_parse("[Script, [String, a\n]]", "<<-'A'\na\n  A\n")
    assert_parse("[Script, [Body, [String, a\n], [String, b\n], [Fixnum, 1]]]",
                 "<<'A';<<'A'\na\nA\nb\nA\n1")
    assert_parse("[Script, [String, a\n]]", "<<\"A\"\na\nA\n")
    assert_parse("[Script, [String, a\n  A\n]]", "<<A\na\n  A\nA\n")
    assert_parse("[Script, [String, a\n]]", "<<-A\na\n  A\n")
    assert_parse("[Script, [DString]]", "<<A\nA\n")
    assert_parse("[Script, [Body, [String, a\n], [String, b\n], [Fixnum, 1]]]",
                 "<<A;<<A\na\nA\nb\nA\n1")
    assert_parse("[Script, [Body, [DString, [EvString, [String, B\n]], [String, \n]], [String, b\n], [Constant, A]]]",
                 "<<A;<<B\n\#{<<A\nB\nA\n}\nA\nb\nB\nA\n")
    assert_fails("<<FOO")
  end
end

__END__
"foo"
"'foo'"
"int[5]"
"a = 1; a"
"@a = 1; @a"
"[a = 1, 1]"
"1.foo(1)"
"foo(1)"
"if 1; 2; elsif !3; 4; else; 5; end"
"begin; 1; 2; end"
"class Foo < Bar; 1; 2; end"
"def foo; end"
"def foo(a, b); 1; end"
"def foo(a, *c, &d); end"
"def self.foo(a, b); 1; end"
"def self.foo(a:foo, b:bar); 1; end"
"return 1"
"while 1; 2; end"
"until 1; 2; end"
"begin; 2; end until 1"
