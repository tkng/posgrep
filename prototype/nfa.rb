# -*- coding: utf-8 -*-

class Token
  attr_accessor :type, :value
  def initialize(type, value)
    @type = type; @value = value
  end
end

class Lexer
  attr_accessor :index, :tokens
  def initialize(str)
    @special_chars = {"(" => :lparen, ")" => :rparen, "|" => :bar, "*" => :star, "." => :dot}
    @tokens = parse(str)
    @index = 0
  end

  def parse(str)
    tokens = [];
    i = 0
    str_size = str.size

    while i < str_size
      if @special_chars[str[i]]
        tokens.push Token.new(@special_chars[str[i]], nil)
      else
        tokens.push Token.new(:normal, str[i])
      end
      i += 1
    end
    return tokens
  end

  def peek()
    if @index <= @tokens.size
      return @tokens[@index]
    else
      return false
    end
  end

  def consume()
    token = peek()
    @index += 1
    return token
  end
end

class State
  attr_accessor :prev_edge, :next_edges, :type, :i
  @@index = 0
  def initialize(type)
    @prev_edge = []; @next_edges = []
    @type = type
    @i = @@index
    @@index += 1
  end
end

class StateEdge
  attr_accessor :type, :val, :src, :dest
  def initialize(type, val, src, dest)
    @type = type
    @val = val
    @src = src
    @dest = dest
  end
end

def connect(src, edge, dest)
  src.next_edges.push edge
  puts "src.i #{src.i}"
  p src.next_edges.map{|e| e.dest.i}
  dest.prev_edge = edge
  return edge.dest
end

def merge_ends(ends, cur)
  if ends.length == 0
    return cur
  else
    ends.each do |e|
      e.prev_edge.dest = cur
    end
  end
  return cur
end

def parse(lexer, start, stack_level = 0)
  cur = start
  prev = false
  ends = []

  while token = lexer.consume()
    p "#{token.type} #{ends.length} #{stack_level}"

    case token.type
    when :normal
      s = State.new(:normal)
      prev = cur
      edge = StateEdge.new(:normal, token.value, cur, s)
      cur = connect(cur, edge, s)
    when :bar # |
      puts "endspush #{stack_level}"
      ends.push cur
      cur = start
      next
#      cur = parse(lexer, start, stack_level + 1)
    when :lparen
      puts "lparen"
      prev = cur
      cur = parse(lexer, cur, stack_level + 1)
    when :rparen
      puts "return from rparen #{ends.length}"
      return merge_ends(ends, cur)
    when :star
      edge = StateEdge.new(:epsilon, nil, cur, prev)
      p "old_cur #{cur.i} new_cur #{prev.i}"
      p "ends.length  #{ends.length} #{stack_level}"
      connect(cur, edge, prev)
      cur = prev
    end
  end

  cur.type = :end
  return merge_ends(ends, cur)
end

require "pp"

def re2nfa(str)
  lexer = Lexer.new(str)
  start = State.new(:start)
  parse(lexer, start)
  return start
end

def put_graph_info(fp, state)
  p "#{state.i}, #{state.type}"
  case state.type
  when :start
    fp.puts "#{state.i} [peripheries = 2];"
  when :end
    fp.puts "#{state.i} [peripheries = 3];"
  end

  for edge in state.next_edges
    if edge.type == :normal
      fp.puts "#{state.i} -> #{edge.dest.i} [label = \"#{edge.val}\"];"
      puts puts "#{state.i} -> #{edge.dest.i} [label = \"#{edge.val}\"];"
      put_graph_info(fp, edge.dest)
    elsif edge.type == :epsilon
      fp.puts "#{state.i} -> #{edge.dest.i} [label = \"ep\"];"
      puts "#{state.i} -> #{edge.dest.i} [label = \"ep\"];"
    end
  end

end

def to_dot(graph, filename)
  puts "----------------------"
  wfp = open(filename, "w")
  wfp.puts "digraph sample {"
  put_graph_info(wfp, graph)
  wfp.puts "}"
  wfp.close
  puts "dot -Tpng #{filename} > #{filename.gsub('.dot', '.png')}"
  `dot -Tpng #{filename} > #{filename.gsub(".dot", ".png")}`
end

g = re2nfa("a*b")
to_dot(g, "a.dot")

g = re2nfa("a(b)*")
to_dot(g, "a.dot")

g = re2nfa("(a|b)*d")
to_dot(g, "a2.dot")

g = re2nfa("a(ab|cd|x(ef|gh))")
to_dot(g, "a3.dot")


# g = re2nfa("a")
# to_dot(g, "a.dot")
# g = re2nfa("ab")
# to_dot(g, "ab.dot")
# g = re2nfa("a|b")
# to_dot(g, "ab2.dot")
# g = re2nfa("a|b|c")
# to_dot(g, "abc.dot")
g = re2nfa("ab|bc|cd")
to_dot(g, "abcd.dot")

# re2nfa("") == match anything
# re2nfa("a") == match to "a", "ab", "ba"
# re2nfa("ab") == match to "ab", "abb", "cab"
# re2nfa("a|b") == match to "a", "b", "cab"
# re2nfa("a*b") == match to "accb", "abb"

"abc|def|ged"




