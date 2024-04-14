class RuleBook {
  static const klondikeDraw1Rules = [
    'Klondike is played with one pack of 52 cards. Your goal is to put cards '
    'of the same Suit, in ascending order, Ace to King, on each of the four '
    'Foundation piles. When a card is ready to go out, just tap on it.'
    ,
    'When you tap on the Stock pile, one card from it will be turned over '
    'onto the Waste pile. You can then drag it to a Tableau pile or a '
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
    'To place a King, or a sequence that starts with a King, on a Tableau '
    'you must first empty out that pile.'
    ,
  ];
  static const klondikeDraw1Tips = [
    'Sorry, nothing written yet.'
  ];
  static const fortyAndEightRules = [
    'Forty & Eight is played with two packs of 52 cards. Your goal is to put '
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
    'This Patience is hard to solve. You should plan ahead: especially to '
    'remove "blockages" such as Aces and other low cards covered up during '
    'the deal or high-ranking cards on tops of Tableaus. The Undo/Redo '
    'buttons also come in handy.'
    ,
  ];
  static const fortyAndEightTips = [
    'Sorry, nothing written yet.'
  ];
  static const mod3Rules = [
    'Mod 3 is played with two packs of 52 cards, excluding Aces. If an Ace '
    'is dealt, it goes into an Aces pile, maybe leaving a space or maybe not. '
    'The cards are dealt in 4 rows of 8 cards each. The first three rows are '
    '24 Foundations and the fourth row contains 8 Tableau piles.'
    ,
    'Your goal is to fill the 24 Foundations with cards of the same Suit that '
    'go up in steps of 3. Row 1 accepts 2-5-8-J, row 2 3-6-9-Q and row 3 '
    '4-7-10-K. You can start a sequence in any empty space. The Deal leaves '
    'invalid cards on the Foundations and a few valid ones. Each invalid card '
    'must go out onto another Foundation, thus creating a space.'
    ,
    'If you tap on the Stock pile, it deals a new card onto each of the eight '
    'Tableaus in the bottom row (or as many cards as it has remaining). Tap '
    'it only when you have no other choice. And try to avoid covering '
    'a 2, 3 or 4. Tableaus that empty during the main game are auto-refilled '
    'from the Stock. When the Stock pile is empty the "endgame" begins.'
    ,
    'In the main game, tap or drag single cards that can go out. In the '
    'endgame, you can also drag a card from anywhere onto an empty Tableau. '
    'It helps to have 2 or 3 of these empty Tableaus. Think about the '
    'exact order to get every card out and win.'
    ,
  ];
  static const mod3Tips = [
    'Sorry, nothing written yet.'
  ];
  static const simpleSimonRules = [
    'Sorry, nothing written yet.'
  ];
  static const simpleSimonTips = [
    'Sorry, nothing written yet.'
  ];
  static const yukonRules = [
    'Sorry, nothing written yet.'
  ];
  static const yukonTips = [
    'Sorry, nothing written yet.'
  ];
}
