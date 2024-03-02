import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../components/card_view.dart';
import '../components/pile.dart';

import '../models/card_moves.dart';

import '../pat_world.dart';
import '../specs/pat_enums.dart';
import '../specs/pat_specs.dart';

// Decoding of GameSpec into Piles and their layout (was in PatWorld's onLoad).
// Shuffle and deal into the layout at the start of a Game.
// Make adjustments after the deal (e.g. in Mod 3, remove Aces, refill Tableaus).

// There are two distinct classes in this file: GameLayOut and Dealer.

class GameLayout {

  int generatePiles(GameSpec gameSpec, Vector2 cellSize, List<Pile> piles) {
    var pileSpecErrorCount = 0;
    var foundStockSpec = false;
    var foundWasteSpec = false;
    var pileIndex = 0;

    final List<Pile> foundations = [];
    final List<Pile> tableaus = [];
    int _stockPileIndex = -1; // No Stock Pile yet: not all games have one.
    int _wastePileIndex = -1; // No Waste Pile yet: not all games have one.
    int _excludedCardsPileIndex = -1; // Games with Excluded Cards need this.

    for (GamePileSpec gamePile in gameSpec.gamePilesSpec) {
      final pileSpec = gamePile.pileSpec;
      final pileType = pileSpec.pileType;
      final nPilesOfThisType = gamePile.nPilesSpec;
      if (nPilesOfThisType != gamePile.pileTrios.length) {
        throw FormatException('${pileSpec.pileType} requires $nPilesOfThisType '
            'piles: number of pileTrios is ${gamePile.pileTrios.length}');
      }
      for (PileTrio trio in gamePile.pileTrios) {
        int row = trio.$1;
        int col = trio.$2;
        int deal = trio.$3;
        double pileX = (col + 0.5) * cellSize.x;
        double pileY = row * cellSize.y;
        final position = PatWorld.topLeft + Vector2(pileX, pileY);
        print('New Pile ${pileSpec.pileType} $pileIndex pos $position row $row col $col');
        final pile = Pile(
          pileSpec,
          pileIndex,
          cellSize.x,
          cellSize.y,
          row: row,
          col: col,
          deal: deal,
          position: position,
        );

        piles.add(pile);

        print('New pile: row $row col $col deal $deal '
            'pos $position ${pile.pileType}');
        switch (pile.pileType) {
          case PileType.stock:
            if (!gameSpec.hasStockPile) {
              throw FormatException(
                  'Stock Pile specified but GameSpec hasStockPile is false');
              pileSpecErrorCount++;
            }
            _stockPileIndex = pileIndex;
            foundStockSpec = true;
          case PileType.waste:
            if (!gameSpec.hasWastePile) {
              throw FormatException(
                  'Waste Pile specified but GameSpec hasWastePile is false');
              pileSpecErrorCount++;
            }
            _wastePileIndex = pileIndex;
            foundWasteSpec = true;
          case PileType.foundation:
            foundations.add(pile);
          case PileType.tableau:
            tableaus.add(pile);
          case PileType.excludedCards:
            _excludedCardsPileIndex = pileIndex;
            break;
        }
        pileIndex++;
      }
    }

    final foundationsNeeded = gameSpec.gameID == PatGameID.mod3 ? 24
        : 4 * gameSpec.nPacks;
    if (!foundStockSpec && gameSpec.hasStockPile) {
      throw FormatException(
          'NO Stock Pile specified but GameSpec hasStockPile is true');
      pileSpecErrorCount++;
    } else if (!foundWasteSpec && gameSpec.hasWastePile) {
      throw FormatException(
          'NO Waste Pile specified but GameSpec hasWastePile is true');
      pileSpecErrorCount++;
    } else if (foundations.length != foundationsNeeded) {
      throw FormatException(
          '${foundations.length} Foundations found: $foundationsNeeded needed');
      pileSpecErrorCount++;
    } else if (tableaus.isEmpty) {
      throw FormatException('NO Tableau Pile specifications found');
      pileSpecErrorCount++;
    }
    // If there are errors in the Pile Specs, probably will not get this far.
    return pileSpecErrorCount;
  }
} // End of GameLayout class.


class Dealer extends Component with HasWorldReference<PatWorld> {
  Dealer(this._cards, this._piles, this._stockPileIndex,
      this._gameSpec, this._excludedCardsPileIndex,
      this._replenishTableauFromStock, this._cardMoves,
  );

  // This data and function-paraameter are needed by the deal() and completeTheDeal()
  // methods and are provided by the GamePlay start() method.
  final List<CardView> _cards;
  final List<Pile> _piles;
  final int _stockPileIndex;
  final GameSpec _gameSpec;
  final int _excludedCardsPileIndex;
  final Function(Pile) _replenishTableauFromStock;
  final CardMoves _cardMoves;

  int _excludedRank = 0;

  bool get hasStockPile => (_stockPileIndex >= 0);

  void deal(DealSequence dealSequence, int seed, {VoidCallback? whenDone,}) {
    // final dealSequence = gameSpec.dealSequence;
    final List<CardView> cardsToDeal = [];
    for (final CardView card in _cards) {
      if (card.isBaseCard) {
        if (hasStockPile) {
          _piles[_stockPileIndex].put(card);
        }
      } else {
        cardsToDeal.add(card);
      }
    }
    // ??????? cardsToDeal.shuffle(Random(seed));
    cardsToDeal.shuffle();

    // print('Cards in Deal: $cardsToDeal');

    List<Pile> dealTargets = [];
    for (Pile pile in _piles) {
      if ((pile.pileType == PileType.stock) ||
          (pile.pileType == PileType.waste)) {
        continue; // These must be dealt last or not at all.
      }
      if (pile.nCardsToDeal > 0) {
        dealTargets.add(pile);
      }
    }

    List<CardView> movingCards = [];
    var nDealtCards = 0;
    var nCardsArrived = 0;
    double cardDealTime = 0.1;
    for (Pile target in dealTargets) {
      if (dealSequence == DealSequence.wholePileAtOnce) {
        bool pileFaceUp = false;
        bool lastFaceUp = false;
        int nCardsLeftToDeal = target.nCardsToDeal;
        while (nCardsLeftToDeal > 0 && cardsToDeal.isNotEmpty) {
          CardView card = cardsToDeal.removeLast();
          movingCards.add(card);
          switch (target.pileSpec.dealFaceRule) {
            case DealFaceRule.faceUp:
              pileFaceUp = true;
            case DealFaceRule.lastFaceUp:
              if (nCardsLeftToDeal == 1) {
                lastFaceUp = true;
              }
            case DealFaceRule.faceDown:
            case DealFaceRule.notUsed:
              break;
          }
          nCardsLeftToDeal--;
        }
        List<CardView> lastCard = [];
        if (lastFaceUp) {
          lastCard.add(movingCards.removeLast());
        }
        if (movingCards.isNotEmpty) {
          target.receiveMovingCards(
            movingCards,
            speed: 15.0,
            startTime: nDealtCards * cardDealTime,
            flipTime: pileFaceUp ? 0.3 : 0.0,
            intervalTime: cardDealTime,
            onComplete: () {
              nCardsArrived++;
              if (nCardsArrived == nDealtCards) {
                print('DEAL COMPLETE...');
                whenDone?.call();
              }
            }
          );
          nDealtCards += movingCards.length;
        }
        if (lastFaceUp) {
          target.receiveMovingCards(
            lastCard,
            speed: 15.0,
            startTime: nDealtCards * cardDealTime,
            flipTime: 0.3,
            onComplete: () {
              nCardsArrived++;
              if (nCardsArrived == nDealtCards) {
                print('DEAL COMPLETE...');
                whenDone?.call();
              }
            }
          );
          nDealtCards++;
        }
        movingCards.clear();
        lastCard.clear();
      } else if (dealSequence == DealSequence.pilesInTurn) {
        // TODO - NOT IMPLEMENTED YET.
        throw UnimplementedError(
            'Dealing from L to R across the Piles is not implemented yet.');
      }
    }

    _piles[_stockPileIndex].dump();
    print('DEAL: TRANSFER REMAINING CARDS TO STOCK PILE...');
    if (hasStockPile && cardsToDeal.isNotEmpty) {
      for (CardView card in cardsToDeal) {
        _piles[_stockPileIndex].put(card);
      }
      _piles[_stockPileIndex].dump();
      cardsToDeal.clear();
    }
  }

  void completeTheDeal() {
    // Last step of the deal - but only if the Game excludes some cards or needs
    // to deal a new Card to a Tableau that is empty or becomes empty.
    //
    // It depends on data and a function passed to the Dealer constructor.
    assert ((_gameSpec.excludedRank > 0) || _gameSpec.redealEmptyTableau);
    assert (_gameSpec.excludedRank <= 13);

    final _excludedRank = _gameSpec.excludedRank; // e.g. Aces in Mod 3 Game.

    List<CardView> excludedCards = [];
    for (Pile pile in _piles) {
      if (pile.pileType == PileType.foundation) {
        pile.removeExcludedCards(_excludedRank, excludedCards);
        if (excludedCards.isNotEmpty) {
          print('Pile ${pile.toString()} excludedCards $excludedCards');
          if (_excludedCardsPileIndex >= 0) {
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
    _cardMoves.reset(); // Clear any Moves made so far (not part of gameplay).
  }
} // End of Dealer class.
