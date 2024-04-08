import 'dart:core';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show EdgeInsets;

import 'components/pile.dart';
import 'components/card_view.dart';
import 'components/flat_button.dart';

import 'models/card_moves.dart';

import 'pat_game.dart';
import 'pat_menu_world.dart';
import 'specs/pat_enums.dart';
import 'specs/pat_specs.dart';
import 'specs/card_image_specs.dart';

import 'views/game_play.dart';
import 'views/game_start.dart';

class PatWorld extends PatBaseWorld with HasGameReference<PatGame> {
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

    final playAreaWidth = gameSpec.nCellsWide * cellSize.x;
    final playAreaHeight = gameSpec.nCellsHigh * cellSize.y;
    final playAreaSize = topLeft + Vector2(playAreaWidth, playAreaHeight);

    final buttonWidth = playAreaWidth / 8;
    addButton('Show rules', 0.5 * buttonWidth, buttonWidth, Action.showRules);
    addButton('Show moves', 1.5 * buttonWidth, buttonWidth, Action.showMoves);
    addButton('Undo move', 3.0 * buttonWidth, buttonWidth, Action.undo);
    addButton('Redo move', 4.0 * buttonWidth, buttonWidth, Action.redo);
    addButton('New deal', 5.5 * buttonWidth, buttonWidth, Action.newDeal);
    addButton('Same deal', 6.5 * buttonWidth, buttonWidth, Action.sameDeal);
    addButton('New game', 7.5 * buttonWidth, buttonWidth, Action.newGame);

    final camera = game.camera;
    camera.viewfinder.visibleGameSize = playAreaSize;
    camera.viewfinder.position = Vector2(playAreaSize.x / 2.0, 0.0);
    camera.viewfinder.anchor = Anchor.topCenter;
    print('WORLD SIZE ${game.size} play area size $playAreaSize');
    print('Viewport AR = ${game.size.x/game.size.y}, play AR ${playAreaSize.x/playAreaSize.y}');
    print('\n');

    print('GAME DATA DIMENSIONS: cards ${cards.length} piles ${piles.length}');

    // The gameplay object is not a Component, but it IS "owned" by PatWorld,
    // in case it is needed in the future (e.g. for saving/reloading a Game).
    gameplay = Gameplay(cards, piles);

    print('GAME ACTION ${game.action}');
    if (game.action != Action.sameDeal) {
      // New deal: change the Random Number Generator's seed.
      print('NEW SEED!!!');
      game.seed = Random().nextInt(PatGame.maxInt);
    }
    print('GAME SEED ${game.seed}');
    // Otherwise, use the same seed again and get a replay of the previous deal.

    // Start the Game by shuffling and dealing the cards.
    gameplay.begin(gameSpec, game.seed);
  }

  void addButton(String label, double buttonX, double buttonWidth,
      Action action) {
    final button = FlatButton(
      label,
      position: Vector2(buttonX, topMargin / 2),
      size: Vector2(0.9 * buttonWidth, 0.3 * buttonWidth), // 0.55 * topMargin),
      onReleased: () {
        game.action = action;
        switch (action) {
          case Action.newGame:
            // Change to a new type of Patience Game.
            game.changeGame();
          case Action.undo:
            gameplay.undoMove();
          case Action.redo:
            gameplay.redoMove();
          case Action.newDeal:
          case Action.sameDeal:
            // Play the same type of Patience Game.
            // If sameDeal, keep same Random seed.
            game.world = PatWorld();
          case Action.showRules:
            add(RulesAndTips());
          case Action.showMoves:
            break;
        }
      },
    );
    add(button);
  }
}


class RulesAndTips extends PositionComponent
    with TapCallbacks, HasGameReference<PatGame> {

  @override
  Future<void> onLoad() async {
    super.size = game.camera.viewfinder.visibleGameSize!;
    super.priority = 1000;
    final gameSpec = PatData.gameList[game.gameIndex];
    final rulesText = gameSpec.gameRules;
    final tipsText = gameSpec.gameTips;
    final panelWidth = size.x / 2;
    final panelHeight = size.y;
    print('ZOOM: ${game.camera.viewfinder.zoom}');
    final textStyle = InlineTextStyle(
      color: PatGame.pileOutline,
      fontScale: 1.0/game.camera.viewfinder.zoom,
    );
    final style = DocumentStyle(
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 140),
      background: BackgroundStyle(
        color: PatGame.screenBackground,
        borderColor: PatGame.pileOutline,
        borderWidth: 2.0,
      ),
      header1: BlockStyle(
        text: textStyle,
      ),
      paragraph: BlockStyle(
        padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 160),
        text: textStyle,
      ),
    );

    final rules = getContents('Rules', gameSpec.gameName, gameSpec.gameRules);
    add(
      TextElementComponent.fromDocument(
        document: DocumentRoot(rules),
        style: style,
        position: Vector2(0, 0),
        size: Vector2(panelWidth, panelHeight),
        priority: 1000,
      ),
    );
    final digits = '0123456789ABCDEF';
    final gameImage = Sprite(
        Flame.images.fromCache(digits[game.gameIndex] + '.png'));
    add(
      SpriteComponent(
        sprite: gameImage,
        position: Vector2(panelWidth, 0),
        size: Vector2(panelWidth, panelHeight / 2),
        priority: 1000,
      ),
    );
    final tips = getContents('Tips', gameSpec.gameName, gameSpec.gameTips);
    add(
      TextElementComponent.fromDocument(
        document: DocumentRoot(tips),
        style: style,
        position: Vector2(panelWidth, panelHeight / 2),
        size: Vector2(panelWidth, panelHeight / 2),
        priority: 1000,
      ),
    );
  }

  @override
  void onTapUp(TapUpEvent event) {
    removeFromParent(); // Close the Rules panels.
  }

  List<BlockNode> getContents(String tag, String name, List<String> text)  {
    List<BlockNode> contents = [];
    contents.add(HeaderNode.simple('$tag for $name', level: 1));
    for (String para in text) {
      contents.add(ParagraphNode.simple(para));
    }
    return contents;
  }
}
