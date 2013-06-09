load 'lib/pokereval.rb'
board = "7h8h9h"
p1 = "5hJh"
p2 = "AsAd"
pe = PokerEval.new

#puts pe.score_hand(p1,board)
#puts pe.score_hand(p2,board)
#puts pe.compare_hands(p1,p2,board)
puts pe.hand_strength(p1, board)
#p1b = PokerEvalAPI.wrap_StdDeck_CardMask_OR(p1,board)
#p2b = PokerEvalAPI.wrap_StdDeck_CardMask_OR(p2,board)
