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
	attach_function :myeval, [:pointer, :int, :string, :int, :int, :completion_function], :int

	attach_function :StdDeck_StdRules_EVAL_TYPE, [:uint64, :int], :int
	attach_function :wrap_StdDeck_MASK, [:int], :uint64
	attach_function :TextToPokerEval, [:string], :uint64
	attach_function :wrap_StdDeck_MAKE_CARD, [:uint, :uint], :int
	attach_function :wrap_StdDeck_CardMask_OR, [:pointer, :pointer], :pointer

	Callback = Proc.new do |p|
		@results.push(p)
	end
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

	def make_card(r,s)
		idx = PokerEvalAPI.wrap_StdDeck_MAKE_CARD(r,s)
		mask = PokerEvalAPI.wrap_StdDeck_MASK(idx)
		card = PokerEvalAPI::CardMask.new
		card[:cards_n] = mask
		return card
	end

	def gen_pockets(pockets)
		strptrs = []
		strptrs = pockets.map {|e| FFI::MemoryPointer.from_string(e)}
		argv = FFI::MemoryPointer.new(:pointer, strptrs.length)
		strptrs.each_with_index do |p, i|
			argv[i].put_pointer(0, p)
		end
		return argv
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

		(3..5).each do |tot|
			next if tot <= bsize
			stage = stages[tot.to_s]

			results = []

			cb = Proc.new do |i|
				results.push(i)
			end

			PokerEvalAPI.myeval(pocket, psize, board, bsize, tot, cb)

			stats = []

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
			r_stages[stage] = stats_name
		end
		return r_stages

	end

	def test
		res = eval_outs("7s8s", "")
		pp res
	end

end
