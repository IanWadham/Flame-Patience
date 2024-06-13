import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import 'pat_game.dart';
import 'pat_world.dart';
import 'specs/pat_enums.dart';
import 'specs/pat_specs.dart';

typedef Layout = (int, int, String); // Row and Column size and occupancy.

class PatMenuWorld extends PatBaseWorld with HasGameReference<PatGame> {

  // @override
  // final debugMode = true;

  @override
  Future<void> onLoad() async {
    print('Game Index is ${game.gameIndex} '
        'name ${PatData.gameList[game.gameIndex].gameName}');
    final gameSpecs = PatData.gameList;
    final nGames = gameSpecs.length;
    assert(nGames > 0 && nGames <= 9);
    final List<Layout> layouts = [
        (1,1,'x'),(2,2,'x..x'),(3,3,'x...x...x'),(3,3,'x...x.x.x'), // 1-4.
        (3,3,'x.x.x.x.x'),(3,3,'x.xx.xx.x'),(3,3,'x.xxxxx.x'),      // 5-7.
        (3,3,'xxxxxxx.x'),(3,3,'xxxxxxxxx'),                        // 8-9.
        ];
    final requiredLayout = layouts[nGames - 1];

    final nRows = requiredLayout.$1;
    final nCols = requiredLayout.$2;
    final cells = requiredLayout.$3;
    final digits = '0123456789ABCDEF';

    final cellHeight = 300.0;
    final cellWidth = 450.0;
    final cellSize = Vector2(cellWidth, cellHeight);
    final menuSize = Vector2(cellWidth * nCols, cellHeight * nRows);

    final camera = game.camera;
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(0.0, 0.0);
    camera.viewfinder.visibleGameSize = menuSize;

    final fontHeight = cellHeight * 0.1;
    print('Font $fontHeight');
    int gameIndex = 0;
    for (int m = 0; m < nRows; m++) {
      for (int n = 0; n < nCols; n++) {
        // If a cell contains an x, allocate a game to it and create a MenuItem
        // at the corresponding row and column position, then bump gameIndex.
        if (cells[m * nRows + n] == 'x') {
          final cellPosition = Vector2(cellWidth * n, cellHeight * m) -
              menuSize * 0.5;
          String gameImageData = digits[gameIndex] + '.png';
          final gameImage = await game.loadSprite(gameImageData);
          // final gameImage = await Image.asset(gameImageData, color: null);
          // final gameSprite = await Sprite(gameImage);
          final caption = PatData.gameList[gameIndex].gameName;
          add(MenuItem(gameIndex, gameImage, caption, fontHeight,
          // add(MenuItem(gameIndex, gameSprite, caption, fontHeight,
              size: cellSize, position: cellPosition));
          print('Game $gameIndex goes at row $m col $n in $nRows x $nCols');
          print('Size $cellSize Position $cellPosition');
          GameSpec spec = PatData.gameList[gameIndex];
          print('Dimensions: ${spec.gameName} Cells ${spec.nCellsWide} '
                '${spec.nCellsHigh} pad ${spec.cardPadX} ${spec.cardPadY}');
          final cSize = Vector2(900.0 + spec.cardPadX, 1200.0 + spec.cardPadY);
          final bSize = Vector2(cSize.x * spec.nCellsWide, 600.0 +
              cSize.y * spec.nCellsHigh);
          print('    cSize $cSize bSize $bSize AR ${bSize.x / bSize.y}');
          gameIndex++;
        }
      }
    }
  }
}

final spriteOutlinePaint = Paint()
    ..color = PatGame.pileOutline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

class MenuItem extends PositionComponent
    with TapCallbacks,  HasGameReference<PatGame> {
  MenuItem(this.myGameIndex, this.gameImage, this.caption, this.fontHeight,
      {super.size, super.position,
  }) : super(
    children: [
      TextComponent(
        text: caption,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: fontHeight,
            fontWeight: FontWeight.bold,
            color: PatGame.pileOutline,
          ),
        ),
        position: Vector2(size!.x * 0.075, size!.y - 30),
        priority: 10,
        anchor: Anchor.centerLeft,
      ),
      SpriteComponent(
        sprite: gameImage,
        position: size * 0.025,
        size: size * 0.95,
        priority: 1,
      ),
      RectangleComponent(
        paint: spriteOutlinePaint,
        position: size * 0.025,
        size: size * 0.95,
        priority: 5,
      ),
    ],
  );

  final int myGameIndex;
  final Sprite gameImage;
  final String caption;
  final double fontHeight;

  @override
  void onTapUp(TapUpEvent event) {
    // Load and start the selected game in a new World.
    game.gameIndex = myGameIndex;
    game.world = PatWorld();
  }
}
