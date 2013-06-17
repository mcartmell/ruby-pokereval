require 'ffi'
require 'pp'

module PokerEvalAPI
	extend FFI::Library
	@results = []

	class Cards < FFI::Struct
		layout :spades, :uint16,
		:clubs, :uint16,
		:diamonds, :uint16,
		:hearts, :uint16
	end

	class CardMask < FFI::Struct
		layout :cards_n, :uint64

		def << (other)
			self[:cards_n] = self[:cards_n] | other[:cards_n]
		end

		def eval(i)
			return PokerEvalAPI.StdDeck_StdRules_EVAL_N(self,i)
		end

		def to_s
			return PokerEvalAPI.wrap_StdDeck_maskString(self)
		end

		def count
			return PokerEvalAPI.wrap_StdDeck_numCards(self)
		end

		def set(i)
			mask = PokerEvalAPI.wrap_StdDeck_MASK(i)
			self | mask
		end

		def is_set(i)
			mask = PokerEvalAPI.wrap_StdDeck_MASK(i)
			return any_set(mask)
		end

		def any_set(m)
			return ((self[:cards_n] & m[:cards_n]) != 0)
		end

	end

	def self.results
		@results
	end

	ffi_lib File.dirname(__FILE__) + '/../ext/poker-eval-api/poker-eval-api.so'

	callback :completion_function, [:int], :void
	attach_function :evalOuts, [:pointer, :int, :string, :int, :int, :completion_function], :int
	attach_function :scoreTwoCards, [:string, :string, :completion_function], :int
	attach_function :Eval_Str_N, [:string], :int
	attach_function :Eval_Str_Type, [:string], :int

	attach_function :StdDeck_StdRules_EVAL_TYPE, [:uint64, :int], :int
	attach_function :StdDeck_StdRules_EVAL_N, [CardMask.by_value, :int], :int
	attach_function :TextToPokerEval, [:string], CardMask.by_value
	attach_function :TextToPtr, [:string], :pointer
	attach_function :Eval_Ptr, [:pointer, :int], :int
	attach_function :handPotential, [:string, :string, :pointer], :int
	attach_function :wrap_StdDeck_MAKE_CARD, [:int, :int], :int
	attach_function :wrap_StdDeck_MASK, [:int], CardMask.by_value
	attach_function :wrap_StdDeck_maskString, [CardMask.by_value], :string
	attach_function :wrap_StdDeck_numCards, [CardMask.by_value], :int

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

	def score_hand(hand, board)
		return PokerEvalAPI.Eval_Str_N(hand + board)
	end

	def type_hand(hand, board)
		type = PokerEvalAPI.Eval_Str_Type(hand + board)
		return HandTypes[type]
	end

	def compare_hands(p1,p2,board)
		p1score = PokerEvalAPI.Eval_Str_N(p1 + board)
		p2score = PokerEvalAPI.Eval_Str_N(p2 + board)
		return -1 if p1score < p2score
		return 0 if p1score == p2score
		return 1 if p1score > p2score
	end

	def effective_hand_strength(pocket, board)
		hs = hand_strength(pocket, board)
		(ppot, npot) = hand_potential(pocket, board)
		ehs = hs * (1 - npot) + (1 - hs) * ppot
		return ehs
	end

	def hand_strength(pocket, board, opponents = 1)
		ahead = tied = behind = 0
		score = PokerEvalAPI.Eval_Str_N(pocket + board)
		cb = Proc.new do |i|
			ahead += 1 if score > i
			tied += 1 if score == i
			behind += 1 if score < i
		end
		PokerEvalAPI.scoreTwoCards(pocket, board, cb)
		handstrength = (ahead+tied/2.0) / (ahead+tied+behind)
		return handstrength ** opponents
	end

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

	def hand_potential(pocket, board)
		ppot = FFI::MemoryPointer.new(:pointer, 1);
		PokerEvalAPI.handPotential(pocket, board, ppot)
		return ppot.read_pointer.read_string.split("|").map{|e| e.to_f}
	end

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
			cb = Proc.new do |i|
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

	def random_card
		return PokerEvalAPI.wrap_StdDeck_MASK(rand(52))
	end

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

	def new_cards
		return PokerEvalAPI::CardMask.new
	end

	def get_cards(str)
		return PokerEvalAPI.TextToPokerEval(str)
	end
end
