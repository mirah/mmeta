# MMeta

MMeta is a parser generator tool for Mirah. It creates Packrat type parsers,
also known as PEGs or backtracking parsers. MMeta is heavily inspired by OMeta
and JMeta.

See also:
* http://en.wikipedia.org/wiki/Parsing_expression_grammar
* http://pdos.csail.mit.edu/~baford/packrat/
* http://tinlizzie.org/ometa/


## Important features:
* Mix and match Mirah with your parsers.
* Error annotation to allow good error reporting.
* Inherit parsers to extend them (from OMeta).
* Semantic actions, using mirah or a shorthand notation.
* Optional support for direct and indirect left recursion.
* Parsing not just for text, but anything 'structured' (Strings, Arrays or
  Lists; because java is statically typed).
* easy; easier compared to rats and antlr?


## Installation
Compile with `jruby -S rake`. Requires java 1.5 or higher.

TODO: fix position in line/char.
TODO: forbid rules names using java keywords, or build-in rules that should not  
      be overridden.
TODO: allow inline classes; allow classes without qualifiers
TODO: allow parsers with custom constructors.
TODO: we could do without a runtime, by just creating inline classes, unless we 
      inherit a grammar.
TODO: implement a more fancy memoization schema, including argument support.
TODO: change the syntax to be more mirah-like, or more OMeta like?
TODO: Create multiple parser classes - string, list, generic, token, etc.

## Error Reporting

MMeta uses `!` syntax to annotate that a rule from that point on may no longer
backtrack, if it does, instead of backtracking, a `SyntaxError` is reported,
noting the last rule that was expected to pass, but failed. A rule must fully
parse after the first `!` appeared in the rule. It is allowed that the whole
rule backtracks. Notice you cannot just put `!` marks everywhere, since
backtracking is the feature that makes PEGs work.

Bad Example; simplistic xml parsing:

```
    element: "<" ! n=name props "/>"
           | "<" ! n=name props ">" element* "<" n=name "/>" ;
```

The second alternative will never run, since the first is not allowed to
backtrack, while it must backtrack in order to try the second alternative. (Both
rule alternatives start with "<")

A much better, yet still simplistic xml parsing, which also ensures proper
nesting:

```
    element: "<" n=name props "/" ! ">"
           | "<" ! n=name props ">" element*
             !"a closing '$n'" &("<" m=name ?{ m.equals(n) }) ! "<" name "/>" ;
```

Notice the use of a custom message, and the use of lookahead (&) in order to put
the error message at the correct location.


## Tokens

In PEG based parsers, there is no separate tokenizer. This simplyfies things,
but does require some thought. Best strategy is whenever you call a rule that
you would normally think of as a token, to prepend it with a call to eat all
whitespace, by default the `.` rule.

Extending the above xml sample:

```
    element: ."<"   .n=name props ."/" ! .">"
           | ."<" ! .n=name props        .">" element*
             !"a closing '$n'" .&("<" .m=name ?{return m.equals(n);}) ! ."<" .name ! ."/".">" ;
```

Notice the `.` just before the lookahead block (`&...`), and not inside, to keep
the position of the error report correct.


## Mirah Caveats

MMeta does not understand mirah code at all. It fakes it. This has some
consequences:

1. Methods must be surrounded with braces instead of using end.
2. When writing semantic expressions, make sure to match the curly braces. Even
   inside strings. you may need to add a closing brace inside a comment, just to
   balance the braces.
3. Memoized rules return Object by default. You either need to cast the result
   or you can use $Memo[String] to declare a rule should be memoized and return
   a string.
4. The parser throws a `SyntaxError` on error, which is not an `Exception`, but
an `Error`, so take care to catch it correctly.


## Semantic Actions
Any rule always returns its last evaluated rule or semantic action. You can
place semantic actions anywhere, and have many of them. They are like methods
that get called with all previously defined variables.

To make it easier to parse text into an Array based AST, MMeta has a shorthand
notation, and two list helper functions, that receive `Object`s which may be
`Object[]` arrays or `List`s: `concat(head:Object, tail:Object)`;
`join(list:Object, sep="")`.

example shorthand:
```
  // equivalent
  name: f=nstart rs=nrest* { [f] + rs } ;
  name: f=nstart rs=nrest* { concat([ f ], rs) } ;
```

And example of the `join` method:
```
  string = "\"" xs=(~"\"" _)* "\"" { join(xs) } ;
```

Notice that in any semantic action you can execute arbitrary Mirah, including
assigning to member fields or running methods.


## Parser creation notes

Also see sample below. Since PEGs backtrack, you must be careful when using
side-effects. That is, it is best that rules return a value that represents
everything about that rule, instead of mutating some instance variable of the
parser.

Also, since MMeta is good at parsing Array based structures too, it is
recommended you parse in two steps (using two distict parsers):

1) Parse the string content to a (simplistic/verbose) AST. Focus on handling
human input, so create a flexible syntax, easy to understand for humans, and
provide good syntax error reporting.

2) Analyze the AST, rework it into the final thing you want. Here you report
semantic errors. But you can rely on the fact that the AST is produced by your
first parser, so is completely valid. Any syntax error here is a bug in either
this parser, or the first.


## annotated example
```
# single line comments
/* multi line comments

   A simple calculator example, save as `Calculator.mmeta`

   compile to java file:
     `java -jar mmeta.jar Calculator.mmeta Calculator.mirah`
   compile to class file:
     `mirahc --classpath /usr/share/java/jmeta-runtime.jar Calculator.mirah`
   run:
     `java -cp/usr/share/java/jmeta-runtime.jar:. Calculator "10 + 10"`
*/
// this parser will turn into: `class Calculator < BaseParser; ...`
parser Calculator {
    // defining a mirah method
    def self.main(args:String): void {
        ast = Calculator.new.parse(args[0])
        puts Interpreter.new.parse(ast)
    }

    // this is mmeta syntax; the 'start' rule is the default rule to start with
    // notible:
    //  `!` means a syntax error occured if the rule backtracks after this point
    //  `.` means any whitespace (it runs the build-in rule `whitespace`)
    //  `end` matches end of input, equivalent to `~_` (not anything)
    //  `e=expr` means, parse an expression and assign it to the variable `e`
    //  `{ e }`  means run a semantic action, in this case, return `e`
    start: ! e=expr . end      { e };
    expr:
        | l=expr ."+"! r=expr1 { ['ADD, l, r] }
        | l=expr ."-"! r=expr1 { ['SUB, l, r] }
        | expr1
    ;
    expr1:
        | l=expr1 ."*"! r=value { ['MUL, l, r] }
        | l=expr1 ."/"! r=value { ['DIV, l, r] }
        | l=expr1 ."%"! r=value { ['MOD, l, r] }
        | value
    ;
    value:
        | ."(" ! e=expr .")" { e }
        | . n=num              { ['INT, n] }
    ;
    num: ds=digit+ { Integer.valueOf(Integer.parseInt(join(ds))) } ;
}

// a second parser in the same file
// notice this parser does not process text, but a tree like nesting of Arrays
// and Lists
// the `[` opens up such a list, and starts parsing inside of it the matching
//  `]` backs up one level. `end` in this context means end of list, not
// necessarily end of input
parser Interpreter {
    start: destruct ;

    // a trick, parse anything and then apply the corresponding rule
    destruct: r=_ res=apply(r) end   { res } ;
    val: [ res=destruct ]            { res } ;

    ADD: l=val r=val
         { Integer.valueOf(Integer(l).intValue + Integer(r).intValue) } ;
    SUB: l=val r=val
         { Integer.valueOf(Integer(l).intValue - Integer(r).intValue) } ;
    MUL: l=val r=val
         { Integer.valueOf(Integer(l).intValue * Integer(r).intValue) } ;
    DIV: l=val r=val
         { Integer.valueOf(Integer(l).intValue / Integer(r).intValue) } ;
    MOD: l=val r=val
         { Integer.valueOf(Integer(l).intValue % Integer(r).intValue) } ;
    INT: v=_ ;
}
```

