import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import 'pat_game.dart';
import 'pat_world.dart';
import 'specs/pat_specs.dart';

typedef Layout = (int, int, String); // Row and Column size and occupancy.

class PatMenuWorld extends PatBaseWorld {

  PatMenuWorld();

  @override
  Future<void> onLoad() async {
    const gameSpecs = PatData.gameList;
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
    const digits = '0123456789ABCDEF';

    const cellHeight = 300.0;
    const cellWidth = 450.0;
    final padding = Vector2(50, 50);
    final cellSize = Vector2(cellWidth, cellHeight);
    final menuSize = Vector2(cellWidth * nCols, cellHeight * nRows) + padding;

    final camera = game.camera;
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(0.0, 0.0);
    camera.viewfinder.visibleGameSize = menuSize;

    const fontHeight = cellHeight * 0.1;

    int gameIndex = 0;
    for (int m = 0; m < nRows; m++) {
      for (int n = 0; n < nCols; n++) {
        // If a cell contains an x, allocate a game to it and create a MenuItem
        // at the corresponding row and column position, then bump gameIndex.
        if (cells[m * nRows + n] == 'x') {
          final cellPosition = Vector2(cellWidth * n, cellHeight * m)
              - menuSize * 0.5 + padding * 0.5;
          String gameImageData = '${digits[gameIndex]}.png';
          final gameImage = await game.loadSprite(gameImageData);
          final caption = PatData.gameList[gameIndex].gameName;
          add(MenuItem(gameIndex, gameImage, caption, fontHeight,
              cellSize: cellSize, cellPosition: cellPosition));
          add(RectangleComponent(size: cellSize, position: cellPosition,
              paint: menuItemOutlinePaint,)); 
          // print('Game $gameIndex goes at row $m col $n in $nRows x $nCols');
          // print('Size $cellSize Position $cellPosition');
        }
        gameIndex++;
      } // End column.
    } // End row.
  } // End onLoad().
}

final menuItemOutlinePaint = Paint()
    ..color = PatGame.faintOutline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

final spriteOutlinePaint = Paint()
    ..color = PatGame.screenBackground
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

class MenuItem extends PositionComponent
    with TapCallbacks,  HasGameReference<PatGame> {
  MenuItem(this.myGameIndex, this.gameImage, this.caption, this.fontHeight,
      {required Vector2 cellSize, required Vector2 cellPosition,
  }) : super(
    size: cellSize,
    position: cellPosition,
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
        position: Vector2(cellSize.x * 0.1, cellSize.y * 0.85),
        priority: 10,
        anchor: Anchor.centerLeft,
      ),
      SpriteComponent(
        sprite: gameImage,
        position: cellSize * 0.05,
        size: cellSize * 0.9,
        priority: 1,
      ),
      RectangleComponent(
        paint: spriteOutlinePaint,
        position: cellSize * 0.05,
        size: cellSize * 0.9,
        priority: 20,
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
