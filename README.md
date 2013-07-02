# ruby-pokereval

An interface to the [poker-eval](http://pokersource.sourceforge.net/) C library, and various other functions written in Ruby.

# Example usage
## Quick calculations
```ruby
require 'pokereval'
pe = PokerEval.new

# Get the type of a given hand
hand_type = pe.type_hand("2h3h", "4h5h6h"); ## StraightFlush

# Get the strength of a hand
hs = pe.str_to_hs("AsAd", "5s7d8c")

# Get the potential of a hand
(ppot, npot) = pe.hand_potential("2h3h", "4h5h9c")

# Get the effective hand strength
ehs = pe.effective_hand_strength("2h3h", "4h5h9c")

# Return the probability of hitting each type of hand on later stages
outs = pe.eval_outs("7s7c", "8h9dJs")
```

## Wrappers for the original C functions
``ruby
hand = "9s9d9h4d4c"
mask = PokerEvalAPI.TextToPokerEval(hand)

# Evaluate the type of a hand
type = PokerEvalAPI.StdDeck_StdRules_EVAL_TYPE(mask, 5) # 6 - FullHouse

# Evaluate the score of a hand
score = PokerEvalAPI.StdDeck_StdRules_EVAL_N(mask, 5) # hand score for comparison
```

#TODO

* Wrappers for the enumeration and Monte Carlo simulations are not yet finished

# See also

* [A Pokersource Poker-Eval Primter](http://www.codingthewheel.com/archives/a-pokersource-poker-eval-primer/)
* [Computer Poker Research Group @ University of Alberta](http://poker.cs.ualberta.ca/)
