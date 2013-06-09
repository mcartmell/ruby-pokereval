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
	end


	def self.results
		@results
	end

	ffi_lib File.dirname(__FILE__) + '/../ext/poker-eval-api/poker-eval-api.so'

	callback :completion_function, [:int], :void
	attach_function :evalOuts, [:pointer, :int, :string, :int, :int, :completion_function], :int
	attach_function :scoreTwoCards, [:string, :string, :completion_function], :int
	attach_function :Eval_Str_N, [:string], :int

	attach_function :StdDeck_StdRules_EVAL_TYPE, [:uint64, :int], :int
	attach_function :StdDeck_StdRules_EVAL_N, [:uint64, :int], :int
	attach_function :TextToPokerEval, [:string], :uint64

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

	def compare_hands(p1,p2,board)
		p1score = PokerEvalAPI.Eval_Str_N(p1 + board)
		p2score = PokerEvalAPI.Eval_Str_N(p2 + board)
		return -1 if p1score < p2score
		return 0 if p1score == p2score
		return 1 if p1score > p2score
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
end
