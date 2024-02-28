import 'dart:ui';
// ??????? import 'dart:meta';

import 'package:flame/components.dart';
import 'package:flame/input.dart' show Vector2;

import '../pat_game.dart';
import '../pat_world.dart';
import '../specs/pat_enums.dart';
import '../specs/pat_specs.dart';
import 'card_view.dart';

class Pile extends PositionComponent with HasWorldReference<PatWorld> {
  Pile(this.pileSpec, this.pileIndex, this.baseWidth, this.baseHeight,
      {required int row, required int col, int deal = 0, super.position})
    :
    pileType = pileSpec.pileType,
    gridRow = row,
    gridCol = col,
    nCardsToDeal = deal,
    _hasFanOut = (pileSpec.fanOutX != 0.0) || (pileSpec.fanOutY != 0.0),
    _fanOutFaceUp = Vector2( // Initial value: needed by deal().
      pileSpec.fanOutX * PatWorld.cardWidth, pileSpec.fanOutY * PatWorld.cardHeight),
    _fanOutFaceDown = Vector2( // Initial value: needed by deal().
      pileSpec.fanOutX * PatWorld.cardWidth, pileSpec.fanOutY * PatWorld.cardHeight)
        * Pile.faceDownFanOutFactor,

    _fanOut = FanOut(pileSpec, position, baseWidth, baseHeight), // FanOut calculator.

    super(
      anchor: Anchor.topCenter,
      size: Vector2(baseWidth, baseHeight),
      priority: -1,
    );

  static const faceDownFanOutFactor = 0.3;

  final PileSpec pileSpec;
  final PileType pileType;

  final int pileIndex;
  final int gridRow;
  final int gridCol;
  final int nCardsToDeal;
  final double baseWidth;
  final double baseHeight;

  final List<CardView> _cards = [];

  int get nCards => pileType == PileType.stock ?
      _cards.length - 1: _cards.length;
  int get topCardIndex => hasNoCards ? -1 : _cards.last.indexOfCard;

  bool get hasNoCards => pileType == PileType.stock ?
      _cards.length == 1 : _cards.isEmpty;

  final FanOut _fanOut;

  // These properties are calculated from the Pile Spec in the constructor body.
  var _hasFanOut = false;
  var _fanOutFaceUp = Vector2(0.0, 0.0);
  var _fanOutFaceDown = Vector2(0.0, 0.0);

  var _transitCount = 0; // The number of cards "in transit" to this Pile.

  final bool debugMode = true;

  void dump() {
    print('DUMP Pile $pileIndex, $pileType: $_cards');
  }

  @override
  String toString() {
    return '$pileIndex';
  }

  MoveResult isDragMoveValid(CardView card, List<CardView> dragList) {
    DragRule dragRule = pileSpec.dragRule;
    dragList.clear();

    // String message = 'Drag $pileType row $gridRow col $gridCol:';
    if (_cards.isEmpty) {
      // print('$message _cards is Empty');
      return MoveResult.pileEmpty;
    }
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
      if (_cards.last.isMoving) {
        return MoveResult.notValid;
      }
      dragList.add(_cards.removeLast());
      _fanOut._expandFanOut(_cards);
      _fanOutFaceUp = _fanOut.faceUpFanOut;
      _fanOutFaceDown = _fanOut.faceDownFanOut;
      _setPileHitArea();
      // print('$message removed top card of Pile');
      return MoveResult.valid;
    }
    assert(card.isFaceUpView && _cards.contains(card));
    final index = _cards.indexOf(card);
    // print('$message ${card.toString()} index $index $_cards');
    dragList.addAll(_cards.getRange(index, _cards.length));

    // Check that none of the cards is already moving. If so, cancel the drag.
    bool bailOut = false;
    for (final dragCard in dragList) {
      if (dragCard.isMoving) {
        bailOut = true;
      }
    }
    if (bailOut) {
      dragList.clear();
      return MoveResult.notValid;
    }

    // The dragged cards now leave the Pile.
    _cards.removeRange(index, _cards.length);
    _fanOut._expandFanOut(_cards);
    _fanOutFaceUp = _fanOut.faceUpFanOut;
    _fanOutFaceDown = _fanOut.faceDownFanOut;
    // print('Pile $_cards, moving $dragList');
    _setPileHitArea();
    return MoveResult.valid;
  }
/*
  bool isCardInPile(CardView card, {required bool mustBeOnTop}) {
    // Integrity check.
    if (mustBeOnTop) {
      print('Pile $pileIndex $pileType isCardInPile(): card ${card.name} '
          'mustBeOnTop $mustBeOnTop... isTopCard()');
      return isTopCard(card);
    } else {
      print('Pile $pileIndex $pileType isCardInPile(): card ${card.name} '
          'mustBeOnTop $mustBeOnTop... contains()');
      return _cards.contains(card);
    }
  }
*/
  MoveResult isTapMoveValid(CardView card) {
    TapRule tapRule = pileSpec.tapRule;
    String message = 'Tap $pileType row $gridRow col $gridCol:';
    if (pileSpec.tapRule == TapRule.tapNotAllowed) {
      print('$message tap not allowed');
      return MoveResult.notValid; // e.g. Foundation Piles do not accept taps.
    }
    if (!isTopCard(card)) {
      print('$message tap is not on top card');
      return MoveResult.notValid;
    }
    // Stock needs top card face-down, other piles need top card face-up.
    final needFaceUp = (pileType != PileType.stock);
    if (needFaceUp != card.isFaceUpView) {
      print('$message card ${card.name} face-up is not $needFaceUp');
      return MoveResult.notValid;
    }
    if (_cards.isEmpty && (pileType != PileType.stock)) {
      print('$message _cards is Empty');
      return MoveResult.pileEmpty;
    }
    switch (pileType) {
      case PileType.stock:
        if (card.isBaseCard) {
          print('$message empty Stock Pile');
          return MoveResult.pileEmpty;
        } else {
          return MoveResult.valid;
        }
      case PileType.waste:
      case PileType.tableau:
        if (tapRule != TapRule.goOut) {
          print('$message $tapRule invalid - should be TapRule.goOut');
          return MoveResult.notValid;
        } else {
          return MoveResult.valid;
        }
      case PileType.foundation:
        // Maybe the card was dealt here but does not belong (e.g. Mod 3).
        // Then it might be able to go out on another Foundation Pile.
        print('Tap Fndn: $pileIndex length ${_cards.length} rank ${card.name} putFirst ${pileSpec.putFirst}');
        return ((_cards.length == 1) && (card.rank != pileSpec.putFirst)) ?
            MoveResult.valid : MoveResult.notValid;
      case PileType.excludedCards:
        return MoveResult.notValid;
    }
    return MoveResult.notValid;
  }

  List<CardView> grabCards(int nRequired) {
    List<CardView> tail = [];
    int nAvailable = (nCards >= nRequired) ? nRequired : nCards;
    int index = _cards.length - nAvailable;
    if (nAvailable > 0) {
      tail.addAll(_cards.getRange(index, _cards.length));
      _cards.removeRange(index, _cards.length);
      _fanOut._expandFanOut(_cards);
      _fanOutFaceUp = _fanOut.faceUpFanOut;
      _fanOutFaceDown = _fanOut.faceDownFanOut;
      _setPileHitArea();
    }
    return tail;
  }

  void dropCards(List<CardView> tail) {
    // Instantaneously drop and display cards on this pile (used in Undo/Redo).
    print('Drop $tail on $pileType index $pileIndex, contents $_cards');
    CardView prev;
    for (final card in tail) {
      _cards.add(card);
      card.pile = this;
      card.priority = _cards.length;
      if (!_hasFanOut || _cards.length == 1) {
        // The card is aligned with the Pile's position.
        card.position = position;
      } else {
        // Fan out the second and subsequent cards.
        prev = _cards[_cards.length - 2];
        final fanOut = prev.isFaceUpView ? _fanOutFaceUp : _fanOutFaceDown; // xxxxx
        print('$pileType $pileIndex card ${card.name} FanOut $fanOut');
        card.position = prev.position + fanOut;
      }
    }
    // If Fan Out changed, reposition all cards.
    if (_hasFanOut && _fanOut._fanOutChanged(_cards.last.position, _cards)) {
      _fanOutFaceUp = _fanOut.faceUpFanOut;
      _fanOutFaceDown = _fanOut.faceDownFanOut;
      for (int n = 1; n < _cards.length; n++) {
        final diff = _cards[n - 1].isFaceUpView ?
            _fanOutFaceUp : _fanOutFaceDown;
        _cards[n].position = _cards[n - 1].position + diff;
      }
    }
    _setPileHitArea();
  }

  // TODO - If the Manhattan distance to be moved is less than a certain amount,
  //        don't animate, just move to new position instantaneously. That way
  //        we can use animation for some but not all cards after reworking
  //        the fan outs.
  void receiveMovingCards(
    List<CardView> movingCards, {
    double speed = 15.0,
    double startTime = 0.0,
    double flipTime = 0.3,
    double intervalTime = 0.0,
    VoidCallback? onComplete,
  }) {
    // Receive animated cards onto this pile.
    // The idea is that only the receiving Pile can calculate exactly where the
    // cards have to go, so that we can have smooth animation and landing, no
    // matter where the cards are starting. The cards are placed into the Pile,
    // but their priority, position and flip are controlled by the animation.
    print('RECV $movingCards on $pileType index $pileIndex, contents $_cards');
    CardView prev;
    int nCardsToMove = movingCards.length;

    // Vector2 tailPosition = position + nDown * downFanOut + nUp * upFanOut;
    // This is where the NEXT card will go, when it arrives.
    Vector2 tailPosition = position;
    bool tailFaceUp = false;

    if (_cards.isNotEmpty) {
      CardView tail = _cards.last;
      print('Tail card: ${tail.name} moving ${tail.isMoving} '
          'new pos ${tail.newPosition} curr pos ${tail.position}');
      tailPosition = tail.isMoving ? tail.newPosition : tail.position;
      tailFaceUp = tail.isMoving ? tail.newFaceUp : tail.isFaceUpView;
    }
    print('Tail position: $tailPosition tail face up $tailFaceUp');

    // TODO - Do a fan out calculation BEFORE deciding where the incoming cards should
    //        go. If the fan out needs to change, move every card that is already in
    //        the Pile...
    for (final card in movingCards) {
      _cards.add(card);
      card.pile = this;
      card.newPriority = _cards.length;
      card.newFaceUp = (flipTime > 0.0) ?
          !card.isFaceUpView : card.isFaceUpView;
      print('_hasFanOut $_hasFanOut, _cards.length ${_cards.length}');
      if (!_hasFanOut || _cards.length == 1) {
        // The card will be aligned with the Pile's position.
        card.newPosition = position;
        tailFaceUp = card.newFaceUp;
        print('FIRST CARD IN PILE: ${card.name} pos ${card.newPosition} '
            'face up ${card.newFaceUp}');
      } else {
        // Fan out the second and subsequent cards.
        final fanOut = tailFaceUp ? _fanOutFaceUp : _fanOutFaceDown;
        tailPosition += fanOut;
        card.newPosition = tailPosition;
        tailFaceUp = card.newFaceUp;
        print('$pileType $pileIndex card ${card.name} FanOut $fanOut '
            'newPos $tailPosition');
        print('CARD IN PILE: ${card.name} pos ${card.newPosition} '
            'face up ${card.newFaceUp}');
      }
    }

    // Make the required cards start moving. Later cards fly higher.
    double startAt = startTime;
    int movePriority = CardView.movingPriority + _transitCount;
    for (final card in movingCards) {
      card.doMoveAndFlip(
        card.newPosition,
        speed: speed,
        flipTime: flipTime, // Optional flip: no flip if flipTime == 0.0.
        start: startAt,
        startPriority: movePriority,
        whenDone: () {
          print('Arriving: pile $pileIndex $pileType card ${card.name} '
              'pri ${card.priority} '
              'new pri ${card.newPriority} count $_transitCount');
          card.priority = card.newPriority;
          _transitCount--;
            // TODO - Minor problem: if several cards are sent rapidly to the
            //        end of a Pile that has overflowed, the Pile gets too long
            //        and then suddenly shrinks. OTOH trying to adjust fan-out
            //        WHILE cards are flying led to many difficulties and bugs.
            //        Perhaps, fan-out can be adjusted each time a card arrives,
            //        provided no cards earlier in the Pile are still moving,
            //        but that would be a lot of overhead. Or maybe the whole
            //        Pile could shrink instantaneously before cards take off.
          if (_transitCount == 0) {
            // If Fan Out changed, reposition all cards.
            if (_hasFanOut && _fanOut._fanOutChanged(_cards.last.position, _cards)) {
              _fanOutFaceUp = _fanOut.faceUpFanOut;
              _fanOutFaceDown = _fanOut.faceDownFanOut;
              for (int n = 1; n < _cards.length; n++) {
                final diff = _cards[n - 1].isFaceUpView ?
                    _fanOutFaceUp : _fanOutFaceDown;
                _cards[n].position = _cards[n - 1].position + diff;
              }
            }
            _setPileHitArea();
          }
          onComplete?.call(); // Optional callback for receiveMovingCards().
        }
      );
      startAt += intervalTime;
      movePriority++;
      _transitCount++;
    }
  }

  void removeExcludedCards(int excludedRank, List<CardView> excludedCards) {
    print('Before remove Aces $pileIndex $pileType: $_cards $excludedCards');
    for (CardView card in _cards) {
      if (card.rank == excludedRank) {
        excludedCards.add(card);
      }
    }
    _cards.removeWhere((card) => card.rank == excludedRank);
    print(' After remove Aces $pileIndex $pileType: $_cards $excludedCards');
  }

  List<CardView> stockLookahead(int excludedRank,
      {bool addPlayableCard = true, int rig = 0}) {
    List<CardView> result = [];
    if ((_cards.length == 1) || (pileType != PileType.stock)) {
      return result;
    }
    if (rig > 0) {
      List<CardView> aces = [];
      List<CardView> doctored = [];
      print('RIGGED STOCK: $rig LEADING ACES');
      dump();
      for (final card in _cards) {
        if (card.isBaseCard) {
          doctored.add(card);
        } else if ((card.rank == excludedRank) && (rig > 0)) {
          rig--;
          aces.add(card);
        } else {
          doctored.add(card);
        }
      }
      for (final card in aces) {
        doctored.add(card);
      }
      _cards.clear();
      _cards.addAll(doctored);
      dump();
    }

    for (final card in _cards.reversed.toList()) {
      if (card.rank == excludedRank) {
        result.add(card);
      } else {
        if (addPlayableCard) {
          result.add(card);
        }
        break;
      }
    }
    return result;
  }

  void setTopFaceUp(bool goFaceUp) {
    // TODO - POLISH THIS.
    if (_cards.isNotEmpty) {
      CardView card = _cards.last;
      print('setTopFaceUp($goFaceUp): $pileIndex $pileType ${card.toString()} '
          'FaceUp ${card.isFaceUpView}');
      if (goFaceUp) {
        // Card moving into play from FaceDown view.
        if (_cards.last.isFaceDownView) _cards.last.flipView();
      } else {
        // Undoing a move that included a flip to FaceUp view.
        if (_cards.last.isFaceUpView) _cards.last.flipView();
      }
    }
  }

  bool isTopCard(CardView card) {
    return _cards.isNotEmpty ? (card == _cards.last) : false;
  }

  bool checkPut(CardView card) {
    // Player can put or drop cards onto Foundation or Tableau Piles only.
    String message = 'Check Put: ${card.toString()} $pileType'
        ' row $gridRow col $gridCol:';
    // TODO - Why wasn't this (pileType == PileType.foundatiom) ||
    //            (pileType == PileType.tableau)? And how did we get to
    //        print 'first card OK' in any case?
    // if ((pileType != PileType.foundation) || (pileType != PileType.waste)) {

    if ((pileType == PileType.foundation) || (pileType == PileType.tableau)) {
      if (_cards.isEmpty) {
        final firstOK =
            (pileSpec.putFirst == 0) || (card.rank == pileSpec.putFirst);
        String result = firstOK ? 'first card OK' : 'first card FAILED';
        print('$message $result');
        return firstOK;
      } else {
        print('$message ${pileSpec.putRule}');
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
          case PutRule.sameRank:
            print('$message sameRank? card ${card.rank} '
                'pile ${_cards.last.rank}');
            return card.rank == _cards.last.rank;
          case PutRule.putNotAllowed:
            return false; // Cannot put card on this Foundation Pile.
        }
        if ((card.rank != (_cards.last.rank + delta)) ||
            (card.suit != pileSuit)) {
          // print('$message checkPut FAIL');
          return false;
        }
        if ((pileType == PileType.foundation) &&
            (_cards.first.rank != pileSpec.putFirst)) {
          // Base card of pile has wrong rank. Can happen if the deal has put
          // random cards on the Foundation Pile (e.g. as in Mod 3).
          print('$message wrong first rank ${_cards.first.name}');
          return false;
        }
      }
      // print('$message checkPut OK');
      return true;
    } // End of Tableau or Foundation Pile check.
    print('$message cannot put on Stock or Waste Piles.');
    return false;
  }

  int turnPileOver(Pile to) {
    // Turn over Waste->Stock, undo it or redo it.
    // Normal or redo move is Waste->Stock, undo is Stock->Waste.
    print('Flip Pile: $pileType last Waste ${world.lastWastePile} $_cards');
    int cardCount = 0;
    if (pileType == PileType.waste) {
      if (world.lastWastePile || _cards.isEmpty) {
        // Don't allow the last Waste Pile, nor an empty Pile, to turn over.
        return 0;
      }
    }
    while (_cards.isNotEmpty) {
      if (_cards.last.isBaseCard) {
        // print('MUST NOT TURN OVER BASE CARD...');
        break;
      }
      CardView card = _cards.removeLast();
      card.flipView();
      to.put(card);
      print('Put ${to.pileType} ${card.name} faceDown ${card.isFaceDownView}');
      cardCount++;
    }
    // TODO - Adjust Fan Out of Waste Pile, if Waste->Stock..
    //        Needed?????????????????
    // Normal or redo move is Waste->Stock, undo is Stock->Waste.
    Pile stock = (pileType == PileType.stock) ? this : to;
    if (stock.pileSpec.tapEmptyRule == TapEmptyRule.turnOverWasteOnce) {
      // Allow the first Waste Pile turnover to be done, undone and redone.
      world.lastWastePile = !world.lastWastePile;
    }
    return cardCount;
  }

  void put(CardView card) {
    List<CardView> tail = [];
    tail.add(card);
    dropCards(tail);
  }

  void _setPileHitArea() {
    if ((pileType == PileType.tableau) || (pileType == PileType.foundation)) {
      double deltaX = (_cards.length < 2 ? 0.0 : _cards.last.x - x);
      double deltaY = (_cards.length < 2 ? 0.0 : _cards.last.y - y);
      width = (deltaX >= 0.0) ? baseWidth + deltaX : baseWidth - deltaX;
      height = (deltaY >= 0.0) ? baseHeight + deltaY : baseHeight - deltaY;
    }
  }

  // TODO - Need to know whether to flip (as in Klondike) or not (as in Forty Eight).
  //        If needed, the flip has to be ANIMATED somehow. Here or in GamePlay?
  bool neededToFlipTopCard() {
    // Used in piles like Klondike Tableaus, where top cards must be face-up.
    print('Pile $pileIndex $pileType needFlip: rule ${pileSpec.dealFaceRule}');
    if (pileSpec.dealFaceRule == DealFaceRule.lastFaceUp) {
      if (_cards.isNotEmpty && _cards.last.isFaceDownView) {
        final savedPriority = _cards.last.priority;
        _cards.last.doMoveAndFlip(
          _cards.last.position,
          speed: 0.0,
          flipTime: 0.3,
          start: 0.1,
          whenDone: () {
            _cards.last.priority = savedPriority;
          },
        );
        return true; // Needed to flip the card.
      }
    }
    return false;
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
    // Outline and fill the image of the Pile (a little smaller than a card).
    canvas.drawRRect(PatWorld.pileRect, pileBackgroundPaint);
    canvas.drawRRect(PatWorld.pileRect, pileOutlinePaint);
  }
}

class FanOut {
  // The initial Fan Out values depend upon const values inside the Pile's PileSpec
  // Record (see parameter _pileSpec). The _fanOutFaceUp and _fanOutFaceDown values
  // can vary during gameplay, depending on availability of space, so must be var.
  PileSpec _pileSpec;
  Vector2? _position;
  double _baseWidth;
  double _baseHeight;

  FanOut(this._pileSpec, this._position, this._baseWidth, this._baseHeight) {
    if (_pileSpec.fanOutX != 0.0 || _pileSpec.fanOutY != 0.0) {
      // Initialize the FanOut variables. Allow extra space for FanOut down.
      print('  ${_pileSpec.pileType} '
          'Xgrowth ${_pileSpec.growthCols} Ygrowth ${_pileSpec.growthRows}');
      final dy = _baseHeight - PatWorld.cardHeight - PatWorld.cardMargin / 2;
      _limitX = _position!.x + _pileSpec.growthCols * _baseWidth;
      _limitY = _position!.y + _pileSpec.growthRows * _baseHeight + dy;
      _baseFanOut = Vector2(_pileSpec.fanOutX * PatWorld.cardWidth,
          _pileSpec.fanOutY * PatWorld.cardHeight);
      _fanOutFaceUp = _baseFanOut;
      _fanOutFaceDown = _baseFanOut * Pile.faceDownFanOutFactor;
      print('  Limit X $_limitX, limit Y $_limitY extra Y $dy FanOut $_baseFanOut');
      _hasFanOut = true;
    } else {
      print('  ${_pileSpec.pileType} has NO FanOut');
    }
  }

  // TODO - Base all calculations on nCards and nFaceDownCards. Assume that no cards
  //        get turned face-down after the deal and that all face-down cards are at
  //        the start of the pile. Then the fan out can also depend on what the _cards
  //        index is, as compared to nFaceDownCards. Use card counts as parameters to
  //        fan out calculations. Then the FanOut class will not need CardView class.
  //        Assume also that only face-up cards are dragged or tapped to go out and
  //        that face-down cards can only be tapped in the Stock Pile, if any.
  // TODO - Check for changes to fan outs, based on future numbers of face-down and
  //        face-up cards, BEFORE telling cards their new positions and flips.

  var _hasFanOut = false;
  var _baseFanOut = Vector2(0.0, 0.0);
  var _fanOutFaceUp = Vector2(0.0, 0.0);
  var _fanOutFaceDown = Vector2(0.0, 0.0);
  var _limitX = 0.0;
  var _limitY = 0.0;

  Vector2 get faceUpFanOut => _fanOutFaceUp;
  Vector2 get faceDownFanOut => _fanOutFaceDown;

  bool _fanOutChanged(Vector2 lastPosition, List<CardView> cardsInPile) {
    // Horizontal Piles can fan out either left or right. Vertical piles always
    // fan out downwards. For X, test NOT overflowing right AND the same left.
    bool xWithinBounds =
        (!((_pileSpec.growthCols > 0) && (lastPosition.x >= _limitX)) &&
        !((_pileSpec.growthCols < 0) && (lastPosition.x <= _limitX)));
    bool yWithinBounds = !(lastPosition.y >= _limitY);
    if (xWithinBounds && yWithinBounds) {
      return false; // No card-position changes are needed.
    }
    var spaceNeeded = 0.0;
    int nCards = cardsInPile.length;
    for (int n = 1; n < nCards; n++) {
      spaceNeeded +=
          cardsInPile[n - 1].isFaceUpView ? 1.0 : Pile.faceDownFanOutFactor;
    }
    final x = xWithinBounds ?
      _fanOutFaceUp.x : (_limitX - _position!.x) / spaceNeeded;
    final y = yWithinBounds ?
      _fanOutFaceUp.y : (_limitY - _position!.y) / spaceNeeded;
    _fanOutFaceUp = Vector2(x, y);
    _fanOutFaceDown = _fanOutFaceUp * Pile.faceDownFanOutFactor;
    print('NEW FACE-UP FAN OUT $_fanOutFaceUp');
    return true; // Card-position changes are needed.
  }

  void _expandFanOut(List<CardView> cardsInPile) {
    if (!_hasFanOut) {
      return; // No Fan Out in this pile.
    }
    int nCards = cardsInPile.length;
    print('Entering _expandFanOut()...');
    var ratio = 1.0;
    if (_pileSpec.fanOutX != 0.0) {
      // Calculate (current / ideal) fan out ratio: always +ve even if both -ve.
      ratio = _fanOutFaceUp.x / _baseFanOut.x;
      if (ratio < 1.0) {
        // Less than ideal: increase the cards' fan outs to base value or less.
        _fanOutFaceUp.x = _adjustFanOut(_limitX - _position!.x, _baseFanOut.x, cardsInPile);
      }
      print('X Ratio $ratio, _fanOutFaceUp ${_fanOutFaceUp.toString()}');
    }
    if (_pileSpec.fanOutY != 0.0) {
      ratio = _fanOutFaceUp.y / _baseFanOut.y;
      if (ratio < 1.0) {
        _fanOutFaceUp.y = _adjustFanOut(_limitY - _position!.y, _baseFanOut.y, cardsInPile);
      }
      print('Y Ratio $ratio, _fanOutFaceUp ${_fanOutFaceUp.toString()}');
    }
    _fanOutFaceDown = _fanOutFaceUp * Pile.faceDownFanOutFactor;
    for (int n = 1; n < cardsInPile.length; n++) {
      var delta = cardsInPile[n - 1].isFaceUpView ? _fanOutFaceUp : _fanOutFaceDown;
      cardsInPile[n].position = cardsInPile[n - 1].position + delta;
    }
  }

  double _adjustFanOut(double lengthAvailable, double baseLength,
      List<CardView> cardsInPile) {
    var slotsNeeded = 0.0;
    for (int n = 1; n < cardsInPile.length; n++) {
      slotsNeeded +=
          cardsInPile[n - 1].isFaceUpView ? 1.0 : Pile.faceDownFanOutFactor;
    }
    double faceUpLength = lengthAvailable / slotsNeeded;
    // When fanning out left, both values are negative, hence the division.
    if (faceUpLength / baseLength > 1.0) faceUpLength = baseLength;
    return faceUpLength;
  }
}
