// Taps
// Drags and drops
// Multiple moves of cards
// Handle Undo/Redo?
// Simple moves are done by Pile (grabCards, dropCards and receiveMovingCards)
// Highlight possible Moves (computed by models CardMoves)

import 'dart:core';
import 'dart:typed_data';

import 'package:flame/components.dart' show Vector2;

import '../components/card_view.dart';
import '../components/pile.dart';
import '../models/card_moves.dart';
import '../specs/pat_enums.dart';

class Gameplay {

  final List<CardView> _cards = [];
  final List<Pile> _piles = [];

  late CardMoves _cardMoves;

  var _redoIndex = 0;

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

  void begin(CardMoves cardMoves,
      List<CardView> cards, List<Pile> piles,
      int stockPileIndex, int wastePileIndex) {
    _cardMoves = cardMoves;
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
    if (fromPile.isDragMoveValid(card, _movingCards) == MoveResult.valid) {
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
          if (_notEnoughSpaceToMove(nCards, start, target)) {
            print('Return _movingCards to start: need more space to move.');
            start.receiveMovingCards( // Return cards to starting Pile.
              _movingCards,
              speed: 15.0,
              flipTime: 0.0, // No flip.
            );
            return;
          }
        }
        target.receiveMovingCards(
          _movingCards,
          speed: 15.0,
          flipTime: 0.0, // No flip.
        );
        Extra flip = start.needFlipTopCard() ? Extra.fromCardUp : Extra.none;
        _cardMoves.storeMove(
          from: start,
          to: target,
          nCards: cardCount,
          extra: flip,
          leadCard: _movingCards[0].indexOfCard,
          strength: 0,
        );
        if (_redealEmptyTableau && start.hasNoCards &&
            (start.pileType == PileType.tableau)) {
          _replenishTableauFromStock(start);
        }
        return;
      }
    }
    print('Return _movingCards to start');
    start.receiveMovingCards( // Return cards to starting Pile.
      _movingCards,
      speed: 15.0,
      flipTime: 0.0, // No flip.
    );
  }
/*
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

  void _replenishTableauFromStock(Pile pile) {
    // Auto-refill an empty Tableau Pile, auto-remove excluded cards or both.

    print('_replenishTableauFromStock: ${pile.pileIndex} ${pile.pileType}');
    if (pile.pileType != PileType.tableau) {
      throw StateError('_replenishTableauFromStock() requires a Tableau Pile');
    }
    if ((_excludedRank == 0) && !_redealEmptyTableau) {
      throw StateError('_replenishTableauFromStock() requires the Game to '
          'have excluded cards or auto-refill of empty Tableau Piles or both');
    }
    if (_redealEmptyTableau && (_stockPileIndex < 0)) {
      throw StateError('Auto-refill of empty Tableau Piles requires the '
          'Game to have a Stock Pile from which to deal Cards');
    }
    if ((_excludedRank > 0) && (_excludedCardsPileIndex < 0)) {
      throw UnimplementedError(
          'Game has excluded cards but no Excluded Card Pile to put them on');
    }

    Pile stock = _piles[_stockPileIndex];
    Pile rejects = _piles[_excludedCardsPileIndex];
    bool excludedCardOnTop = false;
    if (pile.nCards > 0) {
      excludedCardOnTop = (_cards[pile.topCardIndex].rank == _excludedRank);
    }
    print('\n\n\n>>>>>>>> Entered _replenishTableauFromStock $pile '
        'Ace on top $excludedCardOnTop');

      if (excludedCardOnTop && (stock.hasNoCards || (pile.nCards > 1))) {
        // Normal move of excluded card out of Pile.
        print('replenishTableau normal move: excluded card out of Pile.');
        List<CardView> excludedCards = pile.grabCards(1);
        print('Pile ${pile.toString()} excludedCards $excludedCards Extra.none');
        rejects.receiveMovingCards(
          excludedCards,
          speed: 3.0, // 10.0,
          flipTime: 0.0, // No flip.
        );
        _cardMoves.storeMove(
          from: pile,
          to: rejects,
          nCards: 1,
          extra: Extra.none,
          leadCard: rejects.topCardIndex,
          strength: 0,
        );
      } else if (stock.hasNoCards) {
        // break;
        print('STOCK HAS RUN OUT OF CARDS IN _replenishTableau...()');
      } else if (excludedCardOnTop) {
        // Compound move of excluded card out and Stock card in.
        print('replenishTableau compound move: excluded out, Stock card in.');
        _tableauIndex = pile.pileIndex;
        _replaceTableauCard();
      }
      else {
        // Normal move of Stock card to pile face-up.
        assert((pile.pileType == PileType.tableau) && pile.hasNoCards,
            'Tableau Pile $pile is expected to be empty at this point');
        print('replenishTableau normal move: Stock card in.');
        _tableauIndex = pile.pileIndex;
        List<CardView> stockCards = stock.grabCards(1);
        pile.receiveMovingCards(
          stockCards,
          speed: 10.0,
          flipTime: 0.3, // Flip card.
          onComplete: () {
            // TODO - "pile" might have changed before callback... Maybe we
            //        should move all Replenish Pile logic to the Pile class.
            if (_cards[pile.topCardIndex].rank == _excludedRank) {
              _replaceTableauCard();
            }
          }, 
        );
        _cardMoves.storeMove(
          from: stock,
          to: pile,
          nCards: 1,
          extra: Extra.toCardUp,
          leadCard: pile.topCardIndex,
          strength: 0,
        );
      }
      if (pile.nCards > 0) {
        excludedCardOnTop = (_cards[pile.topCardIndex].rank == _excludedRank);
      }
  }

  var _tableauIndex = -1;

  void _replaceTableauCard() {
    final pileToReplenish = _piles[_tableauIndex];
    final rejects = _piles[_excludedCardsPileIndex];
    final stock = _piles[_stockPileIndex];

    print('_replaceTableauCard() compound move: excluded out, Stock card in.');
    List<CardView> excludedCards = pileToReplenish.grabCards(1);
    print('Pile ${rejects.toString()} excludedCards $excludedCards Extra.replaceExcluded');
    rejects.receiveMovingCards(
      excludedCards,
      speed: 10.0,
      flipTime: 0.0, // No flip.
    );
    List<CardView> stockCards = stock.grabCards(1);
    pileToReplenish.receiveMovingCards(
      stockCards,
      speed: 10.0,
      flipTime: 0.3, // Flip card.
      onComplete: () {
        print('Replacement card arrived');
        print('Pile $pileToReplenish: indexOfCard ${pileToReplenish.topCardIndex} card ${_cards[pileToReplenish.topCardIndex]} arrived...');
        pileToReplenish.dump();
        stock.dump();
        if (_cards[pileToReplenish.topCardIndex].rank == _excludedRank) {
          _replaceTableauCard();
        }
      }, 
    );
    _cardMoves.storeMove(
      from: pileToReplenish,
      to: rejects,
      nCards: 1,
      extra: Extra.replaceExcluded,
      leadCard: rejects.topCardIndex,
      strength: 0,
    );
  }

  bool _tapOnStockPile(CardView card, Pile fromPile, MoveResult tapResult) {
    // Check and perform three different kinds of Stock Pile move.
    // fromPile.dump();
    print('Tap Stock Pile: $tapResult Waste Pile present $hasWastePile\n');

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

    // This will handle taps on Mod 3 Foundations. Before a card can go out on
    // Mod 3 Foundation the bottom card there must be 2, 3 or 4, according to
    // the PileSpec OR the Pile must be empty and ready to receive a 2, 3 or 4.
    // This type of Pile must also be allowed to RECEIVE a tap on its top card,
    // e.g. a 2 that has been dealt onto a 4-to-K Foundation must be able to
    // go out to a 2-J foundation if there is one empty.

    bool putOK = false;
    for (Pile target in _piles) {
      if (target.pileType != PileType.foundation) {
        continue;
      }
      putOK = target.checkPut(card);
      print('Try ${target.pileType} at '
          'row ${target.gridRow} col ${target.gridCol} putOK $putOK');
      if (putOK) { // The card goes out.
        List<CardView> movingCards = fromPile.grabCards(1);
        target.receiveMovingCards(
          movingCards,
          flipTime: 0.0, // No flip.
        );
        // Remove this card from source pile and flip next card, if required.
        // List<CardView> unused = fromPile.grabCards(1);
        Extra flip = fromPile.needFlipTopCard() ?
            Extra.fromCardUp : Extra.none;
        _cardMoves.storeMove(
          from: fromPile,
          to: target,
          nCards: 1,
          extra: flip,
          leadCard: card.indexOfCard,
          strength: 0,
        );

        if (_redealEmptyTableau && fromPile.hasNoCards &&
            (fromPile.pileType == PileType.tableau)) {
          print('CARD $card GOES OUT: replenish ${fromPile.toString()}');
          _replenishTableauFromStock(fromPile);
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

      _cardMoves.storeMove( // Record a successful Waste Pile turnover Move.
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
    waste.receiveMovingCards(
      dealtCards,
      speed: 15.0,
      flipTime: 0.3, // Flip the card as it moves.
    );
    _cardMoves.storeMove(
      from: fromPile,
      to: waste,
      nCards: 1,
      extra: Extra.toCardUp,
      leadCard: dealtCards.first.indexOfCard,
      strength: 0,
    );
    return true;
  }

  bool _dealToTableausFromStockPile(Pile fromPile) {
    // Deal a card from the Stock Pile to each Tableau Pile.
    assert(fromPile.pileType == PileType.stock);
    if (fromPile.hasNoCards) {
      print('NO MORE STOCK CARDS - _dealToTableausFromStockPile NOT ATTEMPTED');
      return false;
    }

    var nDealtCards = 0;
    var nCardsArrived = 0;
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

      pile.receiveMovingCards(
        dealtCards,
        speed: 15.0,
        flipTime: 0.3, // Flip the card as it moves.
        onComplete: () {
          print('Pile $pile: card $dealtCards index ${dealtCards.first.indexOfCard} arrived...');
          nCardsArrived++;
          if ((nCardsArrived == nDealtCards) && foundExcludedCard) {
            _adjustDealToTableaus();
          }
        },
      );
      nDealtCards++;
    }

    if (nDealtCards > 0) {
      _cardMoves.storeMove(
        from: fromPile,
        to: fromPile, // Not used in Undo/Redo.
        nCards: nDealtCards,
        extra: Extra.stockToTableaus,
        leadCard: 0, // No particular card.
        strength: 0,
      );
    }
    return (nDealtCards > 0);
  }

  void _adjustDealToTableaus() {
    if (_redealEmptyTableau || (_excludedRank > 0)) {
      // Most games do not need this extra action: Mod 3 is an exception.
      for (Pile pile in _tableaus) {
        if (pile.hasNoCards ||
            (_cards[pile.topCardIndex].rank == _excludedRank)) {
          _replenishTableauFromStock(pile);
        }
      }
    }
  }

  // TODO - This sometimes allows more cards to move than it should. Maybe a
  //        column being vacated is counted as an extra column too early.
  //        Probably corrected now: needs more testing and comparison with KPat.
  bool _notEnoughSpaceToMove(int nCards, Pile start, Pile target) {
    var emptyPiles = 0;
    for (Pile pile in _piles) {
      if ((pile.pileType == PileType.tableau) && (pile != start) &&
          pile.hasNoCards) {
        emptyPiles++;
      }
    }
    if ((target.pileType == PileType.tableau) && target.hasNoCards) emptyPiles--;

    final int maxCards = 1 << emptyPiles; // (2 to the power emptyPiles).
    return (nCards > maxCards);
  }
}
