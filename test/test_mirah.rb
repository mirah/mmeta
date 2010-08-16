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
    assert_parse("[Script, null]", "# foo")
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
    assert_parse("[Script, [Float, 1.0]]", "1.0")
    assert_parse("[Script, [Float, 0.0]]", "0e1")
    assert_parse("[Script, [Float, 10.0]]", "1e0_1")
    assert_parse("[Script, [Float, 20.0]]", "0_2e0_1")
    assert_parse("[Script, [Float, 22.2]]", "0_2.2_2e0_1")
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
    assert_parse("[Script, [String, ]]", "<<A\nA\n")
    assert_parse("[Script, [Body, [String, a\n], [String, b\n], [Fixnum, 1]]]",
                 "<<A;<<A\na\nA\nb\nA\n1")
    assert_parse("[Script, [Body, [DString, [EvString, [String, B\n]], [String, \n]], [String, b\n], [Constant, A]]]",
                 "<<A;<<B\n\#{<<A\nB\nA\n}\nA\nb\nB\nA\n")
    assert_fails("<<FOO")
  end

  def test_regexp
    assert_parse("[Script, [Regex, [[String, a]], ]]", '/a/')
    assert_parse("[Script, [Regex, [[String, \\/]], ]]", '/\\//')
    assert_parse("[Script, [Regex, [[String, a]], i]]", '/a/i')
    assert_parse("[Script, [Regex, [[String, a]], iz]]", '/a/iz')
    assert_parse("[Script, [Regex, [[String, a], [EvString, [Identifier, b]], [String, c]], iz]]", '/a#{b}c/iz')
    assert_parse("[Script, [Regex, [], ]]", '//')
  end

  def test_begin
    assert_parse("[Script, [Begin, [Body, [Fixnum, 1], [Fixnum, 2]]]]", "begin; 1; 2; end")
    assert_parse("[Script, [Begin, [Fixnum, 1]]]", "begin; 1; end")
    assert_parse("[Script, [Begin, [Rescue, [Fixnum, 1], [[RescueClause, [], null, [Fixnum, 2]]], null]]]",
                 "begin; 1; rescue; 2; end")
    assert_parse("[Script, [Begin, [Ensure, [Rescue, [Fixnum, 1], [[RescueClause, [], null, [Fixnum, 2]]], null], [Fixnum, 3]]]]",
                 "begin; 1; rescue; 2; ensure 3; end")
    assert_parse("[Script, [Begin, [Rescue, [Fixnum, 1], [[RescueClause, [], null, [Fixnum, 2]]], null]]]",
                 "begin; 1; rescue then 2; end")
    assert_parse("[Script, [Begin, [Rescue, [Fixnum, 1], [[RescueClause, [], null, [Fixnum, 2]]], [Fixnum, 3]]]]",
                 "begin; 1; rescue then 2; else 3; end")
    assert_parse("[Script, [Begin, [Rescue, [Fixnum, 1], [[RescueClause, [], null, [Fixnum, 2]]], null]]]",
                 "begin; 1; rescue;then 2; end")
    assert_parse("[Script, [Begin, [Rescue, [Fixnum, 1], [[RescueClause, [], ex, [Fixnum, 2]]], null]]]",
                 "begin; 1; rescue => ex; 2; end")
    assert_parse("[Script, [Begin, [Rescue, [Fixnum, 1], [[RescueClause, [], ex, [Fixnum, 2]]], null]]]",
                 "begin; 1; rescue => ex then 2; end")
    assert_parse("[Script, [Begin, [Rescue, [Fixnum, 1], [[RescueClause, [A], null, [Fixnum, 2]]], null]]]",
                 "begin; 1; rescue A; 2; end")
    assert_parse("[Script, [Begin, [Rescue, [Fixnum, 1], [[RescueClause, [A, B], null, [Fixnum, 2]]], null]]]",
                 "begin; 1; rescue A, B; 2; end")
    assert_parse("[Script, [Begin, [Rescue, [Fixnum, 1], [[RescueClause, [A, B], t, [Fixnum, 2]]], null]]]",
                 "begin; 1; rescue A, B => t; 2; end")
    assert_parse("[Script, [Begin, [Rescue, [Fixnum, 1], [[RescueClause, [A], a, [Fixnum, 2]], [RescueClause, [B], b, [Fixnum, 3]]], null]]]",
                 "begin; 1; rescue A => a;2; rescue B => b; 3; end")
    assert_parse("[Script, [Begin, [Body, [Fixnum, 1], [Fixnum, 2]]]]", "begin; 1; else; 2; end")
  end

  def test_primary
    assert_parse("[Script, [True]]", '(true)')
    assert_parse("[Script, [Body, [Fixnum, 1], [Fixnum, 2], [Fixnum, 3]]]", "(1; 2);3")
    assert_parse("[Script, [Colon2Const, [Colon2Const, [Constant, A], B], C]]", 'A::B::C')
    assert_parse("[Script, [Colon2Const, [Colon2Const, [Colon3, A], B], C]]", '::A::B::C')
    assert_parse("[Script, [ZArray]]", ' [ ]')
    assert_parse("[Script, [Array, [Fixnum, 1], [Fixnum, 2]]]", ' [ 1 , 2 ]')
    assert_parse("[Script, [Array, [Fixnum, 1], [Fixnum, 2]]]", ' [ 1 , 2 , ]')
    assert_parse("[Script, [Hash]]", ' { }')
    assert_parse("[Script, [Hash, [Assoc, [Fixnum, 1], [Fixnum, 2]]]]", ' { 1 => 2 }')
    assert_parse("[Script, [Hash, [Assoc, [Fixnum, 1], [Fixnum, 2]], [Assoc, [Fixnum, 3], [Fixnum, 4]]]]", ' { 1 => 2 , 3 => 4 }')
    assert_parse("[Script, [Hash, [Assoc, [Symbol, 1], [Fixnum, 2]]]]", ' { 1: 2 }')
    assert_parse("[Script, [Hash, [Assoc, [Symbol, 1], [Fixnum, 2]], [Assoc, [Symbol, 3], [Fixnum, 4]]]]", ' { 1: 2 , 3: 4 }')
    assert_parse("[Script, [Yield]]", 'yield')
    assert_parse("[Script, [Yield]]", 'yield ( )')
    assert_parse("[Script, [Yield, [Constant, A]]]", 'yield(A)')
    assert_parse("[Script, [Yield, [Constant, A], [Constant, B]]]", 'yield (A , B)')
    assert_parse("[Script, [Yield, [Array, [Constant, A], [Constant, B]]]]", 'yield([A , B])')
    assert_parse("[Script, [Next]]", 'next')
    assert_parse("[Script, [Redo]]", 'redo')
    assert_parse("[Script, [Break]]", 'break')
    assert_parse("[Script, [Retry]]", 'retry')
    assert_parse("[Script, [Call, !, [Nil]]]", '!()')
    assert_parse("[Script, [Call, !, [True]]]", '!(true)')
    assert_parse("[Script, [SClass, [Self], [Fixnum, 1]]]", 'class << self;1;end')
    assert_parse("[Script, [Class, [Constant, A], [Fixnum, 1], null]]", 'class A;1;end')
    assert_parse("[Script, [Class, [Colon2, [Constant, A], [Constant, B]], [Fixnum, 1], null]]", 'class A::B;1;end')
    assert_parse("[Script, [Class, [Constant, A], [Fixnum, 1], [Constant, B]]]", 'class A < B;1;end')
    assert_parse("[Script, [FCall, foo, [], [Iter, null, [Identifier, x]]]]", "foo do;x;end")
    assert_parse("[Script, [FCall, foo, [], [Iter, null, [Identifier, y]]]]", "foo {y}")
    assert_parse("[Script, [FCall, foo?, [], [Iter, null, [Identifier, z]]]]", "foo? {z}")
    assert_fails('class a;1;end')
  end

  def test_if
    assert_parse("[Script, [If, [Identifier, a], [Fixnum, 1], null]]", 'if a then 1 end')
    assert_parse("[Script, [If, [Identifier, a], [Fixnum, 1], null]]", 'if a;1;end')
    assert_parse("[Script, [If, [Identifier, a], null, null]]", 'if a;else;end')
    assert_parse("[Script, [If, [Identifier, a], [Fixnum, 1], [Fixnum, 2]]]", 'if a then 1 else 2 end')
    assert_parse("[Script, [If, [Identifier, a], [Fixnum, 1], [If, [Identifier, b], [Fixnum, 2], [Fixnum, 3]]]]",
                 'if a; 1; elsif b; 2; else; 3; end')
    assert_parse("[Script, [If, [Identifier, a], null, [Fixnum, 1]]]", 'unless a then 1 end')
    assert_parse("[Script, [If, [Identifier, a], null, [Fixnum, 1]]]", 'unless a;1;end')
    assert_parse("[Script, [If, [Identifier, a], [Fixnum, 2], [Fixnum, 1]]]", 'unless a then 1 else 2 end')
    assert_fails("if;end")
    assert_fails("if a then 1 else 2 elsif b then 3 end")
    assert_fails("if a;elsif end")
  end

  def test_loop
    assert_parse("[Script, [While, [True], [Nil]]]", 'while true do end')
    assert_parse("[Script, [While, [Identifier, a], [Identifier, b]]]", 'while a do b end')
    assert_parse("[Script, [While, [Identifier, a], [Identifier, b]]]", 'while a; b; end')
    assert_parse("[Script, [Until, [True], [Nil]]]", 'until true do end')
    assert_parse("[Script, [Until, [Identifier, a], [Identifier, b]]]", 'until a do b end')
    assert_parse("[Script, [Until, [Identifier, a], [Identifier, b]]]", 'until a; b; end')
    assert_parse("[Script, [For, [Identifier, a], [Fixnum, 2], [Array, [Fixnum, 1]]]]", 'for a in [1];2;end')
  end

  def test_def
    names = %w(foo bar? baz! def= rescue Class & | ^ < > + - * / % ! ~ <=> ==
               === =~ !~ <= >= << <<< >> != ** []= [] +@ -@)
    names.each do |name|
      assert_parse("[Script, [Def, #{name}, [Arguments, null, null, null, null, null], [Fixnum, 1]]]",
                   "def #{name}; 1; end")
      assert_parse("[Script, [DefStatic, #{name}, [Arguments, null, null, null, null, null], [Fixnum, 1]]]",
                   "def self.#{name}; 1; end")
    end
    assert_parse("[Script, [Def, foo, [Arguments, [[RequiredArgument, a, null]], null, null, null, null], [Fixnum, 1]]]",
                 "def foo(a); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, [[RequiredArgument, a, null]], null, null, null, null], [Fixnum, 1]]]",
                 "def foo a; 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, [[RequiredArgument, a, [Constant, String]]], null, null, null, null], [Fixnum, 1]]]",
                 "def foo(a:String); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, [[RequiredArgument, a, null], [RequiredArgument, b, null]], null, null, null, null], [Fixnum, 1]]]",
                 "def foo(a, b); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, null, [[OptArg, a, null, [Fixnum, 1]]], null, null, null], [Fixnum, 1]]]",
                 "def foo(a = 1); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, null, [[OptArg, a, [Identifier, int], [Fixnum, 1]]], null, null, null], [Fixnum, 1]]]",
                 "def foo(a:int = 1); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, null, [[OptArg, a, null, [Fixnum, 1]], [OptArg, b, null, [Fixnum, 2]]], null, null, null], [Fixnum, 1]]]",
                 "def foo(a = 1, b=2); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, null, null, [UnnamedRestArg], null, null], [Fixnum, 1]]]",
                 "def foo(*); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, null, null, [RestArg, a, null], null, null], [Fixnum, 1]]]",
                 "def foo(*a); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, null, null, [RestArg, a, [Constant, Object]], null, null], [Fixnum, 1]]]",
                 "def foo(*a:Object); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, null, null, null, null, [BlockArg, a, null]], [Fixnum, 1]]]",
                 "def foo(&a); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, null, null, null, null, [OptBlockArg, a, null]], [Fixnum, 1]]]",
                 "def foo(&a = nil); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, [[RequiredArgument, a, null]], [[OptArg, b, null, [Fixnum, 1]]], [RestArg, c, null], [[RequiredArgument, d, null]], [BlockArg, e, null]], [Fixnum, 1]]]",
                 "def foo(a, b=1, *c, d, &e); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, [[RequiredArgument, a, null]], null, [RestArg, c, null], [[RequiredArgument, d, null]], [BlockArg, e, null]], [Fixnum, 1]]]",
                 "def foo(a, *c, d, &e); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, [[RequiredArgument, a, null]], [[OptArg, b, null, [Fixnum, 1]]], null, [[RequiredArgument, d, null]], [BlockArg, e, null]], [Fixnum, 1]]]",
                 "def foo(a, b=1, d, &e); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, [[RequiredArgument, a, null]], [[OptArg, b, null, [Fixnum, 1]]], [RestArg, c, null], null, [BlockArg, e, null]], [Fixnum, 1]]]",
                 "def foo(a, b=1, *c, &e); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, null, [[OptArg, b, null, [Fixnum, 1]]], [RestArg, c, null], [[RequiredArgument, d, null]], [BlockArg, e, null]], [Fixnum, 1]]]",
                 "def foo(b=1, *c, d, &e); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, null, [[OptArg, b, null, [Fixnum, 1]]], null, [[RequiredArgument, d, null]], [BlockArg, e, null]], [Fixnum, 1]]]",
                 "def foo(b=1, d, &e); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, null, [[OptArg, b, null, [Fixnum, 1]]], [RestArg, c, null], null, [BlockArg, e, null]], [Fixnum, 1]]]",
                 "def foo(b=1, *c, &e); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, null, null, [RestArg, c, null], [[RequiredArgument, d, null]], [BlockArg, e, null]], [Fixnum, 1]]]",
                 "def foo(*c, d, &e); 1; end")
    assert_parse("[Script, [Def, foo, [Arguments, null, null, [RestArg, c, null], null, [BlockArg, e, null]], [Fixnum, 1]]]",
                 "def foo(*c, &e); 1; end")
    assert_fails("def foo(*a, *b);end")
    assert_fails("def foo(&a, &b);end")
    assert_fails("def foo(&a=1);end")
  end

  def test_method_call
    assert_parse("[Script, [FCall, B, [], null]]", 'B()')
    assert_parse("[Script, [FCall, foo, [[Identifier, a]], null]]", 'foo(a)')
    assert_parse("[Script, [FCall, foo, [[Identifier, a], [Identifier, b]], null]]", 'foo(a, b)')
    assert_parse("[Script, [FCall, foo, [[Identifier, a], [Splat, [Identifier, b]]], null]]", 'foo(a, *b)')
    assert_parse("[Script, [FCall, foo, [[Identifier, a], [Splat, [Identifier, b]], [Hash, [Assoc, [Symbol, c], [Identifier, d]]]], null]]", 'foo(a, *b, c:d)')
    assert_parse("[Script, [FCall, foo, [[Identifier, a], [Splat, [Identifier, b]], [Hash, [Assoc, [Symbol, c], [Identifier, d]]]], null]]", 'foo(a, *b, :c => d)')
    assert_parse("[Script, [FCall, foo, [[Identifier, a], [Splat, [Identifier, b]], [Hash, [Assoc, [Symbol, c], [Identifier, d]]], [BlockPass, [Identifier, e]]], null]]", 'foo(a, *b, c:d, &e)')
    assert_parse("[Script, [FCall, foo, [[Hash, [Assoc, [Symbol, c], [Identifier, d]]]], null]]", 'foo(c:d)')
    assert_parse("[Script, [FCall, foo, [[Hash, [Assoc, [Symbol, c], [Identifier, d]]], [BlockPass, [Identifier, e]]], null]]", 'foo(c:d, &e)')
    assert_parse("[Script, [FCall, foo, [[BlockPass, [Identifier, e]]], null]]", 'foo(&e)')
    assert_parse("[Script, [Call, foo, [Identifier, a], null, null]]", 'a.foo')
    assert_parse("[Script, [Call, foo, [Identifier, a], [], null]]", 'a.foo()')
    assert_parse("[Script, [Call, Foo, [Identifier, a], [], null]]", 'a.Foo()')
    assert_parse("[Script, [Call, <=>, [Identifier, a], null, null]]", 'a.<=>')
    assert_parse("[Script, [Call, Bar, [Constant, Foo], [[Identifier, x]], null]]", 'Foo::Bar(x)')
    assert_parse("[Script, [Call, call, [Identifier, a], [], null]]", 'a.()')
    assert_parse("[Script, [Call, in, [Constant, System], null, null]]", "System.in")
    assert_parse("[Script, [Super, [], null]]", 'super()')
    assert_parse("[Script, [ZSuper]]", 'super')
  end

  def test_command
    assert_parse("[Script, [FCall, A, [[Identifier, b]], null]]", 'A b')
    assert_parse("[Script, [Call, Bar, [Constant, Foo], [[Identifier, x]], null]]", 'Foo::Bar x')
    assert_parse("[Script, [Call, bar, [Identifier, foo], [[Identifier, x]], null]]", 'foo.bar x')
    assert_parse("[Script, [Super, [[Identifier, x]]]]", 'super x')
    assert_parse("[Script, [Yield, [[Identifier, x]]]]", 'yield x')
    assert_parse("[Script, [Return, [Identifier, x]]]", 'return x')
    assert_parse("[Script, [FCall, a, [[Character, 97]], null]]", 'a ?a')
  end

  def test_lhs
    assert_parse("[Script, [LocalAssign, a, [Identifier, b]]]", "a = b")
    assert_parse("[Script, [ConstAssign, A, [Identifier, b]]]", "A = b")
    assert_parse("[Script, [InstVarAssign, a, [Identifier, b]]]", "@a = b")
    assert_parse("[Script, [ClassVarAssign, a, [Identifier, b]]]", "@@a = b")
    assert_parse("[Script, [AttrAssign, []=, [Identifier, a], [[Fixnum, 0]], [Identifier, b]]]", "a[0] = b")
    assert_parse("[Script, [AttrAssign, foo=, [Identifier, a], [], [Identifier, b]]]", "a.foo = b")
    assert_parse("[Script, [AttrAssign, foo=, [Identifier, a], [], [Identifier, b]]]", "a::foo = b")
    assert_parse("[Script, [ConstAssign, [Colon2Const, [Identifier, a], Foo], [Identifier, b]]]", "a::Foo = b")
    assert_parse("[Script, [ConstAssign, [Colon3, Foo], [Identifier, b]]]", "::Foo = b")
  end

  def test_arg
    assert_parse("[Script, [LocalAssign, a, [Rescue, [Identifier, b], [[RescueClause, [], null, [Identifier, c]]], null]]]",
                 "a = b rescue c")
    assert_parse("[Script, [If, [Local, a], [LocalAssign, a, [Identifier, b]], null]]",
                 "a &&= b")
    assert_parse("[Script, [If, [Local, a], null, [LocalAssign, a, [Identifier, b]]]]",
                 "a ||= b")
    assert_parse("[Script, [InstVarAssign, a, [Call, +, [InstVar, a], [[Fixnum, 1]]]]]",
                 "@a += 1")
    assert_parse("[Script, [OpElemAssign, [Identifier, a], -, [[Fixnum, 1]], [Fixnum, 2]]]",
                 "a[1] -= 2")
    assert_parse("[Script, [OpAssign, [Identifier, a], foo, /, [Identifier, b]]]",
                 "a.foo /= b")
    assert_parse("[Script, [OpAssign, [Identifier, a], foo, *, [Identifier, b]]]",
                 "a::foo *= b")
    assert_parse("[Script, [OpAssign, [Identifier, a], Foo, &, [Identifier, b]]]",
                 "a.Foo &= b")
    assert_parse("[Script, [If, [Identifier, a], [Identifier, b], [Identifier, c]]]",
                 "a ? b : c")
    # TODO operators need a ton more testing
    assert_parse("[Script, [Call, +, [Identifier, a], [[Identifier, b]]]]",
                 "a + b")
    assert_parse("[Script, [Call, -, [Identifier, a], [[Identifier, b]]]]",
                 "a - b")
    assert_parse("[Script, [Fixnum, -1]]", "-1")
    assert_parse("[Script, [Float, -1.0]]", "-1.0")
    assert_parse("[Script, [Call, -@, [Identifier, a]]]", "-a")
    assert_parse("[Script, [Call, +@, [Identifier, a]]]", "+a")
    assert_fails("::A ||= 1")
    assert_fails("A::B ||= 1")
   end

   def test_expr
    assert_parse("[Script, [And, [LocalAssign, a, [Fixnum, 1]], [LocalAssign, b, [Fixnum, 2]]]]",
                 "a = 1 and b = 2")
    assert_parse("[Script, [Or, [LocalAssign, a, [Fixnum, 1]], [LocalAssign, b, [Fixnum, 2]]]]",
                 "a = 1 or b = 2")
    assert_parse("[Script, [Not, [LocalAssign, a, [Fixnum, 1]]]]",
                 "not a = 1")
    assert_parse("[Script, [Not, [FCall, foo, [[Identifier, bar]], null]]]",
                 "! foo bar")
   end

   def test_stmt
    assert_parse("[Script, [If, [Identifier, b], [Identifier, a], null]]", "a if b")
    assert_parse("[Script, [If, [Identifier, b], null, [Identifier, a]]]", "a unless b")
    assert_parse("[Script, [While, [Identifier, b], [Identifier, a]]]", "a while b")
    assert_parse("[Script, [Until, [Identifier, b], [Identifier, a]]]", "a until b")
    assert_parse("[Script, [DoWhile, [Identifier, b], [Begin, [Identifier, a]]]]", "begin;a;end while b")
    assert_parse("[Script, [DoUntil, [Identifier, b], [Begin, [Identifier, a]]]]", "begin;a;end until b")
    assert_parse("[Script, [Rescue, [Identifier, a], [[RescueClause, [], null, [Identifier, b]]], null]]",
                 "a rescue b")
    assert_parse("[Script, [LocalAssign, a, [FCall, foo, [[Identifier, bar]], null]]]", "a = foo bar")
    assert_parse("[Script, [LocalAssign, a, [Call, +, [Local, a], [[FCall, foo, [[Identifier, bar]], null]]]]]", "a += foo bar")
    assert_parse("[Script, [If, [Local, a], [LocalAssign, a, [FCall, foo, [[Identifier, bar]], null]], null]]",
                 "a &&= foo bar")
    assert_parse("[Script, [If, [Local, a], null, [LocalAssign, a, [FCall, foo, [[Identifier, bar]], null]]]]",
                 "a ||= foo bar")
    assert_parse("[Script, [OpElemAssign, [Identifier, a], -, [[Fixnum, 1]], [FCall, foo, [[Identifier, bar]], null]]]",
                 "a[1] -= foo bar")
    assert_parse("[Script, [OpAssign, [Identifier, a], foo, /, [FCall, foo, [[Identifier, bar]], null]]]",
                 "a.foo /= foo bar")
    assert_parse("[Script, [OpAssign, [Identifier, a], foo, *, [FCall, foo, [[Identifier, bar]], null]]]",
                 "a::foo *= foo bar")
    assert_parse("[Script, [OpAssign, [Identifier, a], Foo, &, [FCall, foo, [[Identifier, bar]], null]]]",
                 "a.Foo &= foo bar")
   end

   def test_block_args
     assert_parse("[Script, [FCall, a, [], [Iter, [Arguments, [[RequiredArgument, x, null]], null, null, null, null], [Identifier, x]]]]", "a {|x| x}")
     assert_parse("[Script, [FCall, a, [], [Iter, [Arguments, null, null, null, null, null], [Identifier, x]]]]", "a {|| x}")
   end

   def test_block_call
     assert_parse("[Script, [Call, c, [FCall, a, [], [Iter, null, [Identifier, b]]], null, null]]", "a do;b;end.c")
     assert_parse("[Script, [Call, c, [FCall, a, [], [Iter, null, [Identifier, b]]], null, null]]", "a {b}.c")
     assert_parse("[Script, [Super, [[Identifier, a]], [Iter, null, [Identifier, b]]]]", "super a do;b;end")
     assert_parse("[Script, [Super, [[Call, c, [FCall, a, [], [Iter, null, [Identifier, b]]], null, null]]]]", "super a {b}.c")
     assert_parse("[Script, [Call, c, [Super, [[Identifier, a]], [Iter, null, [Identifier, b]]], null]]", "super a do;b;end.c")
   end
end
