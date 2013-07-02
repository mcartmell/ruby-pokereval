require 'pokereval'

describe PokerEval do
	pe = PokerEval.new
	it "Can abbreviate hands" do
		pe.str_to_abbr('TcJc').should eq('JTs')
		pe.str_to_abbr('TcJh').should eq('JTo')
		pe.str_to_abbr('TcTh').should eq('TT')
		pe.str_to_abbr('2hAh').should eq('A2s')
	end

	it "Can get Sklansky groups" do
		pe.hand_to_sklansky_group("AsAc").should eq(1)
		pe.hand_to_sklansky_group("2s7c").should eq(8)
		pe.hand_to_sklansky_group("9sTs").should eq(4)
	end

	it "Can get suits from index" do
		pe.card_idx_to_suit(3).should eq(0)
		pe.card_idx_to_suit(13).should eq(1)
	end

	it "Can get ranks from index" do
		pe.card_idx_to_rank(3).should eq(3)
		pe.card_idx_to_rank(13).should eq(0)
	end

	it "Can get ranks from string" do
		pe.card_rank('2c').should eq(2)
		pe.card_rank('Ac').should eq(14)
	end

	it "Can convert string to cardmask and back" do
		cards = pe.get_cards('AsJs')	
		expect(cards).to be_an_instance_of(PokerEvalAPI::CardMask)
		expect(cards).to be_an_instance_of(PokerEvalAPI::CardMask)
		cstr = pe.mask_to_str(cards[:cards_n])
		expect(cstr).to eq('AsJs')
	end

	it "Can type hands" do
		hand_type = pe.type_hand("2h3h", "4h5h6h")
		expect(hand_type).to eq('StraightFlush')
		hand_type = pe.type_hand("2h3h", "4h5h7h")
		expect(hand_type).to eq('Flush')
		hand_type = pe.type_hand("2h3h", "4h5h6d")
		expect(hand_type).to eq('Straight')
		hand_type = pe.type_hand("2h2d", "4h5h6d")
		expect(hand_type).to eq('OnePair')
		hand_type = pe.type_hand("2h2d", "4h4d6d")
		expect(hand_type).to eq('TwoPair')
		hand_type = pe.type_hand("2h2d", "4h4d4c")
		expect(hand_type).to eq('FullHouse')
		hand_type = pe.type_hand("Th2d", "4h4d4c")
		expect(hand_type).to eq('Trips')
		hand_type = pe.type_hand("Th2d", "5h3d9c")
		expect(hand_type).to eq('NoPair')
	end

	it "Can compare hands" do
		cmp = pe.compare_hands("2h3h", "7s2d", "4h5h6h")
		expect(cmp).to eq(1)
		cmp = pe.compare_hands("9hTd", "7s2d", "2c5h6h")
		expect(cmp).to eq(-1)
		cmp = pe.compare_hands("9hTd", "7s2d", "2h3h4h5h6h")
		expect(cmp).to eq(0)
	end

	it "Can get HS" do
		hs = pe.str_to_hs("AsAd", "5s7d8c")
		expect(hs).to be > 0.9
		hs = pe.str_to_hs("7s2d", "5s9d8c")
		expect(hs).to be < 0.2
		hs_from_ruby = pe.hand_strength("7s2d", "5s9d8c")
		expect(hs_from_ruby).to eq(hs)
	end

	it "Can get hand potentials" do
		(ppot, npot) = pe.hand_potential("2h3h", "4h5h9c")
		expect(ppot).to be > 0.3
		(ppot, npot) = pe.hand_potential("Td5s", "4h5h9c")
		expect(npot).to be > 0.1
	end
end

describe PokerEvalAPI do
	thand = "9s9d9h4d4c"
	tmask = PokerEvalAPI.TextToPokerEval(thand)

	it "Can convert string to mask" do
		mask = PokerEvalAPI.TextToPokerEval("AsAd2h2d2c")
		expect(mask).to be_an_instance_of(PokerEvalAPI::CardMask)
	end

	it "Can call methods on CardMask instance" do
		hand = "9s9d9h4d4c"
		mask = PokerEvalAPI.TextToPokerEval(hand)
		expect(mask.type).to eq('FullHouse')
		expect(mask.count).to eq(5)
		expect(mask.to_s).to eq("9s4c9d4d9h")
	end

	it "Can get score of a hand" do
		score = PokerEvalAPI.StdDeck_StdRules_EVAL_N(tmask, 5)
		expect(score).to eq(101130240)
	end

	it "Can get type of a hand" do
		type = PokerEvalAPI.StdDeck_StdRules_EVAL_TYPE(tmask, 5)
		expect(type).to eq(6)
	end

end
