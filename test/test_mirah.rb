require 'test/unit'
require 'java'

$CLASSPATH << 'dist/jmeta-runtime.jar' << 'build/test'

class TestParsing < Test::Unit::TestCase
  java_import 'jmeta.SyntaxError'
  java_import 'MirahParser'

  def parse(text)
    MirahParser.print_r(MirahParser.new.parse(text))
  end

  def assert_parse(expected, text)
    assert_equal(expected, parse(text))
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
    assert_parse("[Script, [[Fixnum, 1], [Fixnum, 2], [Fixnum, 3]]]", code)
  end

  def test_float
    assert_parse("[Script, [Float, 0.0]]", "0e1")
    assert_parse("[Script, [Float, 10.0]]", "1e0_1")
    assert_parse("[Script, [Float, 20.0]]", "0_2e0_1")
    assert_parse("[Script, [Float, 22.2]]", "0_2.2_2e0_1")
    assert_fails("3.E0")
    assert_fails("1.")
  end
end