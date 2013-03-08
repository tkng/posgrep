# -*- coding: utf-8 -*-

class Token
  attr_accessor :type, :val
  def initialize(type, val)
    @type = type; @val = val
  end
end

def create_char_acceptor(char1)
  lambda {|text, posa, i|
    [text[i] == char1, 1]}
end

def find_pos_by_position(posa, i)
  j = 0
  posa.each{|position, val|
    if position == i
      return j
    elsif position > i
      return false
    end
    j += 1
  }
  return false
end

def create_pos_acceptor(pos)
  lambda {|text, posa, i|
    j = find_pos_by_position(posa, i)
    # if j
    #   p ["f", i, pos, j, posa[j]]
    # else
    #   p ["nf", i, pos, j, false]
    # end
    if j and pos == posa[j][1]
      if posa[j+1]
        gap = posa[j+1][0] - posa[j][0]
      else
        gap = text.size - posa[j][0]
      end
      [true, gap]
    else
      [false, 1]
    end
  }
end

def epsilon_acceptor()
  lambda {|text, posa, i| [true, 1]}
end

def dot_acceptor()
  lambda {|text, posa, i| [true, 1]}
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
      elsif str[i] == "[" and str[i+1] == "["
        i += 2
        posname = ""
        while i < str.size and str[i] != "]"
          posname += str[i]
          i += 1
        end
        tokens.push Token.new(:pos, posname)
        i += 2
        next
      else
        tokens.push Token.new(:normal, str[i])
      end
      i += 1
    end
    return tokens
  end

  def consume()
    if @index >= @tokens.size
      return false
    end

    token = @tokens[@index]
    @index += 1
    return token
  end
end

class State
  attr_accessor :type, :prev_edge, :next_edges, :i
  @@index = 0
  def initialize(type)
    @type = type
    @prev_edge = []; @next_edges = []
    @i = @@index
    @@index += 1
  end
end

class StateEdge
  attr_accessor :type, :acceptor, :src, :dest
  def initialize(type, acceptor, src, dest)
    @type = type
    @acceptor = acceptor
    @src = src
    @dest = dest
  end
end

def connect(src, edge, dest)
  src.next_edges.push edge
  dest.prev_edge = edge
  return edge.dest
end

def merge_ends(ends, cur)
  ends.each do |e|
    e.prev_edge.dest = cur
  end
  return cur
end

def parse(lexer, start)
  cur = start
  prev = false
  ends = []

  while token = lexer.consume()
    case token.type
    when :normal
      s = State.new(:normal)
      prev = cur
      acceptor = create_char_acceptor(token.val)
      edge = StateEdge.new(:normal, acceptor, cur, s)
      cur = connect(cur, edge, s)
    when :pos
      s = State.new(:normal)
      prev = cur
      acceptor = create_pos_acceptor(token.val)
      edge = StateEdge.new(:normal, acceptor, cur, s)
      cur = connect(cur, edge, s)
    when :bar
      ends.push cur
      cur = start
      next
    when :lparen
      prev = cur
      cur = parse(lexer, cur)
    when :rparen
      return merge_ends(ends, cur)
    when :star
      edge = StateEdge.new(:epsilon, epsilon_acceptor, cur, prev)
      connect(cur, edge, prev)
      cur = prev
    when :dot
      s = State.new(:normal)
      prev = cur
      edge = StateEdge.new(:normal, dot_acceptor, cur, s)
      cur = connect(cur, edge, s)
    end
  end

  cur.type = :end
  return merge_ends(ends, cur)
end

def re2nfa(str)
  lexer = Lexer.new(str)
  start = State.new(:start)
  parse(lexer, start)
  return start
end

def match(nfa, text)
  clist = [[nfa, 0]] # current state list
  nlist = [] # next state list

  while clist.length != 0
    clist.each do |cstate, i|
      for edge in cstate.next_edges
        accepted, gap = edge.acceptor.call(text, [], i)
        if accepted
          if edge.dest.type == :end
            return true
          end
          nlist.push [edge.dest, i + gap]
        end
      end
    end
    clist = nlist
    nlist = []
  end
  return false
end


def each_sentence(fp, &block)
  s = []

  while line = fp.gets
    line.chomp!
    if line == ""
      block.call(s)
      s = []
    else
      s.push line.split("\t")
    end
  end

  if s.length != 0
    block.call(s)
  end
end

def match_pos(nfa, text, posa)
  clist = [[nfa, 0, 0]] # current state list
  nlist = [] # next state list

  while clist.length != 0
    clist.each do |cstate, i, start_pos|
      for edge in cstate.next_edges
        accepted, gap = edge.acceptor.call(text, posa, i)
        if accepted
          if edge.dest.type == :end
            return true
          end
          nlist.push [edge.dest, i + gap, start_pos]
        end
      end
    end
    clist = nlist
    nlist = []
  end
  return false
end

def search_pos(nfa, text, posa)
  clist = [] # current state list

  for i in 0 .. text.size - 1
    clist.push [nfa, i, i]
  end

  nlist = [] # next state list

  while clist.length != 0

    clist.each do |cstate, i, start_pos|
#      p "#{i} #{start_pos}"
      for edge in cstate.next_edges
        accepted, gap = edge.acceptor.call(text, posa, i)
        if accepted
          if edge.dest.type == :end
            return [start_pos, i + gap]
          end
          nlist.push [edge.dest, i + gap, start_pos]
        end
      end
    end
    clist = nlist
    nlist = []
  end
  return false
end


def put_graph_info(fp, state, visited)
  p "#{state.i}, #{state.type}"
  case state.type
  when :start
    fp.puts "#{state.i} [peripheries = 2];"
  when :end
    fp.puts "#{state.i} [peripheries = 3];"
  end

  for edge in state.next_edges
    next if visited[edge]
    visited[edge] = true
    if edge.type == :normal
      fp.puts "#{state.i} -> #{edge.dest.i} [label = \"#{edge.val}\"];"
      puts "#{state.i} -> #{edge.dest.i} [label = \"#{edge.val}\"];"
      put_graph_info(fp, edge.dest, visited)
    elsif edge.type == :epsilon
      fp.puts "#{state.i} -> #{edge.dest.i} [label = \" * \"];"
      puts "#{state.i} -> #{edge.dest.i} [label = \" * \"];"
    end
  end

end

def to_dot(graph, filename)
  puts "----------------------"
  wfp = open(filename, "w")
  wfp.puts "digraph sample {"
  put_graph_info(wfp, graph, {})
  wfp.puts "}"
  wfp.close
  puts "dot -Tpng #{filename} > #{filename.gsub('.dot', '.png')}"
  `dot -Tpng #{filename} > #{filename.gsub(".dot", ".png")}`
end

if __FILE__ == $0

# g = re2nfa("a*b")
# to_dot(g, "a.dot")

# g = re2nfa("a(b)*")
# to_dot(g, "a2.dot")

# g = re2nfa("(a|b|c)*")
# to_dot(g, "a3.dot")

  # g = re2nfa("a(ab|cd|x(ef|gh))")
  # to_dot(g, "a4.dot")

  # g = re2nfa("ab")
  # to_dot(g, "ab.dot")
  # g = re2nfa("a|b")
  # to_dot(g, "ab2.dot")
  # g = re2nfa("a|b|c")
  # to_dot(g, "abc.dot")
  # g = re2nfa("ab|bc|cd")
  # to_dot(g, "abcd.dot")

  # p match(re2nfa("a.*b"), "aggggb")
  # p match(re2nfa("a.*b"), "gggg")
  # p match(re2nfa(".*"), "")
  # p match(re2nfa(".*"), "fofofo")
  # p match(re2nfa("a|b"), "a")
  # p match(re2nfa("a|b"), "b")
  # p match(re2nfa("a|b"), "c")
  # p match(re2nfa("a(b|c)d"), "abd")
  # p match(re2nfa("a(b|c)d"), "acd")
  # p match(re2nfa("a(b|c)d"), "acc")
  # p match(re2nfa("a(b|c)*d"), "ad")
  # p match(re2nfa("a(b|c)*d"), "abbd")

  re = re2nfa("[[名詞-普通名詞-一般]].*[[名詞-普通名詞-一般]].*")

  each_sentence(open("m42.txt")) do |sentence|
    text = sentence.map{|x| x[0]}.join("")
    r = 0
    posa = []
    for i in 0 .. sentence.size - 1
      posa.push [r, sentence[i][1]]
      r += sentence[i][0].length
    end

    result = search_pos(re, text, posa)

    if result
      puts "------------------------"
      p text
      p result
      p sentence
    end
  end

  # re2nfa("") == match anything
  # re2nfa("a") == match to "a", "ab", "ba"
  # re2nfa("ab") == match to "ab", "abb", "cab"
  # re2nfa("a|b") == match to "a", "b", "cab"
  # re2nfa("a*b") == match to "accb", "abb"

end




