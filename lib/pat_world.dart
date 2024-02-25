import 'dart:core';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import 'components/pile.dart';
import 'components/card_view.dart';
import 'components/flat_button.dart';
// import 'components/waste_pile.dart'; // TODO - How to access _cards ????

import 'models/card_moves.dart';

import 'pat_game.dart';
import 'specs/pat_enums.dart';
import 'specs/pat_specs.dart';
import 'specs/card_image_specs.dart';

import 'views/game_play.dart';

class PatWorld extends World with HasGameReference<PatGame> {
  static const cardDeckName = 'Ancient_Egyptians'; // TODO - Setting needed.
  static const cardWidth = 900.0;
  static const cardHeight = 1200.0;
  static const cardMargin = 100.0;
  static const topMargin = 500.0;
  static const shrinkage = 40.0;

  // Predefine some rectangles, for efficiency of CardView and Pile rendering.
  static final cardRect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(0, 0, cardWidth, cardHeight),
    const Radius.circular(75.0),
  );
  static final pileRect = cardRect.deflate(shrinkage)
     .shift(const Offset(cardMargin / 2.0, 0.0));
  static final baseCardRect = cardRect.deflate(shrinkage);

  static final Vector2 cardSize = Vector2(cardWidth, cardHeight);
  static final topLeft = Vector2(0.0, topMargin);

  /// Constant used to decide when a short drag is treated as a TapUp event.
  static const double dragTolerance = cardWidth / 5;

  static const suits = '♥♦♣♠';
  static const ranks = ' A23456789TJQK';

  // final bool debugMode = true;

  final List<CardView> cards = [];
  final List<Pile> piles = [];

  final List<Pile> foundations = [];
  final List<Pile> tableaus = [];

  late CardMoves cardMoves;
  final gameplay = Gameplay();

  Pile get stock => piles[_stockPileIndex];
  Pile get waste => piles[_wastePileIndex];

  bool get hasStockPile => _stockPileIndex >= 0;
  bool get hasWastePile => _wastePileIndex >= 0;
  int get stockPileIndex => _stockPileIndex;
  int get wastePileIndex => _wastePileIndex;

  int _stockPileIndex = -1; // No Stock Pile yet: not all games have one.
  int _wastePileIndex = -1; // No Waste Pile yet: not all games have one.
  int _excludedCardsPileIndex = -1; // Games with excluded Cards might use this.

  var lastWastePile = false; // Set if no more Stock Pile turnovers are allowed.

  @override
  Future<void> onLoad() async {
    print('Game Index is ${game.gameIndex} name '
        '${PatData.gameList[game.gameIndex].gameName}');
    final gameSpec = PatData.gameList[game.gameIndex];
    final cellSize = Vector2(cardWidth + gameSpec.cardPadX,
        cardHeight + gameSpec.cardPadY);

    // Create List<CardView> cards: it will have (1 + 52 * nPacks) cards in it.
    //
    // The first is a Base Card, which does NOT take part in gameplay, but acts
    // as a base for the Stock Pile (if any). It exists to intercept taps on an
    // empty Stock Pile. It has two back-sprites but is painted only in outline.
    //
    // The others, indexed from 1 to 52 or 1 to 104, are the actual playing
    // cards. Each has a front and a back Sprite, to be rendered as required.
    // The cardSpecs Spritesheet has 53 images on it: 52 for the card faces
    // and one for the card backs. The latter is copied 52 or 104 times.

    String cardDeckImagesData = '$cardDeckName.png';
    String cardDeckSpriteData = 'assets/images/$cardDeckName.txt';
    await Flame.images.load(cardDeckImagesData);
    Future<String> data = Flame.bundle.loadString(cardDeckSpriteData);
    final String cardDataString = await Future.any([data,]);

    ImageSpecs cardSpecs = ImageSpecs();
    cards.addAll(cardSpecs.loadCards(
        cardDeckName, cardDataString, 53, gameSpec.nPacks),);

    // Create List<Pile> piles: it can have any number of piles in it, depending
    // on the game and its layout. Many games have a Stock Pile and Waste Pile,
    // for dealing hidden cards during play, but some have no Waste Pile and
    // can deal onto the Tableaus during play, and some have no Stock Pile
    // because all cards are dealt face-up at the start of play, e.g. Freecell.

    int nExceptions = generatePiles(gameSpec, cellSize);
    if (nExceptions > 0) {
      throw FormatException('FOUND $nExceptions FormatExceptions');
    }

    // Set up a CardMoves Model class that records valid Moves and can undo
    // or redo them. The basic Move is to take one or more cards from the
    // end of one pile and add it/them to the end of another pile, working
    // within the rules of the current game and remembering any card flips
    // that were required. There is also a Move to turn over the whole Stock
    // or Waste Pile. The validity of each Move is checked just once, during
    // the Tap or DragAndDrop callback that accepted and created the Move.
    // The cardMoves object is not a Component, so is not added to the World.
/*
    print('GAME DATA DIMENSIONS: cards ${cards.length} piles ${piles.length}');
    cardMoves.init(cards, piles, stockPileIndex, wastePileIndex);

    // Move all cards to a place in this game-layout from which they are dealt.

    // TODO - THIS will have to be part of gameplay.start().
    final dealerX = (gameSpec.dealerCol + 0.5) * cellSize.x;
    final dealerY = gameSpec.dealerRow * cellSize.x;
    final dealerPosition = Vector2(dealerX, dealerY);
    var cardPriority = 1;
    for (CardView card in cards) {
      card.position = dealerPosition;
      card.priority = cardPriority++;
    }
*/
    // Set up the FlameGame's World and Camera, then shuffle and deal the cards.

    addAll(cards);
    addAll(piles);

    addButton('New game', 0.5 * cellSize.x, Action.newGame);
    addButton('Undo move', 3.5 * cellSize.x, Action.undo);
    addButton('Redo move', 4.5 * cellSize.x, Action.redo);

    final playAreaWidth = gameSpec.nCellsWide * cellSize.x;
    final playAreaHeight = gameSpec.nCellsHigh * cellSize.y;
    final playAreaSize = topLeft + Vector2(playAreaWidth, playAreaHeight);

    final camera = game.camera;
    camera.viewfinder.visibleGameSize = playAreaSize;
    camera.viewfinder.position = Vector2(playAreaSize.x / 2.0, 0.0);
    camera.viewfinder.anchor = Anchor.topCenter;
    print('WORLD SIZE ${game.size} play area size $playAreaSize');

    print('GAME DATA DIMENSIONS: cards ${cards.length} piles ${piles.length}');

    cardMoves = CardMoves(cards, piles, stockPileIndex);

    // Move all cards to a place in this game-layout from which they are dealt.

    // TODO - THIS will have to be part of gameplay.start().
    final dealerX = (gameSpec.dealerCol + 0.5) * cellSize.x;
    final dealerY = gameSpec.dealerRow * cellSize.x;
    final dealerPosition = Vector2(dealerX, dealerY);
    var cardPriority = 1;
    for (CardView card in cards) {
      card.position = dealerPosition;
      card.priority = cardPriority++;
    }

    deal(gameSpec);

    gameplay.begin(cardMoves, cards, piles, stockPileIndex, wastePileIndex);
  }

  void addButton(String label, double buttonX, Action action) {
    final button = FlatButton(
      label,
      size: Vector2(0.9 * cardWidth, 0.55 * topMargin),
      position: Vector2(buttonX, topMargin / 2),
      onReleased: () {
        switch (action) {
          case Action.newGame:
            game.changeGame();
            game.world = PatWorld();
          case Action.undo:
            cardMoves.undoMove();
          case Action.redo:
            cardMoves.redoMove();
          case Action.newDeal:
          case Action.sameDeal:
            break;
        }
      },
    );
    add(button);
  }

  void deal(GameSpec gameSpec) {
    final dealSequence = gameSpec.dealSequence;
    final List<CardView> cardsToDeal = [];
    for (final CardView card in cards) {
      if (card.isBaseCard) {
        if (hasStockPile) {
          piles[_stockPileIndex].put(card);
        }
      } else {
        cardsToDeal.add(card);
      }
    }
    // cardsToDeal.shuffle(Random(game.seed));
    cardsToDeal.shuffle();

    // print('Cards in Deal: $cardsToDeal');

    List<DealTarget> dealTargets = [];
    // print('Number of piles ${piles.length}');
    for (Pile pile in piles) {
      if ((pile.pileType == PileType.stock) ||
          (pile.pileType == PileType.waste)) {
        continue; // These must be dealt last.
      }
      print('Deal ${pile.pileType} row ${pile.gridRow} col ${pile.gridCol}'
          ' nCards ${pile.nCardsToDeal} pos ${pile.position}');
      if (pile.nCardsToDeal > 0) {
        dealTargets.add(DealTarget(pile));
        dealTargets.last.init();
      }
    }

    // print('CARDS READY TO DEAL');
    List<CardView> movingCards = [];
    var nDealtCards = 0;
    var nCardsArrived = 0;
    double cardDealTime = 0.1;
    for (DealTarget target in dealTargets) {
      // print('Deal Sequence: $dealSequence\n');
      if (dealSequence == DealSequence.wholePileAtOnce) {
        bool pileFaceUp = false;
        bool lastFaceUp = false;
        while (target.nCardsLeftToDeal > 0 && cardsToDeal.isNotEmpty) {
          CardView card = cardsToDeal.removeLast();
          movingCards.add(card);
          // print('Deal ${card.toString()} target ${target.pile.pileType}'
          // ' row ${target.pile.gridRow} col ${target.pile.gridCol}'
          // ' nCards left ${target.nCardsLeftToDeal})');
          switch (target.dealFaceRule) {
            case DealFaceRule.faceUp:
              pileFaceUp = true;
            case DealFaceRule.lastFaceUp:
              if (target.nCardsLeftToDeal == 1) {
                lastFaceUp = true;
              }
            case DealFaceRule.faceDown:
            case DealFaceRule.notUsed:
              break;
          }
          target.nCardsLeftToDeal--;
        }
        List<CardView> lastCard = [];
        if (lastFaceUp) {
          lastCard.add(movingCards.removeLast());
        }
        if (movingCards.isNotEmpty) {
          target.pile.receiveMovingCards(
            movingCards,
            speed: 15.0,
            startTime: nDealtCards * cardDealTime,
            flipTime: pileFaceUp ? 0.3 : 0.0,
            intervalTime: cardDealTime,
            // isRelativeStartTime: true,
            onComplete: () {
              nCardsArrived++;
              print('Arrived $nCardsArrived Dealt $nDealtCards');
              if (nCardsArrived == nDealtCards) {
                print('DEAL COMPLETE...');
                // ??????? finishTheDeal(gameSpec);
              }
            }
          );
          nDealtCards += movingCards.length;
        }
        if (lastFaceUp) {
          target.pile.receiveMovingCards(
            lastCard,
            speed: 15.0,
            startTime: nDealtCards * cardDealTime,
            flipTime: 0.3,
            // isRelativeStartTime: true,
            onComplete: () {
              nCardsArrived++;
              print('Arrived $nCardsArrived Dealt $nDealtCards');
              if (nCardsArrived == nDealtCards) {
                print('DEAL COMPLETE...');
                // ??????? finishTheDeal(gameSpec);
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

    piles[_stockPileIndex].dump();
    print('DEAL: TRANSFER REMAINING CARDS TO STOCK PILE...');
    if (hasStockPile && cardsToDeal.isNotEmpty) {
      // print('${cardsToDeal.length} CARDS LEFT TO DEAL: $cardsToDeal');
      for (CardView card in cardsToDeal) {
        piles[_stockPileIndex].put(card);
      }
      piles[_stockPileIndex].dump();
      cardsToDeal.clear();
    }
  }
/*
  void finishTheDeal(GameSpec gameSpec) {

    // TODO - Could do cardMoves.init() here... making a clean break between
    //        PatWorld setup and gameplay. Could do deal and letsCelebrate???
    if (gameSpec.excludedRank > 0 || gameSpec.redealEmptyTableau) {
      // Get CardMoves to finish the deal (e.g. remove Aces in Mod 3).
      cardMoves.completeTheDeal(gameSpec, _excludedCardsPileIndex);
    }
  }
*/
  // TODO - Maybe could do all this in a helper Class...
  int generatePiles(GameSpec gameSpec, Vector2 cellSize) {
    var pileSpecErrorCount = 0;
    var foundStockSpec = false;
    var foundWasteSpec = false;
    var pileIndex = 0;
    for (GamePileSpec gamePile in gameSpec.gamePilesSpec) {
      final pileSpec = gamePile.pileSpec;
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
        final position = topLeft + Vector2(pileX, pileY);
        final size = Vector2(cellSize.x, cellSize.y);
        PileParameters p = (pileSpec.pileType, pileIndex, /*cellSize.x, cellSize.y,*/
            row: row, col: col, deal: deal, position: position, size: size);
        print('New Pile ${pileSpec.pileType} $pileIndex pos $position row $row col $col');
        final pile = Pile(pileSpec, p);
/*
        final pile = Pile(
          pileSpec,
          pileIndex,
          cellSize.x,
          cellSize.y,
          position: position,
          row: row,
          col: col,
          deal: deal,
        );
*/
        piles.add(pile);

        // print('New pile: row $row col $col deal $deal '
            // 'pos $position ${pile.pileType}');
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
}

class DealTarget {
  DealTarget(this.pile);

  final Pile pile;
  var nCardsLeftToDeal = 0;
  var dealFaceRule = DealFaceRule.faceDown;

  init() {
    nCardsLeftToDeal = pile.nCardsToDeal;
    dealFaceRule = pile.pileSpec.dealFaceRule;
  }
}
