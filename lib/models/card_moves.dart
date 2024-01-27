import 'dart:typed_data';

import 'package:flame/components.dart' show Vector2;

import '../components/card_view.dart';
import '../components/pile.dart';
import '../specs/pat_enums.dart';
import '../specs/pat_specs.dart';

enum Flips {
  noChange,
  fromUp,
  toUp, /* bothUp, */
}

// TODO - Maybe add values to Flips to cover extra move-actions in Mod 3 and
//        also change the name Flips to something else (e.g. ExtraMove?).
//        Another idea would be to have "Forced" flags for multiple Moves that
//        have to be Redone as one.

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

  var _redoIndex = 0;
  final List<CardViewMove> _playerMoves = [];

  bool get hasStockPile => _stockPileIndex >= 0;
  bool get hasWastePile => _wastePileIndex >= 0;

  int _stockPileIndex = -1;
  int _wastePileIndex = -1;
  int _excludedCardsPileIndex = -1;

  void dump() {
    print('DUMP ${_playerMoves.length} MOVES: redo index $_redoIndex');
  }

  void init(List<CardView> cards, List<Pile> piles,
      int stockPileIndex, int wastePileIndex) {
    _cards.addAll(cards);
    _piles.addAll(piles);
    _stockPileIndex = stockPileIndex;
    _wastePileIndex = wastePileIndex;
  }

/*
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

  bool tapMove(CardView card, Pile fromPile) {
    // TODO - Can use fromPile = card.pile; and drop fromPile parameter???
    // TODO - Pile.tapMove, if tapResult == MoveResult.valid, HAS ALREADY DONE
    //        A _cards.removeLast().... FIXED NOW ???

    // ??????? if (fromPile.isCardInPile(card, mustBeOnTop: true))
/*
    if (card.pile.isCardInPile(card, mustBeOnTop: true)) {
      print('CardMoves tapMove(): card ${card.name} is not on top of pile '
          '${fromPile.pileIndex} ${fromPile.pileType}');
      fromPile.dump();
      return false;
    }
*/

    MoveResult tapResult = fromPile.isTapMoveValid(card);
    print('Tap seen ${fromPile.pileType} result: $tapResult');
    if (tapResult == MoveResult.notValid) {
      return false;
    }

    if (fromPile.pileType == PileType.stock) {
      // Check and perform Stock Pile moves.
      fromPile.dump();
      print('Tap Stock Pile: $tapResult Waste Pile present $hasWastePile');
      TapRule rule = fromPile.pileSpec.tapRule;
      if (tapResult == MoveResult.pileEmpty) {
        if (fromPile.pileSpec.tapEmptyRule == TapEmptyRule.tapNotAllowed) {
          // print('${pile.pileType} TAP ON EMPTY PILE WAS IGNORED');
          return false;
        }

        if (hasWastePile) {
          // Turn over the Waste Pile, if the Game's rules allow it.
          final waste = _piles[_wastePileIndex];
          int n = waste.turnPileOver(fromPile);
          if (n == 0) {
            return false; // Not able to turn over the Waste Pile any more.
          }

          storeMove( // Record a successful Waste Pile turnover Move.
              from: waste,
              to: fromPile,
              nCards: 1,
              lead: card.name,
              flips: Flips.noChange);
          // TODO: MUST set the Flips correctly.
          return true;
        }
        return false;

      } else if (hasWastePile) {
        // Deal one or more cards from the Stock Pile to the Waste Pile.
        final waste = _piles[_wastePileIndex];
        // TODO - Maybe passing "this" is superfluous: unless we want to
        //        assert() that this card is actually on top of the Pile.
        List<CardView> dealtCards = fromPile.grabCards(1); // TODO - Could be 3.
        dealtCards.first.doMoveAndFlip(
          waste.position,
          whenDone: () {
            waste.put(dealtCards.first);
          },
        );
        storeMove(
            from: fromPile,
            to: waste,
            nCards: 1,
            lead: dealtCards.first.name,
            flips: Flips.toUp); // TODO: MUST set the Flips correctly.
        return true;

      } else {
        // Deal a card from the Stock Pile to each Tableau Pile.
        int nPiles = 0;
        for (Pile pile in _piles) {
          if (pile.pileType == PileType.tableau) {
            List<CardView> dealtCards = fromPile.grabCards(1);
            dealtCards.first.doMoveAndFlip(
              pile.position,
              whenDone: () {
                pile.put(dealtCards.first);
              },
            );
            nPiles++;
            storeMove(
                from: fromPile,
                to: pile,
                nCards: 1,
                lead: dealtCards.first.name,
                flips: Flips.toUp); // TODO: MUST set the Flips correctly.
          }
          MoveResult moveResult = fromPile.isTapMoveValid(card);
          if (moveResult != MoveResult.valid) {
            break; // No more Stock cards.
          }
          // TODO - Ensure that any solitary excluded Cards now in Tableaus are
          //        replaced with non-excluded Cards, if Stock Cards available.
          // TODO - Record Tableau-deal moves and make them re-doable. KPat does
          //        this by using compound moves: one move-type to deal N Cards
          //        from Stock and a 2-Card 3-Pile move to take out an Ace and
          //        replace it with a Stock Card. Not sure of the order of those
          //        moves, nor how multiple Undo moves are achieved. Maybe the
          //        Dealer does all this somehow. The deal of N cards is the
          //        ONLY move that has "from" == Stock. The 3-Pile move has
          //        Tableau as "from", Aces as "to" and "turn_index" == 1 to
          //        get an extra card from Stock.
          // NOTE - If KPat's Solver and Autodrop are BOTH OFF, compound Ace
          //        Moves definitely occur AFTER the deal-to-Tableau Move. You
          //        have to trigger each Ace Move manually.
        }
        return (nPiles > 0);
      }

    } else {
      // Not a tap on the Stock Pile, check whether the tapped card can go out.
      bool putOK = false;
      for (Pile target in _piles) {
        if (target.pileType != PileType.foundation) {
          continue;
        }
        putOK = target.checkPut(card);
        print('Try ${target.pileType} at '
            'row ${target.gridRow} col ${target.gridCol} putOK $putOK');
        if (putOK) { // The card goes out.
          card.doMove(
            target.position,
            onComplete: () {
              target.put(card);
            },
          );

          // Remove this card from source pile and flip next card, if required.
          List<CardView> unused = fromPile.grabCards(1);
          Flips flip = fromPile.needFlipTopCard() ?
              Flips.fromUp : Flips.noChange;
          storeMove(
            from: fromPile,
            to: target,
            nCards: 1,
            lead: card.name,
            flips: flip); // TODO: MUST set the Flips correctly.
          return true;
        }
      } // End of Foundation Pile search.

      return false; // The card is not ready to go out yet.
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
        int nCards = _movingCards.length;
        if (nCards > 1 &&
            target.pileSpec.dragRule == DragRule.fromAnywhereViaEmptySpace) {
          // The move is OK, but is there enough space to do it? Some games
          // require empty Tableaus or free cells to do a multi-card move,
          // notably Free Cell and Forty & Eight. Others (e.g. Klondike) allow
          // any number of cards to be moved provided there is a valid target.
          if (_notEnoughSpaceToMove(nCards, target)) {
            print('Return _movingCards to start: need more space to move.');
            // TODO - Should not happen instantaneously...
            start.dropCards(_movingCards); // Return cards to start.
            return;
          }
        }
        target.dropCards(_movingCards);
        Flips flip = start.needFlipTopCard() ? Flips.fromUp : Flips.noChange;
        storeMove(from: start, to: target, nCards: cardCount, flips: flip);
        return;
      }
    }
    print('Return _movingCards to start');
    // TODO - Should not happen instantaneously...
    start.dropCards(_movingCards); // Return cards to start.
  }

  bool _notEnoughSpaceToMove(int nCards, Pile target) {
    var emptyPiles = 0;
    for (Pile pile in _piles) {
      if ((pile.pileType == PileType.tableau) && pile.isEmpty) {
        emptyPiles++;
      }
    }
    if (target.isEmpty) emptyPiles--;

    final int maxCards = 1 << emptyPiles; // (2 to the power emptyPiles).
    return (nCards > maxCards);
  }

  void moveExcludedCardsOut(GameSpec gameSpec, int unusedCardsPileIndex) {
    // The last step of PatWorld.deal(), if the Game excludes some Cards.
    List<CardView> excludedCards = [];

    assert ((gameSpec.excludedRank >= 1) && (gameSpec.excludedRank <= 13));
    for (Pile pile in _piles) {
      print('moveExcludedCardsOut ${pile.pileIndex} ${pile.pileType}');
      if ((pile.pileType == PileType.tableau) ||
          (pile.pileType == PileType.foundation)) {
         pile.removeExcludedCards(gameSpec.excludedRank, excludedCards);
      }
      if (unusedCardsPileIndex >= 0) {
        _piles[unusedCardsPileIndex].dropCards(excludedCards);
        excludedCards.clear();
      }
      else {
        // TODO - Make them vanish (i.e. go to (cardWidth / 2.0, -cardHeight)).
      }
    }
    // TODO - Fill any holes in Tableau with non-excluded Cards.
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
        'Redo: ${move.fromPile} ${from.pileType} to ${move.toPile} '
       '${to.pileType} redo $_redoIndex list ${_playerMoves.length}');
    if ((from.pileType == PileType.waste) && (to.pileType == PileType.stock)) {
      from.turnPileOver(to); // Do/redo turn over of Waste Pile to Stock.
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
    print('Back: ${move.fromPile} ${from.pileType} to ${move.toPile} '
        '${to.pileType} redo $_redoIndex list ${_playerMoves.length}');
    if ((from.pileType == PileType.waste) && (to.pileType == PileType.stock)) {
      to.turnPileOver(from); // Undo (return cards to Waste Pile from Stock).
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
