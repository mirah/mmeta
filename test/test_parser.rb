require 'test/unit'
require 'java'

$CLASSPATH << 'dist/mmeta-runtime.jar' << 'build'

class TestParsing < Test::Unit::TestCase
  java_import 'mmeta.SyntaxError'
  java_import 'mmeta.BaseParser'
  java_import 'test.TestParser'

  def parse(text)
    TestParser.new.parse(text)
  end

  def assert_parse(expected, text)
    assert_equal(expected, TestParser.print_r(parse(text)))
  end

  def assert_fails(text)
    begin
      fail("Should raise syntax error, but got #{parse text}")
    rescue SyntaxError
      # ok
    end
  end

  def test_eof
    assert_parse('[EOF]', '')
    assert_fails('a')
  end

  def test_empty_string
    assert_parse('[Empty, ]', 'empty_string')
    assert_parse('[Empty, ]', 'empty_string ')
  end

  def test_syn_pred
    assert_parse('[SynPred, p]', 'syn_pred p')
    assert_parse('[SynPred, x]', 'syn_pred x')
    assert_fails('syn_pred q')
    assert_fails('syn_pred pp')
  end

  def test_token_literal
    assert_parse('[Token, foo]', 'token foo')
    assert_parse('[Token, bar]', 'token bar')
    assert_fails('token if')
    assert_fails('token')
  end

  def test_token_range
    assert_parse('[Token, unless]', 'range unless')
    assert_parse('[Token, until]', 'range until')
    assert_fails('range true')
    assert_fails('range when')
    assert_fails('range')
  end

  def test_star
    assert_parse('[Star, []]', 'star')
    assert_parse('[Star, [a]]', 'star a')
    assert_parse('[Star, [a, a]]', 'star aa')
    assert_parse('[Star, [a, a, a, a]]', 'star aaaa')
    assert_fails('star b')
    assert_fails('starb')
  end

  def test_plus
    assert_parse('[Plus, [a]]', 'plus a')
    assert_parse('[Plus, [a, a]]', 'plus aa')
    assert_parse('[Plus, [a, a, a, a]]', 'plus aaaa')
    assert_fails('plus')
    assert_fails('plus ')
    assert_fails('plus b')
  end

  def test_save
    assert_parse('[Save, 2, 1]', 'save 12')
    assert_parse('[Save, a, b]', 'save ba')
  end

  def test_peek
    assert_parse('[Peek, a]', 'peek a')
    assert_fails('peek aa')
  end

  def test_not
    assert_parse('[Not, b]', 'not b')
    assert_parse('[Not, c]', 'not c')
    assert_parse('[Not, z]', 'not z')
    assert_fails('not a')
  end

  def test_opt
    assert_parse('[Opt, a]', 'opt a')
    assert_parse('[Opt, null]', 'opt')
  end

  def test_pred
    assert_parse('[Pred, [a, a, a]]', 'pred aaa')
    assert_fails('pred a')
    assert_fails('pred aaaa')
  end

  def test_action
    assert_parse('[Action, a]', 'action a')
    assert_parse('[Action, aa]', 'action aa')
    assert_parse('[Action, aaaaa]', 'action aaaaa')
  end

  def test_scope
    assert_parse('[Scope, aba]', 'scope')
  end

  def test_empty_last
    assert_parse('[ELast, x]', 'elast x')
    assert_parse('[ELast, y]', 'elast y')
    assert_parse('[ELast, null]', 'elast')
  end

  def test_squote
    assert_parse('[SQuote]', "'")
  end

  def test_dquote
    assert_parse('[DQuote]', '"')
  end

  def test_memo
    assert_parse('[Memo, memo]', 'memo')
  end
end
