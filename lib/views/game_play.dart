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
import '../specs/pat_specs.dart';
import 'game_start.dart';

class Gameplay {
  Gameplay(this._cards, this._piles);

  final List<CardView> _cards;
  final List<Pile> _piles;

  late CardMoves _cardMoves;
  late PatGameID _gameID;
  late GameSpec _gameSpec;

  bool get hasStockPile => _stockPileIndex >= 0;
  bool get hasWastePile => _wastePileIndex >= 0;

  int _stockPileIndex = -1;
  int _wastePileIndex = -1;
  int _excludedCardsPileIndex = -1;
  final List<Pile> _foundations = [];
  final List<Pile> _tableaus = [];
  final List<Pile> _freecells = [];

  // Most Game do not have these features: Mod 3 has both of the first two.
  int _excludedRank = 0; // Rank of excluded cards (e.g. Aces in Mod 3).
  bool _redealEmptyTableau = false; // Automatically redeal an empty Tableau?

  final _grandfatherRedeals = 2; // Max number of redeals in Grandfather Game.
  int _redealCount = 0;

  void begin(GameSpec gameSpec, int randomSeed) {
    _gameSpec = gameSpec;
    for (Pile pile in _piles) {
      switch(pile.pileType) {
        case PileType.foundation:
          _foundations.add(pile);
        case PileType.tableau:
          _tableaus.add(pile);
        case PileType.stock:
          _stockPileIndex = pile.pileIndex;
        case PileType.waste:
          _wastePileIndex = pile.pileIndex;
        case PileType.excludedCards:
          _excludedCardsPileIndex = pile.pileIndex;
        case PileType.freecell:
          _freecells.add(pile);
      }
      // Set game-wide rules for the gameplay in this Game.
      _excludedRank = gameSpec.excludedRank;
      _redealEmptyTableau = gameSpec.redealEmptyTableau;
    }

    // Get Game ID (late) - needed in Klondike Draw 3.
    _gameID = gameSpec.gameID;

    // Create Move storage and Undo/Redo facility (late).
    _cardMoves = CardMoves(_cards, _piles, _tableaus, _stockPileIndex);

    // Create a (temporary) Dealer and give it access to data needed for the
    // for the deal and a completeTheDeal() procedure needed in some games.
    final cardDealer = Dealer(_cards, _piles, _stockPileIndex,
        gameSpec, _excludedCardsPileIndex,
    );

    // Decide whether a second Dealer phase is needed.
    bool moreToDo = (gameSpec.excludedRank > 0 || gameSpec.redealEmptyTableau);

    // Do the main deal, followed by a callback to completeTheDeal() if needed.
    cardDealer.deal(gameSpec.dealSequence, randomSeed, moreToDo);
  }

  void storeReplenishmentMove(Pile tableau, Extra moveType, int cardIndex) {
    if ((_excludedCardsPileIndex < 0) || (_stockPileIndex < 0)) {
      throw StateError('Gameplay.storeReplenishmentMove() must be called via '
          'Pile.replenishTableauFromStock() and Pile._replaceTableauCard()');
    }
    Pile stock = _piles[_stockPileIndex];
    Pile rejects = _piles[_excludedCardsPileIndex];
    _cardMoves.storeMove(
      from: (moveType == Extra.toCardUp) ? stock : tableau,
      to: (moveType == Extra.toCardUp) ? tableau : rejects,
      nCards: 1,
      extra: moveType,
      leadCard: cardIndex,
      strength: 0,
    );
  }

  void undoMove() {
    UndoRedoResult result = _cardMoves.undoMove();
    print('UNDO MOVE GameID $_gameID RESULT $result');
    if ((_gameID == PatGameID.grandfather) &&
        (result == UndoRedoResult.undidRedeal)) {
      _redealCount--;
      print('UNDID GRANDFATHER REDEAL $result _redealCount $_redealCount');
    }
  }

  void redoMove() {
    UndoRedoResult result = _cardMoves.redoMove();
    if ((_gameID == PatGameID.grandfather) &&
        (result == UndoRedoResult.redidRedeal)) {
      _redealCount++;
      print('REDID GRANDFATHER REDEAL $result _redealCount $_redealCount');
    }
  }

  bool tapMove(CardView card) {
    Pile fromPile = card.pile;
    MoveResult tapResult = fromPile.isTapMoveValid(card);
    print('Tap seen ${fromPile.pileType} result: $tapResult');
    fromPile.dump();
    if (tapResult == MoveResult.notValid) {
      return false;
    }

    if (fromPile.pileType == PileType.stock) {
      return _tapOnStockPile(card, fromPile, tapResult);
    } else {
      return _tapToGoOut(card, fromPile);
    }
  }

  void dragEnd(List<CardView> movingCards, Vector2 startPosition,
        int fromPileIndex, List<Pile> targets, double tolerance) {
    final fromPile = _piles[fromPileIndex];
    final cardCount = movingCards.length;
    if ((movingCards.first.position - startPosition).length < tolerance) {
      fromPile.dropCards(movingCards); // Short drop: return card(s) to start.
      if (cardCount == 1) {
        // Only one card has moved a short distance. Treat that as a tap move.
        tapMove(movingCards.first);
      }
      return;
    }
    if (targets.isNotEmpty) {
      final target = targets.first;
      if (target.checkPut(movingCards)) {
        int nCards = movingCards.length;
        bool dropOK = true;
        if (target.pileType == PileType.foundation) {
          // Tableaus can accept more than one card - but not in all games.
          // Foundations usually accept just 1 card: Simple Simon accepts 13.
          if (nCards != ((target.pileSpec.putRule == PutRule.wholeSuit) ?
                13 : 1)) {
            dropOK = false;
            print('Return movingCards to start: target cannot accept card(s).');
          }
        }
        else if (nCards > 1 &&
            target.pileSpec.dragRule == DragRule.fromAnywhereViaEmptySpace) {
          // The move is OK, but is there enough space to do it?
          //
          // Some games require empty Tableaus or free cells to do a multi-card
          // move, notably Free Cell and Forty & Eight. Others (e.g. Klondike)
          // allow any number of cards to be moved - if there is a valid target.
          if (_notEnoughSpaceToMove(nCards, fromPile, target)) {
            print('Return movingCards to start: need more space to move.');
            dropOK = false;
          }
        }
        if (dropOK) {
          target.receiveMovingCards(
            movingCards,
            speed: 15.0,
            flipTime: 0.0, // No flip.
          );
          // Need to know whether to flip (as in Klondike) or not (as in
          // Fort & Eight). The decision and animation is in a Pile method.
          Extra flip = fromPile.neededToFlipTopCard() ?
              Extra.fromCardUp : Extra.none;
          _cardMoves.storeMove(
            from: fromPile,
            to: target,
            nCards: cardCount,
            extra: flip,
            leadCard: movingCards[0].indexOfCard,
            strength: 0,
          );
          if (_redealEmptyTableau && fromPile.hasNoCards &&
              (fromPile.pileType == PileType.tableau)) {
            fromPile.replenishTableauFromStock(
              _stockPileIndex,
              _excludedCardsPileIndex,
            );
          }
          return;
        }
      }
    }
    print('Return movingCards to start');
    fromPile.receiveMovingCards( // Return cards to starting Pile.
      movingCards,
      speed: 15.0,
      flipTime: 0.0, // No flip.
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

      if (_gameID == PatGameID.grandfather) {
        print('REDEAL GRANDFATHER GAME _redealCount $_redealCount');
        if (_redealGrandfatherGame()) {
          _cardMoves.storeMove( // Record a successful Grandfather Redeal Move.
            from: fromPile,
            to: _tableaus[0], // Not used in Undo/Redo.
            nCards: _redealCount, // Which state of each Tableau to Undo.
            extra: Extra.redeal,
            leadCard: 0, // No particular card.
            strength: 0,
          );
          return true;
        }
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
      putOK = target.checkPut([card]);
      print('Try Pile ${target.pileIndex} ${target.pileType}: putOK $putOK');
      if (putOK) { // The card goes out.
        List<CardView> movingCards = fromPile.grabCards(1);
        target.receiveMovingCards(
          movingCards,
          flipTime: 0.0, // No flip.
        );
        // Remove this card from source pile and flip next card, if required
        // (as in Klondike) or not (as in Forty & Eight). The decision and
        // animation is in a Pile method.
        Extra flip = fromPile.neededToFlipTopCard() ?
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
          fromPile.replenishTableauFromStock(
            _stockPileIndex,
            _excludedCardsPileIndex,
          );
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

  bool _redealGrandfatherGame() {
    print('ENTERED _redealGrandfatherGame() redeals $_grandfatherRedeals');
    if (_redealCount >= _grandfatherRedeals) {
      print('RETURN REDEAL false _redealCount $_redealCount');
      return false;
    }

    // Collect cards from the Grandfather Tableaus.
    final Pile stockPile = _piles[_stockPileIndex];
    for (Pile pile in _tableaus.reversed) { // Right-hand Tableau first...
      pile.saveState(_redealCount); // For Undo of Redeal Move.
      List<CardView> cardsToRedeal = pile.grabCards(pile.nCards);
      for (CardView card in cardsToRedeal) {
        if (card.isFaceUpView) {
          card.flipView();
        }
      }
      stockPile.dropCards(cardsToRedeal);
    }
    int nCardsToBeDealt = stockPile.nCards;
    stockPile.dump();

    final cardDealer = Dealer(_cards, _piles, _stockPileIndex, _gameSpec, -1);

    // Do the redeal for the Grandfather game.
    cardDealer.grandfatherDeal(stockPile, _tableaus);

    _redealCount++;
    print('REDEAL SUCCESSFUL _redealCount $_redealCount');
    return true;
  }

  bool _tapOnFilledStockPile(Pile fromPile) {
    // Deal one or more cards from the Stock Pile to the Waste Pile.
    final waste = _piles[_wastePileIndex];
    fromPile.dump();
    List<CardView> dealtCards = [];
    int nCards = (_gameID == PatGameID.klondikeDraw3) ? 3 : 1;

    // In Klondike Draw 3, the LAST card drawn goes on TOP of the Waste Pile.
    // This means the dealtCards[] must be drawn one-at-a-time and the last
    // of the 3, 2 or 1 cards goes on top. The other cards go under (if avail).
    for (int n = 0; n < nCards; n++) {
      dealtCards.add(fromPile.grabCards(1).first);
      if (fromPile.hasNoCards) {
        nCards = n + 1;
        break;
      }
    }
    waste.receiveMovingCards(
      dealtCards,
      speed: 15.0,
      flipTime: 0.3, // Flip the card as it moves.
      startTime: 0.0,
      intervalTime: 0.2,
    );
    fromPile.dump();
    _cardMoves.storeMove(
      from: fromPile,
      to: waste,
      nCards: nCards,
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
            _adjustDealToTableausFromStockPile();
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

  void _adjustDealToTableausFromStockPile() {
    if (_redealEmptyTableau || (_excludedRank > 0)) {
      // Most games do not need this extra action: Mod 3 is an exception.
      for (Pile pile in _tableaus) {
        if (pile.hasNoCards ||
            (_cards[pile.topCardIndex].rank == _excludedRank)) {
          pile.replenishTableauFromStock(
            _stockPileIndex,
            _excludedCardsPileIndex,
          );
        }
      }
    }
  }

  // In this Gameplay rule, the number of cards you can move depends on how many
  // empty Tableaus there are. It is based on moving one card at a time into or
  // via the empty Tableaus. So, with two empty Tableaus, you can move up to
  // three cards into them, one card at a time, and leave them there. Then you
  // can move a fourth into another Tableau and put the other three on top of
  // it, if all the cards satisfy the rule for that pile. In the Freecell Game,
  // empty cells also affect the number you can move.
  //
  // All this is automated in actual play and is not animated (because that is
  // tedious to watch). So, in an actual Game, you can move 1-2 cards if you
  // have one empty Tableau, 1-4 if you have two empty Tableaus, and so on.
  // The method is used to build up long sequences (e.g. in Forty and Eight).

  bool _notEnoughSpaceToMove(int nCards, Pile fromPile, Pile target) {
    var emptyPiles = 0;
    var emptyCells = 0;
    for (Pile pile in _piles) {
      if ((pile.pileType == PileType.tableau) && (pile != fromPile) &&
          pile.hasNoCards) {
        emptyPiles++;
      }
      else if ((pile.pileType == PileType.freecell) && pile.hasNoCards) {
        emptyCells++;
      }
    }
    if ((target.pileType == PileType.tableau) && target.hasNoCards) {
      emptyPiles--;
    }

    // Max cards = (emptyCells + 1) * (2 to the power emptyPiles).
    final int maxCards = (emptyCells + 1) * (1 << emptyPiles);
    return (nCards > maxCards);
  }
}
