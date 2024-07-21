// Run win-celebration. Kill PatWorld. Start new Game and World of same type.

import 'package:flame/components.dart';
import 'package:flutter/animation.dart' show Curves;

import '../pat_game.dart';
import '../pat_world.dart';
import '../components/card_view.dart';
import '../components/pile.dart';
import '../specs/pat_enums.dart';
import '../specs/pat_specs.dart';

class GameEnd {
  GameEnd(this.game, this._cards, this._piles);

  final PatGame game;
  final List<CardView> _cards;
  final List<Pile> _piles;

  void letsCelebrate({bool testing = false,}) {
    // Deal won: scatter all cards to points just outside the screen.
    //
    // First get the device's screen-size in game co-ordinates, then get the
    // top-left of the off-screen area that will accept the scattered cards.
    // Note: The play area is anchored at TopCenter, so topLeft.y is fixed.

    final cameraZoom = game.camera.viewfinder.zoom;
    final zoomedScreen = game.size / cameraZoom;
    final playAreaSize = PatWorld.playAreaSize;
    // final screenCenter = (playAreaSize - PatWorld.cardSize) / 2;
    final topLeft = Vector2((playAreaSize.x - zoomedScreen.x) / 2
        - PatWorld.cardWidth / 2, -PatWorld.cardHeight);

    final nCards = _cards.length;
    final offscreenHeight = zoomedScreen.y + PatWorld.cardHeight;
    final offscreenWidth = zoomedScreen.x + PatWorld.cardWidth;
    final spacing = 2.0 * (offscreenHeight + offscreenWidth) / (nCards - 1);

    // Starting points, directions and lengths of offscreen rect's sides.
    final corner = [
      Vector2(0.0, 0.0),
      Vector2(offscreenWidth, 0.0),
      Vector2(offscreenWidth, offscreenHeight),
      Vector2(0.0, offscreenHeight),
    ];
    final direction = [
      Vector2(1.0, 0.0),
      Vector2(0.0, 1.0),
      Vector2(-1.0, 0.0),
      Vector2(0.0, -1.0),
    ];
    final length = [
      offscreenWidth,
      offscreenHeight,
      offscreenWidth,
      offscreenHeight,
    ];

    var side = 0;
    var cardsToMove = nCards - 1;
    var offScreenPosition = corner[side] + topLeft;
    var space = length[side];
    var cardNum = 1;
    var movePriority = 200 + nCards;

    while (cardNum < nCards) {
      for (Pile pile in _piles) {
        List<CardView> tail = pile.getCards();
        if (tail.isEmpty) {
          continue;
        }
        int nTail = tail.length;
        for (int n = 0; n < nTail; n++) {
          final card = tail[nTail - 1 - n];
          if (card.isBaseCard) {
            continue; // Don't animate the Base Card.
          }
          if (card.isFaceDownView) {
            card.flipView();
          }
          // Start cards a short time apart to give a riffle effect.
          final delay = 0.75 + cardNum * 0.02;
          final destination = offScreenPosition;
          // print('Card $card delay $delay to $destination');
          card.doMoveAndFlip(
            destination,
            time: 1.5,
            flipTime: 0.0,
            start: delay,
            startPriority: movePriority,
            curve: Curves.easeOutQuad,
            whenDone: () {
              cardsToMove--;
              if (cardsToMove == 0) {
                if (!testing) {
                  // Restart with a new deal after winning.
                  game.action = Action.newDeal;
                  game.world = PatWorld();
                }
              }
            },
          );
          cardNum++;
          movePriority--;
          // The next card goes to the same side with full spacing, if possible.
          offScreenPosition = offScreenPosition + direction[side] * spacing;
          space = space - spacing;
          if ((space < 0.0) && (side < 3)) {
            // Out of space: change to next side and use excess spacing there.
            side++;
            offScreenPosition =
                topLeft + corner[side] - direction[side] * space;
            space = length[side] + space;
          }
        } // End for card
      } // End for Pile
    } // End while
  }

  void test() {
    // Fill Foundations and ExcludedCards Piles.
    // Run letsCelebrate() with "testing: true".
    final gameSpec = PatData.gameList[game.gameIndex];
    final isMod3 = (gameSpec.gameID == PatGameID.mod3);
    final excludedRank = isMod3 ? 1 : 0;
    final List<Pile> foundations = [];
    final List<Pile> excluded = [];
    final nCards = _cards.length - 1;
    for (Pile pile in _piles) {
      if (pile.pileType == PileType.foundation) {
        foundations.add(pile);
      }
      if (pile.pileType == PileType.excludedCards) {
        excluded.add(pile);
      }
      if (pile.pileType == PileType.stock) {
        _cards[0].position = pile.position;
      }
    }
    int cardIndex = 1;
    int pileIndex = 0;
    int nFoundations = foundations.length;
    while (cardIndex <= nCards) {
      CardView card = _cards[cardIndex];
      if (card.isFaceDownView) {
        card.flipView();
      }
      if (card.rank == excludedRank) {
        excluded.first.put(card);
      } else {
        pileIndex = 4 * card.pack + card.suit;
        if (isMod3) {
          int p = card.pack;
          int n = (cardIndex - 1) - 4 * (p + 1);
          pileIndex = ((n ~/ 4) * 8 + card.suit + 4 * p) % nFoundations;
        }
	card = _cards[cardIndex];
        foundations[pileIndex].put(card);
        pileIndex = (pileIndex < nFoundations - 1) ? ++pileIndex : 0;
      }
      cardIndex++;
    }
    letsCelebrate(testing: true);
  }
}
