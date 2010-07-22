import java.util.AbstractList
import java.util.ArrayList
import java.util.Collections
import java.util.List

class Position
    def initialize(pos:int, linepos:int, line:int)
      # humans start counting at 1, not 0, thus we add 1 to line and column
      @pos = pos
      @line = line + 1
      @col = pos - linepos + 1
    end

    def toString
        "(line: #{line}, char: #{col})"
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

class Ast < AbstractList
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

  def remove(index:int)
    if index == 0
      raise IllegalArgumentException, "Can't remove child #{index}."
    end
    @children.remove(index - 1)
  end

  def children
    Collections.unmodifiableList(@children)
  end

  def name
    @name
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
end