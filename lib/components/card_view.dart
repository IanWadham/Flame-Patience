import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';

import '../pat_world.dart';
import '../models/card_moves.dart';
import '../specs/pat_enums.dart';
import 'pile.dart';

// TODO - Separate the card-views and card-models.

class CardView extends PositionComponent
    with DragCallbacks, TapCallbacks, HasWorldReference<PatWorld> {
  CardView(this.indexOfCard, this.face, this.back, {this.isBaseCard = false})
      : super(
          anchor: Anchor.topCenter,
          size: Vector2(PatWorld.cardWidth, PatWorld.cardHeight),
        );

  // final bool debugMode = true;
  final int indexOfCard;
  final Sprite face;
  final Sprite back;
  final bool isBaseCard;

  late Pile pile;

  final movingPriority = 200; // Enough to fly above two packs of cards.
  List<CardView> movingCards = [];

  bool _viewFaceUp = false;
  bool _isDragging = false;
  Vector2 _whereCardStarted = Vector2(0.0, 0.0);

  // Packs are numbered 0-1, suits 0-3, ranks 1-13.
  int get pack => (indexOfCard - 1) ~/ 52;
  int get suit => (indexOfCard - 1) % 4;
  int get rank => (indexOfCard - 1) ~/ 4 % 13 + 1;
  bool get isRed => suit < 2;
  bool get isBlack => suit >= 2;
  String get name => (indexOfCard == 0) ? 'BC' : PatWorld.ranks[rank] + PatWorld.suits[suit]; // toString()

  // bool get isBaseCard => (indexOfCard == 0);

  bool get isFaceUpView => _viewFaceUp;
  bool get isFaceDownView => !_viewFaceUp;

  void flipView() => _viewFaceUp = !_viewFaceUp;

  static final Paint cardBorderPaint = Paint()
    ..color = const Color(0xffbbbbbb) // Grey.
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10;

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
      // Draw the Base Card in outline only.
      RRect cardRect = PatWorld.cardRect.deflate(PatWorld.shrinkage);
      canvas.drawRRect(cardRect, baseBorderPaint);
    }
    return;
  }

  @override
  // String toString() => PatWorld.ranks[rank] + PatWorld.suits[suit];
  String toString() => name;

  // CARD MOVES:
  //
  // A card-move can be started either by tapping a card or by dragging and
  // dropping it.
  //
  // Both methods begin with a TapDownEvent (which is not processed). If the
  // pointer stays still and the finger or mouse-button is raised, a TapUp
  // event occurs and that event is received as a card-tap in the onTapUp
  // callback. But, if the pointer moves slightly before the finger or mouse
  // button is raised, a TapCancel event occurs followed by a DragStart event.
  //
  // The Stock Pile does not allow drags-and-drops, so a TapCancel on the Stock
  // Pile is treated as equivalent to a TapUp on the Stock Pile and the drag is
  // ignored. Drags on other piles are followed, if the rules of the game allow
  // such a move, but if the drag finishes within a short distance, it is also
  // treated as a TapUp.
  //
  // This is all so that a small movement or hand-tremor during a tap will not
  // cause the tap action to fail silently and be lost, which would annoy the
  // player, especially if he/she is trying to play fast.
  //
  // USE OF TAP MOVES:
  //
  // A tap on a face-up card makes it auto-move and go out to a Foundation Pile
  // (if acceptable), but if it is face-down on a Stock Pile, it turns over and
  // moves to the Waste Pile. In Klondike Draw 3, three cards are turned over
  // and moved. Some games have a Stock Pile but no Waste Pile: what happens
  // then depends on the rules of the game. And some have neither a Stock Pile
  // nor a Waste Pile (i.e. all the cards are dealt face-up, as in Free Cell).
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

  void handleTap() {
    // Can be called by onTapUp or after a very short (failed) drag-and-drop.
    // For ease of gameplay the game accepts taps that include a short drag.

    bool success = world.cardMoves.tapMove(this);
    // TODO - Beep, flash or other view-type things if not successful.
    print('CardView: Returned from tap on $name, pile ${pile.pileIndex} ${pile.pileType} success $success');
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

    // The rules for this pile in this game might allow a multi-card move. The
    // cards to be moved, including one or none, are returned in movingCards.
    // Alternatively, dragging a Stock card or Base Card is treated as a tap.

    if (world.cardMoves.dragStart(this, pile, movingCards)) {
    // if (pile.dragMove(this, movingCards) == MoveResult.valid) {
      _isDragging = true;
      // Clone position, otherwise _whereCardStarted changes as the card moves.
      // _whereCardStarted = position.clone();
      var cardPriority = movingPriority;
      String moving = 'Moving: ';
      for (final movingCard in movingCards) {
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
    movingCards.forEach((card) => card.position.add(delta));
  }

  // TODO - Move SOME of this code into CardMoves.dragAndDropMove().
    // bool success = world.cardMoves.dragAndDropMove(movingCards, target);
    // TODO - Beep, flash or other view-type things if not successful.

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!_isDragging) {
      return;
    }
    _isDragging = false;
    // Find out what is under the center-point of this card when dropped.
    final targets = parent!
        .componentsAtPoint(position + Vector2(0.0, height / 2.0))
        .whereType<Pile>()
        .toList();
    // Drop the cards, if valid, or try a tap move if drag was too short,
    // or, if all else fails, return the card(s) to where they started.
    world.cardMoves.dragEnd(targets, PatWorld.dragTolerance);
  }

  //#region Effects

  void doMove(
    Vector2 to, {
    double speed = 10.0,
    double start = 0.0,
    Curve curve = Curves.easeOutQuad,
    VoidCallback? onComplete,
    bool bumpPriority = true,
  }) {
    assert(speed > 0.0, 'Speed must be > 0 widths per second');
    final dt = (to - position).length / (speed * size.x);
    assert(dt > 0, 'Distance to move must be > 0');
    if (bumpPriority) {
      priority = movingPriority;
    }
    add(
      MoveToEffect(
        to,
        EffectController(duration: dt, startDelay: start, curve: curve),
        onComplete: () {
          onComplete?.call();
        },
      ),
    );
  }

  void doMoveAndFlip(
    Vector2 to, {
    double speed = 10.0,
    double start = 0.0,
    Curve curve = Curves.easeOutQuad,
    VoidCallback? whenDone,
  }) {
    assert(speed > 0.0, 'Speed must be > 0 widths per second');
    final dt = (to - position).length / (speed * size.x);
    assert(dt > 0, 'Distance to move must be > 0');
    priority = movingPriority;
    add(
      MoveToEffect(
        to,
        EffectController(duration: dt, startDelay: start, curve: curve),
        onComplete: () {
          turnFaceUp(
            onComplete: whenDone,
          );
        },
      ),
    );
  }

  void turnFaceUp({
    double time = 0.3,
    double start = 0.0,
    VoidCallback? onComplete,
  }) {
    assert(!_viewFaceUp, 'Card must be face-down before turning face-up.');
    assert(time > 0.0, 'Time to turn card over must be > 0');
    assert(start >= 0.0, 'Start time must be >= 0');
    priority = movingPriority;
    add(
      ScaleEffect.to(
        Vector2(scale.x / 100, scale.y),
        EffectController(
          startDelay: start,
          curve: Curves.easeOutSine,
          duration: time / 2,
          onMax: () {
            _viewFaceUp = true;
          },
          reverseDuration: time / 2,
          onMin: () {
            _viewFaceUp = true;
          },
        ),
        onComplete: () {
          onComplete?.call();
        },
      ),
    );
  }
}
