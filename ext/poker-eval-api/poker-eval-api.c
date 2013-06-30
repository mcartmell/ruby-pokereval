#include "poker-eval/poker_defs.h"
#include "poker-eval/enumdefs.h"
#include <poker_wrapper.h>
#include "poker-eval-api.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>

extern uint8 nBitsAndStrTable[StdDeck_N_RANKMASKS];

#define SC sc
#define SD sd
#define SH sh
#define SS ss

HandVal StdDeck_StdRules_EVAL_N( StdDeck_CardMask cards, int n_cards )
{
  HandVal retval;
  uint32 ranks, four_mask, three_mask, two_mask, 
    n_dups, n_ranks;
  uint32 sc, sd, sh, ss;

  ss = StdDeck_CardMask_SPADES(cards);
  sc = StdDeck_CardMask_CLUBS(cards);
  sd = StdDeck_CardMask_DIAMONDS(cards);
  sh = StdDeck_CardMask_HEARTS(cards);

  retval = 0;
  ranks = SC | SD | SH | SS;
  n_ranks = nBitsTable[ranks];
  n_dups = n_cards - n_ranks;

  /* Check for straight, flush, or straight flush, and return if we can
     determine immediately that this is the best possible hand 
  */
  if (n_ranks >= 5) {
    if (nBitsTable[SS] >= 5) {
      if (straightTable[SS]) 
        return HandVal_HANDTYPE_VALUE(StdRules_HandType_STFLUSH)
          + HandVal_TOP_CARD_VALUE(straightTable[SS]);
      else
        retval = HandVal_HANDTYPE_VALUE(StdRules_HandType_FLUSH) 
          + topFiveCardsTable[SS];
    } 
    else if (nBitsTable[SC] >= 5) {
      if (straightTable[SC]) 
        return HandVal_HANDTYPE_VALUE(StdRules_HandType_STFLUSH)
          + HandVal_TOP_CARD_VALUE(straightTable[SC]);
      else 
        retval = HandVal_HANDTYPE_VALUE(StdRules_HandType_FLUSH) 
          + topFiveCardsTable[SC];
    } 
    else if (nBitsTable[SD] >= 5) {
      if (straightTable[SD]) 
        return HandVal_HANDTYPE_VALUE(StdRules_HandType_STFLUSH)
          + HandVal_TOP_CARD_VALUE(straightTable[SD]);
      else 
        retval = HandVal_HANDTYPE_VALUE(StdRules_HandType_FLUSH) 
          + topFiveCardsTable[SD];
    } 
    else if (nBitsTable[SH] >= 5) {
      if (straightTable[SH]) 
        return HandVal_HANDTYPE_VALUE(StdRules_HandType_STFLUSH)
          + HandVal_TOP_CARD_VALUE(straightTable[SH]);
      else 
        retval = HandVal_HANDTYPE_VALUE(StdRules_HandType_FLUSH) 
          + topFiveCardsTable[SH];
    } 
    else {
      int st;

      st = straightTable[ranks];
      if (st) 
        retval = HandVal_HANDTYPE_VALUE(StdRules_HandType_STRAIGHT)
          + HandVal_TOP_CARD_VALUE(st);
    };

    /* Another win -- if there can't be a FH/Quads (n_dups < 3), 
       which is true most of the time when there is a made hand, then if we've
       found a five card hand, just return.  This skips the whole process of
       computing two_mask/three_mask/etc.
    */
    if (retval && n_dups < 3)
      return retval;
  };

  /*
   * By the time we're here, either: 
     1) there's no five-card hand possible (flush or straight), or
     2) there's a flush or straight, but we know that there are enough
        duplicates to make a full house / quads possible.  
   */
  switch (n_dups)
    {
    case 0:
      /* It's a no-pair hand */
      return HandVal_HANDTYPE_VALUE(StdRules_HandType_NOPAIR)
        + topFiveCardsTable[ranks];
      break;
      
    case 1: {
      /* It's a one-pair hand */
      uint32 t, kickers;

      two_mask   = ranks ^ (SC ^ SD ^ SH ^ SS);

      retval = HandVal_HANDTYPE_VALUE(StdRules_HandType_ONEPAIR)
        + HandVal_TOP_CARD_VALUE(topCardTable[two_mask]);
      t = ranks ^ two_mask;      /* Only one bit set in two_mask */
      /* Get the top five cards in what is left, drop all but the top three 
       * cards, and shift them by one to get the three desired kickers */
      kickers = (topFiveCardsTable[t] >> HandVal_CARD_WIDTH)
        & ~HandVal_FIFTH_CARD_MASK;
      retval += kickers;

      return retval;
    }
    break;
      
    case 2: 
      /* Either two pair or trips */

      two_mask   = ranks ^ (SC ^ SD ^ SH ^ SS);
      if (two_mask) { 
        uint32 t;

        t = ranks ^ two_mask; /* Exactly two bits set in two_mask */
        retval = HandVal_HANDTYPE_VALUE(StdRules_HandType_TWOPAIR)
          + (topFiveCardsTable[two_mask]
             & (HandVal_TOP_CARD_MASK | HandVal_SECOND_CARD_MASK))
          + HandVal_THIRD_CARD_VALUE(topCardTable[t]);

        return retval;
      }
      else {
        int t, second;
        
        three_mask = (( SC&SD )|( SH&SS )) & (( SC&SH )|( SD&SS ));
        
        retval = HandVal_HANDTYPE_VALUE(StdRules_HandType_TRIPS)
          + HandVal_TOP_CARD_VALUE(topCardTable[three_mask]);

        t = ranks ^ three_mask; /* Only one bit set in three_mask */
        second = topCardTable[t];
        retval += HandVal_SECOND_CARD_VALUE(second);
        t ^= (1 << second);
        retval += HandVal_THIRD_CARD_VALUE(topCardTable[t]);
        return retval;
      }
      break;
      
    default:
      /* Possible quads, fullhouse, straight or flush, or two pair */
      four_mask  = SH & SD & SC & SS;
      if (four_mask) {
        int tc;

        tc = topCardTable[four_mask];
        retval = HandVal_HANDTYPE_VALUE(StdRules_HandType_QUADS)
          + HandVal_TOP_CARD_VALUE(tc)
          + HandVal_SECOND_CARD_VALUE(topCardTable[ranks ^ (1 << tc)]);
        return retval;
      };

      /* Technically, three_mask as defined below is really the set of
         bits which are set in three or four of the suits, but since
         we've already eliminated quads, this is OK */
      /* Similarly, two_mask is really two_or_four_mask, but since we've
         already eliminated quads, we can use this shortcut */

      two_mask   = ranks ^ (SC ^ SD ^ SH ^ SS);
      if (nBitsTable[two_mask] != n_dups) {
        /* Must be some trips then, which really means there is a 
           full house since n_dups >= 3 */
        int tc, t;

        three_mask = (( SC&SD )|( SH&SS )) & (( SC&SH )|( SD&SS ));
        retval  = HandVal_HANDTYPE_VALUE(StdRules_HandType_FULLHOUSE);
        tc = topCardTable[three_mask];
        retval += HandVal_TOP_CARD_VALUE(tc);
        t = (two_mask | three_mask) ^ (1 << tc);
        retval += HandVal_SECOND_CARD_VALUE(topCardTable[t]);
        return retval;
      };

      if (retval) /* flush and straight */
        return retval;
      else {
        /* Must be two pair */
        int top, second;
          
        retval = HandVal_HANDTYPE_VALUE(StdRules_HandType_TWOPAIR);
        top = topCardTable[two_mask];
        retval += HandVal_TOP_CARD_VALUE(top);
        second = topCardTable[two_mask ^ (1 << top)];
        retval += HandVal_SECOND_CARD_VALUE(second);
        retval += HandVal_THIRD_CARD_VALUE(topCardTable[ranks ^ (1 << top) 
                                                        ^ (1 << second)]);
        return retval;
      };

      break;
    };

  /* Should never happen */
  assert(!"Logic error in StdDeck_StdRules_EVAL_N");
}

void evalSingleType(StdDeck_CardMask player, StdDeck_CardMask board, int tot, void *callback(int, StdDeck_CardMask)) {
	int type;
	StdDeck_CardMask_OR(player, player, board);
	type = StdDeck_StdRules_EVAL_TYPE(player, tot);
	callback(type, player);
	return;
}

void evalSingle(StdDeck_CardMask player, StdDeck_CardMask board, int tot, void *callback(int, StdDeck_CardMask)) {
	HandVal score;

	StdDeck_CardMask orig_cards = player;
	StdDeck_CardMask_OR(player, player, board);
	score = StdDeck_StdRules_EVAL_N(player, tot);
	callback(score, orig_cards);
	return;
}

HandVal Eval_Str_N (char* hand) {
		int n_cards;
		StdDeck_CardMask thehand = TextToPokerEval(hand);
		n_cards = strlen(hand) / 2;
		return StdDeck_StdRules_EVAL_N(thehand, n_cards);
}

HandVal Eval_Ptr (StdDeck_CardMask *cards, int n_cards) {
	return StdDeck_StdRules_EVAL_N(*cards, n_cards); 
}

int Eval_Str_Type (char* hand) {
		StdDeck_CardMask thehand = TextToPokerEval(hand);
		int n_cards = strlen(hand) / 2;
		return StdDeck_StdRules_EVAL_TYPE(thehand, n_cards);
}

void tallyScore (int tally[], int us, int them) {
	if (us > them) {
		tally[2] += 1;
	}
	else if (us < them) {
		tally[0] += 1;
	}
	else {
		tally[1] += 1;
	}
}

void evalAndTally(StdDeck_CardMask opp, StdDeck_CardMask board, HandVal us, int tot, int tally[]) {
	HandVal score;
	StdDeck_CardMask_OR(opp, opp, board);
	score = StdDeck_StdRules_EVAL_N(opp, tot);
	tallyScore(tally, us, score);
}

double handStrength(StdDeck_CardMask us, StdDeck_CardMask board) {
	StdDeck_CardMask opp;
	StdDeck_CardMask dead;
	int tot;
	HandVal ourscore;
	int tally[3] = { 0 };

  StdDeck_CardMask_RESET(dead);
	StdDeck_CardMask_OR(dead,dead,us);
	StdDeck_CardMask_OR(dead,dead,board);

  StdDeck_CardMask_RESET(opp);

	tot = StdDeck_numCards(dead);
	ourscore = StdDeck_StdRules_EVAL_N(dead, tot);

	DECK_ENUMERATE_2_CARDS_D(StdDeck, opp, dead, evalAndTally(opp, board, ourscore, tot, tally););
	return ((tally[2] + tally[1] / 2.0) / (tally[0] + tally[1] + tally[2]));
}

int scoreTwoCards(char* str_pocket, char* str_board, void *callback(int, StdDeck_CardMask)) {
	StdDeck_CardMask board;
	StdDeck_CardMask pocket;
	StdDeck_CardMask dead;
	StdDeck_CardMask opp;
	int tot;

  StdDeck_CardMask_RESET(opp);
  StdDeck_CardMask_RESET(pocket);
  StdDeck_CardMask_RESET(board);
  StdDeck_CardMask_RESET(dead);
	pocket = TextToPokerEval(str_pocket);
	board = TextToPokerEval(str_board);
	tot = (2 + (strlen(str_board) / 2));
	StdDeck_CardMask_OR(dead,dead,pocket);
	StdDeck_CardMask_OR(dead,dead,board);
	DECK_ENUMERATE_2_CARDS_D(StdDeck, opp, dead, evalSingle(opp, board, tot, callback););
	return 1;
}

void handPotInnerInner(StdDeck_CardMask turnriver, StdDeck_CardMask ourcards, StdDeck_CardMask oppcards, StdDeck_CardMask board, int index, int hp[][3], int maxcards) {
	HandVal ourrank;
	HandVal opprank;
	StdDeck_CardMask_OR(turnriver, turnriver, board);
	StdDeck_CardMask_OR(ourcards, ourcards, turnriver);
	StdDeck_CardMask_OR(oppcards, oppcards, turnriver);
	ourrank = StdDeck_StdRules_EVAL_N(ourcards, maxcards);
	opprank = StdDeck_StdRules_EVAL_N(oppcards, maxcards);
	if (ourrank > opprank) {
		hp[index][2] += 1;
	}
	else if (ourrank == opprank) {
		hp[index][1] += 1;
	}
	else {
		hp[index][0] += 1;
	}
	return;
}

void handPotInner(HandVal ourrank, int hp[][3], int hptotal[], StdDeck_CardMask ourcards, StdDeck_CardMask board, StdDeck_CardMask oppcards, StdDeck_CardMask dead, int nboard, int maxcards) {
	StdDeck_CardMask turnriver;
	HandVal opprank;
	int index;
	int i;

	StdDeck_CardMask_OR(oppcards, oppcards, board);
	opprank = StdDeck_StdRules_EVAL_N(oppcards, 2 + nboard);

	if (ourrank > opprank) {
		index = 2;
	} else if (ourrank == opprank) {
		index = 1;
	} else {
		index = 0;
	}

	hptotal[index] += 1;

	StdDeck_CardMask_OR(dead, dead, oppcards)
  StdDeck_CardMask_RESET(turnriver);

	i = ((nboard > 3) ? (5 - nboard) : (5 - (7 - maxcards) - nboard));

	DECK_ENUMERATE_N_CARDS_D(StdDeck, turnriver, i, dead, handPotInnerInner(turnriver, ourcards, oppcards, board, index, hp, maxcards););
}

int handPotential(char* str_pocket, char* str_board, char** ppot, int maxcards) {
	int hp[3][3] = {{0}};
	int hptotal[3] = {0};
	int nboard;
	float mult, ppott, npott, ppct, npct;
	char tmpout[80];
	HandVal ourrank;
	
	StdDeck_CardMask board;
	StdDeck_CardMask pocket;
	StdDeck_CardMask opp;
	StdDeck_CardMask ourcards;
	StdDeck_CardMask dead;

  StdDeck_CardMask_RESET(pocket);
  StdDeck_CardMask_RESET(board);
  StdDeck_CardMask_RESET(opp);
	StdDeck_CardMask_RESET(ourcards);
  StdDeck_CardMask_RESET(dead);

	pocket = TextToPokerEval(str_pocket);
	board = TextToPokerEval(str_board);

	nboard = strlen(str_board) / 2;

	StdDeck_CardMask_OR(ourcards,ourcards,pocket);
	StdDeck_CardMask_OR(ourcards,ourcards,board);
	StdDeck_CardMask_OR(dead,dead,ourcards);
	ourrank = StdDeck_StdRules_EVAL_N(ourcards, 2 + nboard);
	DECK_ENUMERATE_2_CARDS_D(StdDeck, opp, dead, handPotInner(ourrank, hp, hptotal, ourcards, board, opp, dead, nboard, maxcards););

	mult = (((2 + nboard == 5) && maxcards == 7) ? 990.0f : 45.0f);
	ppott = (hp[0][2] + hp[0][1]/2 + hp[1][2]/2);
	ppct = ppott / (mult * (hptotal[0] + hptotal[1] / 2.0));
	npott = (hp[2][0] + hp[1][0]/2 + hp[2][1]/2);
	npct = npott / (mult * (hptotal[2] + hptotal[1] / 2.0));
  sprintf( tmpout, "%f|%f",ppct,npct);
	*ppot = strdup(tmpout);

	return 1;
}

int evalOuts(char* str_pocket, int npockets, char* str_board, int nboard, int totboard, void *callback(int, StdDeck_CardMask)) {
		// totboard = total cards wanted on board
		int i = totboard - nboard; // total cards to enumerate
		int tot = totboard + 2; // total cards including player
    StdDeck_CardMask board;
    StdDeck_CardMask dead;
    StdDeck_CardMask pocket;
    StdDeck_CardMask_RESET(pocket);
    StdDeck_CardMask_RESET(board);
    StdDeck_CardMask_RESET(dead);

		pocket = TextToPokerEval(str_pocket);
		board = TextToPokerEval(str_board);
		StdDeck_CardMask_OR(dead,dead,pocket);
		StdDeck_CardMask_OR(dead,dead,board);

		StdDeck_CardMask_OR(pocket, pocket, board);
		printf("I'm OK!\n");

		DECK_ENUMERATE_N_CARDS_D(StdDeck, board, i, dead, evalSingleType(pocket, board, tot, callback););
		return 1;
}


/*
 * When run over seven cards, here are the distribution of hands:
 *        high hand: 23294460
 *             pair: 58627800
 *         two pair: 31433400
 *  three of a kind: 6461620
 *         straight: 6180020
 *            flush: 4047644
 *       full house: 3473184
 *   four of a kind: 224848
 *   straight flush: 41584
 *
 */

/*
 * is_straight used to check for a straight by masking the ranks with four
 * copies of itself, each shifted one bit with respect to the
 * previous one.  So any sequence of five adjacent bits will still
 * be non-zero, but any gap will result in a zero value.  There's
 * a nice side-effect of leaving the top most bit set so we can use
 * it to set top_card.
 * Now we use a precomputed lookup table.  
 *
 */

#if 0
/* Keith's is-straight, which is still pretty good and uses one less table. */
    if ( (ranks2  = ranks & (ranks << 1)) &&
	 (ranks2 &=         (ranks << 2)) &&
	 (ranks2 &=         (ranks << 3)) &&
	 (ranks2 &=         (ranks << 4)) ) {
        retval.eval_t.hand     = StdRules_HandType_STRAIGHT;
        retval.eval_t.top_card = topCardTable[ranks2];
    } else if ((ranks & StdDeck_FIVE_STRAIGHT) ==  StdDeck_FIVE_STRAIGHT) {
        retval.eval_t.hand     = StdRules_HandType_STRAIGHT;
        retval.eval_t.top_card = StdDeck_Ranks_5;
    }
#endif



#undef SC
#undef SH
#undef SD
#undef SS

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
char* wrap_StdDeck_maskString(StdDeck_CardMask m) { return StdDeck_maskString(m); }
int wrap_StdDeck_numCards(StdDeck_CardMask m) { return StdDeck_numCards(m); }

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

StdDeck_CardMask TextToPokerEval(char* strHand)
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

StdDeck_CardMask *TextToPtr(char* strHand) {
	StdDeck_CardMask theHand = TextToPokerEval(strHand);
	StdDeck_CardMask *ptr = malloc(sizeof *ptr);
	*ptr = theHand;
	return ptr;
}


