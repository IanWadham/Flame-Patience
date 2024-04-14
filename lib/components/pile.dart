import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/input.dart' show Vector2;

import '../pat_game.dart';
import '../pat_world.dart';
import '../specs/pat_enums.dart';
import '../specs/pat_specs.dart';
import 'card_view.dart';

class Pile extends PositionComponent with HasWorldReference<PatWorld> {
  Pile(this.pileSpec, this.pileIndex, this.baseWidth, this.baseHeight,
      {int deal = 0, super.position})
    :
    pileType = pileSpec.pileType,
    nCardsToDeal = deal,
    _hasFanOut = (pileSpec.fanOutX != 0.0) || (pileSpec.fanOutY != 0.0),
    _baseFanOut = Vector2( // The starting FanOut and the maximum allowed.
        pileSpec.fanOutX * PatWorld.cardWidth,
        pileSpec.fanOutY * PatWorld.cardHeight),
    _limitX = position!.x + pileSpec.growthCols * baseWidth,
    _limitY = position!.y + pileSpec.growthRows * baseHeight +
        (baseHeight - PatWorld.cardHeight) / 2,
    super(
      anchor: Anchor.topCenter,
      size: Vector2(baseWidth, baseHeight), // i.e. cellSize from PatWorld.
      priority: -1,
    );

  static const faceDownFanOutFactor = 0.3;

  final PileSpec pileSpec;
  final PileType pileType;

  final int pileIndex;
  final int nCardsToDeal;
  final double baseWidth;
  final double baseHeight;
  final double _limitX;
  final double _limitY;

  final List<CardView> _cards = []; // The cards contained in this pile.

  int get nCards => pileType == PileType.stock ?
      _cards.length - 1: _cards.length;
  int get topCardIndex => hasNoCards ? -1 : _cards.last.indexOfCard;

  bool get hasNoCards => pileType == PileType.stock ?
      _cards.length == 1 : _cards.isEmpty;

  // These properties are calculated in the constructor from the Pile Spec.
  final bool _hasFanOut;
  final Vector2 _baseFanOut;
  var _fanOutFaceUp = Vector2(0.0, 0.0);
  var _fanOutFaceDown = Vector2(0.0, 0.0);

  var _transitCount = 0; // The number of cards "in transit" to this Pile.

  // @override
  final debugMode = true;

  void dump() {
    print('DUMP Pile $pileIndex, $pileType: nCards ${_cards.length} $_cards');
  }

  @override
  String toString() {
    return '$pileIndex';
  }

  MoveResult isDragMoveValid(CardView card, List<CardView> dragList) {
    DragRule dragRule = pileSpec.dragRule;
    dragList.clear();

    String message = 'Drag Pile $pileIndex, $pileType:';
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

    assert(card.isFaceUpView && _cards.contains(card));
    int nCards = cardOnTop ? 1 : (_cards.length - _cards.indexOf(card));
    print('$message ${card.toString()} nCards $nCards $_cards');

    // If any of the cards is already moving, cancel the drag.
    for (int n = 1; n <= nCards; n++) {
      print('$message nCards is card $n moving? ${_cards[_cards.length - n]}');
      if (_cards[_cards.length - n].isMoving) {
        return MoveResult.notValid;
      }
    }

    // The dragged cards leave the Pile and it adjusts its FanOut and hitArea.
    dragList.addAll(grabCards(nCards));
    print('$message nCards $nCards dragList $dragList');
    return MoveResult.valid;
  }

  MoveResult isTapMoveValid(CardView card) {
    TapRule tapRule = pileSpec.tapRule;
    String message = 'Tap Pile $pileIndex, $pileType:';
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
  }

  List<CardView> grabCards(int nRequired) {
    // Grab up to nRequired cards from end of Pile, incl. none if Pile isEmpty.
    List<CardView> tailCards = [];
    int nAvailable = (nCards >= nRequired) ? nRequired : nCards;
    int index = _cards.length - nAvailable;
    if (nAvailable > 0) {
      tailCards.addAll(_cards.getRange(index, _cards.length));
      _cards.removeRange(index, _cards.length);
    }
    // print('Grab $tailCards from $pileType index $pileIndex, '
        // 'contents $_cards');
    print('Grab $tailCards from $pileType index $pileIndex');
    if (_checkFanOut(_cards, tailCards, adding: false)) { 
      // If Fan Out changed, reposition any cards remaining in the Pile.
      _fanOutPileCards();
      _setPileHitArea();
    }
    return tailCards;
  }

  void dropCards(List<CardView> tailCards) {
    // Instantaneously drop and display cards on this pile (used in Undo/Redo).
    print('Drop $tailCards on $pileType index $pileIndex, contents $_cards');
    if (_checkFanOut(_cards, tailCards, adding: true) && _cards.isNotEmpty) {
      // If Fan Out changed, reposition all cards currently in the Pile.
      _fanOutPileCards();
    }

    for (final card in tailCards) {
      if (!_hasFanOut || _cards.isEmpty) {
        // The card is aligned with the Pile's position.
        card.position = position;
      } else {
        // Fan out the second and subsequent cards.
        final prev = _cards[_cards.length - 1];
        final fanOut = prev.isFaceUpView ? _fanOutFaceUp : _fanOutFaceDown;
        card.position = prev.position + fanOut;
        // print('$pileType $pileIndex prev $prev ${prev.position} '
            // 'card $card ${card.position}');
      }
      _cards.add(card);
      card.pile = this;
      card.priority = _cards.length;
    }
    _setPileHitArea();
  }

  // TODO - If we click too fast on full then empty Stock, cards can get frozen
  //        and become unplayable, making it impossible to finish the game.
  // TODO - Also, cards in the 48 Waste can get misplaced if you click too
  //        fast, but they come good when you drag the tail of the pile a bit..

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
    // cards have to go, so that we can have smooth animation and landing.
    final nCardsToMove = movingCards.length;
    final nPrevCardsInPile = _cards.length;
    final newFaceUp = movingCards.first.isFaceUpView ^ (flipTime > 0.0);
    print('RECV $movingCards on $pileType index $pileIndex, contents $_cards');
    print('Flip? ${flipTime > 0.0} '
        'last FaceUp? ${movingCards.last.isFaceUpView} newFaceUp $newFaceUp');

    if (_hasFanOut) {
      if (_checkFanOut(_cards, movingCards, adding: true)) {
        // FanOut must change: reposition all the cards currently in the Pile.
        for (int n = 1; n < nPrevCardsInPile; n++) {
          final diff =
              _cards[n - 1].isFaceUpView ?  _fanOutFaceUp : _fanOutFaceDown;
          if ( _cards[n].isMoving) {
            _cards[n].newPosition = _cards[n - 1].newPosition + diff;
          } else {
            _cards[n].position = _cards[n - 1].position + diff;
          }
        }
      }
    }

    // Calculate where the first incoming card will go.
    Vector2 tailPosition = position;
    if (nPrevCardsInPile > 0) {
      CardView card = _cards.last;
      tailPosition = card.isMoving ? card.newPosition : card.position;
      tailPosition += card.isFaceUpView ? _fanOutFaceUp : _fanOutFaceDown;
    }

    double startAt = startTime;
    int movePriority = CardView.movingPriority + _transitCount;

    for (final card in movingCards) {
      _cards.add(card);
      card.pile = this;
      card.newPriority = _cards.length;
      // Set up the animated moves the new cards should make.
      // print('_hasFanOut $_hasFanOut, _cards.length ${_cards.length}');
      if (!_hasFanOut || _cards.length == 1) {
        // The card will be aligned with the Pile's position.
        card.newPosition = position;
        tailPosition += newFaceUp ? _fanOutFaceUp : _fanOutFaceDown;
        // print('FIRST CARD IN PILE: ${card.name} pos ${card.newPosition}');
      } else {
        // Fan out the second and subsequent cards.
        card.newPosition = tailPosition;
        // print('SUBSEQUENT POSITION: $tailPosition');
        tailPosition += newFaceUp ? _fanOutFaceUp : _fanOutFaceDown;
      }

      // Make the card start moving. Later cards fly higher.
      print('DO MoveAndFlip: card $card pos ${card.newPosition} '
          'flip $flipTime start $startAt pri $movePriority');
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
          if (_transitCount == 0) {
            if (card.position != card.newPosition) {
              card.position = card.newPosition;
            }
            _setPileHitArea(); // TODO - Can do this before callback?
          }
          onComplete?.call(); // Optional callback for receiveMovingCards().
        }
      );
      startAt += intervalTime;
      movePriority++;
      _transitCount++;
    }
  }

  void setTopFaceUp(bool goFaceUp) {
    // Used by Undo and Redo to maintain flipped state of Cards.
    // In storeMove() only the "extra:" parameter indicates what is happening.
    if (_cards.isNotEmpty) {
      CardView card = _cards.last;
      if (goFaceUp) {
        // Card moving into play from FaceDown view.
        if (card.isFaceDownView) card.flipView();
      } else {
        // Undoing a move that included a flip to FaceUp view.
        if (card.isFaceUpView) card.flipView();
      }
    }
  }

  // TODO - Need to know whether to flip (as in Klondike) or not (as in Forty
  //        Eight). If needed, the flip has to be ANIMATED. Here or in GamePlay?
  bool neededToFlipTopCard() {
    // Used in piles like Klondike Tableaus, where top cards must be face-up.
    print('Pile $pileIndex $pileType needFlip: rule ${pileSpec.dealFaceRule}');
    if ((pileSpec.dealFaceRule == DealFaceRule.lastFaceUp) ||
        (pileSpec.dealFaceRule == DealFaceRule.last5FaceUp)) {
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

  bool isTopCard(CardView card) {
    return _cards.isNotEmpty ? (card == _cards.last) : false;
  }

  bool checkPut(CardView card) {
    // Player can put or drop cards onto Foundation or Tableau Piles only.
    String message = 'Check Put: ${card.name} Pile $pileIndex, $pileType:';
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
          case PutRule.descendingAnySuitBy1:
            return (card.rank == _cards.last.rank - 1);
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
      // print('Put ${to.pileType} ${card.name} faceDown ${card.isFaceDownView}');
      cardCount++;
    }
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

  void _fanOutPileCards() {
    if (_cards.isNotEmpty) {
      // Reposition the cards in the Pile.
      _cards.first.position = position;
      for (int n = 1; n < _cards.length; n++) {
        final diff = _cards[n - 1].isFaceUpView ?
            _fanOutFaceUp : _fanOutFaceDown;
        _cards[n].position = _cards[n - 1].position + diff;
      }
    }
  }

  bool _checkFanOut(List<CardView> pileCards, List<CardView> movingCards,
      {bool adding = false}) {
    if (!_hasFanOut || movingCards.isEmpty) {
      // print('NO FanOut change...');
      return false;
    }
    // print('Enter checkFanOut: $pileType $pileIndex $pileCards '
        // 'moving $movingCards add: $adding');

    if (!adding && (_fanOutFaceUp == _baseFanOut)) {
      // TODO - If Pile is now empty, just set FanOuts to base values?
      // print('NO FanOut change... adding: $adding');
      return false; // No need to expand FanOut after these cards have left.
    }
    if (_fanOutFaceUp == Vector2(0.0, 0.0)) {
      // Set the initial FanOuts (not allowed in Dart's constructor initialize).
      _fanOutFaceUp = _baseFanOut;
      _fanOutFaceDown = _baseFanOut * faceDownFanOutFactor;
      // print('INITIALIZE FanOut... adding: $adding');
      return true; // FanOut changed.
    }
    var tail = pileCards.isEmpty ? position : pileCards.last.pilePosition;
    final newFaceUp = movingCards.first.isFaceUpView;
    final factor = newFaceUp ? 1.0 : faceDownFanOutFactor;
    if (adding) {
      if (pileCards.isNotEmpty) {
        tail += pileCards.last.isFaceUpView ? _fanOutFaceUp : _fanOutFaceDown;
      }
      tail += _fanOutFaceUp * (factor * (movingCards.length - 1));
      var spaceLeft = Vector2(_limitX, _limitY) - tail;
      spaceLeft.x = (_limitX < position.x) ? -spaceLeft.x : spaceLeft.x;
      if ((spaceLeft.x >= 0.0) && (spaceLeft.y >= 0.0)) {
        // print('NO FanOut change... enough space available.');
        return false; // No change needed: enough space available,
      }
    }

    // Calculate the number of FanOut spaces needed.
    var slotsNeeded = 0.0;
    for (CardView card in pileCards) {
      slotsNeeded += card.isFaceUpView ? 1.0 : faceDownFanOutFactor;
    }
    slotsNeeded += adding ? (movingCards.length - 1) * factor : -1.0;

    // Avoid calculating a very large FanOut, or maybe even dividing by zero.
    slotsNeeded = (slotsNeeded < 1.0) ? 1.0 : slotsNeeded;

    final lastPosition = position + _fanOutFaceUp * slotsNeeded;
    // print('  Position of Last Card in Pile $lastPosition');
    // print('  Limit X $_limitX, limit Y $_limitY base FanOut $_baseFanOut');
    // print('  FanOut FaceUp $_fanOutFaceUp FaceDown $_fanOutFaceDown');

    // Horizontal Piles fan out left or right. Vertical piles fan out downwards.
    bool xWithinBounds = (pileSpec.growthCols > 0) ?
        (lastPosition.x <= _limitX) : (lastPosition.x >= _limitX);
    bool yWithinBounds = (lastPosition.y <= _limitY);
    // print('xWithinBounds $xWithinBounds, yWithinBounds $yWithinBounds');
    if (adding && xWithinBounds && yWithinBounds) {
      // print('No FanOut change needed... within bounds.');
      return false; // No card-position changes are needed.
    }

    // print('CURRENT FanOut $_fanOutFaceUp');
    // Need to decrease FanOut if adding or increase it if removing cards.
    var x = adding && xWithinBounds ?
      _fanOutFaceUp.x : (_limitX - position.x) / slotsNeeded;
    var y = adding && yWithinBounds ?
      _fanOutFaceUp.y : (_limitY - position.y) / slotsNeeded;
    // print('Calculated FanOut: slots $slotsNeeded x ${_limitX - position.x} y ${_limitY - position.y}');

    // Don't let FanOut get too large after removing cards from the Pile. Use
    // ratios in the tests, to allow for FanOuts being negative.
    if (!adding) {
      x = ((x / _baseFanOut.x) > 1.0) ? _baseFanOut.x : x;
      y = ((y / _baseFanOut.y) > 1.0) ? _baseFanOut.y : y;
    }

    _fanOutFaceUp = Vector2(x, y);
    _fanOutFaceDown = _fanOutFaceUp * Pile.faceDownFanOutFactor;
    // print('NEW FanOut $_fanOutFaceUp');
    return true;
  }

  void _setPileHitArea() {
    if ((pileType == PileType.tableau) || (pileType == PileType.foundation)) {
      double deltaX = (_cards.length < 2 ? 0.0 : _cards.last.x - x);
      double deltaY = (_cards.length < 2 ? 0.0 : _cards.last.y - y);
      width = (deltaX >= 0.0) ? baseWidth + deltaX : baseWidth - deltaX;
      height = (deltaY >= 0.0) ? baseHeight + deltaY : baseHeight - deltaY;
    }
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
