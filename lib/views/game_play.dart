// Handle actions affecting several Cards or piles: Game layout, dealing, taps
// and drags, validating moves, undoing and redoing moves and detecting a win. 

import 'dart:core';

import 'package:flame/components.dart' show Vector2;

import '../pat_game.dart';
import '../components/card_view.dart';
import '../components/pile.dart';
import '../models/card_moves.dart';
import '../specs/pat_enums.dart';
import '../specs/pat_specs.dart';
import 'game_start.dart';

class Gameplay {
  Gameplay(this.game, this._cards, this._piles);

  final PatGame game;
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

  List<CardView> getPossibleMoves() => _cardMoves.getPossibleMoves();

  // Most Games do not have these features: Mod 3 has both of the first two.
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

    // Get Game ID (late) - needed in Klondike Draw 3 and Grandfather Games.
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

  void storeReplenishmentMove(Pile tableau, Pile target, Extra moveType,
      int cardIndex) {
    if ((_excludedCardsPileIndex < 0) || (_stockPileIndex < 0)) {
      throw StateError('Gameplay.storeReplenishmentMove() must be called via '
          'Pile.replenishTableauFromStock() and Pile._replaceTableauCard()');
    }
    Pile stock = _piles[_stockPileIndex];
    _cardMoves.storeMove(
      from: (moveType == Extra.toCardUp) ? stock : tableau,
      to: (moveType == Extra.toCardUp) ? tableau : target,
      nCards: 1,
      extra: moveType,
      leadCard: cardIndex,
      strength: 0,
    );
  }

  void undoMove() {
    UndoRedoResult result = _cardMoves.undoMove();
    // print('UNDO MOVE GameID $_gameID RESULT $result');
    if ((_gameID == PatGameID.grandfather) &&
        (result == UndoRedoResult.undidRedeal)) {
      _redealCount--;
      // print('UNDID GRANDFATHER REDEAL $result _redealCount $_redealCount');
    }
  }

  void redoMove() {
    UndoRedoResult result = _cardMoves.redoMove();
    if ((_gameID == PatGameID.grandfather) &&
        (result == UndoRedoResult.redidRedeal)) {
      _redealCount++;
      // print('REDID GRANDFATHER REDEAL $result _redealCount $_redealCount');
    }
  }

  bool tapMove(CardView card) {
    Pile fromPile = card.pile;
    MoveResult tapResult = fromPile.isTapMoveValid(card);
    // print('\n\nflutter: Tap Pile ${fromPile.pileIndex}, '
        // '${fromPile.pileType}: seen, result $tapResult');
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
        movingCards.first.handleTap();
      }
      return;
    }
    if (targets.isNotEmpty) {
      final target = targets.first;
      if ((target != fromPile) &&
          target.checkPut(movingCards, from: fromPile)) {
        if (_redealEmptyTableau && (fromPile.nCards == 0) &&
            (fromPile.pileType == PileType.tableau) &&
            (_stockPileIndex >= 0) && (_piles[_stockPileIndex].nCards > 0)) {
          // A compound move is needed for ANY one-card move that would empty
          // a Tableau (go-out, remove Ace or whatever) in this Game Type.
          // Deal a card to a Tableau that will be empty after this Move. The
          // top card has already left the Pile and dropped elsewhere.
          fromPile.replenishTableauFromStock(
            _stockPileIndex,
            _excludedCardsPileIndex,
            destinationPileIndex: target.pileIndex,
            droppedCards: movingCards,
          );
          return;
        }

        target.receiveMovingCards(
          movingCards,
          speed: 15.0,
          flipTime: 0.0, // No flip.
        );
        // Need to know whether to flip (as in Klondike) or not (as in
        // Forty & Eight). The decision and animation is in a Pile method.
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
        return;
      } // End valid drop on target Pile.
    } // End (if targets.isNotEmpty).

    // Failed drop: return cards to starting Pile.
    fromPile.receiveMovingCards(
      movingCards,
      speed: 15.0,
      flipTime: 0.0, // No flip.
    );
  }

  bool checkForAWin() {
    for (Pile pile in _foundations) {
      if (pile.isFullFoundationPile) {
        continue;
      }
      return false;
    }
    return true;
  }

  bool _tapOnStockPile(CardView card, Pile stockPile, MoveResult tapResult) {
    // Check and perform three different kinds of Stock Pile move.
    // print('Tap Stock Pile: $tapResult Waste Pile present $hasWastePile');
    stockPile.dump();

    if (tapResult == MoveResult.pileEmpty) {
      if (stockPile.pileSpec.tapEmptyRule == TapEmptyRule.tapNotAllowed) {
        // print('${stockPile.pileType} TAP ON EMPTY PILE WAS IGNORED');
        return false;
      }

      if (_gameID == PatGameID.grandfather) {
        // print('REDEAL GRANDFATHER GAME _redealCount $_redealCount');
        if (_redealGrandfatherGame()) {
          _cardMoves.storeMove( // Record a successful Grandfather Redeal Move.
            from: stockPile,
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
      return _tapEmptyStockPile(stockPile);

    } else if (hasWastePile) {

      // Turn one or more Stock Pile cards face-up onto the Waste Pile.
      return _tapNonEmptyStockPile(stockPile);

    } else {

      // Deal one Stock Pile card face-up onto each of several Tableau Piles.
      return _dealToTableausFromStockPile(stockPile);
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
      // print('Try Pile ${target.pileIndex} ${target.pileType}: putOK $putOK');
      if (putOK) { // The card goes out.
        if (_redealEmptyTableau && (fromPile.nCards == 1) &&
            (fromPile.pileType == PileType.tableau)) {
          if ((_stockPileIndex >= 0) && (_piles[_stockPileIndex].nCards > 0))
          { // Deal a card to a Tableau that will be empty after this Move.
            // print('CARD $card GOES OUT: replenish ${fromPile.toString()}');
            fromPile.replenishTableauFromStock(
              _stockPileIndex,
              _excludedCardsPileIndex,
              destinationPileIndex: target.pileIndex,
            );
            return true;
          }
        }
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
        return true;
      }
    } // End of Foundation Pile search.

    return false; // The card is not ready to go out yet.
  }

  bool _tapEmptyStockPile(Pile stockPile) {
    // Tapped on an empty Stock Pile: if the Game has a Waste Pile and it is
    // not empty and not blocked, the Waste Pile is turned over and refills
    // the Stock Pile. Some Games (e.g. Forty and Eight) limit the number of
    // times this Move can occur. Others (e.g. Klondike) have no limit.

    if (hasWastePile) {
      // Turn over the Waste Pile, if the Game's rules allow it.
      final waste = _piles[_wastePileIndex];
      int n = waste.turnPileOver(stockPile);
      if (n == 0) {
        return false; // Not able to turn over the Waste Pile any more.
      }

      _cardMoves.storeMove( // Record a successful Waste Pile turnover Move.
        from: waste,
        to: stockPile,
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
    // print('ENTERED _redealGrandfatherGame() redeals $_grandfatherRedeals');
    if (_redealCount >= _grandfatherRedeals) {
      // print('RETURN REDEAL false _redealCount $_redealCount');
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

    // Do the redeal for the Grandfather game.
    final cardDealer = Dealer(_cards, _piles, _stockPileIndex, _gameSpec, -1);
    cardDealer.grandfatherDeal(stockPile, _tableaus);
    _redealCount++;
    // print('REDEAL SUCCESSFUL _redealCount $_redealCount');
    return true;
  }

  bool _tapNonEmptyStockPile(Pile stockPile) {
    // Deal one or more cards from the Stock Pile to the Waste Pile.
    final waste = _piles[_wastePileIndex];
    List<CardView> dealtCards = [];
    int nCards = waste.isKlondikeDraw3Waste ? 3 : 1;
    double flipIntervalTime = waste.isKlondikeDraw3Waste ? 0.2 : 0.0;

    // In Klondike Draw 3, the LAST card drawn goes on top of the Waste Pile.
    dealtCards = stockPile.grabCards(nCards, reverseAndFlip: true);
    waste.receiveMovingCards(
      dealtCards,
      speed: 15.0,
      flipTime: 0.3, // Flip the card as it moves.
      startTime: 0.0,
      intervalTime: flipIntervalTime,
    );
    _cardMoves.storeMove(
      from: stockPile,
      to: waste,
      nCards: dealtCards.length,
      extra: Extra.toCardUp,
      leadCard: dealtCards.last.indexOfCard,
      strength: 0,
    );
    return true;
  }

  bool _dealToTableausFromStockPile(Pile stockPile) {
    // Deal a card from the Stock Pile to each Tableau Pile.
    assert(stockPile.pileType == PileType.stock);
    if (stockPile.hasNoCards) {
      // print('NO MORE STOCK CARDS - _dealToTableausFromStockPile NOT ATTEMPTED');
      return false;
    }

    var nDealtCards = 0;
    var nCardsArrived = 0;
    bool foundExcludedCard = false;

    for (Pile pile in _tableaus) {
      if (stockPile.hasNoCards) {
        // print('NO MORE STOCK CARDS - _dealToTableausFromStockPile '
            // 'TERMINATED EARLY');
        break; // No more Stock cards.
      }
      List<CardView> dealtCards = stockPile.grabCards(1);
      if (dealtCards.first.rank == _excludedRank) {
        // print('EXCLUDED CARD: ${dealtCards.first} going to $pile');
        foundExcludedCard = true;
      }

      pile.receiveMovingCards(
        dealtCards,
        speed: 15.0,
        flipTime: 0.3, // Flip the card as it moves.
        onComplete: () {
          // TODO - Check this logic vs. the onComplete logic in the Pile class.
          // print('Pile $pile: card $dealtCards '
              // 'index ${dealtCards.first.indexOfCard} arrived...');
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
        from: stockPile,
        to: stockPile, // Not used in Undo/Redo.
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
  // empty cells multiply the number of cards you can move (see formula below).
  //
  // All this is automated in actual play and is not animated (because that is
  // tedious to watch). So, in a Forty and Eight Game, you can move 1-2 cards
  // if you have one empty Tableau, 1-4 if you have two empty Tableaus, and so
  // on. The method is used to build up long sequences until they can go out.

  bool notEnoughSpaceToMove(int nCards, Pile fromPile, Pile target) {
    if (target == fromPile) {
      return false; // No Move required: the drop is on the fromPile.
    }
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
      // Target != fromPile: so emptyPiles cannot go -'ve and cause a crash.
      emptyPiles--;
    }

    // Max cards = (emptyCells + 1) * (2 to the power emptyPiles).
    final int maxCards = (emptyCells + 1) * (1 << emptyPiles);
    return (nCards > maxCards);
  }
}
