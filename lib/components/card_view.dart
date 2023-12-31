import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';

import '../pat_world.dart';
import '../specs/pat_specs.dart';
import 'pile.dart';

// TODO - Separate the card-views and card-models.

class CardView extends PositionComponent
    with DragCallbacks, TapCallbacks, HasWorldReference<PatWorld> {
  CardView(this.indexOfCard, this.face, this.back, {this.isBaseCard = false})
      : super(
          anchor: Anchor.topCenter,
          size: Vector2(PatWorld.cardWidth, PatWorld.cardHeight),
        );

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

  // bool get isBaseCard => (indexOfCard == 0);

  bool get isFaceUpView => _viewFaceUp;
  bool get isFaceDownView => !_viewFaceUp;

  void flipView() => _viewFaceUp = !_viewFaceUp;

  static final Paint cardBorderPaint = Paint()
    ..color = const Color(0xffbbbbbb)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10;

  static final Paint baseBorderPaint = Paint()
    ..color = const Color(0xffff0000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10;

  @override
  void render(Canvas canvas) {
    if (_viewFaceUp) {
      face.render(
        canvas,
        size: PatWorld.cardSize,
        // anchor: Anchor.topCenter,
      );
    } else if (!isBaseCard) {
      back.render(
        canvas,

        size: PatWorld.cardSize,
        // anchor: Anchor.topCenter,
      );
    } else {
      // Draw the Base Card in outline only.
      RRect cardRect =
          PatWorld.cardRect; // .shift(Offset(PatWorld.cardMargin / 2, 0));
      // canvas.drawRRect(cardRect, cardBorderPaint);
      canvas.drawRRect(cardRect, baseBorderPaint);
    }
    return;
  }

  @override
  String toString() => PatWorld.ranks[rank] + PatWorld.suits[suit];

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
  // and moved.
  //
  // USE OF DRAG AND DROP MOVES:
  //
  // Drag-and-drop moves transfer one or more cards from one pile to another,
  // within whatever rules apply to the move and piles in question. If the card
  // or cards are dropped near a place where they are allowed to land, they
  // settle into place automatically. If not, they are returned automatically
  // to where they started.

  @override
  void onTapDown(TapDownEvent event) {
    print('Tap Down on ${pile.pileType} at $position');
  }

  @override
  void onTapUp(TapUpEvent event) {
    print('Tap Up on ${pile.pileType} at $position');
    handleTap();
  }

  void handleTap() {
    // Can be called by onTapUp or after a very short (failed) drag-and-drop.
    // For user-friendliness we accept taps that include a short drag.

    MoveResult tapResult = pile.tapMove(this);
    print('Tap seen ${pile.pileType} result: $tapResult');
    if (tapResult == MoveResult.notValid) {
      return;
    } else if (pile.pileType == PileType.stock) {
      print(
          'Tap on Stock Pile: $tapResult Waste Pile present ${world.hasWastePile}');
      if (tapResult == MoveResult.pileEmpty) {
        if (pile.pileSpec.tapEmptyRule == TapEmptyRule.tapNotAllowed) {
          print('${pile.pileType} TAP ON EMPTY PILE WAS IGNORED');
          return;
        }
        if (world.hasWastePile) {
          final wasteCards = world.waste.removeAllCards();
          print('Turned-over Waste cards: $wasteCards');
          for (final card in wasteCards) {
            // Top Waste Pile cards go face-down to bottom of Stock Pile.
            if (card.isFaceUpView) card.flipView();
            pile.put(card, MoveMethod.tap);
          }
        }
        return;
      } else if (world.hasWastePile) {
        // TODO - Maybe passing "this" is superfluous: unless we want to
        //        assert() that this card is actually on top of the Pile.
        pile.flipCards(this, pile.pileSpec.tapRule, world.waste);
      } else {
        return; // TODO - Deal more cards to Tableaus? e.g. Mod3.
      }
    } else {
      bool putOK = false;
      for (Pile target in world.foundations) {
        print(
            'Try ${target.pileType} at row ${target.gridRow} col ${target.gridCol}');
        putOK = target.checkPut(this, MoveMethod.tap);
        if (putOK) {
          pile.flipTopCardMaybe(); // Turn up next card on source pile, if reqd.
          doMove(
            target.position,
            onComplete: () {
              target.put(this, MoveMethod.tap);
            },
          );
          break;
        }
      } // End of Foundation Pile checks.
      if (!putOK) {
        // TODO - Use same animation as for failed drag? Or go instantaneous?
        //        Probably no need for animation: shouldn't have gone far.
        pile.returnCard(this);
      }
    }
  }

  // Handle drag-and-drop events
  @override
  void onTapCancel(TapCancelEvent event) {
    print('Tap Cancel on ${pile.pileType} at $position');
    if (pile.pileType == PileType.stock) {
      _isDragging = false;
      handleTap();
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (pile.pileType == PileType.stock) {
      _isDragging = false;
      print('Drag start on Stock');
      return;
    }
    // Clone the position, else _whereCardStarted changes as the position does.
    print('Drag start on ${pile.pileType} at $position');
    _whereCardStarted = position.clone();
    movingCards = [];
    MoveResult dragResult = pile.dragMove(this, movingCards);
    if (dragResult == MoveResult.notValid) {
      _isDragging = false;
    } else {
      _isDragging = true;
      var cardPriority = movingPriority;
      String moving = 'Moving: ';
      for (final movingCard in movingCards) {
        movingCard.priority = cardPriority;
        moving += '${movingCard.toString()} ${movingCard.priority}, ';
        cardPriority++;
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
    // movingCards.forEach((card) => card.position.add(delta));
    movingCards.forEach((card) {card.position.add(delta);});
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!_isDragging) {
      return;
    }
    _isDragging = false;

    // If short drag, return card to Pile and treat it as having been tapped.
    final shortDrag =
        (position - _whereCardStarted).length < PatWorld.dragTolerance;
    if (shortDrag && (movingCards.length == 1)) {
      doMove(
        _whereCardStarted,
        onComplete: () {
          pile.returnCard(this);
          // Card moves to a Foundation Pile next, if valid, or it stays put.
          handleTap();
        },
      );
      return;
    }

    // Find out what is under the center-point of this card when it is dropped.
    final targets =
        parent!.componentsAtPoint(position).whereType<Pile>().toList();
    if (targets.isNotEmpty) {
      print('');
      final target = targets.first;
      print('Drop-target Pile found! ${target.pileType}'
          ' row ${target.gridRow} col ${target.gridCol}');
      if (target.checkPut(this, MoveMethod.drag)) {
        pile.flipTopCardMaybe(); // Turn up next card on source pile, if reqd.
        // Found a Pile: move card(s) the rest of the way onto it.
        for (final droppedCard in movingCards) {
          doMove(
            target.position,
            onComplete: () {
              target.put(droppedCard, MoveMethod.drag);
            },
          );
        }
        movingCards.clear();
        return;
      }
    }

    // Invalid drop (middle of nowhere, invalid pile or invalid card for pile).
    movingCards.forEach((card) {
      final offset = card.position - position;
      card.doMove(
        _whereCardStarted + offset,
        onComplete: () {
          pile.returnCard(card);
        },
      );
    });
    movingCards.clear();
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
