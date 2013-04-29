#include "poker-eval/poker_defs.h"
#include "poker-eval/enumdefs.h"
#include <poker_wrapper.h>

extern uint8 nBitsAndStrTable[StdDeck_N_RANKMASKS];

StdDeck_CardMask TextToPokerEval(const char* strHand)
{
    StdDeck_CardMask theHand, theCard;
    StdDeck_CardMask_RESET(theHand);

    if (strHand && strlen(strHand))
    {
        int cardIndex = -1;
        char* curCard = strHand;
        while (*curCard)
        {
            // Take the card text and convert it to an index (0..51)
            StdDeck_stringToCard(curCard, &cardIndex);
            // Convert the card index to a mask
            theCard = StdDeck_MASK(cardIndex);
            // Add the card (mask) to the hand
            StdDeck_CardMask_OR(theHand, theHand, theCard);
            // Advance to the next card (if any)
            curCard += 2;
        }
    }
    return theHand;
}

void evalSingleType(StdDeck_CardMask player, StdDeck_CardMask board, int tot, void *callback(int)) {
	StdDeck_CardMask_OR(player, player, board);
	int type = StdDeck_StdRules_EVAL_TYPE(player, tot);
	callback(type);
	return;
}

int myeval(char* str_pocket, int npockets, char* str_board, int nboard, int totboard, void *callback(int)) {
		// totboard = total cards wanted on board
		int i = totboard - nboard; // total cards to enumerate
		int tot = totboard + 2; // total cards including player
    StdDeck_CardMask board;
    StdDeck_CardMask dead;
    StdDeck_CardMask pocket;
    StdDeck_CardMask_RESET(pocket);
    StdDeck_CardMask_RESET(board);
    StdDeck_CardMask_RESET(dead);
    StdDeck_CardMask pockets[ENUM_MAXPLAYERS];

		pocket = TextToPokerEval(str_pocket);
		board = TextToPokerEval(str_board);
		StdDeck_CardMask_OR(dead,dead,pocket);
		StdDeck_CardMask_OR(dead,dead,board);

		StdDeck_CardMask_OR(pocket, pocket, board);

		DECK_ENUMERATE_N_CARDS_D(StdDeck, board, i, dead, evalSingleType(pocket, board, tot, callback););
		return 1;
}

int 
StdDeck_StdRules_EVAL_TYPE( StdDeck_CardMask cards, int n_cards )
{
  uint32 ranks, four_mask, three_mask, two_mask, 
    n_dups, n_ranks, is_st_or_fl = 0, t, sc, sd, sh, ss;

  sc = StdDeck_CardMask_CLUBS(cards);
  sd = StdDeck_CardMask_DIAMONDS(cards);
  sh = StdDeck_CardMask_HEARTS(cards);
  ss = StdDeck_CardMask_SPADES(cards);

  ranks = sc | sd | sh | ss;
  n_ranks = nBitsAndStrTable[ranks] >> 2;
  n_dups = n_cards - n_ranks;

  if (nBitsAndStrTable[ranks] & 0x01) { /* if n_ranks > 5 */
    if (nBitsAndStrTable[ranks] & 0x02)
      is_st_or_fl = StdRules_HandType_STRAIGHT;

    t = nBitsAndStrTable[ss] | nBitsAndStrTable[sc]
      | nBitsAndStrTable[sd] | nBitsAndStrTable[sh];

    if (t & 0x01) {
      if (t & 0x02) 
        return StdRules_HandType_STFLUSH;
      else 
        is_st_or_fl = StdRules_HandType_FLUSH;
    };

    if (is_st_or_fl && n_dups < 3)
      return is_st_or_fl;
  };

  switch (n_dups) {
  case 0:
    return StdRules_HandType_NOPAIR;
    break;

  case 1:
    return StdRules_HandType_ONEPAIR;
    break;

  case 2:
    two_mask = ranks ^ (sc ^ sd ^ sh ^ ss);
    return (two_mask != 0) 
      ? StdRules_HandType_TWOPAIR 
      : StdRules_HandType_TRIPS;
    break;

  default:
    four_mask  = (sc & sd) & (sh & ss);
    if (four_mask) 
      return StdRules_HandType_QUADS;
    three_mask = (( sc&sd )|( sh&ss )) & (( sc&sh )|( sd&ss ));
    if (three_mask) 
      return StdRules_HandType_FULLHOUSE;
    else if (is_st_or_fl)
      return is_st_or_fl;
    else 
      return StdRules_HandType_TWOPAIR;

    break;
  };

}

unsigned int wrap_StdDeck_N_CARDS(void) { return StdDeck_N_CARDS; }

StdDeck_CardMask wrap_StdDeck_MASK(int index) { return StdDeck_MASK(index); }

unsigned int wrap_StdDeck_Rank_2(void) { return StdDeck_Rank_2; }
unsigned int wrap_StdDeck_Rank_3(void) { return StdDeck_Rank_3; }
unsigned int wrap_StdDeck_Rank_4(void) { return StdDeck_Rank_4; }
unsigned int wrap_StdDeck_Rank_5(void) { return StdDeck_Rank_5; }
unsigned int wrap_StdDeck_Rank_6(void) { return StdDeck_Rank_6; }
unsigned int wrap_StdDeck_Rank_7(void) { return StdDeck_Rank_7; }
unsigned int wrap_StdDeck_Rank_8(void) { return StdDeck_Rank_8; }
unsigned int wrap_StdDeck_Rank_9(void) { return StdDeck_Rank_9; }
unsigned int wrap_StdDeck_Rank_TEN(void) { return StdDeck_Rank_TEN; }
unsigned int wrap_StdDeck_Rank_JACK(void) { return StdDeck_Rank_JACK; }
unsigned int wrap_StdDeck_Rank_QUEEN(void) { return StdDeck_Rank_QUEEN; }
unsigned int wrap_StdDeck_Rank_KING(void) { return StdDeck_Rank_KING; }
unsigned int wrap_StdDeck_Rank_ACE(void) { return StdDeck_Rank_ACE; }
unsigned int wrap_StdDeck_Rank_COUNT(void) { return StdDeck_Rank_COUNT; }
unsigned int wrap_StdDeck_Rank_FIRST(void) { return StdDeck_Rank_FIRST; }
unsigned int wrap_StdDeck_Rank_LAST(void) { return StdDeck_Rank_LAST; }
unsigned int wrap_StdDeck_RANK(unsigned int index) { return StdDeck_RANK(index); }
unsigned int wrap_StdDeck_SUIT(unsigned int index) { return StdDeck_SUIT(index); }
unsigned int wrap_StdDeck_MAKE_CARD(unsigned int rank, unsigned int suit) { return StdDeck_MAKE_CARD(rank, suit); }
unsigned int wrap_StdDeck_Suit_HEARTS(void) { return StdDeck_Suit_HEARTS; }
unsigned int wrap_StdDeck_Suit_DIAMONDS(void) { return StdDeck_Suit_DIAMONDS; }
unsigned int wrap_StdDeck_Suit_CLUBS(void) { return StdDeck_Suit_CLUBS; }
unsigned int wrap_StdDeck_Suit_SPADES(void) { return StdDeck_Suit_SPADES; }
unsigned int wrap_StdDeck_Suit_FIRST(void) { return StdDeck_Suit_FIRST; }
unsigned int wrap_StdDeck_Suit_LAST(void) { return StdDeck_Suit_LAST; }
unsigned int wrap_StdDeck_Suit_COUNT(void) { return StdDeck_Suit_COUNT; }

unsigned int wrap_StdDeck_CardMask_SPADES(StdDeck_CardMask cm) { return StdDeck_CardMask_SPADES(cm); }
unsigned int wrap_StdDeck_CardMask_CLUBS(StdDeck_CardMask cm) { return StdDeck_CardMask_CLUBS(cm); }
unsigned int wrap_StdDeck_CardMask_DIAMONDS(StdDeck_CardMask cm) { return StdDeck_CardMask_DIAMONDS(cm); }
unsigned int wrap_StdDeck_CardMask_HEARTS(StdDeck_CardMask cm) { return StdDeck_CardMask_HEARTS(cm); }
StdDeck_CardMask wrap_StdDeck_CardMask_SET_HEARTS(StdDeck_CardMask cm, unsigned int ranks) { StdDeck_CardMask_SET_HEARTS(cm, ranks); return cm; }
StdDeck_CardMask wrap_StdDeck_CardMask_SET_DIAMONDS(StdDeck_CardMask cm, unsigned int ranks) { StdDeck_CardMask_SET_DIAMONDS(cm, ranks); return cm; }
StdDeck_CardMask wrap_StdDeck_CardMask_SET_CLUBS(StdDeck_CardMask cm, unsigned int ranks) { StdDeck_CardMask_SET_CLUBS(cm, ranks); return cm; }
StdDeck_CardMask wrap_StdDeck_CardMask_SET_SPADES(StdDeck_CardMask cm, unsigned int ranks) { StdDeck_CardMask_SET_SPADES(cm, ranks); return cm; }
StdDeck_CardMask wrap_StdDeck_CardMask_NOT(StdDeck_CardMask cm) { StdDeck_CardMask_NOT(cm, cm); return cm; }
StdDeck_CardMask wrap_StdDeck_CardMask_OR(StdDeck_CardMask op1, StdDeck_CardMask op2) { StdDeck_CardMask_OR(op1, op1, op2); return op1; } 
StdDeck_CardMask wrap_StdDeck_CardMask_AND(StdDeck_CardMask op1, StdDeck_CardMask op2) { StdDeck_CardMask_AND(op1, op1, op2); return op1; } 
StdDeck_CardMask wrap_StdDeck_CardMask_XOR(StdDeck_CardMask op1, StdDeck_CardMask op2) { StdDeck_CardMask_XOR(op1, op1, op2); return op1; } 
StdDeck_CardMask wrap_StdDeck_CardMask_SET(StdDeck_CardMask mask, unsigned int index) { StdDeck_CardMask_SET(mask, index); return mask; } ;
StdDeck_CardMask wrap_StdDeck_CardMask_UNSET(StdDeck_CardMask mask, unsigned int index) { StdDeck_CardMask_UNSET(mask, index); return mask; }
int wrap_StdDeck_CardMask_CARD_IS_SET(StdDeck_CardMask mask, unsigned int index) { return StdDeck_CardMask_CARD_IS_SET(mask, index); }
int wrap_StdDeck_CardMask_ANY_SET(StdDeck_CardMask mask1, StdDeck_CardMask mask2) { return StdDeck_CardMask_ANY_SET(mask1, mask2); }
StdDeck_CardMask wrap_StdDeck_CardMask_RESET(void) { StdDeck_CardMask mask; StdDeck_CardMask_RESET(mask); return mask; }
int wrap_StdDeck_CardMask_IS_EMPTY(StdDeck_CardMask mask) { return StdDeck_CardMask_IS_EMPTY(mask); }
int wrap_StdDeck_CardMask_EQUAL(StdDeck_CardMask mask1, StdDeck_CardMask mask2) { return StdDeck_CardMask_EQUAL(mask1, mask2); }
