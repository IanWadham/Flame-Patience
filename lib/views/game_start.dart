import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../components/card_view.dart';
import '../components/pile.dart';

import '../models/card_moves.dart';

import '../pat_world.dart';
import '../specs/pat_enums.dart';
import '../specs/pat_specs.dart';

// There are two distinct classes in this file: GameLayOut and Dealer.

class GameLayout {
// Decode GameSpec into Piles and their layout (called from PatWorld's onLoad).

  int generatePiles(GameSpec gameSpec, Vector2 cellSize, List<Pile> piles) {
    var pileSpecErrorCount = 0;
    var foundStockSpec = false;
    var foundWasteSpec = false;
    var pileIndex = 0;

    final List<Pile> foundations = [];
    final List<Pile> tableaus = [];
    final List<Pile> freecells = [];
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
        // print('New Pile ${pileSpec.pileType} $pileIndex pos $position '
        //     'row $row col $col');
        final pile = Pile(
          pileSpec,
          pileIndex,
          cellSize.x,
          cellSize.y,
          deal: deal,
          position: position,
        );

        piles.add(pile);

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
          case PileType.freecell:
            freecells.add(pile);
            break;
        }
        pileIndex++;
      }
    }

    final foundationsNeeded = gameSpec.gameID == PatGameID.mod3 ? 24
        : 4 * gameSpec.nPacks;
    if (!foundStockSpec) {
      if (gameSpec.hasStockPile) {
        throw FormatException(
            'NO Stock Pile specified but GameSpec hasStockPile is true');
        pileSpecErrorCount++;
      } else {
        // Create a Stock Pile, but off-screen and just for Dealer usage.
        final pile = createDefaultStockPile(cellSize, piles.length);
        _stockPileIndex = piles.length;
        piles.add(pile);
      }
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

  Pile createDefaultStockPile(Vector2 cellSize, int pileIndex) {
    final pileSpec = PatData.dealerStock;
    final pile = Pile(
          pileSpec,
          pileIndex,
          cellSize.x,
          cellSize.y,
          position: Vector2(0.0, 0.0) - cellSize,
    );
    return pile;
  }
} // End of GameLayout class.


class Dealer extends Component with HasWorldReference<PatWorld> {
// This Class shuffles and deals into the layout at the start of a Game and
// makes changes after the deal (e.g. in Mod 3, remove Aces, refill Tableaus).

  Dealer(this._cards, this._piles, this._stockPileIndex,
      this._gameSpec, this._excludedCardsPileIndex, this._cardMoves,
  );

  // The following data items are needed by the deal() and completeTheDeal()
  // methods and are provided by the GamePlay.start() method.
  final List<CardView> _cards;
  final List<Pile> _piles;
  final int _stockPileIndex;
  final GameSpec _gameSpec;
  final int _excludedCardsPileIndex;
  final CardMoves _cardMoves;

  int _excludedRank = 0;

  bool get hasStockPile => (_stockPileIndex >= 0);

  var nDealtCards = 0;
  var nCardsArrived = 0;

  void deal(DealSequence dealSequence, int seed, {VoidCallback? whenDone,}) {
    final cardsToDeal = List<CardView>.of(_cards);
    assert(_stockPileIndex >= 0);
    final Pile stockPile = _piles[_stockPileIndex];
    final baseCard = cardsToDeal.removeAt(0);
    stockPile.put(baseCard);

    // Shuffle the cards. Put them in the Stock Pile, from which they are dealt.
    cardsToDeal.shuffle(Random(seed));
    stockPile.dropCards(cardsToDeal);
    cardsToDeal.clear();

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

    print('BEFORE DEAL');
    stockPile.dump();

    if (_gameSpec.gameID == PatGameID.grandfather) {
      // The Grandfather Game has an idiosyncratic deal, which is hand-coded.
      grandfatherDeal(stockPile, dealTargets);
      return;
    }

    List<CardView> movingCards = [];
    double cardDealTime = 0.1;
    for (Pile target in dealTargets) {
      if (dealSequence == DealSequence.wholePileAtOnce) {
        // Decide what mixture of FaceDown and FaceUp cards to deal.
        int nCardsLeftToDeal = target.nCardsToDeal;
        int nCardsFaceDown = 0;
        int nCardsFaceUp = 0;
        switch (target.pileSpec.dealFaceRule) {
          case DealFaceRule.faceUp:
            nCardsFaceUp = nCardsLeftToDeal;
          case DealFaceRule.lastFaceUp:
            nCardsFaceDown = nCardsLeftToDeal - 1;
            nCardsFaceUp = 1;
          case DealFaceRule.last2FaceUp:
            if (nCardsLeftToDeal <= 2) {
              nCardsFaceUp = nCardsLeftToDeal;
            } else {
              nCardsFaceDown = nCardsLeftToDeal - 2;
              nCardsFaceUp = 2;
            }
          case DealFaceRule.last5FaceUp:
            if (nCardsLeftToDeal <= 5) {
              nCardsFaceUp = nCardsLeftToDeal;
            } else {
              nCardsFaceDown = nCardsLeftToDeal - 5;
              nCardsFaceUp = 5;
            }
          case DealFaceRule.faceDown:
            nCardsFaceDown = nCardsLeftToDeal;
          case DealFaceRule.notUsed:
            break;
        }

        // Deal 1 or 2 chunks: all FaceDown, all FaceUp or FaceDown then FaceUp.
        while (nCardsLeftToDeal > 0 && (stockPile.nCards > 0)) {
          int nStock = stockPile.nCards;
          int nToDeal = 0;
          bool flip = false;
          if (nCardsFaceDown > 0) {
            nToDeal = (nStock < nCardsFaceDown) ? nStock : nCardsFaceDown;
            movingCards = stockPile.grabCards(nToDeal);
            nCardsFaceDown = 0;
          } else if (nCardsFaceUp > 0) {
            flip = true;
            nToDeal = (nStock < nCardsFaceUp) ? nStock : nCardsFaceUp;
            movingCards = stockPile.grabCards(nToDeal);
            nCardsFaceUp = 0;
          }
          nCardsLeftToDeal -= nToDeal;
          if (movingCards.isNotEmpty) {
            target.receiveMovingCards(
              movingCards,
              speed: 15.0,
              startTime: nDealtCards * cardDealTime,
              flipTime: flip ? 0.3 : 0.0,
              intervalTime: cardDealTime,
              onComplete: () {
                nCardsArrived++;
                if (nCardsArrived == nDealtCards) {
                  whenDone?.call();
                }
              }
            );
            nDealtCards += movingCards.length;
          }
        }
        movingCards.clear();
      } else if (dealSequence == DealSequence.pilesInTurn) {
        throw UnimplementedError(
            'Dealing from L to R across the Piles is not implemented yet.');
      }
    } // End for Pile target

    stockPile.dump();
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
              speed: 10.0,
              flipTime: 0.0, // No flip.
            );
          } else { // Not implemented yet.
            throw UnimplementedError(
                'Excluded Rank $_excludedRank has no Excluded Card Pile');
          }
          excludedCards.clear();
        }
      } else if (pile.pileType == PileType.tableau) {
        if (pile.hasNoCards ||
            (_cards[pile.topCardIndex].rank == _excludedRank)) {
          pile.replenishTableauFromStock(
            _stockPileIndex,
            _excludedCardsPileIndex
          );
        }
      }
    }
    _cardMoves.reset(); // Clear any Moves made so far (not part of Gameplay).
  }

  void grandfatherDeal(Pile stockPile, List<Pile> dealTargets) {
    // Implement the Grandfather Game's idiosyncratic Deal and Redeal actions.
    final nCols = dealTargets.length;
    final nRows = nCols;
    int nStock = stockPile.nCards;
    int start = 0;
    int stop = nCols - 1;
    int inc = 1;

    // Deal an inverted pyramid of cards, row by row, most face-down.
    for (int row = 0; (row < nRows) && (nStock > 0); row++) {
      int n = start;
      bool faceUp = true;
      do {
        // Deal a card.
        print('Row $row n $n ends $start $stop inc $inc');
        dealGrandfatherCard(stockPile, dealTargets[n], faceUp: faceUp);
        faceUp = false;
        n += inc;
      } while ((--nStock > 0) && (n != stop + inc));
      // Switch between L to R deal and reverse: 1 card less per row each time.
      int temp = start + inc;
      start = stop;
      stop = temp;
      inc = -inc;
    }
    int n = 0;
    while (nStock-- > 0) {
      // If cards available, keep dealing to 6 of the 7 Tableaus face-up.
      dealGrandfatherCard(stockPile, dealTargets[n + 1], faceUp: true);
      n = (n + 1) % 6;
    }
    for (int col = 0; col < 7; col++) {
      // Ensure that the top card of each Tableau is face-up.
    }
  }

  void dealGrandfatherCard(Pile stockPile, Pile pile, {required bool faceUp}) {
    // Deal one card in Grandfather Game.
    pile.receiveMovingCards(
      stockPile.grabCards(1),
      speed: 25.0,
      startTime: 0.2 * nDealtCards,
      flipTime: faceUp ? 0.1 : 0.0,
      onComplete: () {
        nCardsArrived++;
        if (nCardsArrived == nDealtCards) {
          print('GRANDFATHER DEAL FINISHED'); // whenDone?.call();
          adjustGrandfatherTopCards();
        }
      }
    );
    nDealtCards++;
  }

  void adjustGrandfatherTopCards() {
    // In the 2nd and 3rd deals, with fewer than 52 cards, some top-cards
    // might have ended up face-down when the Stock Pile ran out of cards.
    for (Pile pile in _piles) {
      if ((pile.pileType == PileType.tableau) && (pile.topCardIndex != -1)) {
        CardView card = _cards[pile.topCardIndex];
        if (card.isFaceDownView) {
          card.flipView();
        }
      }
    }
  }
} // End of Dealer class.
