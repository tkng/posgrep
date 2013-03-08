# -*- coding: utf-8 -*-
require "sinatra"
require "./nfa"

get "/" do
  @fp = open("m42.txt")
  erb :index
end

post "/search" do

  nfa = re2nfa(params["q"])
  puts params["q"]
  @results = []

  each_sentence(open("m4.txt")) do |sentence|
    text = sentence.map{|x| x[0]}.join("")
    r = 0
    posa = []
    for i in 0 .. sentence.size - 1
      posa.push [r, sentence[i][1]]
      r += sentence[i][0].length
    end

    result = search_pos(nfa, text, posa)
    p "result:" , result

    if result
      if result[0] == 0
        @results << "<span class='emphasis'>" + text[result[0] .. result[1]-1] + "</span>" + text[result[1] .. -1]
      else
        @results << text[0..result[0]-1] + "<span class='emphasis'>" + text[result[0] .. result[1]-1] + "</span>" + text[result[1] .. -1]
      end

    end
  end

  erb :search
end
