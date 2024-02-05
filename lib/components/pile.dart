import 'dart:ui';

import 'package:flame/components.dart';

import '../pat_game.dart';
import '../pat_world.dart';
import '../specs/pat_enums.dart';
import '../specs/pat_specs.dart';
import 'card_view.dart';

class Pile extends PositionComponent with HasWorldReference<PatWorld> {
  Pile(this.pileSpec, this.pileIndex, this.baseWidth, this.baseHeight,
      {required int row, required int col, int deal = 0, super.position})
      : pileType = pileSpec.pileType,
        gridRow = row,
        gridCol = col,
        nCardsToDeal = deal,
        super(
          anchor: Anchor.topCenter,
          size: Vector2(baseWidth, baseHeight),
          priority: -1,
        ) {

    // The initial Fan Out values are calulated here because they depend upon
    // const values inside the Pile's PileSpec Record (see parameter pileSpec).
    // Also, the _fanOutFaceUp and _fanOutFaceDown properties can vary during
    // gameplay, depending on availability of space, so they must be var.

    if (pileSpec.fanOutX != 0.0 || pileSpec.fanOutY != 0.0) {
      // Initialize the FanOut variables. Allow extra space for FanOut down.
      print('  $pileType index $pileIndex '
          'Xgrowth ${pileSpec.growthCols} Ygrowth ${pileSpec.growthRows}');
      final dy = baseHeight - PatWorld.cardHeight - PatWorld.cardMargin / 2;
      limitX = position.x + pileSpec.growthCols * baseWidth;
      limitY = position.y + pileSpec.growthRows * baseHeight + dy;
      _baseFanOut = Vector2(pileSpec.fanOutX * PatWorld.cardWidth,
          pileSpec.fanOutY * PatWorld.cardHeight);
      _fanOutFaceUp = _baseFanOut;
      _fanOutFaceDown = _baseFanOut * Pile.faceDownFanOutFactor;
      print('  Limit X $limitX, limit Y $limitY extra Y $dy FanOut $_baseFanOut');
      _hasFanOut = true;
    } else {
      print('  $pileType has NO FanOut in this game');
    }
  }

  static const faceDownFanOutFactor = 0.3;

  // final bool debugMode = true;
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

  // These properties are calculated from the Pile Spec in the constructor body.
  var _hasFanOut = false;
  var _baseFanOut = Vector2(0.0, 0.0);
  var _fanOutFaceUp = Vector2(0.0, 0.0);
  var _fanOutFaceDown = Vector2(0.0, 0.0);
  var limitX = 0.0;
  var limitY = 0.0;

  void dump() {
    print('DUMP Pile $pileIndex, $pileType: $_cards');
  }

  String toString() {
    return '$pileIndex';
  }

  void setPileHitArea() {
    if (pileType == PileType.tableau) {
      double deltaX = (_cards.length < 2 ? 0.0 : _cards.last.x - x);
      double deltaY = (_cards.length < 2 ? 0.0 : _cards.last.y - y);
      width = (deltaX >= 0.0) ? baseWidth + deltaX : baseWidth - deltaX;
      height = (deltaY >= 0.0) ? baseHeight + deltaY : baseHeight - deltaY;
    }
  }

  MoveResult dragMove(CardView card, List<CardView> dragList) {
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
      dragList.add(_cards.removeLast());
      _expandFanOut();
      setPileHitArea();
      // print('$message removed top card of Pile');
      return MoveResult.valid;
    }
    assert(card.isFaceUpView && _cards.contains(card));
    final index = _cards.indexOf(card);
    // print('$message ${card.toString()} index $index $_cards');
    dragList.addAll(_cards.getRange(index, _cards.length));
    _cards.removeRange(index, _cards.length);
    _expandFanOut();
    // print('Pile $_cards, moving $dragList');
    setPileHitArea();
    return MoveResult.valid;
  }

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
          // TODO - Need removeLast AND expandFanOut HERE OR SOMEWHERE ELSE ????
          // ??????? _cards.removeLast();
          // ??????? _expandFanOut(); // In case there is a game that fans out the Stock.
          // print('$message take ${card.toString()} from top');
          return MoveResult.valid;
        }
      case PileType.waste:
      case PileType.tableau:
        if (tapRule != TapRule.goOut) {
          print('$message $tapRule invalid - should be TapRule.goOut');
          return MoveResult.notValid;
        } else {
          // TODO - Need removeLast(), expandFanOut AND setPileHitArea HERE OR SOMEWHERE ELSE ????
          // ??????? _cards.removeLast();
          // ??????? _expandFanOut();
          // ??????? setPileHitArea();
          // print('$message take ${card.toString()} from top');
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
      _expandFanOut();
      if ((pileType == PileType.tableau) || (pileType == PileType.waste)) {
        setPileHitArea();
      }
    }
    return tail;
  }

  void dropCards(List<CardView> tail) {
    print('Drop $tail on $pileType index $pileIndex, contents $_cards');
    for (final card in tail) {
      put(card);
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
    // print('isTopCard(${card.name})? _cards $_cards');
    // print('card hashCode ${card.hashCode} last card ${_cards.last.hashCode}');
    // print('_cards.isNotEmpty ${_cards.isNotEmpty}, _cards.last ${_cards.last}');
    // return (_cards.isNotEmpty && (card == _cards.last));
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
    _cards.add(card);
    card.pile = this;
    card.priority = _cards.length;
    if (!_hasFanOut || _cards.length == 1) {
      // The card is aligned with the Pile's position.
      card.position = position;
    } else {
      // Fan out the second and subsequent cards.
      final prevFaceUp = _cards[_cards.length - 2].isFaceUpView;
      final fanOut = prevFaceUp ? _fanOutFaceUp : _fanOutFaceDown;
      print('$pileType $pileIndex card ${card.name} FanOut $fanOut');
      card.position = _cards[_cards.length - 2].position + fanOut;
      if (card.position.y >= limitY) {
        print('OVERFLOW Y: ${card.position.y} limit $limitY');
        _bunchUpCards(onY: true);
      }
      if (((pileSpec.growthCols > 0) && (card.position.x >= limitX)) ||
          ((pileSpec.growthCols < 0) && (card.position.x <= limitX))) {
        print('OVERFLOW X: ${card.position.x} limit $limitX '
            '${pileSpec.growthCols} cols growth');
        _bunchUpCards(onY: false);
      }
    }
    // print('Put ${card.toString()} $pileType $gridRow $gridCol'
    // ' pos ${card.position} pri ${card.priority}');
    setPileHitArea();
  }

  void _bunchUpCards({required bool onY}) {
    var spaceNeeded = 0.0;
    int nCards = _cards.length;
    for (int n = 1; n < nCards; n++) {
      spaceNeeded +=
          _cards[n - 1].isFaceUpView ? 1.0 : Pile.faceDownFanOutFactor;
    }
    _fanOutFaceUp = onY
        ? Vector2(_fanOutFaceUp.x, (limitY - position.y) / spaceNeeded)
        : Vector2((limitX - position.x) / spaceNeeded, _fanOutFaceUp.y);
    _fanOutFaceDown = _fanOutFaceUp * Pile.faceDownFanOutFactor;
    for (int n = 1; n < nCards; n++) {
      var delta = _cards[n - 1].isFaceUpView ? _fanOutFaceUp : _fanOutFaceDown;
      _cards[n].position = _cards[n - 1].position + delta;
    }
  }

  void _expandFanOut() {
    if (!_hasFanOut) {
      return; // No Fan Out in this pile.
    }
    print('Entering _expandFanOut()...');
    var ratio = 1.0;
    if (pileSpec.fanOutX != 0.0) {
      // Calculate (current / ideal) fan out ratio: always +ve even if both -ve.
      ratio = _fanOutFaceUp.x / _baseFanOut.x;
      if (ratio < 1.0) {
        // Less than ideal: increase the cards' fan outs to base value or less.
        _fanOutFaceUp.x = _adjustFanOut(limitX - position.x, _baseFanOut.x);
      }
    }
    if (pileSpec.fanOutY != 0.0) {
      ratio = _fanOutFaceUp.y / _baseFanOut.y;
      if (ratio < 1.0) {
        _fanOutFaceUp.y = _adjustFanOut(limitY - position.y, _baseFanOut.y);
      }
      print('Ratio $ratio, _fanOutFaceUp ${_fanOutFaceUp.toString()}');
    }
    _fanOutFaceDown = _fanOutFaceUp * Pile.faceDownFanOutFactor;
    int nCards = _cards.length;
    for (int n = 1; n < _cards.length; n++) {
      var delta = _cards[n - 1].isFaceUpView ? _fanOutFaceUp : _fanOutFaceDown;
      _cards[n].position = _cards[n - 1].position + delta;
    }
  }

  double _adjustFanOut(double lengthAvailable, double baseLength) {
    var slotsNeeded = 0.0;
    for (int n = 1; n < _cards.length; n++) {
      slotsNeeded +=
          _cards[n - 1].isFaceUpView ? 1.0 : Pile.faceDownFanOutFactor;
    }
    double faceUpLength = lengthAvailable / slotsNeeded;
    // When fanning out left, both values are negative, hence the division.
    if (faceUpLength / baseLength > 1.0) faceUpLength = baseLength;
    return faceUpLength;
  }

  bool needFlipTopCard() {
    // Used in piles like Klondike Tableaus, where top cards must be face-up.
    print('Pile $pileIndex $pileType needFlip: rule ${pileSpec.dealFaceRule}');
    if (pileSpec.dealFaceRule == DealFaceRule.lastFaceUp) {
      // print('Not empty ${_cards.isNotEmpty} card ${_cards.last.name} last face-down ${_cards.last.isFaceDownView}');
      if (_cards.isNotEmpty && _cards.last.isFaceDownView) {
        final savedPriority = _cards.last.priority;
        _cards.last.turnFaceUp(
          start: 0.1,
          onComplete: () {
            _cards.last.priority = savedPriority;
          },
        );
        return true; // Need to flip the card.
      }
    }
    return false;
  }

  int dealFromStock(TapRule tapRule, Pile target, List<CardView> movingCards) {
    assert(target.pileType == PileType.waste ||
        target.pileType == PileType.tableau);
    assert(pileType == PileType.stock);
    assert((tapRule == TapRule.turnOver1) || (tapRule == TapRule.turnOver3));
    assert(_cards.length > 0 && _cards.first.isBaseCard);
    int result = 0;
    dump();
    if (tapRule == TapRule.turnOver1 && _cards.length > 1) {
      CardView cardToDeal = _cards.removeLast();
      movingCards.add(cardToDeal);
      result = 1;
      cardToDeal.doMoveAndFlip(
        target.position,
        whenDone: () {
          target.put(cardToDeal);
        },
      );
      return result;
    }
    return result;
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
    // Outline and fill the image of the Pile (a little smaller than a card).
    canvas.drawRRect(PatWorld.pileRect, pileBackgroundPaint);
    canvas.drawRRect(PatWorld.pileRect, pileOutlinePaint);
  }
}
