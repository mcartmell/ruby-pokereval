load '../merlion/lib/merlion/bot.rb'
require 'pokereval'
require 'ruby-prof'
board = "2h3h8d"
p1 = "4h8h"
p2 = "7s2d"
p3 = "AsAc"
pe = PokerEval.new

p3c = pe.get_cards(p1)
bc = pe.get_cards(board)


hand = "2h3h4h8h8h"
hand2 = "AhAd8c8s9h"
myc = pe.get_cards("AhAd8c8s9h")
p pe.hand_potential(p1, board)
exit
#puts PokerEvalAPI.StdDeck_StdRules_EVAL_N(myc, 5)
#puts PokerEvalAPI.Eval_Str_N(hand2)

p1h = pe.get_cards(p1)
boardh = pe.get_cards(board)
#puts p1h

RubyProf.start
%w{As5d AsJd Ah2h}.each do |hole|
	puts pe.get_equity(pocket: hole, board: '', iterations: 5000, num_opponents: 2)
end

result = RubyProf.stop
pr = RubyProf::GraphHtmlPrinter.new(result)
pr.print(STDOUT)
