import 'dart:core';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import 'components/pile.dart';
import 'components/card_view.dart';
import 'components/flat_button.dart';

import 'models/card_moves.dart';

import 'pat_game.dart';
import 'specs/pat_enums.dart';
import 'specs/pat_specs.dart';
import 'specs/card_image_specs.dart';

import 'views/game_play.dart';
import 'views/game_start.dart';

class PatWorld extends World with HasGameReference<PatGame> {
  static const cardDeckName = 'Ancient_Egyptians'; // TODO - Setting needed.
  static const cardWidth = 900.0;
  static const cardHeight = 1200.0;
  static const shrinkage = 40.0;
  static const topMargin = 600.0;

  // Predefine some rectangles, for efficiency of CardView and Pile rendering.
  static final cardRect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(0, 0, cardWidth, cardHeight),
    const Radius.circular(75.0),
  );
  static var pileRect = cardRect.deflate(shrinkage)
     .shift(const Offset(50.0, 0.0)); // Re-aligned in onLoad() using cardPadX.
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

  // Don't need foundations, tableaus and cardMoves in the World any more?
  final List<Pile> foundations = [];
  final List<Pile> tableaus = [];

  late Gameplay gameplay;

  int _stockPileIndex = -1; // No Stock Pile yet: not all games have one.
  int _wastePileIndex = -1; // No Waste Pile yet: not all games have one.
  int _excludedCardsPileIndex = -1; // Games with excluded Cards might use this.

  var lastWastePile = false; // Set if no more Stock Pile turnovers are allowed.

  @override
  Future<void> onLoad() async {
    print('Game Index is ${game.gameIndex} '
        'name ${PatData.gameList[game.gameIndex].gameName}');
    final gameSpec = PatData.gameList[game.gameIndex];
    final cellSize = Vector2(cardWidth + gameSpec.cardPadX,
        cardHeight + gameSpec.cardPadY);
    pileRect = cardRect.deflate(shrinkage)
        .shift(Offset((cellSize.x - cardWidth) / 2.0, 0.0));

    // Create List<CardView> cards: it will have (1 + 52 * nPacks) cards in it.
    //
    // The first is a Base Card, which does NOT take part in gameplay, but acts
    // as a base for the Stock Pile (if any). It exists to intercept taps on an
    // empty Stock Pile and is painted only in outline.

    String cardDeckImagesData = '$cardDeckName.png';
    String cardDeckSpriteData = 'assets/images/$cardDeckName.txt';
    await Flame.images.load(cardDeckImagesData);
    Future<String> data = Flame.bundle.loadString(cardDeckSpriteData);
    final String cardDataString = await Future.any([data,]);

    ImageSpecs cardSpecs = ImageSpecs();
    cards.addAll(cardSpecs.loadCards(
        cardDeckName, cardDataString, 53, gameSpec.nPacks),);

    // The Game can have any number of piles, depending on its Spec and layout.
    final layout = GameLayout();
    layout.generatePiles(gameSpec, cellSize, piles);

    print('Viewport size: ${game.camera.viewport.size}');

    // Set up the FlameGame's World and Camera.
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

    // The gameplay object is not a Component, but it IS "owned" by PatWorld,
    // in case it is needed in the future (e.g. for saving/reloading a Game).
    gameplay = Gameplay(cards, piles);

    // Start the Game by shuffling and dealing the cards.
    gameplay.begin(gameSpec, game.seed);
  }

  void addButton(String label, double buttonX, Action action) {
    final button = FlatButton(
      label,
      size: Vector2(1.0 * cardWidth, 0.55 * topMargin),
      position: Vector2(buttonX, topMargin / 2),
      onReleased: () {
        switch (action) {
          case Action.newGame:
            game.changeGame();
            game.world = PatWorld();
          case Action.undo:
            gameplay.undoMove();
          case Action.redo:
            gameplay.redoMove();
          case Action.newDeal:
          case Action.sameDeal:
            break;
        }
      },
    );
    add(button);
  }
}
