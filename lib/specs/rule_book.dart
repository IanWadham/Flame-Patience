class RuleBook {
  static const klondikeDraw1Rules = [
    'Klondike uses one pack of 52 cards. Your goal is to put cards '
    'of the same suit, in ascending order, Ace to King, on each of the four '
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
    'If an Ace or a two can go out, move it immediately.'
    ,
  ];
  static const klondikeDraw1Tips = [
    'Look through the Stock pile early on. Leave low cards (3 4 5) till '
    'later. Build Tableaus using higher cards at first.'
    ,
    'Try to move all face-up cards off Tableaus and reveal face-down cards, '
    'giving priority to the rightmost Tableaus.'
    ,
    'As cards go out, try to keep Foundations even, within one or two ranks '
    'of each other. If you play one suit too much, you may block others.'
    ,
    'Sometimes you can win by going out with two suits alternately (red '
    'and black) until you reach a vital hidden card.'
    ,
  ];
  static const fortyAndEightRules = [
    'Forty & Eight uses two packs of 52 cards. Your goal is to put '
    'cards of the same suit, in ascending order, Ace to King, on each of the '
    'eight Foundation piles. When a card is ready to go out, just tap on it.'
    ,
    'When you tap on the Stock pile, one card from it will be turned over '
    'onto the Waste pile. You can move it to a Tableau pile or a '
    'Foundation pile, if that move is valid. When the Stock pile is empty, '
    'a tap will move the whole Waste pile back to the Stock. You can do this '
    'only once. The game is lost if the Stock pile empties again and no more '
    'cards can go out.'
    ,
    'Sequences on the Tableau piles can only be built up in descending order, '
    'with cards of the same suit. You need such moves to prepare cards to go '
    'out onto the Foundations. At first you can move only one card from one '
    'pile to another. But if one or more Tableaus become empty, you can move '
    'more cards, either to other Tableaus or into empty Tableaus. Any card of '
    'any suit can be dragged into an empty Tableau.'
    ,
    'This Patience is hard to solve, but a good player can have about 80% '
    'success rate. The Undo/Redo buttons come in handy. So does the Show Moves '
    'button.'
    ,
  ];
  static const fortyAndEightTips = [
    'Plan ahead: to remove "blockages", such as Aces and other low-ranking '
    'cards covered up during the deal.'
    ,
    'In the first phase, concentrate on getting out as many Aces and '
    'low-ranking cards as you can and try to shift high-ranking cards from '
    'the tops of Tableaus. Think twice before building on high cards that are '
    'blocking low-ranking cards.'
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
    'spaces, but replaces them in the Tableaus.'
    ,
    'Your goal is to fill the 24 Foundations with cards of the same suit that '
    'go up in steps of 3. Row 1 accepts 2-5-8-J, row 2 3-6-9-Q and row 3 '
    '4-7-10-K. Sequences can start in any empty space.'
    ,
    'The deal can leave invalid cards on the Foundation rows (e.g. an 8, 6 or '
    'K in row 1). These must go out onto another Foundation, to create space '
    'to play valid cards.'
    ,
    'In the main game, tap or drag single cards that can go out. Tap on '
    'the Stock pile only when you have no other choice. It deals a new card '
    'onto each of the eight Tableaus (or as many cards as it has left), but '
    'try to avoid covering a 2, 3 or 4 and blocking it.'
    ,
    'When the Stock pile is empty, try to empty 2 or 3 Tableaus. If a card is '
    'blocking other cards, you can then drag it into an empty Tableau. Think '
    'about the exact order of moves to get every card out and win.'
    ,
  ];
  static const mod3Tips = [
    'Good moves can be hard to spot in Mod 3. Make good use of the Show Moves '
    'button.'
    ,
    'Try to keep at least one space open in each Foundation row. Give priority '
    'to moving out invalid cards, especially if they are in the right row but '
    'the wrong rank (e.g. a 6 in row 2 with no 3 beneath it).'
    ,
    'Try to keep a few Tableaus small, especially on the right, to be ready '
    'for when the Stock pile empties. It is good to have a Tableau empty on '
    'the right when the last few cards are dealt on the left.'
    ,
  ];
  static const simpleSimonRules = [
    'Simple Simon uses one pack of 52 cards and all the cards are dealt '
    'face-up. It has 10 Tableau piles and 4 Foundations. Your goal is to move '
    'all the cards to the Foundation piles, in ascending order, Ace to King, '
    'of each suit.'
    ,
    'In the Tableaus, you can move any card from the top of one pile to the '
    'top of another, regardless of suit, as long as the receiving card has a '
    'rank that is one point higher (e.g. 4 of Hearts can go on 5 of any '
    'suit). But you can move multiple cards only if they are all in sequence '
    'and of the same suit. You can drag any card or sequence of cards into '
    'an empty Tableau.'
    ,
    'What could be easier?'
    ,
    'The catch is that you must assemble all 13 cards of a suit into sequence, '
    'Ace to King, before you can drag the King and the other 12 cards to a '
    'Foundation and go out with that suit.'
    ,
    'Simple Simon is actually quite a difficult game.'
    ,
  ];
  static const simpleSimonTips = [
    'Make good use of the Show Moves button.'
    ,
    'Be patient. Build up small fragments of two or more suits, then combine '
    'the fragments when you can, rather than trying to build long sequences '
    'all at once.'
    ,
    'Empty two or more Tableaus and keep them that way if possible. Use them '
    'as staging points for moving cards and fragments of sequences freely.'
  ];
  static const yukonRules = [
    'Yukon uses one pack of 52 cards. The deal is similar to Klondike, with '
    '7 Tableaus and 4 Foundation, except that it continues dealing face-up '
    'cards until there are none left and there is no Waste or Stock pile. '
    'Your goal is to place cards of one suit onto each Foundation in the '
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
    'As cards go out, keep the Foundations even, within one or two ranks '
    'of each other.'
    ,
    'Try to remove all face-up cards from Tableaus repeatedly, to reveal '
    'hidden cards, giving the rightmost Tableaus priority.'
    ,
    'Look high in the layout for possible cards to play, especially if they '
    'are on top of a hidden card which can turn face-up. Such moves are hard '
    'to spot, so use the Show Moves button.'
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
