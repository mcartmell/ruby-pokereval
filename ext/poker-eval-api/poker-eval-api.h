StdDeck_CardMask *TextToPtr(char*);
StdDeck_CardMask TextToPokerEval(char*);
int 
StdDeck_StdRules_EVAL_TYPE( StdDeck_CardMask, int);
void evalSingleType(StdDeck_CardMask player, StdDeck_CardMask board, int tot, void *callback(int, StdDeck_CardMask));
