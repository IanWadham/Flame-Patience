import 'dart:ui';

import 'package:flame/components.dart';

import '../pat_game.dart';
import '../pat_world.dart';
import '../specs/pat_specs.dart';
import 'card_view.dart';

class Pile extends PositionComponent {
  Pile(this.pileSpec,
      {required int row, required int col, int deal = 0, super.position})
      : pileType = pileSpec.pileType,
        gridRow = row,
        gridCol = col,
        baseWidth = PatWorld.cellSize.x,
        baseHeight = PatWorld.cellSize.y,
        nCardsToDeal = deal,
        super(
          anchor: Anchor.topCenter,
          size: PatWorld.cellSize,
          priority: -1,
        );

  // final bool debugMode = true;
  final PileSpec pileSpec;
  final PileType pileType;

  final int gridRow;
  final int gridCol;
  final double baseWidth;
  final double baseHeight;
  final int nCardsToDeal;

  final List<CardView> _cards = [];

  late final Vector2 _faceDownFanOut;
  late final Vector2 _faceUpFanOut;

  bool _lastWastePile = false;

  void init() {
    _faceDownFanOut = Vector2(pileSpec.faceDownFanOut.$1 * PatWorld.cardWidth,
        pileSpec.faceDownFanOut.$2 * PatWorld.cardHeight);
    _faceUpFanOut = Vector2(pileSpec.faceUpFanOut.$1 * PatWorld.cardWidth,
        pileSpec.faceUpFanOut.$2 * PatWorld.cardHeight);
  }

  void setPileHitArea() {
    double deltaX = (_cards.length < 2 ? 0.0 : _cards.last.x - x);
    double deltaY = (_cards.length < 2 ? 0.0 : _cards.last.y - y);
    width = (deltaX >= 0.0) ? baseWidth + deltaX : baseWidth - deltaX;
    height = (deltaY >= 0.0) ? baseHeight + deltaY : baseHeight - deltaY;
  }

  MoveResult dragMove(CardView card, List<CardView> dragList) {
    DragRule dragRule = pileSpec.dragRule;
    // String message = 'Drag $pileType row $gridRow col $gridCol:';
    if (_cards.isEmpty) {
      // print('$message _cards is Empty');
      return MoveResult.pileEmpty;
    }
    switch (pileType) {
      case PileType.stock:
      case PileType.foundation:
      case PileType.waste:
      case PileType.tableau:
        if (dragRule == DragRule.dragNotAllowed) {
          // print('$message drag not allowed');
          return MoveResult.notValid;
        }
        final cardOnTop = isTopCard(card);
        if (dragRule == DragRule.fromTop && !cardOnTop) {
          // print('$message ${card.toString()} not on top of Pile');
          return MoveResult.notValid;
        }
        if (card.isFaceDownView) {
          // print('$message ${card.toString()} not face-up');
          return MoveResult.notValid;
        }
        if (cardOnTop) {
          dragList.add(_cards.removeLast());
          setPileHitArea();
          // print('$message removed top card of Pile');
          return MoveResult.valid;
        }
        assert(card.isFaceUpView && _cards.contains(card));
        final index = _cards.indexOf(card);
        // print('$message ${card.toString()} index $index $_cards');
        dragList.addAll(_cards.getRange(index, _cards.length));
        _cards.removeRange(index, _cards.length);
        // print('Pile $_cards, moving $dragList');
        setPileHitArea();
        return MoveResult.valid;
      // Depends on Game Type. In 48, need to look inside Waste,
      // but not go anywhere or put the card anywhere.
      // Depends on Game Type. In 48, need empty Tableaus for moving >1 card.
      // In Klondike, can drag many cards but must satisfy checkPut on drop.
    }
  }

  MoveResult tapMove(CardView card) {
    TapRule tapRule = pileSpec.tapRule;
    // String message = 'Tap $pileType row $gridRow col $gridCol:';
    if (pileSpec.tapRule == TapRule.tapNotAllowed) {
      // print('$message tap not allowed');
      return MoveResult.notValid; // e.g. Foundation Piles do not accept taps.
    }
    final needFaceUp = (pileType != PileType.stock);
    if (!isTopCard(card) || (needFaceUp != card.isFaceUpView)) {
      // print('$message tap not on top card or face-up is not $needFaceUp');
      return MoveResult.notValid; // Stock needs face-down, other piles face-up.
    }
    if (_cards.isEmpty && (pileType != PileType.stock)) {
      // print('$message _cards is Empty');
      return MoveResult.pileEmpty;
    }
    // TODO - Redundant? Same as previous !isTopCard(card) check?
    if (_cards.isNotEmpty && (card != _cards.last)) {
      // print('$message ${card.toString()} is not on top');
      return MoveResult.notValid;
    }
    switch (pileType) {
      case PileType.stock:
        if (card.isBaseCard) {
          // print('$message empty Stock Pile');
          return MoveResult.pileEmpty;
        } else {
          _cards.removeLast();
          // print('$message take ${card.toString()} from top');
          return MoveResult.valid;
        }
      case PileType.waste:
      case PileType.tableau:
        if (tapRule != TapRule.goOut) {
          // print('$message $tapRule invalid - should be TapRule.goOut');
          return MoveResult.notValid;
        } else {
          _cards.removeLast();
          // print('$message take ${card.toString()} from top');
          setPileHitArea();
          return MoveResult.valid;
        }
      case PileType.foundation:
      // ??????? What is needed here? Anything?
    }
    return MoveResult.notValid;
  }

  bool isTopCard(CardView card) {
    return _cards.isNotEmpty && card == _cards.last;
  }

  bool checkPut(CardView card, MoveMethod method) {
    // Player can put or drop cards onto Foundation or Tableau Piles only.
    // String message = 'Check Put: ${card.toString()} $pileType'
        // ' $method row $gridRow col $gridCol:';
    if ((pileType == PileType.foundation) || (pileType == PileType.tableau)) {
      if (_cards.isEmpty) {
        final firstOK =
            (pileSpec.putFirst == 0) || (card.rank == pileSpec.putFirst);
        // String result = firstOK ? 'first card OK' : 'first card FAILED';
        // print('$message $result');
        return firstOK;
      } else {
        int pileSuit = _cards.last.suit;
        int delta = 1;
        switch (pileSpec.putRule) {
          case PutRule.ascendingSameSuitBy1:
            delta = 1;
          case PutRule.ascendingSameSuitBy3:
            delta = 3;
          case PutRule.descendingSameSuitBy1:
            delta = -1;
          case PutRule.descendingAlternateColorsBy1:
            final isCardOK = (card.isRed == !_cards.last.isRed) &&
                (card.rank == _cards.last.rank - 1);
            // print('$message ${isCardOK ? "card OK" : "card FAILED"}');
            return isCardOK;
          case PutRule.putNotAllowed:
            return false; // Cannot put card on this Foundation Pile.
        }
        if ((card.rank != (_cards.last.rank + delta)) ||
            (card.suit != pileSuit)) {
          // print('$message checkPut FAIL');
          return false;
        }
      }
      // print('$message checkPut OK');
      return true;
    } // End of Tableau or Foundation Pile check.
    // print('$message can only put on Foundation or Tableau Piles.');
    return false;
  }

  List<CardView> removeAllCards() {
    final List<CardView> result = [];
    if ((pileType == PileType.waste) && !_lastWastePile) {
      // print('Waste Pile cards: $_cards');
      while (_cards.isNotEmpty) {
        result.add(_cards.removeLast()); // Last Waste card -> first in result.
      }
      _lastWastePile = pileSpec.tapEmptyRule == TapEmptyRule.turnOverWasteOnce;
      // print('Pile $pileType: WARNING - LAST Waste Pile!');
    }
    return result;
  }

  void put(CardView card, MoveMethod method) {
    _cards.add(card);
    card.pile = this;
    card.priority = _cards.length;
    if (_cards.length == 1) {
      card.position = position;
    } else {
      final prevFaceUp = _cards[_cards.length - 2].isFaceUpView;
      final fanOut = prevFaceUp ? _faceUpFanOut : _faceDownFanOut;
      card.position = _cards[_cards.length - 2].position + fanOut;
    }
    // print('Put ${card.toString()} $pileType $gridRow $gridCol'
        // ' pos ${card.position} pri ${card.priority}');
    setPileHitArea();
  }

  void flipTopCardMaybe() {
    // Used in piles like Klondike Tableaus, where top cards must be face-up.
    if (pileSpec.dealFaceRule == DealFaceRule.lastFaceUp) {
      if (_cards.isNotEmpty && _cards.last.isFaceDownView) {
        final savedPriority = _cards.last.priority;
        _cards.last.turnFaceUp(
          start: 0.1,
          onComplete: () {
            _cards.last.priority = savedPriority;
          },
        );
      }
    }
  }

  void returnCard(CardView card) {
    _cards.add(card);
    card.priority = _cards.length;
    setPileHitArea();
  }

  void flipCards(CardView card, TapRule tapRule, Pile target) {
    assert(target.pileType == PileType.waste);
    assert(pileType == PileType.stock);
    assert((tapRule == TapRule.turnOver1) || (tapRule == TapRule.turnOver3));
    if (tapRule == TapRule.turnOver1) {
      card.doMoveAndFlip(
        target.position,
        whenDone: () {
          target.put(card, MoveMethod.tap);
        },
      );
    }
    // TODO - TapRule.turnOver3. Maybe make the above a loop and have a
    //        faceUpFanOut defined for the Waste Pile
  }

  static final Paint pileOutlinePaint = Paint()
    ..color = PatGame.pileOutline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10;

  static final Paint pileBackgroundPaint = Paint()
    ..color = PatGame.pileBackground
    ..style = PaintingStyle.fill;

  @override
  void render(Canvas canvas) {
    // Debugging: outline the boundaries of the piles.
    // final cellSize = PatWorld.cellSize;
    // Rect cell = Rect.fromLTWH(0.0, 0.0, cellSize.x, cellSize.y);
    // canvas.drawRect(cell, pileOutlinePaint);

    RRect pileRect = PatWorld.cardRect.deflate(PatWorld.shrinkage);
    Offset rectShift = Offset(PatWorld.cardMargin / 2.0, 0);
    canvas.drawRRect(pileRect.shift(rectShift), pileBackgroundPaint);
    canvas.drawRRect(pileRect.shift(rectShift), pileOutlinePaint);
  }
}
