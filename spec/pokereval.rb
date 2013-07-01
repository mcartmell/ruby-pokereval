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
end
