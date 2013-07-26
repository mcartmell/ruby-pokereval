require 'ffi'
require 'pp'

# The FFI wrapper module
module PokerEvalAPI
	extend FFI::Library
	@results = []

	class Cards < FFI::Struct
		layout :spades, :uint16,
		:clubs, :uint16,
		:diamonds, :uint16,
		:hearts, :uint16
	end

	# A struct representing a cardmask
	class CardMask < FFI::Struct
		layout :cards_n, :uint64

		# Add cards from another cardmask to this set
		# @param other [PokerEvalAPI::CardMask]
		#
		# @example
		#		cardmask << other_cardmask
		def << (other)
			self[:cards_n] = self[:cards_n] | other[:cards_n]
		end

		# Get the raw integer from this struct
		def cards_n
			self[:cards_n]
		end

		# Returns an integer score representing the value of this hand, for use in comparisons
		#
		# @param i [Integer] The number of cards in the hand
		def eval(i)
			return PokerEvalAPI.StdDeck_StdRules_EVAL_N(self,i)
		end

		# Returns a string representation of these cards
		def to_s
			return PokerEvalAPI.wrap_StdDeck_maskString(self).gsub(/\s+/, '')
		end

		def type
			type = PokerEvalAPI.StdDeck_StdRules_EVAL_TYPE(self, count)
			return PokerEval::HandTypes[type]
		end

		# Returns the number of cards in this set
		def count
			return PokerEvalAPI.wrap_StdDeck_numCards(self)
		end

		# Adds a single card to this set by specifying its index
		#
		#	@param i [Integer] The card index to add
		def set(i)
			mask = PokerEvalAPI.wrap_StdDeck_MASK(i)
			self << mask
		end

		# Returns true if the given card is in this set
		#
		# @param i [Integer] The card index to check
		def is_set(i)
			mask = PokerEvalAPI.wrap_StdDeck_MASK(i)
			return any_set(mask)
		end

		# Returns true if any of the given cards are in the set
		#
		# @param m [PokerEvalAPI::CardMask] The cards to check
		def any_set(m)
			return ((self[:cards_n] & m[:cards_n]) != 0)
		end
	end

	def self.results
		@results
	end

	ffi_lib File.dirname(__FILE__) + '/../ext/poker-eval-api/poker-eval-api.so'

	callback :completion_function, [:int, CardMask.by_value], :void
	attach_function :TextToPokerEval, [:string], CardMask.by_value
	attach_function :StdDeck_StdRules_EVAL_TYPE, [CardMask.by_value, :int], :int
	attach_function :StdDeck_StdRules_EVAL_N, [CardMask.by_value, :int], :int
	attach_function :handStrength, [CardMask.by_value, CardMask.by_value], :double
	attach_function :handPotential, [:string, :string, :pointer, :int], :int
	attach_function :evalOuts, [:string, :int, :string, :int, :int, :completion_function], :int
	attach_function :scoreTwoCards, [:string, :string, :completion_function], :int
	attach_function :Eval_Str_N, [:string], :int
	attach_function :Eval_Str_Type, [:string], :int
	attach_function :TextToPtr, [:string], :pointer
	attach_function :wrap_StdDeck_MAKE_CARD, [:int, :int], :int
	attach_function :wrap_StdDeck_MASK, [:int], CardMask.by_value
	attach_function :wrap_StdDeck_maskString, [CardMask.by_value], :string
	attach_function :wrap_StdDeck_numCards, [CardMask.by_value], :int
	attach_function :wrap_StdDeck_RANK, [:uint], :uint
	attach_function :wrap_StdDeck_SUIT, [:uint], :uint

end

class PokerEval

	HandTypes = [
	"NoPair",
	"OnePair",
	"TwoPair",
	"Trips",
	"Straight",
	"Flush",
	"FullHouse",
	"Quads",
	"StraightFlush"
	]

	Ranks = {
		'A' => 14,
		'K' => 13,
		'Q' => 12,
		'J' => 11,
		'T' => 10,
		'9' => 9,
		'8' => 8,
		'7' => 7,
		'6' => 6, 
		'5' => 5,
		'4' => 4,
		'3' => 3,
		'2' => 2
	}

	HandGroups = {
		1 => %w{AA KK QQ JJ AKs},
		2 => %w{TT AQs AJs KQs AKo},
		3 => %w{99 ATs KJs QJs TJs AQo},
		4 => %w{88 KTs QTs J9s T9s 98s AJo KQo},
		5 => %w{77 A9s A8s A7s A6s A5s A4s A3s A2s Q9s T8s 97s 87s 76s KJo QJo JTo},
		6 => %w{66 55 K9s J8s 86s 75s 54s ATo KTo QTo},
		7 => %w{44 33 22 K8s K7s K6s K5s K4s K3s K2s Q8s T7s 64s 53s 43s J9o T9o 98o}
	}

	# Scores a single hand, passed by string
	#
	# @param hand [String] The player's pocket cards
	# @param board [String] The board cards
	# @return [Integer] The score of the hand
	def score_hand(hand, board)
		return PokerEvalAPI.Eval_Str_N(hand + board)
	end

	# Classifies the hand (one pair, two pair, flush etc.)
	#
	# @param hand [String] The player's pocket cards
	# @param board [String] The board cards
	# @return [String] A string representing the hand type
	def type_hand(hand, board)
		type = PokerEvalAPI.Eval_Str_Type(hand + board)
		return HandTypes[type]
	end

	# Compares two hands by evaluating them against the current board
	# 
	# @param p1 [String] The first player's pocket cards
	# @param p2 [String] The second player's pocket cards
	# @param board [String] The board cards
	# @return [Integer] 1 if p1 wins, -1 if p2 wins, 0 of they are equal
	def compare_hands(p1,p2,board)
		p1score = PokerEvalAPI.Eval_Str_N(p1 + board)
		p2score = PokerEvalAPI.Eval_Str_N(p2 + board)
		return -1 if p1score < p2score
		return 0 if p1score == p2score
		return 1 if p1score > p2score
	end

	# Returns the EHS of the current hand
	# 
	# @param pocket [String] The player's pocket cards
	# @param board [String] The board cards
	# @param hs [Integer] (optional) The hand strength to use in the calculation. If not specified, will be calculated
	# @param use_npot [Boolean] (optional, default false) Whether or not to return the negative potential
	def effective_hand_strength(pocket, board, hs = nil, use_npot = false)
		return 0 if pocket.empty? || board.empty?
		hs ||= str_to_hs(pocket, board)
		(ppot, npot) = hand_potential(pocket, board)
		npot = 0 unless use_npot
		ehs = hs * (1 - npot) + (1 - hs) * ppot
		return {
			ehs: ehs,
			ppot: ppot,
			npot: npot
		}
	end

	def get_weight_from_table(cards, weight_table = {})
		return weight_table[cards.cards_n] || 1
	end

	# Returns the hand strength using the poker-eval library
	#
	# @return [Float]
	def hs(*a)
		return PokerEvalAPI.handStrength(*a)
	end

	# Returns the hand strength using the poker-eval library
	#
	# @param pocket [String] The player's pocket cards
	# @param board [String] The player's board cards
	# @return [Float]
	def str_to_hs(pocket, board)
		return hs(get_cards(pocket), get_cards(board))
	end

	# Returns the hand strength using Ruby
	#
	# @param pocket [String] The player's pocket cards
	# @param board [String] The board cards
	# @param opponents [Integer] (default: 1) The number of opponents
	#	@param weight_table [Hash] (default: {}) A weight table to adjust the score given to each pair of opponent's cards.
	def hand_strength(pocket, board, opponents = 1, weight_table = {})
		ahead = tied = behind = 0
		score = PokerEvalAPI.Eval_Str_N(pocket + board)
		weighted_proc = Proc.new do |i, cards|
			w = get_weight_from_table(cards, weight_table)
			ahead += w if score > i
			tied += w if score == i
			behind += w if score < i
		end
		normal_proc =  Proc.new do |i, cards|
			ahead += 1 if score > i
			tied += 1 if score == i
			behind += 1 if score < i
		end
		cb = weight_table.empty? ? normal_proc : weighted_proc
		PokerEvalAPI.scoreTwoCards(pocket, board, cb)
		handstrength = (ahead+tied/2.0) / (ahead+tied+behind)
		return handstrength ** opponents
	end

	# Does a montecarlo simulation to estimate the strength of a given hand
	#	
	# @option options [String] :pocket The player's hole cards
	# @option options [String] :board The board cards
	# @option options [Integer] :iterations The number of montecarlo simulations
	# @option options [Integer] :num_opponents The number of opponent hands to simulate
	# @return [Float] The percentage of times the player's hand wins
	def get_equity(options = {})
		defaults = {
			pocket: '',
			board: '',
			iterations: 500,
			num_opponents: 1
		}

		options = defaults.merge(options)

		pocket = options[:pocket]
		board = options[:board]
		num_opponents = options[:num_opponents]
		num_iter = options[:iterations]

		pcards = get_cards(pocket)
		bcards = get_cards(board)
		dead = new_cards
		dead << pcards
		dead << bcards
		player_sizes = [2] * num_opponents
		player_sizes << 5 - bcards.count

		ahead = tied = behind = 0

		montecarlo_sets(player_sizes, dead, num_iter) do |sets|
			board = sets.pop
			ours = dead.clone
			ours << board
			ourscore = ours.eval(7)
			
			oppscores = sets.map {|cards| cards << board; cards.eval(7)}
			score = oppscores.max
			ahead += 1 if ourscore > score
			tied += 1 if ourscore == score
			behind += 1 if ourscore < score
		end

		equity = (ahead+tied/2.0) / (ahead+tied+behind)
		return equity
	end

	def mc_hand_potential(ours, board, num_iter = 100)
		set_sizes = [2,1]
		dead = ours.clone
		dead << board

		our_current = ours.clone
		our_current << board
		our_rank = our_current.eval(our_current.count)

		hp = [[], [], []]

		montecarlo_sets(set_sizes, dead, num_iter) do |sets|
			our_hand = ours.clone
			board_cards = board.clone
			our_hand << board_cards

			opp = sets.pop
			bc = sets.pop

			opp_current = opp.clone
			opp_current << board
			opp_rank = opp_current.eval(opp_current.count)

			cur_idx = if our_rank > opp_rank
									0
								elsif opp_rank > our_rank
									2
								else
									1
								end

			our_next = our_current.clone
			our_next << bc

			opp_next = opp_current.clone
			opp_next << bc

			our_next_rank = our_next.eval(our_next.count)
			opp_next_rank = opp_next.eval(opp_next.count)

			next_idx = if our_next_rank > opp_next_rank
									 0
								 elsif opp_next_rank > our_next_rank
									 2
								 else
									 1
								 end
			hp[cur_idx][next_idx] ||= 0
			hp[cur_idx][next_idx] += 1
		end
		ppot = ((hp[2][0] || 0) / 100.to_f)
		return ppot
	end

	# Returns the hand potential (positive and negative) of the current hand
	# By default will only do a one-card lookahead
	#
	# @param pocket [String] The player's hole cards
	# @param board [String] The board cards
	# @param maxcards [Integer] The maximum number of cards to score (7 is 2-card lookahead, 6 is 1-card)
	# @return [Array] 
	def hand_potential(pocket, board, maxcards = 6)
		if ((board.length / 2) == 5)
			return [0,0]
		end
		ppot = FFI::MemoryPointer.new(:pointer, 1);
		PokerEvalAPI.handPotential(pocket, board, ppot, maxcards)
		return ppot.read_pointer.read_string.split("|").map{|e| e.to_f}
	end

	# @param pocket [String] Hole cards
	# @param board [String] Board cards
	# @return [Hash] Probability of hitting each type of hand
	# @example
	#		outs = pe.eval_outs("7s7c", "8h9dJs")
	def eval_outs(pocket, board)
		psize = pocket.length / 2
		bsize = board.length / 2

		stages = {
			'3' => "Flop",
			'4' => "Turn",
			'5' => "River"
		}

		r_stages = {}

		# 3..5 = for flop, turn, river
		(3..5).each do |tot|
			next if tot <= bsize
			stage = stages[tot.to_s]

			results = []

			# simple callback to fetch results for each iteration
			cb = Proc.new do |i,cards|
				results.push(i)
			end

			# run the eval
			PokerEvalAPI.evalOuts(pocket, psize, board, bsize, tot, cb)

			stats = []

			# collect stats for each type of hand
			results.each do |e|
				stats[e] = (stats[e] || 0) + 1
			end

			# get sum
			total = stats.inject(0) {|sum, n| sum += (n || 0)}

			stats_name = {}

			# get percentages
			(0..8).each do |i|
				pct = (((stats[i] || 0) / total.to_f) * 100)
				stats_name[HandTypes[i]] = pct
			end
			
			# set percentages for this stage
			r_stages[stage] = stats_name
		end

		# return percentages
		return r_stages
	end

	# Returns a random card (as a PokerEvalAPI::CardMask)
	def random_card
		return PokerEvalAPI.wrap_StdDeck_MASK(rand(52))
	end

	#	Performs a montecarlo simulation, yielding the generated cards
	def montecarlo(dead, num_cards, num_iter)
		num_iter.times do
			cards = new_cards
			used = dead.clone
			num_cards.times do
				add_random_card_not_in(cards, used)
			end
			yield cards
		end
	end

	# Returns a random pair of cards that are not contained in the given string of cards
	def get_random_hand_not_in_str(str)
		get_random_cards_not_in_str(str)
	end

	def get_random_cards_not_in_str(str, i = 2)
		used = get_cards(str)
		cards = new_cards
		i.times do
			add_random_card_not_in(cards, used)
		end
		return cards.to_s
	end

	def get_random_card_not_in_str(str)
		get_random_cards_not_in_str(str, 1)
	end

	# Adds one random card that's not in the given set of used cards 
	def add_random_card_not_in(cards, used)
		loop do
			card = random_card
			unless used.any_set(card)
				cards << card
				used << card
				break
			end
		end
	end

	# Deals random cards in the given sizes of sets, up to the requested number of iterations
	# This can be used for Montecarlo simulations.
	#
	# @param set_sizes [Array] The number of cards in each set
	# @param dead [PokerEvalAPI::CardMask] Cards to exclude from the selection
	# @param num_iter [Integer] The number of iterations
	def montecarlo_sets(set_sizes, dead, num_iter)
		num_iter.times do
			used = dead.clone
			sets = []
			set_sizes.each do |size|
				set_cards = new_cards
				size.times do
					add_random_card_not_in(set_cards, used)
				end
				sets << set_cards
			end
			yield sets
		end
	end

	# Returns an empty CardMask
	# @return [PokerEvalAPI::CardMask]
	def new_cards
		return PokerEvalAPI::CardMask.new
	end

	# Returns a CardMask for the given string
	#
	# @param str [String] The string representing the cards, eg. AsAc
	# @return [PokerEvalAPI::CardMask]
	def get_cards(str)
		return PokerEvalAPI.TextToPokerEval(str)
	end

	def mask_to_str(cards_n)
		cm = PokerEvalAPI::CardMask.new
		cm[:cards_n] = cards_n
		return cm.to_s
	end

	def rank_to_num(rank)
		return Ranks[rank]
	end

	def card_rank(card)
		return Ranks[card[0]]
	end

	# Returns a short abbreviation of the current hand, eg. AA, AKs or AKo
	# @param str [String] The string representing the current hand
	# @return [String] The abbreviation for the given hand
	def str_to_abbr(str)
		chars = str.split(//)

		if (Ranks[chars[2]] > Ranks[chars[0]])
			chars = [chars[2], chars[3], chars[0], chars[1]]
		end

		suited = ''
		if chars[1] == chars[3] 
			suited = 's'
		elsif chars[0] != chars[2]
			suited = 'o'
		end
		return chars[0] + chars[2] + suited
	end

	# Returns the rank of the card as an integer
	# @param idx [Integer] The card index
	# @return [Integer] The card rank
	def card_idx_to_rank(idx)
		return PokerEvalAPI.wrap_StdDeck_RANK(idx)
	end

	# Returns the suit of the card as an integer
	# @param idx [Integer] The card index
	# @return [Integer] The card suit
	def card_idx_to_suit(idx)
		return PokerEvalAPI.wrap_StdDeck_SUIT(idx)
	end

	# Calculates the 'Sklansky group' of 2 hole cards, where 1 is the best and 8 is the worst.
	# @param hand_str [String] The hole cards
	# @return [Integer] The Sklansky group
	def hand_to_sklansky_group(hand_str)
		abbr = str_to_abbr(hand_str)
		HandGroups.each do |group, hands|
			if hands.include?(abbr)
				return group
			end
		end
		return 8
	end

end
