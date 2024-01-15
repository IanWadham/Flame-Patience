import 'dart:typed_data';

import 'package:flame/components.dart' show Vector2;

import '../components/card_view.dart';
import '../components/pile.dart';
import '../specs/pat_enums.dart';

enum Flips {
  noChange,
  fromUp,
  toUp, /* bothUp, */
}

typedef CardViewMove = ({
  int fromPile, // Starting Pile.
  int toPile, // Finishing Pile.
  int nCards, // Number of Card(s) to move.
  Flips flips, // 0 no changes, 1 from -> up, 2 to -> up, 3 both -> up.
  String lead, // DEBUG: Name of first card.
});

typedef CardMove = ({
  int fromPile, // Index of starting Pile.
  int leadCard, // Index of first card. Card(s) to move: [leadCard] - [length - 1].
  int toPile, // Index of finishing Pile.
  Flips flips, // 0 no changes, 1 from -> up, 2 to -> up, 3 both -> up.
  int strength, // Estimated strength of move (used only in solver).
});

class CardMoves {
  final List<CardView> _cards = [];
  final List<Pile> _piles = [];

  final ByteData _b = ByteData(100);

  var _redoIndex = 0;
  final List<CardViewMove> _playerMoves = [];

  bool get hasStockPile => _stockPileIndex >= 0;
  bool get hasWastePile => _wastePileIndex >= 0;

  int _stockPileIndex = -1;
  int _wastePileIndex = -1;

  void init(List<CardView> cards, List<Pile> piles,
      int stockPileIndex, int wastePileIndex) {
    _cards.addAll(cards);
    _piles.addAll(piles);
    _stockPileIndex = stockPileIndex;
    _wastePileIndex = wastePileIndex;
/*
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
  }

  bool tapMove(CardView card, Pile fromPile) {
    // TODO - Can use fromPile = card.pile; and drop fromPile parameter.
    MoveResult tapResult = fromPile.tapMove(card);
    // print('Tap seen ${fromPile.pileType} result: $tapResult');
    if (tapResult == MoveResult.notValid) {
      return false;
    } else if (fromPile.pileType == PileType.stock) {
      // print('Tap Stock Pile: $tapResult Waste Pile present $hasWastePile');
      if (tapResult == MoveResult.pileEmpty) {
        if (fromPile.pileSpec.tapEmptyRule == TapEmptyRule.tapNotAllowed) {
          // print('${pile.pileType} TAP ON EMPTY PILE WAS IGNORED');
          return false;
        }
        if (hasWastePile) {
          final waste = _piles[_wastePileIndex];
          waste.turnPileOver(fromPile);
/*
          final wasteCards = waste.removeAllCards();
          // print('Turned-over Waste cards: $wasteCards');
          for (final card in wasteCards) {
            // Top Waste Pile cards go face-down to bottom of Stock Pile.
            if (card.isFaceUpView) card.flipView();
            fromPile.put(card);
          }
*/
          storeMove(
              from: waste,
              to: fromPile,
              nCards: 1,
              lead: card.name,
              flips: Flips.noChange);
          // TODO: MUST set the Flips correctly.
        }
        return true;
      } else if (hasWastePile) {
        final waste = _piles[_wastePileIndex];
        // TODO - Maybe passing "this" is superfluous: unless we want to
        //        assert() that this card is actually on top of the Pile.
        fromPile.dealCardFromStock(card, fromPile.pileSpec.tapRule, waste);
        storeMove(
            from: fromPile,
            to: waste,
            nCards: 1,
            lead: card.name,
            flips: Flips.toUp); // TODO: MUST set the Flips correctly.
      } else {
        throw UnimplementedError('Cannot yet flip Stock cards to Tableaus.');
        return false; // TODO - Deal more cards to Tableaus? e.g. Mod3.
      }
    } else {
      bool putOK = false;
      for (Pile target in _piles) { // ??????? world.foundations) {
        if (target.pileType != PileType.foundation) continue;
        // print(
        // 'Try ${target.pileType} at row ${target.gridRow} col ${target.gridCol}');
        putOK = target.checkPut(card);
        if (putOK) {
          card.doMove(
            target.position,
            onComplete: () {
              target.put(card);
            },
          );
          // Turn up next card on source pile, if required.
          Flips flip = fromPile.needFlipTopCard() ? Flips.fromUp : Flips.noChange;
          storeMove(
              from: fromPile,
              to: target,
              nCards: 1,
              lead: card.name,
              flips: flip); // TODO: MUST set the Flips correctly.
          break;
        }
      } // End of Foundation Pile checks.
      if (!putOK) {
        fromPile.put(card);
        return  false;
      }
    }
    return true;
  }

  var _fromPileIndex = -1;
  var _startedAt = Vector2(0.0, 0.0);
  final List<CardView> _movingCards = [];

  bool dragStart(CardView card, Pile fromPile, List<CardView> movingCards) {
    if (fromPile.dragMove(card, _movingCards) == MoveResult.valid) {
      print('_movingCards $_movingCards');
      _startedAt = card.position.clone();
      movingCards.clear();
      movingCards.addAll(_movingCards);
      _fromPileIndex = fromPile.pileIndex;
      return true;
    }
    // If not OK to drag, might have started a tap move on a Stock Pile.
    return false;
  }

  void dragEnd(List<Pile> targets, double tolerance) {
    final start = _piles[_fromPileIndex];
    final cardCount = _movingCards.length;
    if ((_movingCards.first.position - _startedAt).length < tolerance) {
      start.dropCards(_movingCards); // Short drop: return card(s) to start.
      if (cardCount == 1) {
        // Only one card has moved a short distance. Treat that as a tap move.
        tapMove(_movingCards.first, start);
      }
      return;
    }
    if (targets.isNotEmpty) {
      final target = targets.first;
      if (target.checkPut(_movingCards.first)) {
        target.dropCards(_movingCards);
        Flips flip = start.needFlipTopCard() ? Flips.fromUp : Flips.noChange;
        storeMove(from: start, to: target, nCards: cardCount, flips: flip);
        return;
      }
    }
    print('Return _movingCards to start');
    // TODO - Should not happen instantaneously...
    start.dropCards(_movingCards); // Failed drop: return cards to start.
  }

  void storeMove({
    required Pile from,
    required Pile to,
    required int nCards,
    required Flips flips,
    String lead = '',
  }) {
    if (_redoIndex < _playerMoves.length) {
      // Remove range from redoIndex to end.
      _playerMoves.removeRange(_redoIndex, _playerMoves.length);
    }
    CardViewMove move = (
      fromPile: from.pileIndex,
      toPile: to.pileIndex,
      nCards: nCards,
      lead: lead,
      flips: flips
    );
    _playerMoves.add(move);
    _redoIndex = _playerMoves.length;
    print('Move: ${from.pileIndex} ${from.pileType} to ${to.pileIndex} '
        '${to.pileType} $nCards cards $lead flip ${flips.index}');
  }

  void makeMove(CardViewMove move) {
    CardViewMove move = _playerMoves.last;
    Pile from = _piles[move.fromPile];
    Pile to = _piles[move.toPile];
    print(
        'Redo: ${move.fromPile} ${from.pileType} to ${move.toPile} ${to.pileType} '
        'redo $_redoIndex list ${_playerMoves.length}');
    if ((from.pileType == PileType.waste) && (to.pileType == PileType.stock)) {
      from.turnPileOver(to);
      return;
    }
    to.dropCards(from.grabCards(move.nCards));
    switch (move.flips) {
      case Flips.fromUp:
        from.setTopFaceUp(true);
      case Flips.toUp:
        to.setTopFaceUp(true);
      case Flips.noChange:
        break;
    }
  }

  void moveBack(CardViewMove move) {
    Pile from = _piles[move.fromPile];
    Pile to = _piles[move.toPile];
    print(
        'Back: ${move.fromPile} ${from.pileType} to ${move.toPile} ${to.pileType} '
        'redo $_redoIndex list ${_playerMoves.length}');
    if ((from.pileType == PileType.waste) && (to.pileType == PileType.stock)) {
      to.turnPileOver(from);
      return;
    }
    switch (move.flips) {
      case Flips.fromUp:
        from.setTopFaceUp(false);
      case Flips.toUp:
        to.setTopFaceUp(false);
      case Flips.noChange:
        break;
    }
    from.dropCards(to.grabCards(move.nCards));
  }

  void undoMove() {
    if (_redoIndex < 1) {
      return;
    }
    moveBack(_playerMoves[--_redoIndex]);
  }

  void redoMove() {
    // Same as makeMove(), except that storeMove() clears the tail of the redo List.
    if (_redoIndex >= _playerMoves.length) {
      return;
    }
    makeMove(_playerMoves[_redoIndex++]);
  }

  List<CardMove> getPossibleMoves() {
    List<CardMove> possibleMoves = [];
    return possibleMoves;
  }
}
