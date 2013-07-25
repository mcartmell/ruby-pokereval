#load '../merlion/lib/merlion/bot.rb'
require 'benchmark'
require 'pokereval'
require 'ruby-prof'
board = "2h3h8d"
p1 = "4h5h"
p2 = "7s2d"
p3 = "AsAc2h"
pe = PokerEval.new

p3c = pe.get_cards(p1)
bc = pe.get_cards(board)

p p3c.any_set(bc)

wt = {}
(0..51).each do |o|
  (0..o).each do |t|
    next if o == t
    cards = pe.new_cards
    cards.set(o)
    cards.set(t)
    wt[cards.cards_n] = 1
  end
end

used_cards = pe.get_cards(board)

ppot = pe.mc_hand_potential(p3c, bc)
puts ppot
puts pe.hand_potential(p1, board)

puts Benchmark.measure {
	wt.keys.each do |cards|
		cm = PokerEvalAPI::CardMask.new
		cm[:cards_n] = cards
		if (cards & used_cards.cards_n) != 0
			next
		end
		str = pe.mask_to_str(cards)
		#pe.mc_hand_potential(cm, bc)
		pe.hand_potential(str, board)
	end
}
exit

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
