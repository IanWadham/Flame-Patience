class RuleBook {
  static const klondikeDraw1Rules = [
    'Klondike uses one pack of 52 cards. Your goal is to put cards '
    'of the same Suit, in ascending order, Ace to King, on each of the four '
    'Foundation piles. When a card is ready to go out, just tap on it.'
    ,
    'When you tap on the Stock pile, one card from it will be turned over '
    'onto the Waste pile. You can then move it to a Tableau pile or '
    'Foundation pile, if that move is valid. When the Stock pile is empty, '
    'a tap will move the whole Waste pile back to the Stock. You can flip '
    'through the cards on the Stock pile any number of times.'
    ,
    'Sequences on the Tableau piles can only be built up in descending order, '
    'with cards of alternating colors (red and black). You need such '
    'moves to prepare cards to go out onto the Foundations and to expose '
    'face-down cards automatically. You can drag and drop a sequence of any '
    'length, or a part of it, if the first card fits a sequence on another '
    'Tableau pile.'
    ,
    'To move a King, or a sequence that starts with a King, you must first '
    'empty out a Tableau pile. And only a King can move to an empty Tableau.'
    ,
  ];
  static const klondikeDraw1Tips = [
    'Make Aces and twos go out immediately.'
    ,
    'Have a look through the Stock Pile early on. Play Aces and twos, but '
    'leave other low cards (3 4 5) for later.'
    ,
    'Try to empty the rightmost Tableaus, to reveal the most hidden cards.'
    ,
    'As cards go out, try to keep Foundations even, within one or two ranks '
    'of each other.'
    ,
  ];
  static const fortyAndEightRules = [
    'Forty & Eight uses two packs of 52 cards. Your goal is to put '
    'cards of the same Suit, in ascending order, Ace to King, on each of the '
    'eight Foundation piles. When a card is ready to go out, just tap on it.'
    ,
    'When you tap on the Stock pile, one card from it will be turned over '
    'onto the Waste pile. You can drag it to a Tableau pile or a '
    'Foundation pile, if that move is valid. When the Stock pile is empty, '
    'a tap will move the whole Waste pile back to the Stock. You can do this '
    'only once. The game is lost if the Stock pile empties again and no more '
    'cards can go out.'
    ,
    'Sequences on the Tableau piles can only be built up in descending order, '
    'with cards of the same Suit. You need such moves to prepare cards to go '
    'out onto the Foundations. At first you can move only one card from one '
    'pile to another. But if one or more Tableaus become empty, you can move '
    'more cards, either to other Tableaus or into empty Tableaus. Any card of '
    'any Suit can go into an empty Tableau.'
    ,
    'This Patience is hard to solve. The Undo/Redo buttons come in handy.'
    ,
  ];
  static const fortyAndEightTips = [
    'Plan ahead: to remove "blockages", such as Aces and other low-ranking '
    'cards covered up during the deal, or to shift high-ranking cards from the '
    'tops of Tableaus.'
    ,
    'In the first phase, concentrate on getting out as many Aces and '
    'low-ranking cards as you can.'
    ,
    'In the second phase, open up two or more empty Tableaus, to ease the '
    'handling of long sequences. Keep the Waste pile short (<10-15 cards) '
    'and plan how to go back and "rescue" low-numbered cards from it.'
    ,
  ];
  static const mod3Rules = [
    'Mod 3 uses two packs of 52 cards, excluding Aces. Cards are dealt in 4 '
    'rows of 8 cards each. The first three rows are Foundations and the fourth '
    'has 8 Tableau piles. The deal removes Aces from the Foundations, leaving '
    'spaces, but it replaces them in the Tableaus.'
    ,
    'Your goal is to fill the 24 Foundations with cards of the same Suit that '
    'go up in steps of 3. Row 1 accepts 2-5-8-J, row 2 3-6-9-Q and row 3 '
    '4-7-10-K. Sequences can start in any empty space. Invalid cards on the '
    'Foundations (e.g. an 8, 6 or K in row 1) must go out onto another '
    'Foundation, to create space to play valid cards.'
    ,
    'In the main game, tap or drag single cards that can go out. Tap on'
    'the Stock pile only when you have no other choice. It deals a new card '
    'onto each of the eight Tableaus (or as many cards as it has left), but '
    'try to avoid covering a 2, 3 or 4 and blocking it.'
    ,
    'When the Stock pile is empty, try to empty 2 or 3 Tableaus. If a card is '
    'blocking other cards, you can now drag it into an empty Tableau. Think '
    'about the exact order of moves to get every card out and win.'
    ,
  ];
  static const mod3Tips = [
    'Sorry, nothing written yet.'
  ];
  static const simpleSimonRules = [
    'Simple Simon uses one pack of 52 cards and all the cards are dealt '
    'face-up. It has 10 Tableau piles and 4 Foundations. Your goal is to move '
    'all the cards to the Foundation piles, in ascending order, Ace to King, '
    'of each Suit.'
    ,
    'In the Tableaus, you can move any card from the top of one pile to the '
    'top of another, regardless of Suit, as long as the receiving card has a '
    'rank that is one point higher (e.g. 4 of Hearts can go on 5 of any '
    'Suit). But you can move multiple cards only if they are all in sequence '
    'and of the same Suit. You can drag any card or sequence of cards into '
    'an empty Tableau.'
    ,
    'What could be easier?'
    ,
    'The catch is that you must assemble all 13 cards of a Suit into sequence, '
    'Ace to King, before you can drag the King to a Foundation and go out with '
    'that Suit.'
    ,
    'Simple Simon is actually quite a difficult game.'
    ,
  ];
  static const simpleSimonTips = [
    'Be patient. Build up small fragments of two or more Suits, then combine '
    'the fragments when you can, rather than trying to build long sequences '
    'all at once.'
    ,
    'Empty two or more Tableaus and keep them that way. Use them as staging '
    'points for moving cards and fragments of sequences freely.'
  ];
  static const yukonRules = [
    'Yukon uses one pack of 52 cards. The deal is similar to Klondike, with '
    '7 Tableaus and 4 Foundation, except that it continues dealing face-up '
    'cards until there are none left and there is no Waste or Stock pile. '
    'Your goal is to place cards of one Suit onto each Foundation in the '
    'order Ace up to King.'
    ,
    'Any card from any part of any Tableau, along with all the cards on top of '
    'it, can be dragged and dropped onto another Tableau, provided that the '
    'receiving card is one rank higher and the opposite color (red or black) '
    'to the incoming card. Cards can be tapped or dragged to go out if thay '
    'are on top of a Tableau and in sequence with their Foundation.'
    ,
    'If a Tableau becomes empty, any face-up King can be moved into it, along '
    'with all the cards on top of that King.'
  ];
  static const yukonTips = [
    'Make Aces go out immediately. Leave other low cards (2 3 4 5) in case you '
    'need them to receive a later move.'
    ,
    'Try to empty the rightmost Tableaus, to reveal the most hidden cards.'
    ,
    'As cards go out, keep the Foundations even, within one or two ranks '
    'of each other.'
    ,
    'Look high in the Tableaus for possible cards to play, especially if they '
    'are on top of a hidden card which can turn face-up. Such moves are hard '
    'to spot at first.'
    ,
  ];
  static const klondikeDraw3Rules = [
    'Sorry, nothing written yet.'
  ];
  static const klondikeDraw3Tips = [
    'Sorry, nothing written yet.'
  ];
  static const freecellRules = [
    'Sorry, nothing written yet.'
  ];
  static const freecellTips = [
    'Sorry, nothing written yet.'
  ];
  static const gypsyRules = [
    'Sorry, nothing written yet.'
  ];
  static const gypsyTips = [
    'Sorry, nothing written yet.'
  ];
  static const grandfatherRules = [
    'Sorry, nothing written yet.'
  ];
  static const grandfatherTips = [
    'Sorry, nothing written yet.'
  ];
}
