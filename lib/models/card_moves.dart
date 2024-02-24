import 'dart:core';
import 'dart:typed_data';

import 'package:flame/components.dart' show Vector2;

import '../components/card_view.dart';
import '../components/pile.dart';
import '../specs/pat_enums.dart';

// TODO - Another idea would be to have "Forced" flags for multiple Moves that
//        have to be redone as one.

typedef CardMove = ({
  int fromPile, // Starting PileIndex.
  int toPile, // Finishing PileIndex.
  int nCards, // Number of Card(s) to move.
  Extra extra, // See enum definition above.
  int strength, // Reserved for use in Solver, default = 0.
  int leadCard, // For DEBUG: index number of first card (if known).
});

class CardMoves {
  final List<CardView> _cards = [];
  final List<Pile> _piles = [];

  var _redoIndex = 0;
  final List<CardMove> _playerMoves = [];

  bool get hasStockPile => _stockPileIndex >= 0;
  bool get hasWastePile => _wastePileIndex >= 0;

  int _stockPileIndex = -1;
  int _wastePileIndex = -1;
  int _excludedCardsPileIndex = -1;
  final List<Pile> _foundations = [];
  final List<Pile> _tableaus = [];

  // Most Games do not have these features: Mod 3 has both.
  int _excludedRank = 0; // Rank of excluded cards (e.g. Aces in Mod 3).
  bool _redealEmptyTableau = false; // Automatically redeal an empty Tableau?

  void dump() {
    print('DUMP ${_playerMoves.length} MOVES: redo index $_redoIndex');
  }

  void printMoves() {
    List<String> moves = [];
    for (CardMove move in _playerMoves) {
      moves.add('${move.fromPile} ${move.toPile} n${move.nCards} '
          '${_cards[move.leadCard]} e${move.extra.index}');
    }
    print(moves);
  }

  void init(List<CardView> cards, List<Pile> piles,
      int stockPileIndex, int wastePileIndex) {
    _cards.addAll(cards);
    _piles.addAll(piles);
    _stockPileIndex = stockPileIndex;
    _wastePileIndex = wastePileIndex;
    for (Pile pile in _piles) {
      if (pile.pileType == PileType.foundation) {
        _foundations.add(pile);
      }
      if (pile.pileType == PileType.tableau) {
        _tableaus.add(pile);
      }
    }
  }

/* TODO - KEEP THIS: TO BE INCLUDED IN views/game_start.dart.
  void completeTheDeal(GameSpec gameSpec, int excludedCardsIndex) {
    // Last step of PatWorld.deal() - but only if the Game excludes some cards or
    // needs to deal a new Card to a Tableau that is empty or becomes empty.
    assert ((gameSpec.excludedRank > 0) || gameSpec.redealEmptyTableau);
    assert (gameSpec.excludedRank <= 13);

    _excludedRank = gameSpec.excludedRank; // e.g. Aces in Mod 3 Game.
    _excludedCardsPileIndex = (excludedCardsIndex >= 0)
      ? excludedCardsIndex // Index of a Pile to hold and show excluded cards.
      : -1; // If the Game does not have such a Pile, cards must just disappear.
    _redealEmptyTableau = gameSpec.redealEmptyTableau; // e.g. in Mod 3 Game.

    List<CardView> excludedCards = [];
    for (Pile pile in _piles) {
      if (pile.pileType == PileType.foundation) {
        pile.removeExcludedCards(_excludedRank, excludedCards);
        if (excludedCards.isNotEmpty) {
          print('Pile ${pile.toString()} excludedCards $excludedCards');
          if (_excludedCardsPileIndex >= 0) {
            // ??????? _piles[_excludedCardsPileIndex].dropCards(excludedCards);
            _piles[_excludedCardsPileIndex].receiveMovingCards(
              excludedCards,
              speed: 3.0, // 10.0,
              flipTime: 0.0, // No flip.
            );
          } else { // NOT IMPLEMENTED YET.
            throw UnimplementedError(
                'Excluded Rank $_excludedRank has no Excluded Card Pile');
          }
          excludedCards.clear();
        }
      } else if (pile.pileType == PileType.tableau) {
        if (pile.hasNoCards ||
            (_cards[pile.topCardIndex].rank == _excludedRank)) {
          Pile stock = _piles[_stockPileIndex];
          // final List<CardView> look = stock.stockLookahead(1, rig: 3);
          // print('Lookahead: $look $pile ${pile.pileType}');
          _replenishTableauFromStock(pile);
        }
      }
    }
    // Discard the Moves recorded so far: they are not part of the gameplay.
    _playerMoves.clear();
    _redoIndex = 0;
    print('Player Moves: $_playerMoves redo index $_redoIndex');
  }
*/

  void storeMove({
    required Pile from,
    required Pile to,
    required int nCards,
    required Extra extra,
    int leadCard = 0,
    int strength = 0,
  }) {
    print('MOVE LIST before storeMove() index $_redoIndex:'); printMoves();
    if (_redoIndex < _playerMoves.length) {
      // Remove range from redoIndex to end.
      _playerMoves.removeRange(_redoIndex, _playerMoves.length);
      print('MOVE LIST after PRUNING, index $_redoIndex:'); printMoves();
    }
    CardMove move = (
      fromPile: from.pileIndex,
      toPile: to.pileIndex,
      nCards: nCards,
      extra: extra,
      leadCard: leadCard,
      strength: strength,
    );
    _playerMoves.add(move);
    _redoIndex = _playerMoves.length;
    // print('MOVE LIST after storeMove() index $_redoIndex:'); printMoves();
    print('Move: ${from.pileIndex} ${from.pileType} to ${to.pileIndex} '
        '${to.pileType} $nCards cards ${_cards[leadCard]} $extra');
  }

  void undoMove() {
    if (_redoIndex < 1) {
      return;
    }
    print('MOVE LIST before undoMove() index $_redoIndex:'); printMoves();
    moveBack(_playerMoves[--_redoIndex]);
    print('MOVE LIST after undoMove() index $_redoIndex:'); printMoves();
  }

  void redoMove() {
    // Same as makeMove(), except storeMove() clears the tail of the redo List.
    if (_redoIndex >= _playerMoves.length) {
      return;
    }
    print('MOVE LIST before redoMove() index $_redoIndex:'); printMoves();
    makeMove(_playerMoves[_redoIndex++]);
    print('MOVE LIST after redoMove() index $_redoIndex:'); printMoves();
  }

  void makeMove(CardMove move) {
    // This is a "redo" of a stored Move. The original Move was validated and
    // executed after a Tap or Drag fron the player, then stored. We just "go
    // through the motions" this time around.
    print('Redo Index $_redoIndex $move');
    assert((_redoIndex >= 0) && (_redoIndex <= _playerMoves.length));
    Pile from = _piles[move.fromPile];
    Pile to = _piles[move.toPile];
    print(
        'Redo: ${move.fromPile} ${from.pileType} to ${move.toPile} '
       '${to.pileType} redo $_redoIndex list ${_playerMoves.length}');

    // SPECIAL CASE: Turn Waste Pile over, back onto Stock (tap on empty Stock).
    if ((from.pileType == PileType.waste) && (to.pileType == PileType.stock)) {
      from.turnPileOver(to); // Do/redo turn over of Waste Pile to Stock.
      return;
    }
    switch (move.extra) {
      case Extra.none:
        // Normal Tap or Drag move from one pile to another, with no flips.
        to.dropCards(from.grabCards(move.nCards));
      case Extra.fromCardUp:
        // Normal Tap or Drag from one pile to another, but "from" pile flips
        // its next card to face-up (e.g. move card(s) from Klondike Tableau).
        to.dropCards(from.grabCards(move.nCards));
        from.setTopFaceUp(true);
      case Extra.toCardUp:
        // Normal Tap or Drag from one pile to another, but "to" pile flips
        // its new card to face-up (e.g. move card from Stock to Waste).
        to.dropCards(from.grabCards(move.nCards));
        to.setTopFaceUp(true);
      case Extra.stockToTableaus:
        // One card from Stock to each Tableau, OR until nCards is exhausted.
        var n = 0;
        final nMax = move.nCards;
        assert (from.nCards >= nMax);
        print('Tableau Indices: $_tableaus');
        from.dump();
        for (final pile in _tableaus) {
          pile.dropCards(from.grabCards(1));
          pile.setTopFaceUp(true);
          if (++n >= nMax) break;
        }
        from.dump();
      case Extra.replaceExcluded:
        // From Tableau to Excluded, PLUS from Stock to Tableau (replacement).
        to.dropCards(from.grabCards(1));
        assert(_stockPileIndex >= 0);
        Pile stock = _piles[_stockPileIndex];
        assert (stock.nCards >= 1);
        from.dropCards(stock.grabCards(1));
        from.setTopFaceUp(true);
    }
  }

  void moveBack(CardMove move) {
    // This the reverse (or "undo") of a previously stored Move. For comments
    // on the switch() cases, see makeMove() above.
    Pile from = _piles[move.fromPile];
    Pile to = _piles[move.toPile];
    print('Back: ${move.fromPile} ${from.pileType} to ${move.toPile} '
        '${to.pileType} redo $_redoIndex list ${_playerMoves.length}');

    if ((from.pileType == PileType.waste) && (to.pileType == PileType.stock)) {
      to.turnPileOver(from); // Undo (return cards to Waste Pile from Stock).
      return;
    }
    switch (move.extra) {
      case Extra.none:
        from.dropCards(to.grabCards(move.nCards));
      case Extra.fromCardUp:
        from.setTopFaceUp(false);
        from.dropCards(to.grabCards(move.nCards));
      case Extra.toCardUp:
        to.setTopFaceUp(false);
        from.dropCards(to.grabCards(move.nCards));
      case Extra.stockToTableaus:
        var n = 0;
        final nMax = move.nCards;
        final List<Pile> piles =  _tableaus.reversed.toList();
        print('Reversed Tableaus: $piles');
        from.dump();
        for (final pile in _tableaus.reversed.toList()) {
          assert (pile.nCards >= 1);
          pile.setTopFaceUp(false);
          from.dropCards(pile.grabCards(1));
          if (++n >= nMax) break;
        }
        from.dump();
      case Extra.replaceExcluded:
        assert(_stockPileIndex >= 0);
        Pile stock = _piles[_stockPileIndex];
        from.setTopFaceUp(false);
        stock.dropCards(from.grabCards(1));
        from.dropCards(to.grabCards(1));
    }
  }

  List<CardMove> getPossibleMoves() {
    // TODO - IMPLEMENT THIS.
    List<CardMove> possibleMoves = [];
    return possibleMoves;
  }
}

/*
  // EXPERIMENTAL CODE - Might need to use ByteData in proposed Solver.

  final ByteData _b = ByteData(100);

    print('START 1,000,000,000 ${DateTime.now().toString()}');
    for (int k = 0; k < 1000000000; k++) {
    for (int n = 1; n <= 100; n++) {
      _b.setUint8(n - 1, n);
    }
    }
    print('DONE ${DateTime.now().toString()}');
    // One billion repeats of the inner loop of 100 took 1 min 25 sec.
    // Happily accepts ByteData size of 1 to 4 billion bytes.
    // Has Range Checking on setUint8() and presumably getUint8().
    print('Element length _b ${_b.elementSizeInBytes} ByteData length ${_b.lengthInBytes}');
    print('_b ByteBuffer size ${_b.buffer.lengthInBytes}');
    print('_b[41] ${_b.getUint8(41)}');
    // _b.setUint8(100, 3); // Dart throws a RangeError...
*/
