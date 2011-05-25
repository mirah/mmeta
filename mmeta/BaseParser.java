// copyright 2009 ActiveVideo; license: MIT; see license.txt
package mmeta;

import java.util.*;

class MemoStat {
  public String name;
  public long stores;
  public long hits;
  public long misses;
  public boolean recursion;
}

class State {
    State prev = null;
    int pos; Object[] list; SparseArrayList<HashMap<String, Memoize>> positions;
    public State(State prev, int p, Object[] l, SparseArrayList<HashMap<String, Memoize>> m) {
        this.prev = prev;
        pos = p; list = l; positions = m;
    }
}

class Memoize {
    public Object val; public int pos; int seed = -1;
    public Memoize(Object val, int pos) { this.val = val; this.pos = pos; }
    public String toString() { return "at: "+ pos +" val: "+ val; }
}

/// Root parser object, all parsers will in the end extend BaseParser
public class BaseParser {
    public BaseParser() {
        lines.put(0, 0);
    }

    private static class ReverseComparator implements Comparator<Comparable>  {
        public int compare(Comparable a, Comparable b) {
            return -a.compareTo(b);
        }
    }

    public static String print_r(Object o) {
        StringBuffer sb = new StringBuffer();
        print_r(o, sb);
        return sb.toString();
    }
    public static void print_r(Object o, StringBuffer sb) {
        if (o instanceof List) {
            sb.append("[");
            for (int i = 0; i < ((List)o).size(); i++) {
                if (i > 0) sb.append(", ");
                print_r(((List)o).get(i), sb);
            }
            sb.append("]");
        } else if (o instanceof Object[]) {
            sb.append("[");
            for (int i = 0; i < ((Object[])o).length; i++) {
                if (i > 0) sb.append(", ");
                print_r(((Object[])o)[i], sb);
            }
            sb.append("]");
        } else {
            sb.append(o);
        }
    }
    public void _enter(String label) {
      if (debug_parse_tree) {
        String parent = parseTree.peekLast();
        if ("ws".equals(label) ||
            "<skip>".equals(label) ||
            "skip".equals(parent)) {
          parseTree.addLast("skip");
          return;
        }
        String nodeName = "n" + nodeCount++;
        label = label.replaceAll("\"", "\\\\\"").replaceAll("\n", "\\\\n");
        System.out.println("  " + nodeName + "[label=\"" + label + "\"];");
        if (parent != null) {
          System.out.println("  " + parent + " -- " + nodeName + ";");
        }
        parseTree.addLast(nodeName);
      }
    }

    public Object _exit(Object result) {
      if (debug_parse_tree) {
        String nodeName = parseTree.removeLast();
        if ("skip".equals(nodeName)) {
          // don't print anything
        } else if (result == ERROR || result instanceof RuleFailure) {
          System.out.println("  " + nodeName + "[color=red];");
        }
      }
      return result;
    }

    public static boolean tracing = false;
    public static boolean debug_parse_tree = Boolean.getBoolean("mmeta.debug_parse_tree");
    public Object trace(Object... args) throws RuleFailure {
        if (tracing) {
            for (int i = 0; i < args.length; i++) {
                if (i > 0) System.out.print(" ");
                System.out.print(print_r(args[i]));
            }
            System.out.println(" at " + _pos);
        }
        Object result = args[args.length - 1];
        if (result == ERROR) {
            return _error("");
        } else if (result instanceof RuleFailure) {
            throw (RuleFailure)result;
        }
        return result;
    }

    public Object _error(String expected) throws RuleFailure {
        RuleFailure failure = new RuleFailure();
        failure.last = expected;
        throw failure;
    }

    /// Object indicating a parsing error
    private static final Object ERROR = new Object() { public String toString() { return "ERROR"; }};
    private static final Object LEFT_REC = new Object() { public String toString() { return "LEFT_REC"; }};
    private static final Grow GROW = new Grow();
    public static final Memoize NOT_MEMOIZED = new Memoize(null, -1)  { public String toString() { return "not memoized"; }};

    LinkedList<Object> args;
    State _stack = null;
    SparseArrayList<HashMap<String, Memoize>> _positions;
    LinkedList<HashSet<String>> _lefts;
    // Use a reverse sorted TreeSet so we can use lines.tailSet(x).first() to find the
    // first value <= x;
    private TreeMap<Integer, Integer> lines = new TreeMap<Integer, Integer>(new ReverseComparator());
    private long nodeCount;
    private LinkedList<String> parseTree = new LinkedList<String>();

    public String filename = "<unknown>";
    public ErrorHandler errorHandler = new DefaultErrorHandler();
    public int _pos = 0;
    public int _pos() { return _pos; }
    public void _pos_set(int pos) { _pos = pos; }
    public String _string;
    public String _string() { return _string; }
    public char[] _chars;
    public char[] _chars() { return _chars; }
    public Object[] _list;
    public Object[] _list() { return _list; }
    public void _list_set(Object[] list) { _list = list; }
    private Token<?> cached_token = new Token(null, -1, -1, -1);

    public Object _memoize(String s, int p, Object o) throws Grow, RuleFailure {
        HashMap<String, Memoize> map = _positions.get(p);
        if (map == null) {
            map = new HashMap<String, Memoize>();
            _positions.set(p, map);
        }
        MemoStat stats = _stats.get(s);
        if (stats == null) {
          stats = new MemoStat();
          stats.name = s;
          _stats.put(s, stats);
        }
        stats.stores += 1;
        Memoize entry = map.get(s);
        if (entry == null) {
            if (args.isEmpty()) {
                entry = new Memoize(o, p);
                map.put(s, entry);
            } else {
                // sometimes we don't have a entry, incase args > 0
                return trace("unmemoize:", s, o);
            }
        }
        if (entry.seed != -1) {
            // if we are done growing, stop it, and remove this left recursion from stack
            if (o instanceof RuleFailure || _pos <= entry.pos) {
                _pos = entry.pos;
                entry.seed = -1;
                _lefts.pop();
                return trace("< END:", s, _pos, entry.val);
            }

            // we will try to grow, reset all entries for this position, and record current result
            for (String k : _lefts.pop()) map.remove(k);
            // setup another left recursion stack
            _lefts.push(new HashSet<String>());
            // update the growing entry, and reset pos to its seed
            entry.val = o;
            entry.pos = _pos;
            _pos = entry.seed;
            throw GROW;
        }

        // if we are in a left recursive situation, mark each evaluated rule
        if (! _lefts.isEmpty()) _lefts.peek().add(s);

        entry.pos = _pos;
        entry.val = o;
        if (o instanceof RuleFailure) {
            _pos = p;
            return trace("< err:", s, o);
        }
        return trace("<  ok:", s, o);
    }

    private HashMap<String, MemoStat> _stats = new HashMap<String, MemoStat>();
    public Object _sretrieve(String s) throws RuleFailure {
      // we cannot memoize in face of arguments
      if (! args.isEmpty()) return trace(">ntry:", s, NOT_MEMOIZED);

      int p = _pos;
      HashMap<String, Memoize> map = _positions.get(p);
      MemoStat stats =  _stats.get(s);
      if (stats == null) {
        stats = new MemoStat();
        _stats.put(s, stats);
        stats.name = s;
      }
      Memoize entry = map == null ? null : map.get(s);
      if (entry == null) {
          stats.misses += 1;
      } else {
          stats.hits += 1;
          _pos = entry.pos;
          if (entry.val == LEFT_REC) {
              // notice we are diving into a left recursion, grow a seed from here, and start a left recursion stack
              entry.val = ERROR;
              entry.seed = entry.pos;
              _lefts.push(new HashSet<String>());
              stats.recursion = true;
              return trace(">LEFT:", s, _pos, ERROR);
          }
          if (entry.val == ERROR) return trace("> err:", s, entry.val);
          return trace(">  ok:", s, entry.val);
      }
      return trace("> try:", s, NOT_MEMOIZED);
    }
    public Object _retrieve(String s) throws RuleFailure {
      Object o = _sretrieve(s);
      if (o == NOT_MEMOIZED && args.isEmpty()) {
        HashMap<String, Memoize> map = _positions.get(_pos);
        if (map == null) {
            map = new HashMap<String, Memoize>();
            _positions.set(_pos, map);
        }
        // mark that we are starting with this rule
        map.put(s, new Memoize(LEFT_REC, _pos));
      }
      return o;
    }

    public void _init() {
        _pos = 0;
        _positions = new SparseArrayList<HashMap<String, Memoize>>();
        _lefts = new LinkedList<HashSet<String>>();
        lines = new TreeMap<Integer, Integer>(new ReverseComparator());
        lines.put(0, 0);
        args = new LinkedList<Object>();
        init();
    }

    /// called after init(data)
    public void init() {}

    /// init parser with String, use parser.rule() to actually parse
    public void init(String s) {
        _string = s;
        _chars = s.toCharArray();
        _list = null;
        _init();
    }

    /// init parser with a Object[] array, @see init(String s);
    public void init(Object[] ls) {
        _string = null; _list = ls; _init();
    }

    /// init parser with a ArrayList, @see init(String s);
    public void init(ArrayList<? extends Object> as) {
        _string = null; _list = as.toArray(); _init();
    }

    public void init(List<? extends Object> as) {
        init(new ArrayList(as).toArray());
    }

    public Object parse(Object o) { return parse(o, null); }
    public Object parse(Object o, String r) {
             if (o instanceof ArrayList) init((ArrayList) o);
        else if (o instanceof Object[])  init((Object[]) o);
        else if (o instanceof String)    init((String) o);
        else if (o instanceof List)    init((List) o);
        else throw new AssertionError("parse requires a List, Object[] or String; got " + (o == null ? "null" : o.getClass().toString()));

        if (debug_parse_tree) {
          System.out.println("graph parse {");
        }

        Object _t = null;
        try {
            if (r != null) _t = _jump(r.intern());
            else _t = start();
        } catch (RuleFailure ex) {
            syntaxError("", ex);
        }

        if (debug_parse_tree) {
          System.out.println("}");
          System.err.println("Memo Stats:");
          for (MemoStat stat : _stats.values()) {
            if (stat.hits == 0) continue;
            System.err.println(stat.name + ": " + stat.stores + " stores, " + 
                               stat.hits + " hits, " +
                               (((double)stat.hits)/(stat.hits+stat.misses))
                               );
          }
        }
        return _t;
    }

    public void syntaxError(String message, RuleFailure ex) {
      throw new SyntaxError(message, ex.last, _pos, _string, _list);
    }

    public void warn(String message) {
      errorHandler.warning(new String[] {message}, new Position[] {pos()});
    }

    public void warn(String message, String message2, int position2) {
      errorHandler.warning(new String[] {message, message2}, new Position[] {pos(), pos(position2)});
    }

    /// start rule; override by creating a rule called 'start'
    public Object start() { throw new IllegalStateException("provide a rule called 'start'"); }

    public void _push(Object... as) { for (int i = as.length - 1; i >= 0; i--) args.push(as[i]); }
    public void _push(Object a) { args.push(a); }
    public Object _pop() { return args.pop(); }

    /// rule that requires a Symbol and runs the corresponding rule
    public Object apply() throws RuleFailure {
      return apply(_pop());
    }
    public Object apply(Object r) throws RuleFailure {
        if (!(r instanceof String)) { return _error("apply() must receive a string"); }
        try {
          return _jump((String) r);
        } catch (AssertionError e) {
          return _jump(((String) r).intern());
        }
    }

    /// hasRule; returns true or false, depending on if the given rule exists
    public boolean hasRule() {
        Object r = _pop();
        return hasRule(r);
    }

    public boolean hasRule(Object r) {
        if (!(r instanceof String)) return false;
        return (Boolean) _has(((String) r).intern());
    }

    /// str; next element must be given string
    public Object str() throws RuleFailure {
      return str(_pop());
    }
    public Object str(Object r) throws RuleFailure {
        if (!(r instanceof String)) throw new IllegalArgumentException("'str' must receive a String; not: "+ r);
        return _str((String) r);
    }

    /// sym; next element must be given symbol
    public Object sym() throws RuleFailure {
      return sym(_pop());
    }
    public Object sym(Object r) throws RuleFailure {
        if (!(r instanceof String)) throw new IllegalArgumentException("'sym' must receive a String; not: "+ r);
        return _sym((String) r);
    }

    public void note_newline(int pos) {
      if (!lines.containsKey(pos)) {
          lines.put(pos, lines.size());
      }
    }

    /// '_'
    public Object _any() throws RuleFailure {
        if (! args.isEmpty()) return args.pop();

        if (_string != null) {
            if (_pos < _chars.length) {
                char c = _chars[_pos++];
                if (c == '\n' || (c == '\r' && _cpeek() != '\n')) {
                    note_newline(_pos);
                }
                return c;
            } else {
                return _error("");
            }
        }
        if (_list != null)
            if (_pos < _list.length) return _exit(_list[_pos++]); else return _error("");
        throw new IllegalStateException("no _list nor _string??");
    }

    /// empty; returns an empty string (or null when parsing lists) without consuming any input
    public Object empty() {
        if (_string != null) return "";
        return null;
    }

    /// returns current position in stream, counted by every success of apply(nl)
    public Position pos() {
        return pos(_pos);
    }
    
    public Position pos(int pos) {
        if (_string == null)
            throw new IllegalStateException("'pos' is only available in string parsing");

        int linepos = lines.tailMap(pos).firstKey();
        int line = lines.get(linepos);

        // TODO actually keep track of every apply(nl) that succeeds
        return new Position(filename, pos, linepos, line);
    }

    public Object col() {
        if (_string == null)
            throw new IllegalStateException("'col' is only available in string parsing");
        int pos = _pos - 1;

        while (pos >= 0 && _chars[pos] != '\n') pos--;
        return _pos - pos - 1;
    }

    public Ast build_node(String name, List<?> children, int start_pos, int end_pos) {
        Ast node = new Ast(name, children);
        node.start_position_set(pos(start_pos));
        node.end_position_set(pos(end_pos));
        return node;
    }

    public Ast build_node(String name, int start_pos, int end_pos) {
        Ast node = new Ast(name);
        node.start_position_set(pos(start_pos));
        node.end_position_set(pos(end_pos));
        return node;
    }

    public Ast build_node(String name, Object children, int start_pos, int end_pos) {
        return build_node(name, (List<?>)children, start_pos, end_pos);
    }

    public String text(int start, int end) {
      return _string.substring(start, end);
    }

    public char _cpeek() throws RuleFailure {
        if (_pos < _chars.length) {
            return _chars[_pos];
        } else {
            _error("");
            return '\0';
        }
    }

    public String _rpeek() {
      if (_pos == 0 || _string == null) {
        return "";
      }
      return _string.substring(_pos - 1, _pos);
    }

    public Object _peek() throws RuleFailure {
      if (! args.isEmpty()) return args.peek();
        if (_string != null)
            if (_pos < _chars.length) return _chars[_pos]; else return _error("");
        if (_list != null)
            if (_pos < _list.length) return _list[_pos]; else return _error("");
        throw new IllegalStateException("no _list nor _string??");
    }

    /// returns success if the end of file or list has been reached; same as `end: ~_;`
    public Object end() throws RuleFailure {
        try {
            _peek();
        } catch (RuleFailure ex) {
            return null;
        }
        return _error("end of input");
    }

    public Object __end__() throws RuleFailure {
      return end();
    }

    /// '.' parses as much whitespace as possible, override the default `ws: nl | sp;` rule to define the whitespace
    public Object ws() throws RuleFailure {
        if (_string == null)
            throw new IllegalStateException("whitespace ('.') is only available in string parsing");
        do {
            try {
                char c = _cpeek();
                if (!(c == ' ' || c == '\t' || c == '\f' || c == '\n' | c == '\r')) { break; }
                _any();
            } catch (RuleFailure ex) {
                return null;
            }
        } while (true);
        return null;
    }

    /// '"..."' parses a string when string parsing
    public Object _str(String s) throws RuleFailure {
        trace("try _str():", s);
        _enter("'"+s+"'");
        if (_string == null)
            throw new IllegalStateException("string ('\""+ s +"\"') is only available in string parsing");
        int p = _pos;
        if (p + s.length() > _chars.length) {
            return _error("'"+ s +"'");
        }
        for (int i = 0; i < s.length(); i++) {
          if (s.charAt(i) != _chars[p++]) {
              _exit(ERROR);
              return _error("'"+ s +"'");
          }
        }
        _pos = p;
        return _exit(trace(" ok _str():", s));
    }

    /// '`...' parses a string based symbols when list parsing (e.g. `new Object[] { "hello" }` matches `[ `hello ]`)
    public Object _sym(String s) throws RuleFailure {
        trace("try _sym():", s);
        if (_list == null && args.isEmpty())
            throw new IllegalStateException("symbol ('`"+ s +"') is only available in list parsing");
        if (_peek().equals(s)) { _any(); return trace(" ok _sym():",s); } else return _error(s);
    }

    public Object _char(String s) throws RuleFailure {
        _enter("["+s+"]");
        if (_string == null)
            throw new IllegalStateException("charRange is only available in string parsing");
        char c = _cpeek();
        if (s.indexOf(c) >= 0) { _any(); return _exit(c); }
        _exit(ERROR);
        return _error("["+s+"]");
    }

    /// nl; parses a single newline
    public Object nl() throws RuleFailure {
        return _char("\n\r");
    }

    /// sp; parses a single space
    public Object sp() throws RuleFailure {
        return _char(" \t\f");
    }

    public Object _charRange(char b, char e) throws RuleFailure {
        if (_string == null)
            throw new IllegalStateException("charRange is only available in string parsing");
        char c = _cpeek();
        if (c >= b && c <= e) { _any(); return c; }
        return _error("["+b+"-"+e+"]");
    }

    /// default rule that parses [0-9]
    public Object digit() throws RuleFailure { return _charRange('0', '9'); }

    /// default rule that parses [a-zA-Z]
    public Object letter() throws RuleFailure {
        try {
            return _charRange('a', 'z');
        } catch (RuleFailure ex) {
            return _charRange('A', 'Z');
        }
    }

    public String join(Object ls) { return join(ls, ""); }

    /// helper that folds an Array or ArrayList into a single string (using toString())
    public String join(Object ls, String sep) {
        StringBuilder sb = new StringBuilder();
        boolean first = true;
        if (ls instanceof Object[]) {
            for (Object o : (Object[])ls) {
                if (first) first = false; else sb.append(sep);
                sb.append(o.toString());
            }
        } else if (ls instanceof List) {
            for (Object o : (List<?>)ls) {
                if (first) first = false; else sb.append(sep);
                sb.append(o.toString());
            }
        } else if (ls != null ){
            throw new IllegalArgumentException("'join' must receive a List or Object[]. Got " + ls.getClass().getName());
        }
        return sb.toString();
    }

    // helper that concatenates two Arrays or Lists together
    public List concat(Object ls, Object rs) {
        if (ls == null) {
            if (rs == null) {
                return Collections.emptyList();
            }
            ls = rs;
            rs = null;
        }
        if (ls instanceof Object[]) {
            Object[] la = (Object[]) ls;
            if (rs instanceof Object[]) {
                Object[] ra = (Object[]) rs;
                Object na = Arrays.copyOf(la, la.length + ra.length);
                System.arraycopy(rs, 0, na, la.length, ra.length);
                return Arrays.asList(na);
            } else if (rs instanceof List) {
                List ra = (List<?>) rs;
                Object[] na = Arrays.copyOf(la, la.length + ra.size());
                for (int i = 0; i < ra.size(); i++) na[la.length + i] = ra.get(i);
                return Arrays.asList(na);
            } else if (rs == null) {
                return Arrays.asList(la);
            }
        } else if (ls instanceof List) {
            List<?> la = (List<?>) ls;
            if (rs instanceof Object[]) {
                Object[] ra = (Object[]) rs;
                ArrayList na = new ArrayList(la);
                na.addAll(Arrays.asList(ra));
                return na;
            } else if (rs instanceof List) {
                List ra = (List<?>) rs;
                ArrayList na = new ArrayList(la);
                na.addAll(ra);
                return na;
            } else if (rs == null) {
                return la;
            }
         }

        throw new IllegalArgumentException("'concat' must receive two Lists or Object[]s. Got " + ls.getClass().getName() + " and " + rs.getClass().getName());
    }

    public Object _listBegin() throws RuleFailure {
        if (_list == null)
            throw new IllegalStateException("list ('[ ... ]') operations only available in list parsing");

        Object ls = _peek();
        Object[] list = null;
        if (ls instanceof Object[]) {
            list = (Object[])ls;
        } else if (ls instanceof ArrayList) {
            list = ((ArrayList<?>)ls).toArray();
        } else if (ls instanceof List) {
            list = new ArrayList((List)ls).toArray();
        } else {
            return _error("");
        }
        _any();

        _stack = new State(_stack, _pos, _list, _positions);
        _pos = 0;
        _list = list;
        _positions = new SparseArrayList<HashMap<String, Memoize>>();
        return null;
    }

    public void _listEnd() {
        _pos = _stack.pos;
        _list = _stack.list;
        _positions = _stack.positions;
        _stack = _stack.prev;
    }

    public Object _jump(String r) throws RuleFailure {
        throw new AssertionError("_jump: rule '"+ r +"' does not exist; or not properly implemented yet");
    }
    public boolean _has(String r) {
        return false;
    }
    
    public <T extends Enum<T>> Token<T> build_token(Enum<T> type, int pos, int start) {
      return new Token<T>(type, pos, start, _pos);
    }
    public <T extends Enum<T>> Token<T> build_token(Enum<T> type, int pos, int start, int endpos) {
      return new Token<T>(type, pos, start, endpos);
    }

    public class Token<T extends Enum<T>> {
      public Token(Enum<T> type, int pos, int start, int end) {
        this.type = type;
        this.pos = pos;
        this.startpos = start == -1 ? pos : start;
        this.endpos = end;
      }
      
      public final Enum<T> type;
      public final int pos;
      public final int startpos;
      public final int endpos;
      
      public String text() {
        return _string.substring(startpos, endpos);
      }
      
      public boolean space_seen() {
        return pos != startpos;
      }
      
      public String toString() {
        return "<Token " + type + ": '" + text() + "'>";
      }
    }
    
    
}

