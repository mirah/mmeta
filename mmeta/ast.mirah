package mmeta

import java.io.Serializable
import java.util.AbstractList
import java.util.ArrayList
import java.util.Collections
import java.util.List

class Grow < Exception
end

class Position; implements Serializable
    def initialize(filename:String, pos:int, linepos:int, line:int)
      # humans start counting at 1, not 0, thus we add 1 to line and column
      @filename = filename
      @pos = pos
      @line = line + 1
      @col = pos - linepos + 1
    end

    def toString
        "(line: #{line}, char: #{col})"
    end

    def filename
      @filename
    end

    def pos
      @pos
    end

    def line
      @line
    end

    def col
      @col
    end
end

interface ErrorHandler do
  def warning(messages:String[], positions:Position[]):void; end
  # TODO
  #def error(messages:String[], positions:Position[]):void; end
end

class DefaultErrorHandler; implements ErrorHandler
  def formatMessage(messages:String[], positions:Position[], start:int)
    out = StringBuilder.new
    start.upto(messages.length - 1) do |i|
      out.append(messages[i])
      out.append(" at ")
      p = positions[i]
      if p
        out.append(p.filename)
        out.append(":")
        out.append(p.line)
        out.append(":")
        out.append(p.col)
        out.append(" ")
      end
    end
    out.toString
  end

  def warning(messages:String[], positions:Position[]):void
    System.err.print("Warning: ")
    System.err.println(formatMessage(messages, positions, 0))
  end
end

class Ast < AbstractList; implements Cloneable
  def initialize(name:String)
    @name = name
    @children = ArrayList.new
  end

  def initialize(name:String, children:List)
    @name = name
    @children = ArrayList.new(children)
  end

  def size
    @children.size + 1
  end

  def get(index)
    return @name if index == 0
    @children.get(index - 1)
  end

  def set(index, child)
    if index == 0
      old_name = Object(@name)
      @name = String(child)
      old_name
    else
      @children.set(index - 1, child)
    end
  end

  def add(index, child)
    if index == 0
      raise IllegalArgumentException, "Can't insert child at index #{index}."
    end
    @children.add(index - 1, child)
  end

  def remove(index:int):void # aid compiler in determining the return type. FIXME: Aiding the compiler should not be necessary here. 
    if index == 0
      raise IllegalArgumentException, "Can't remove child #{index}."
    end
    @children.remove(index - 1)
  end

  def children
    List(@children)
  end

  def name
    @name
  end

  def name=(name:String)
    @name = name
  end

  def start_position
    @start
  end

  def start_position=(position:Position)
    @start = position
  end

  def end_position
    @end
  end

  def end_position=(position:Position)
    @end = position
  end

  def clone
    n = Ast.new(name, children)
    n.start_position = @start
    n.end_position = @end
    n
  end
end