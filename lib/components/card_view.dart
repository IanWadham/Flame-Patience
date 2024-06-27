import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';

import '../pat_world.dart';
import '../specs/pat_enums.dart';
import '../views/game_play.dart';

import 'pile.dart';

class CardView extends PositionComponent
    with DragCallbacks, TapCallbacks, HasWorldReference<PatWorld> {
  CardView(this.indexOfCard, this.face, this.back, {this.isBaseCard = false})
      : super(
          anchor: Anchor.topCenter,
          size: Vector2(PatWorld.cardWidth, PatWorld.cardHeight),
        );
  // In general, moves are either instaneous or dynamic but buffered (i.e. no
  // waiting for a callback). However there are a few exceptions. The idea is
  // that the player can start moves as quickly as they like, provided they do
  // not try to move the same card more than once at a time.

  final int indexOfCard;
  final Sprite face;
  final Sprite back;
  final bool isBaseCard;

  late Pile pile;

  static const movingPriority = 200; // To fly above 2 or 3 packs of 52 cards.

  // Position and priority this card WILL have when it lands on a Pile, a little
  // time after being dealt, dropped (after a drag), tapped or short-dragged
  // (treated as a tap) and beginning a valid move or failing a drag-and-drop.
  Vector2 newPosition = Vector2(0.0, 0.0);
  int newPriority = 0;

  // Data used to keep track of drag moves with this card as the leading-card.
  final List<CardView> _movingCards = [];
  var _startPosition = Vector2(0.0, 0.0);
  var _fromPileIndex = -1;

  bool _viewFaceUp = false;
  bool _isDragging = false;

  bool _isMoving = false;
  bool _isAnimatedFlip = false;

  // Packs are numbered 0-1, suits 0-3, ranks 1-13.
  int get pack => (indexOfCard - 1) ~/ 52;
  int get suit => (indexOfCard - 1) % 4;
  int get rank => (indexOfCard - 1) ~/ 4 % 13 + 1;
  bool get isRed => suit < 2;
  bool get isBlack => suit >= 2;
  String get name => toString();

  // bool get isBaseCard => (indexOfCard == 0);

  bool get isMoving => _isMoving;

  Vector2 get pilePosition => _isMoving ? newPosition : position;
  bool get isFaceUpView => _isAnimatedFlip ? true : _viewFaceUp;
  bool get isFaceDownView => _isAnimatedFlip ? false : !_viewFaceUp;

  void flipView() {
    if (_isAnimatedFlip) {
      // Animated flips always go towards FaceUp view (NOTE in doMoveAndFlip()).
      _viewFaceUp = true;
    } else {
      // No animation: flip and render the card immediately.
      _viewFaceUp = !_viewFaceUp;
    }
  }

  static final Paint baseBorderPaint = Paint()
    ..color = const Color(0xffdd2200) // Darkish red-orange.
    ..style = PaintingStyle.stroke
    ..strokeWidth = 20;

  @override
  void render(Canvas canvas) {
    if (_viewFaceUp) {
      face.render(
        canvas,
        size: PatWorld.cardSize,
      );
    } else if (!isBaseCard) {
      back.render(
        canvas,
        size: PatWorld.cardSize,
      );
    } else {
      // Draw the Base Card, in outline only.
      canvas.drawRRect(PatWorld.baseCardRect, baseBorderPaint);
    }
    return;
  }

  @override
  String toString() => isBaseCard ? 'BC' :
      (_viewFaceUp ? '+' : '-') + PatWorld.ranks[rank] + PatWorld.suits[suit];

  // THE ERGONOMICS OF CARD MOVES:
  //
  // A card-move can be started either by tapping a card or by dragging and
  // dropping it.
  //
  // In Flutter and Flame, Both methods begin with a TapDownEvent (which is not
  // processed in this app). If the pointer stays still and the finger or mouse
  // button is raised, a TapUp event occurs and that event is received as a
  // card-tap in the onTapUp callback. But, if the pointer moves slightly
  // before the finger or mouse button is raised, a TapCancel event occurs
  // followed by a DragStart event.
  //
  // This code treats a very short drag as a tap, so that a small movement or
  // hand-tremor during a tap will not cause the tap action to fail silently
  // and be lost (which will annoy the player).
  //
  // USE OF TAP MOVES:
  //
  // A tap on a face-up card makes it auto-move and go out to a Foundation Pile
  // (if acceptable). If it is face-down on a Stock Pile, it turns over and
  // moves to another pile. In Klondike Draw 3, three cards are turned over
  // and moved. Some games have a Stock Pile but no Waste Pile: what happens
  // then depends on the rules of the game. And some have neither a Stock Pile
  // nor a Waste Pile (i.e. all the cards are dealt face-up, as in Free Cell).
  // If the Stock Pile is empty, a tap on it is received by the Base Card and
  // usually causes Waste Pile cards to return to the Stock, depending on the
  // rules of the game.
  //
  // USE OF DRAG AND DROP MOVES:
  //
  // Drag-and-drop moves transfer one or more cards from one pile to another,
  // within whatever rules apply to the move and piles in question. If the card
  // or cards are dropped near a place where they are allowed to land, they
  // settle into place automatically. If not, they are returned automatically
  // to where they started.

  @override
  void onTapUp(TapUpEvent event) {
    handleTap();
  }

  // TODO - Beep, flash or other view-type things if drag/tap not successful.

  void handleTap() {
    // Can be called by onTapUp or after a very short (failed) drag-and-drop.
    if (_isMoving) {
      return; // Ignore taps while moving, otherwise it's a sure way to crash...
    }
    bool success = world.gameplay.tapMove(this);
    print('CardView: Returned from tap on $name, pile ${pile.pileIndex} '
        '${pile.pileType} success $success');
    return;
  }

  // Handle drag-and-drop events
  @override
  void onTapCancel(TapCancelEvent event) {
    // print('Tap Cancel on ${pile.pileType} at $position');
    if (pile.pileType == PileType.stock) {
      _isDragging = false;
      handleTap();
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _isDragging = false;
    _startPosition = position.clone();
    _fromPileIndex = pile.pileIndex;
    print('\n\nflutter: Drag Card $this from Pile ${pile.pileIndex}');

    // The rules for this pile in this game might allow a multi-card move. The
    // cards to be moved, including one or none, are returned in movingCards.
    // Alternatively, dragging a Stock card or Base Card is treated as a tap.

    if (pile.isDragMoveValid(this, _movingCards, grabbing: true)
        == MoveResult.valid) {
      _isDragging = true;
      _isMoving = true;
      var cardPriority = movingPriority;
      String moving = 'Moving: ';
      for (final movingCard in _movingCards) {
        movingCard.priority = cardPriority;
        cardPriority++;
        moving += '${movingCard.toString()} ${movingCard.priority}, ';
      }
      print(moving);
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!_isDragging) {
      return;
    }
    final delta = event.localDelta;
    _movingCards.forEach((card) => card.position.add(delta));
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!_isDragging) {
      return;
    }
    _isMoving = false;
    _isDragging = false;

    // Find out what is under the center-point of this card when dropped.
    final targets = parent!
        .componentsAtPoint(position + Vector2(0.0, height / 2.0))
        .whereType<Pile>()
        .toList();

    // Drop the cards, if valid, or try a tap move if drag was too short,
    // or, if all else fails, return the card(s) to where they started.
    world.gameplay.dragEnd(_movingCards, _startPosition, _fromPileIndex,
        targets, PatWorld.dragTolerance);
  }

  // TODO - Not urgent: experiment with doing the flip within some PART of the
  //        move, instead of spreading it out over the whole move as at present.
  // TODO - NICE to have: an automatic instantaneous move if time < _minTime...

  // The ONLY animation function of Cards. Depending on parameter values, it
  // does a simple Move, a combined Move and Flip, or a Flip with no move.
  void doMoveAndFlip(
    Vector2 to, {
    double speed = 15.0,
    double flipTime = 0.3,
    double start = 0.0,
    int startPriority = movingPriority,
    Curve curve = Curves.easeOutQuad,
    VoidCallback? whenDone,
  }) {
    final dt = speed > 0.0 ? (to - position).length / (speed * size.x) : 0.0;
    assert((((speed > 0.0) && (dt > 0.0)) || (flipTime > 0.0)),
        'Speed and distance must be > 0.0 OR flipTime must be > 0.0');
    final moveTime = dt > flipTime ? dt : flipTime; // Use the larger time.
    // print('START new move+flip: $to $this speed $speed flip $flipTime '
        // 'pri $startPriority');
    // Maybe _isMoving was set EARLIER - but it won't hurt to set it again.
    _isMoving = true;
    bool flipOnly = ((flipTime > 0.0) && (speed <= 0.0));
    if (dt > 0.0) { // The card will change position.
      add(
        CardMoveEffect(
          to,
          EffectController(
            duration: moveTime,
            startDelay: start,
            curve: curve,
            onMax: () {if (!flipOnly) _isMoving = false;},
          ),
          transitPriority: startPriority,
          onComplete: flipOnly ? null : whenDone,
        ),
      );
    }
    if (flipTime > 0.0) {
      // NOTE: Animated flips are to FaceUp only. Reverse flips occur in Undo
      //       and when turning the Waste Pile over to Stock: they are always
      //       instantaneous.
      _isAnimatedFlip = true;
      add(
        ScaleEffect.to(
          Vector2(scale.x / 100, scale.y),
          EffectController(
            startDelay: start,
            curve: Curves.easeOutSine,
            duration: moveTime / 2,
            onMax: () {
              _viewFaceUp = true;
            },
            reverseDuration: moveTime / 2,
            onMin: () {
              _isAnimatedFlip = false;
              _viewFaceUp = true;
              if (flipOnly) _isMoving = false;
            },
          ),
          onComplete: flipOnly ? whenDone : null,
        ),
      );
    }
  }
}

// This extension is to support multiple overlapped moves, e.g. when dealing. It
// allows cards to stay in their correct place in the starting pile while they
// wait to move, then to "fly" at the correct height when they are moving. The
// Pile.receiveMovingCard() method later allocates the correct priority in the
// receiving Pile when the cards "land".

class CardMoveEffect extends MoveToEffect {
  CardMoveEffect(
    super.destination,
    super.controller, {
    super.onComplete,
    this.transitPriority = 100,
  });

  final int transitPriority;

  @override
  void onStart() {
    super.onStart(); // Flame connects MoveToEffect to EffectController.
    parent?.priority = transitPriority;
  }
}
