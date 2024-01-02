import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import 'components/pile.dart';
import 'components/card_view.dart';

import 'pat_game.dart';
import 'specs/pat_specs.dart';
import 'specs/card_image_specs.dart';

class PatWorld extends World with HasGameReference<PatGame> {
  static const cardDeckName = 'Ancient_Egyptians'; // A Setting is needed.
  // final PatGameID gameID = PatGameID.fortyAndEight;
  // final PatGameID gameID = PatGameID.mod3;
  final PatGameID gameID = PatGameID.klondikeDraw1;

  static const cardWidth = 900.0;
  static const cardHeight = 1200.0;
  static const cardMargin = 100.0;
  static const topMargin = 500.0;
  static const shrinkage = 40.0; // Applied to Pile Rect and Base Card rendering.
  static final cardRect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(0, 0, cardWidth, cardHeight),
    const Radius.circular(75.0),
  );
  static final Vector2 cardSize = Vector2(cardWidth, cardHeight);
  static final Vector2 cellSize =
      Vector2(cardWidth + cardMargin, cardHeight + cardMargin);
  static final topLeft = Vector2(0.0, topMargin);

  /// Constant used to decide when a short drag is treated as a TapUp event.
  static const double dragTolerance = cardWidth / 5;

  static const suits = '♥♦♣♠';
  static const ranks = ' A23456789TJQK';
  // final bool debugMode = true;

  final List<CardView> cards = [];
  final List<Pile> piles = [];

  bool hasStockPile = false;
  bool hasWastePile = false;
  var wasteTurnoverCount = 0;

  late final Pile stock;
  late final Pile waste;

  final List<Pile> foundations = [];
  final List<Pile> tableaus = [];

  late final GameSpec _gameSpec;

  @override
  Future<void> onLoad() async {
    String cardDeckImagesData = '$cardDeckName.png';
    String cardDeckSpriteData = 'assets/images/$cardDeckName.txt';

    bool gameNotFound = true;
    for (final GameSpec game in PatData.gameList) {
      if (game.gameID == gameID) {
        // printGameSpec(game);
        gameNotFound = false; // Game Spec found.
        _gameSpec = game;
        break;
      }
    }
    if (gameNotFound) {
      // print('$gameID: Game not found');
      return;
    }

    await Flame.images.load(cardDeckImagesData);
    String cardDataString = await Flame.bundle.loadString(cardDeckSpriteData);

    // List<Pile> can have any number of piles in it, depending on the game and
    // its layout. Many games have a Stock Pile and a Waste Pile, for dealing
    // hidden cards during play, but some have a Stock Pile only and can deal
    // onto the Tableaus during play, and some have no Stock Pile because all
    // cards are dealt face-up at the start of play, e.g. Freecell.

    var foundStockSpec = false;
    var foundWasteSpec = false;
    for (GamePileSpec gamePile in _gameSpec.gamePilesSpec) {
      PileSpec spec = gamePile.pileSpec;
      int nPilesOfThisType = gamePile.nPilesSpec;
      assert(nPilesOfThisType == gamePile.pileTrios.length);
      for (PileTrio trio in gamePile.pileTrios) {
        int row = trio.$1;
        int col = trio.$2;
        int deal = trio.$3;
        Vector2 position =
            topLeft + Vector2((col + 0.5) * cellSize.x, row * cellSize.y);
        final pile = Pile(
          spec,
          position: position,
          row: row,
          col: col,
          deal: deal,
        );
        pile.init();

        piles.add(pile);

        // print('New pile: row $row col $col pos $position ${pile.pileType}');
        switch (pile.pileType) {
          case PileType.stock:
            if (!_gameSpec.hasStockPile) break;
            stock = pile;
            hasStockPile = true;
            foundStockSpec = true;
          case PileType.waste:
            if (!_gameSpec.hasWastePile) break;
            waste = pile;
            hasWastePile = true;
            foundWasteSpec = true;
          case PileType.foundation:
            foundations.add(pile);
          case PileType.tableau:
            tableaus.add(pile);
        }
      }
    }

    // List<CardView> will have (1 + 52 * nPacks) cards in it.
    //
    // The first is a Base Card, which does NOT take part in gameplay, but acts
    // as a base for the Stock Pile (if any). It exists to intercept taps on an
    // empty Stock Pile, has two back-sprites and is rendered only in outline.
    //
    // The others, indexed from 1 to 52 or 1 to 104, are the actual playing
    // cards. Each has a front and a back Sprite, to be rendered as required.
    // The cardSpecs Spritesheet as 53 images on it: 52 for the card faces and
    // 1 for the card backs, which is copied 52 or 104 times.

    ImageSpecs cardSpecs = ImageSpecs();
    cards.addAll(
      cardSpecs.loadCards(cardDeckName, cardDataString, 53, _gameSpec.nPacks),
    );
    // print('Cards: $cards');

    var pileSpecErrorCount = 0;
    var nNeeded = 4 * _gameSpec.nPacks;
    if (!foundStockSpec && hasStockPile) {
      // print('NO Stock Spec: hasStockPile $hasStockPile found $foundStockSpec');
      pileSpecErrorCount++;
    } else if (!foundWasteSpec && hasWastePile) {
      // print('NO Waste Spec: hasWastePile $hasWastePile found $foundWasteSpec');
      pileSpecErrorCount++;
    } else if (foundations.length < nNeeded) {
      // print('Only ${foundations.length} Foundation Specs: expected $nNeeded');
      pileSpecErrorCount++;
    } else if (tableaus.isEmpty) {
      // print('NO Tableau Specs found');
      pileSpecErrorCount++;
    }
    if (pileSpecErrorCount > 0) return;

    // print('${piles.length} piles, Stock: $hasStockPile'
        // ' Waste: $hasWastePile Foundations: ${foundations.length}'
        // ' Tableaus: ${tableaus.length} Dealer OK');

    var cardPriority = 1;
    final dealerPosition = Vector2(
        _gameSpec.dealerCol * cellSize.x, _gameSpec.dealerRow * cellSize.y);
    for (CardView card in cards) {
      card.position = dealerPosition + Vector2(cellSize.x / 2.0, 0.0);
      card.priority = cardPriority;
      cardPriority++;
    }

    addAll(piles);
    addAll(cards);

    int nCols = _gameSpec.nCellsWide;
    int nRows = _gameSpec.nCellsHigh;
    Vector2 playAreaSize =
        topLeft + Vector2(nCols * cellSize.x, nRows * cellSize.y);
    // print('$nRows by $nCols cells of size $cellSize, Play area: $playAreaSize');

    final camera = game.camera;
    camera.viewfinder.visibleGameSize = playAreaSize;
    camera.viewfinder.position = Vector2(playAreaSize.x / 2.0, 0.0);
    camera.viewfinder.anchor = Anchor.topCenter;
  }

  @override
  void onMount() {
    // print('Cards BEFORE Deal: $cards');
    deal(_gameSpec.dealSequence);
  }

  void deal(DealSequence dealSequence) {
    final List<CardView> cardsToDeal = [];
    for (final CardView card in cards) {
      if (card.isBaseCard) {
        if (hasStockPile) {
          stock.put(card, MoveMethod.deal);
        }
      } else {
        cardsToDeal.add(card);
      }
    }
    cardsToDeal.shuffle();

    // print('Cards in Deal: $cardsToDeal');

    List<DealTarget> dealTargets = [];
    // print('Number of piles ${piles.length}');
    for (Pile pile in piles) {
      if ((pile.pileType == PileType.stock) ||
          (pile.pileType == PileType.waste)) {
        continue; // These must be dealt last.
      }
      // print('Target? ${pile.pileType} row ${pile.gridRow} col ${pile.gridCol}'
          // ' nCards ${pile.nCardsToDeal}');
      if (pile.nCardsToDeal > 0) {
        dealTargets.add(DealTarget(pile));
        dealTargets.last.init();
      }
    }

    // print('CARDS READY TO DEAL');
    for (DealTarget target in dealTargets) {
      // print('Deal Sequence: $dealSequence\n');
      if (dealSequence == DealSequence.wholePileAtOnce) {
        while (target.nCardsLeftToDeal > 0 && cardsToDeal.isNotEmpty) {
          CardView card = cardsToDeal.removeLast();
          // print('Deal ${card.toString()} target ${target.pile.pileType}'
              // ' row ${target.pile.gridRow} col ${target.pile.gridCol}'
              // ' nCards left ${target.nCardsLeftToDeal})');
          switch (target.dealFaceRule) {
            case DealFaceRule.faceUp:
              card.flipView();
            case DealFaceRule.lastFaceUp:
              if (target.nCardsLeftToDeal == 1) {
                card.flipView();
              }
            case DealFaceRule.faceDown:
            case DealFaceRule.notUsed:
              break;
          }
          target.pile.put(card, MoveMethod.deal);
          target.nCardsLeftToDeal--;
        }
      } else if (dealSequence == DealSequence.pilesInTurn) {
        // TODO - NOT IMPLEMENTED YET.
      }
    }
    if (hasStockPile && cardsToDeal.isNotEmpty) {
      // print('${cardsToDeal.length} CARDS LEFT TO DEAL: $cardsToDeal');
      for (CardView card in cardsToDeal) {
        stock.put(card, MoveMethod.deal);
      }
      cardsToDeal.clear();
    }
  }

  // Probably OBSOLETE...
  int findPile(PileType pileType) {
    int index = 0;
    for (Pile pile in piles) {
      if (pile.pileType == pileType) {
        return index;
      }
      index++;
    }
    return -1;
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
