import 'dart:typed_data';

import 'package:flame/components.dart' show Vector2;

import '../components/card_view.dart';
import '../components/pile.dart';
import '../specs/pat_enums.dart';
import '../specs/pat_specs.dart';

enum Extra {
  // Actions that might follow card moves from one pile to another. Having
  // this enum allows multiple Moves to be treated as one in undo/redo and
  // will also simplify the proposed Solver's task.

  none, // The Move is a simple transfer of cards from one pile to another.
  fromCardUp, // The last card of the "from" pile must be Face Up at the finish.
  toCardUp, // The card(s) must go Face Up as they arrive (e.g. Stock-to-Waste).
  stockToTableaus, // Cards are moved successively from Stock to Tableau Piles.
  replaceExcluded, // An excluded card leaving a Tableau is replaced from Stock.
}

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

// ??????? typedef TableauData = ({int index, int length, int indexOfCard,});

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
      moves.add('${move.fromPile} ${move.toPile} n${move.nCards} ${_cards[move.leadCard]} e${move.extra.index}');
    }
    print(moves);
  }

  void init(List<CardView> cards, List<Pile> piles, int stockPileIndex,
      int wastePileIndex, List<Pile> foundations, List<Pile> tableaus) {
    _cards.addAll(cards);
    _piles.addAll(piles);
    _stockPileIndex = stockPileIndex;
    _wastePileIndex = wastePileIndex;
    _foundations.addAll(foundations);
    _tableaus.addAll(tableaus);
  }

  bool tapMove(CardView card) {
    Pile fromPile = card.pile;
    MoveResult tapResult = fromPile.isTapMoveValid(card);
    print('Tap seen ${fromPile.pileType} result: $tapResult');
    if (tapResult == MoveResult.notValid) {
      return false;
    }

    if (fromPile.pileType == PileType.stock) {
      return _tapOnStockPile(card, fromPile, tapResult);
    } else {
      return _tapToGoOut(card, fromPile);
    }
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
        tapMove(_movingCards.first);
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
        Extra flip = start.needFlipTopCard() ? Extra.fromCardUp : Extra.none;
        storeMove(
          from: start,
          to: target,
          nCards: cardCount,
          extra: flip,
          leadCard: _movingCards[0].indexOfCard,
          strength: 0,
        );
        if (_redealEmptyTableau && start.hasNoCards &&
            (start.pileType == PileType.tableau)) {
          _replenishTableauFromStock(start, playerMove: true);
        }
        return;
      }
    }
    print('Return _movingCards to start');
    // TODO - Should not happen instantaneously...
    start.dropCards(_movingCards); // Return cards to start.
  }

  void moveExcludedCardsOut(GameSpec gameSpec, int excludedCardsIndex) {
    // Last step of PatWorld.deal() - but only if the Game excludes some cards.
    assert ((gameSpec.excludedRank >= 1) && (gameSpec.excludedRank <= 13));

    _excludedRank = gameSpec.excludedRank; // e.g. Aces in Mod 3 Game.
    _excludedCardsPileIndex = (excludedCardsIndex >= 0)
      ? excludedCardsIndex
      : -1; // If the Game does not have such a Pile, cards must just disappear.
    _redealEmptyTableau = gameSpec.redealEmptyTableau; // e.g. in Mod 3 Game.

    List<CardView> excludedCards = [];
    for (Pile pile in _piles) {
      if ((pile.pileType == PileType.tableau) ||
          (pile.pileType == PileType.foundation)) {
         print('moveExcludedCardsOut ${pile.pileIndex} ${pile.pileType}');
         pile.removeExcludedCards(_excludedRank, excludedCards);
      }
    }
    if (!gameSpec.redealEmptyTableau) return;

    // Fill any holes in the Tableaus with non-excluded Cards. 
    for (Pile pile in _tableaus) {
      while (pile.nCards < pile.nCardsToDeal) {
        print('moveExcludedCardsOut refill ${pile.pileIndex} ${pile.pileType}');
        pile.dropCards(_piles[_stockPileIndex].grabCards(1));
        pile.setTopFaceUp(true);
        pile.dump();
        pile.removeExcludedCards(_excludedRank, excludedCards);
      }
    }

    if (_excludedCardsPileIndex >= 0) {
      _piles[_excludedCardsPileIndex].dropCards(excludedCards);
      excludedCards.clear();
    }
    else {
      // TODO - Make them vanish (i.e. go to (cardWidth / 2.0, -cardHeight)).
      assert(_excludedCardsPileIndex < 0, "NOT IMPLEMENTED YET");
    }
  }

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
    print('MOVE LIST after storeMove() index $_redoIndex:'); printMoves();
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

  void _replenishTableauFromStock(Pile pile, {required playerMove}) {
    print('_replenishTableaus: ${pile.pileIndex} ${pile.pileType} '
        'playerMove $playerMove');
  }

  bool _tapOnStockPile(CardView card, Pile fromPile, MoveResult tapResult) {
    // Check and perform three different kinds of Stock Pile move.
    fromPile.dump();
    print('Tap Stock Pile: $tapResult Waste Pile present $hasWastePile');

    if (tapResult == MoveResult.pileEmpty) {
      if (fromPile.pileSpec.tapEmptyRule == TapEmptyRule.tapNotAllowed) {
        print('${fromPile.pileType} TAP ON EMPTY PILE WAS IGNORED');
        return false;
      }

      // Turn over the Waste Pile and refill the Stock Pile.
      return _tapOnEmptyStockPile(fromPile);

    } else if (hasWastePile) {

      // Turn one or more Stock Pile cards face-up onto the Waste Pile.
      return _tapOnFilledStockPile(fromPile);

    } else {

      // Deal one Stock Pile card face-up onto each of several Tableau Piles.
      return _dealToTableausFromStockPile(fromPile);
    }
  }

  bool _tapToGoOut(CardView card, Pile fromPile) {
    // Tapped on a Card that may be able to move to a Foundation and go out.

    // TODO - Modify this to handle taps on Mod 3 Foundations. The base card
    //        must be 2, 3 or 4, according to the PileSpec. Otherwise, the Pile
    //        must be empty and ready to receive a 2, 3 or 4. Also, this type
    //        of Foundation must be allowed to RECEIVE a tap on its top card.
    bool putOK = false;
    // bool tableauLike = false;
    // if (fromPile.pileType == PileType.foundation) {
      // tableauLike = (fromPile.nCards > 0) && (fromPile.first.rank != fromPile.pileSpec.putFirst);
    // }
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
        Extra flip = fromPile.needFlipTopCard() ?
            Extra.fromCardUp : Extra.none;
        storeMove(
          from: fromPile,
          to: target,
          nCards: 1,
          extra: flip,
          leadCard: card.indexOfCard,
          strength: 0,
        );

        if (_redealEmptyTableau && fromPile.hasNoCards &&
            (fromPile.pileType == PileType.tableau)) {
          _replenishTableauFromStock(fromPile, playerMove: true);
        }
        return true;
      }
    } // End of Foundation Pile search.

    return false; // The card is not ready to go out yet.
  }

  bool _tapOnEmptyStockPile(Pile fromPile) {
    // Tapped on an empty Stock Pile: if the Game has a Waste Pile and it is
    // not empty and not blocked, the Waste Pile is turned over and refills
    // the Stock Pile. Some Games (e.g. Forty and Eight) limit the number of
    // times this Move can occur. Others (e.g. Klondike) have no limit.

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
        extra: Extra.none,
        leadCard: 0,
        strength: 0,
      );
      return true;
    }
    return false;
  }

  bool _tapOnFilledStockPile(Pile fromPile) {
    // Deal one or more cards from the Stock Pile to the Waste Pile.
    final waste = _piles[_wastePileIndex];
    List<CardView> dealtCards = fromPile.grabCards(1); // TODO - May be 3 or 2.
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
      extra: Extra.toCardUp,
      leadCard: dealtCards.first.indexOfCard,
      strength: 0,
    );
    return true;
  }

    // TODO - DON'T ANIMATE THIS! Too tricky. Might need a queue. REVIEW...

    // TODO - Deal a new card to Tableau from Stock EVERY TIME it becomes empty.

    // TODO - Must NOT allow Tap or Drag on INNER card of a Tableau - ONLY Top.

    // TODO - Provide support in makeMove() and moveBack() to provide:
    //         1. multiple deals to Tableaus from Stock as one Move type,
    //         2. excluded card move to Excluded Cards Pile WITHOUT replacement,
    //         3. excluded card move to Excluded Cards Pile WITH replacement,
    //         4. Stock card moving to a Tableau Pile that became empty,
    //         5. auto Undo of Move Types 2 and 3 back to and including Type 1.

    // TODO - Ensure that any solitary excluded Cards in Tableaus are
    //        replaced with non-excluded Cards, if Stock Cards available.

    // TODO - Record Tableau-deal moves and make them re-doable. KPat does
    //        this by using compound moves: a move-type to deal N Cards
    //        from Stock to N Tableaus and a 2-Card 3-Pile move to take
    //        out an Ace and replace it with a Stock Card. The Moves are
    //        done in that order, i.e. One N-card move then <N Ace moves.
    //
    //        The deal of N cards is the ONLY move that has "from" ==
    //        Stock. The 3-Pile move has a Tableau as "from", Aces as "to"
    //        and "turn_index" == 1 to get an extra card from Stock.
    // NOTE - If KPat's Solver and Autodrop are BOTH OFF, compound Ace
    //        Moves definitely occur AFTER the deal-to-Tableau Move. You
    //        have to trigger each Ace Move manually.
    // TODO - Need to have index of each Tableau Pile, its length and its
    //        top card (or no-card). WHILE length == 1 and top card is an
    //        excluded card, move card to excludedPile and move a Stock
    //        to the Tableau Pile, if there are any Stock Cards left.

  bool _dealToTableausFromStockPile(Pile fromPile) {
    // Deal a card from the Stock Pile to each Tableau Pile.
    assert(fromPile.pileType == PileType.stock);
    if (fromPile.hasNoCards) {
      print('NO MORE STOCK CARDS - _dealToTableausFromStockPile NOT ATTEMPTED');
      return false;
    }

    int nPiles = 0;
    bool foundExcludedCard = false;
    for (Pile pile in _tableaus) {
      if (fromPile.hasNoCards) {
        print('NO MORE STOCK CARDS - _dealToTableausFromStockPile '
            'TERMINATED EARLY');
        break; // No more Stock cards.
      }
      List<CardView> dealtCards = fromPile.grabCards(1);
      if (dealtCards.first.rank == _excludedRank) {
        print('EXCLUDED CARD: ${dealtCards.first} going to $pile');
        foundExcludedCard = true;
      }
      // dealtCards.first.doMoveAndFlip(
        // pile.position,
        // whenDone: () {
          // pile.put(dealtCards.first);
        // },
      // );
      // TODO - NOT ANIMATED...
      pile.put(dealtCards.first);
      pile.setTopFaceUp(true);
      nPiles++;
    }

    if (nPiles > 0) {
      storeMove(
        from: fromPile,
        to: fromPile, // Not used in Undo/Redo.
        nCards: nPiles,
        extra: Extra.stockToTableaus,
        leadCard: 0, // No particular card.
        strength: 0,
      );
    }

    // TODO - Change this concept to replenishTableaus()... Dependent on
    //        removing excluded cards AND/OR GameSpec.redealEmptyTableau.
    //        
    print('foundExcludedCard: $foundExcludedCard');
    if (foundExcludedCard) {
      _removeExcludedCards(fromPile);
    }
    return (nPiles > 0);
  }

  void _removeExcludedCards(Pile fromPile) {
    assert(fromPile.pileType == PileType.stock);
    print('ENTERED _removeExcludedCards()');

    for (final pile in _tableaus) {
      print('_removeExcludedCards: pile ${pile.pileIndex} ${pile.pileType} nCards ${pile.nCards}');
      pile.dump();
      if (pile.hasNoCards) {
        print('EMPTY PILE');
        continue;
      }
      CardView itemCard = _cards[pile.topCardIndex];
      print('Item card: ${itemCard.name}');
      bool replaceItem = false;
      if (itemCard.rank == _excludedRank) {
        replaceItem = (pile.nCards == 1);
        List<CardView> wasDealt = pile.grabCards(1);
        if (!replaceItem || wasDealt.isEmpty) { // Just move excluded card out.
          print('Remove ${itemCard.name} to pile $_excludedCardsPileIndex');
          print('NO REPLACEMENT CARD...');
          _piles[_excludedCardsPileIndex].put(itemCard);
          storeMove(
            from: pile,
            to: _piles[_excludedCardsPileIndex],
            nCards: 1,
            extra: Extra.none,
            leadCard: itemCard.indexOfCard,
            strength: 0,
          );
          continue; // Next Tableau.
        }
      }
      print('_redealEmptyTableau $_redealEmptyTableau replace_item $replaceItem');
      if (!_redealEmptyTableau) continue;

      assert(fromPile.nCards > 0);
      while (replaceItem) {
        // TODO - NOT ANIMATED...
        print('Put Tableau top-card ${itemCard.name} onto Excluded Pile');
        _piles[_excludedCardsPileIndex].put(itemCard);
        CardView replacementCard = fromPile.grabCards(1).first;
        print('Put ${replacementCard.name} from Stock onto Tableau Pile');
        pile.put(replacementCard);
        pile.setTopFaceUp(true);
        print('Exclude++ ${itemCard.name} to pile $_excludedCardsPileIndex');
        storeMove(
          from: pile,
          to: _piles[_excludedCardsPileIndex],
          nCards: 1,
          extra: Extra.replaceExcluded,
          leadCard: replacementCard.indexOfCard,
          strength: 0,
        );
        if (replacementCard.rank == _excludedRank) {
          itemCard = replacementCard;
          if (fromPile.hasNoCards) {
            print('NO MORE STOCK CARDS');
            print('Remove ${itemCard.name} to pile $_excludedCardsPileIndex');
            print('NO REPLACEMENT CARD...');
            _piles[_excludedCardsPileIndex].put(itemCard);
            storeMove(
              from: pile,
              to: _piles[_excludedCardsPileIndex],
              nCards: 1,
              extra: Extra.none,
              leadCard: itemCard.indexOfCard,
              strength: 0,
            );
            break; // No more Stock cards.
          }
        } else {
          replaceItem = false;
        }
      } // End while(replaceItem).
    } // End Tableaus loop.
  }

  bool _notEnoughSpaceToMove(int nCards, Pile target) {
    var emptyPiles = 0;
    for (Pile pile in _piles) {
      if ((pile.pileType == PileType.tableau) && pile.hasNoCards) {
        emptyPiles++;
      }
    }
    if ((target.pileType == PileType.tableau) && target.hasNoCards) emptyPiles--;

    final int maxCards = 1 << emptyPiles; // (2 to the power emptyPiles).
    return (nCards > maxCards);
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
