import 'dart:ui';

import 'package:flame/components.dart';

import '../pat_game.dart';
import '../pat_world.dart';
import '../specs/pat_enums.dart';
import '../specs/pat_specs.dart';
import 'card_view.dart';
import '../views/game_end.dart';

class Pile extends PositionComponent with HasWorldReference<PatWorld> {
  Pile(this.pileSpec, this.pileIndex, this.baseWidth, this.baseHeight,
      {int deal = 0, required Vector2 position})
    :
    pileType = pileSpec.pileType,
    nCardsToDeal = deal,
    _hasFanOut = (pileSpec.fanOutX != 0.0) || (pileSpec.fanOutY != 0.0),
    _baseFanOut = Vector2( // The starting FanOut and the maximum allowed.
        pileSpec.fanOutX * PatWorld.cardWidth,
        pileSpec.fanOutY * PatWorld.cardHeight),
    _limitX = position.x + pileSpec.growthCols * baseWidth,
    _limitY = position.y + pileSpec.growthRows * baseHeight +
        (baseHeight - PatWorld.cardHeight) / 2,
    super(
      anchor: Anchor.topCenter,
      size: Vector2(baseWidth, baseHeight), // i.e. cellSize from PatWorld.
      position: position,
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
  List<CardView> getCards() => List.of(_cards);

  bool get hasNoCards => pileType == PileType.stock ?
      _cards.length == 1 : _cards.isEmpty;
  bool get isKlondikeDraw3Waste =>
      ((world.gameSpec.gameID == PatGameID.klondikeDraw3) &&
        (pileType == PileType.waste));
  bool get isFullFoundationPile => (pileType == PileType.foundation) &&
    (_cards.length == ((world.gameSpec.gameID == PatGameID.mod3) ? 4 : 13));

  // These properties are calculated later from the PileSpec data.
  final bool _hasFanOut;
  final Vector2 _baseFanOut;
  var _fanOutFaceUp = Vector2(0.0, 0.0);
  var _fanOutFaceDown = Vector2(0.0, 0.0);

  var _transitCount = 0; // The number of cards "in transit" to this Pile.

/* For debugging
  // @override
  // final debugMode = false;
  // final debugMode = true;

  void dump() {
    print('DUMP Pile $pileIndex $pileType: nCards ${_cards.length} $_cards');
  }

  @override
  String toString() {
    return '$pileIndex';
  }
*/

  MoveResult isDragMoveValid(CardView card, List<CardView> dragList,
      {bool grabbing = false}) {
    final dragRule = pileSpec.dragRule;
    dragList.clear();

    // String message = 'Drag Pile $pileIndex, $pileType:';
    // print('$message seen');
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
    // print('$message ${card.toString()} nCards $nCards $_cards');
    // print('Drag rule is $dragRule');
    if (nCards > 1) {
      var prevCard = card;
      for (int n = _cards.length - nCards + 1; n < _cards.length; n++) {
        // print('SEQUENCE-TEST ${_cards[n]} versus $prevCard');
        switch (pileSpec.multiCardsRule) {
          case MultiCardsRule.inAnyOrder: // (e.g. Yukon).
            break;
          case MultiCardsRule.descendingSameSuitBy1: // (e.g. Forty & Eight).
            if ((_cards[n].suit != prevCard.suit) ||
                (_cards[n].rank != prevCard.rank - 1)) {
              return MoveResult.notValid;
            }
          case MultiCardsRule.descendingAlternateColorsBy1: // (e.g. Freecell).
            if ((_cards[n].isRed == prevCard.isRed) ||
                (_cards[n].rank != prevCard.rank - 1)) {
              return MoveResult.notValid;
            }
          default:
        }
        prevCard = _cards[n];
      }
    }

    // If any of the cards is already moving, cancel the drag.
    for (int n = 1; n <= nCards; n++) {
      if (_cards[_cards.length - n].isMoving) {
        return MoveResult.notValid;
      }
    }

    if (grabbing) {
      // The dragged cards leave the Pile and it adjusts its FanOut and hitArea.
      dragList.addAll(grabCards(nCards));
    } else {
      // Get a COPY of the cards that could be dragged, as a possible move.
      int index = _cards.length - nCards;
      dragList.addAll(_cards.getRange(index, _cards.length).toList());
    }
    return MoveResult.valid;
  }

  MoveResult isTapMoveValid(CardView card) {
    TapRule tapRule = pileSpec.tapRule;
    // String message = 'Tap Pile $pileIndex, $pileType:';
    if (pileSpec.tapRule == TapRule.tapNotAllowed) {
      // print('$message tap not allowed');
      return MoveResult.notValid; // e.g. Foundation Piles do not accept taps.
    }
    if (!isTopCard(card)) {
      // print('$message tap is not on top card');
      return MoveResult.notValid;
    }
    // Stock needs top card face-down, other piles need top card face-up.
    final needFaceUp = (pileType != PileType.stock);
    if (needFaceUp != card.isFaceUpView) {
      // print('$message card ${card.name} face-up is not $needFaceUp');
      return MoveResult.notValid;
    }
    if (_cards.isEmpty && (pileType != PileType.stock)) {
      // print('$message _cards is Empty');
      return MoveResult.pileEmpty;
    }
    switch (pileType) {
      case PileType.stock:
        if (card.isBaseCard) {
          // print('$message empty Stock Pile');
          return MoveResult.pileEmpty;
        } else {
          return MoveResult.valid;
        }
      case PileType.waste:
      case PileType.tableau:
      case PileType.freecell:
        if (tapRule != TapRule.goOut) {
          // print('$message $tapRule invalid - should be TapRule.goOut');
          return MoveResult.notValid;
        } else {
          return MoveResult.valid;
        }
      case PileType.foundation:
        // Maybe the card was dealt here but does not belong (e.g. Mod 3).
        // Then it might be able to go out on another Foundation Pile.
        return ((_cards.length == 1) && (card.rank != pileSpec.putFirst)) ?
            MoveResult.valid : MoveResult.notValid;
      case PileType.excludedCards:
        return MoveResult.notValid;
    }
  }

  List<CardView> grabCards(int nRequired, {bool reverseAndFlip = false}) {
    // Grab up to nRequired cards from end of Pile, incl. none if Pile isEmpty.
    List<CardView> tailCards = [];
    int nAvailable = (nCards >= nRequired) ? nRequired : nCards;
    int index = _cards.length - nAvailable;
    if (nAvailable > 0) {
      List<CardView> temp = _cards.getRange(index, _cards.length).toList();
      _cards.removeRange(index, _cards.length);
      if (reverseAndFlip && temp.isNotEmpty) {
        // Reverse the order of the cards and flip them, as in Klondike 3 Draw.
        temp = temp.reversed.toList();
        for (final tempCard in temp) {
          tempCard.flipView();
        }
      }
      tailCards.addAll(temp);
    }
    if (_checkFanOut(_cards, tailCards, adding:false) || isKlondikeDraw3Waste) {
      // If Fan Out changed or Klondike 3 Draw, reposition any cards remaining.
      _fanOutPileCards();
    }
    _setPileHitArea();
    return tailCards;
  }

  void dropCards(List<CardView> tailCards) {
    // Instantaneously drop and display cards on this pile (used in Undo/Redo).
    // print('Drop $tailCards on $pileType index $pileIndex, contents $_cards');
    if (_checkFanOut(_cards, tailCards, adding: true) && _cards.isNotEmpty) {
      // If Fan Out changed, reposition all cards currently in the Pile.
      // ??????? _fanOutPileCards();
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
    _fanOutPileCards(); // ???????
    _setPileHitArea();
  }

  void receiveMovingCards(
    List<CardView> movingCards, {
    double speed = 15.0,
    double startTime = 0.0,
    double flipTime = 0.3,
    double intervalTime = 0.0,
    VoidCallback? onComplete,
  }) {
    // Receive animated cards onto this pile, calculating exactly where cards
    // have to go, thus providing smooth animation and fan-out.
    final nCardsToMove = movingCards.length;
    final nPrevCardsInPile = _cards.length;
    final newFaceUp = movingCards.first.isFaceUpView || (flipTime > 0.0);

    double distancePerFrame = /*speed * */9.0 * movingCards.first.size.x / 60.0;
    bool noFanOutChange = true;
    if (_hasFanOut) {
      noFanOutChange = !_checkFanOut(_cards, movingCards, adding: true);
    }
    double startAt = startTime;
    int movePriority = CardView.movingPriority + _transitCount;

    for (final card in movingCards) {
      _cards.add(card);
      card.pile = this;
      card.newPriority = _cards.length;
    }
    List<Vector2>newPositions =
        _calculatePositions(_cards, nAdd: nCardsToMove, faceUp: newFaceUp);

    int index = -1;
    for (final card in _cards) {
      index++;
      // print('Index $index card ${card.name} pri ${card.priority} moving '
          // '${card.isMoving}');
      if (noFanOutChange && (index < nPrevCardsInPile) && !isKlondikeDraw3Waste)
      {
        continue;
      }
      // If Klondike Draw 3 Waste or fan-out change, may re-position prev cards.
      card.newPosition = newPositions[index];

      if (card.position == newPositions[index]) {
        // This card does not need to move.
        card.priority = index + 1;
        continue;
      }
      Vector2 delta = card.position - newPositions[index];
      double manhattanDistance = delta.x.abs() + delta.y.abs();
      if ((manhattanDistance < distancePerFrame) || (index < nPrevCardsInPile))
      {
        // Not far to go, skip doing the animation.
        // print('Card $card goes small distance $manhattanDistance');
        card.position = card.newPosition;
        card.priority = index + 1;
        continue;
      }

      // Make the card start moving. Later cards fly higher.
      // print('DO MoveAndFlip: card $card pos ${card.newPosition} '
          // 'flip $flipTime start $startAt pri $movePriority');
      card.doMoveAndFlip(
        card.newPosition,
        speed: speed,
        flipTime: flipTime, // Optional flip: no flip if flipTime == 0.0.
        start: startAt,
        startPriority: movePriority,
        whenDone: () {
          card.priority = card.newPriority;
          _transitCount--;
          if (card.position != card.newPosition) {
            card.position = card.newPosition;
          }
          // N.B. _transitCount can apply to SEVERAL receives of cards.
          if (_transitCount == 0) {
            if (isFullFoundationPile && world.gameplay.checkForAWin()) {
              final gameEnd = GameEnd(world.game, world.cards, world.piles);
              gameEnd.letsCelebrate();
            } else {
              onComplete?.call(); // Optional callback for receiveMovingCards().
            }
          }
        }
      );
      startAt += intervalTime;
      movePriority++;
      _transitCount++;
    }
    _setPileHitArea();
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

  bool neededToFlipTopCard() {
    // Used in Tableau piles (e.g. Klondike), where top cards must be face-up.
    // print('Pile $pileIndex $pileType needFlip?');
    if (pileType == PileType.tableau) {
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
    // print('Before remove Aces $pileIndex $pileType: $_cards $excludedCards');
    for (CardView card in _cards) {
      if (card.rank == excludedRank) {
        excludedCards.add(card);
      }
    }
    _cards.removeWhere((card) => card.rank == excludedRank);
    // print(' After remove Aces $pileIndex $pileType: $_cards $excludedCards');
  }

  bool isTopCard(CardView card) {
    return _cards.isNotEmpty ? (card == _cards.last) : false;
  }

  bool checkPut(List<CardView> cardsToBePut, {Pile? from}) {
    CardView leadCard = cardsToBePut.first;
    // String message = 'Check Put: $leadCard Pile $pileIndex, $pileType:';
    // Player can put cards onto Foundation, Tableau or Freecell Piles only.
    if ((pileType != PileType.foundation) && (pileType != PileType.tableau) &&
        (pileType != PileType.freecell)) {
      // print('$message cannot put on Stock, Waste or Excluded Piles.');
      return false;
    }
    // print('Put $cardsToBePut from $from');

    int nCardsToBePut = cardsToBePut.length;
    if (pileType == PileType.foundation) {
      // Foundations usually accept just 1 card: Simple Simon requires 13.
      if (nCardsToBePut != ((pileSpec.putRule == PutRule.wholeSuit) ? 13 : 1)) {
        // print('$message Foundation cannot accept $nCardsToBePut cards');
        return false;
      }
    }

    bool result = false;
    bool calculate = false;
    int pileSuit = 0;
    int delta = 1;

    if (_cards.isEmpty) {
      final firstOK =
          (pileSpec.putFirst == 0) || (leadCard.rank == pileSpec.putFirst);
      // String resultString = firstOK ? 'first card OK' : 'first card FAILED';
      // print('$message $resultString');
      result = firstOK;
      if (pileSpec.putRule == PutRule.ifEmptyAnyCard) {
        // PileType.freecell can accept just one card.
        //print('Freecell empty? ${_cards.isEmpty} cards to put $cardsToBePut');
        result = (firstOK && (nCardsToBePut == 1));
      }
      calculate = false;

    } else { // Pile is not empty.
      // print('$message ${pileSpec.putRule}');
      pileSuit = _cards.last.suit;
      switch (pileSpec.putRule) {
        case PutRule.ascendingSameSuitBy1:
          delta = 1;
          calculate = true;
        case PutRule.ascendingSameSuitBy3:
          delta = 3;
          calculate = true;
        case PutRule.descendingSameSuitBy1:
          delta = -1;
          calculate = true;
        case PutRule.descendingAnySuitBy1:
          result = (leadCard.rank == _cards.last.rank - 1);
        case PutRule.descendingAlternateColorsBy1:
          final isCardOK = (leadCard.isRed == !_cards.last.isRed) &&
              (leadCard.rank == _cards.last.rank - 1);
          // print('$message ${isCardOK ? "card OK" : "card FAILED"}');
          result = isCardOK;
        case PutRule.sameRank:
          // print('$message sameRank? card ${leadCard.rank} '
              // 'pile ${_cards.last.rank}');
          result = (leadCard.rank == _cards.last.rank);
        case PutRule.wholeSuit:
          // Leading card's rank must be King (Simple Simon game) or Ace(?).
          result = (leadCard.rank == pileSpec.putFirst);
        case PutRule.putNotAllowed:
          return false; // Cannot put card on this Pile.
        case PutRule.ifEmptyAnyCard:
          // Pile is not empty, so PileType.freecell cannot accept a card.
          return false;
      }
    }

    // print('Calc $calculate result $result delta $delta ${pileSpec.putRule}');
    if ((calculate == false) && (result == false)) {
      // print('$message checkPut FAILED non-calculation PutRule');
      return false;
    }
    if (calculate && ((leadCard.rank != (_cards.last.rank + delta)) ||
        (leadCard.suit != pileSuit))) {
      // print('$message checkPut FAILED calculation with delta $delta');
      return false;
    }
    if ((pileType == PileType.foundation) && _cards.isNotEmpty &&
        (_cards.first.rank != pileSpec.putFirst)) {
      // Base card of pile has wrong rank. Can happen if the deal has put
      // random cards on the Foundation Pile (e.g. as in Mod 3).
      // print('$message wrong first rank ${_cards.first.name}');
      return false;
    }

    // Check if there are enough empty Tableaus and/or freecells to do the move.
    if ((nCardsToBePut > 1) && (from != null) &&
        (pileSpec.dragRule == DragRule.fromAnywhereViaEmptySpace)) {
      if (world.gameplay.notEnoughSpaceToMove(nCardsToBePut, from, this)) {
        // print('$message not enough space to move $nCardsToBePut cards');
        return false;
      }
    }
    // print('$message checkPut() OK');
    return true;
  }

  int turnPileOver(Pile to) {
    // Turn over Waste->Stock, undo it or redo it.
    // Normal or redo move is Waste->Stock, undo is Stock->Waste.
    // print('Flip Pile: $pileType last Waste ${world.lastWastePile} $_cards');
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

  var _excludedCardsPileIndex = -1;
  var _destinationPileIndex = -1;
  var _storing = true; // Only the  deal before play begins sets this to false.
  final List<CardView> _cardsToDeal = []; // Stock that must Move to this Pile.

  void replenishTableauFromStock(int stockPileIndex, int excludedCardsPileIndex,
      {int destinationPileIndex = -1, List<CardView> droppedCards = const [],
      bool storing = true,})
  {
    // Auto-refill a Tableau Pile that is empty or has its last card about to
    // be played. Auto-remove excluded cards (eg. Aces), repeatedly if required.

    final excludedRank = world.gameSpec.excludedRank;
    final redealEmptyTableau = world.gameSpec.redealEmptyTableau;

    if (pileType != PileType.tableau) {
      throw StateError('replenishTableauFromStock() requires a Tableau Pile');
    }
    if ((excludedRank == 0) && !redealEmptyTableau) {
      throw StateError('replenishTableauFromStock() requires the Game to '
          'have excluded cards or auto-refill of empty Tableau Piles or both');
    }
    if (redealEmptyTableau && (stockPileIndex < 0)) {
      throw StateError('Auto-refill of empty Tableau Piles requires the '
          'Game to have a Stock Pile from which to deal Cards');
    }
    if ((excludedRank > 0) && (excludedCardsPileIndex < 0)) {
      throw UnimplementedError(
          'Game has excluded cards but no Excluded Card Pile to put them on');
    }

    Pile stock = world.piles[stockPileIndex];
    _excludedCardsPileIndex = excludedCardsPileIndex;
    _destinationPileIndex = destinationPileIndex;
    _storing = storing;

    bool excludedCardOnTop = false;
    if (nCards > 0) {
      excludedCardOnTop = (_cards.last.rank == excludedRank);
    }

    // Option 1: One card in Pile (poss. excluded), it leaves and is replaced.
    //        2: Last of >1 cards is excluded: it leaves and is not replaced.
    //        3: No cards in Pile, but a card has been dragged out and dropped.
    assert((nCards == 1) || ((nCards > 1) && (_cards.last.rank == excludedRank))
        || droppedCards.isNotEmpty);

    if (excludedCardOnTop && (nCards > 1)) {
      _replaceTableauCard(); // Just reject the top card: no need to replenish.
      return;
    }

    // Queue a card to replenish the Tableau, preceded by rejects (if any).
    bool foundSuitableCard = false;
    while (! foundSuitableCard) {
      List<CardView> stockTop = stock.grabCards(1);
      if (stockTop.isEmpty) {
        break; // No more cards in the Stock Pile.
      }
      _cardsToDeal.add(stockTop.first);
      if (stockTop.first.rank != excludedRank) {
        foundSuitableCard = true; // Found a card that is not excluded.
      }
    }
    _replaceTableauCard(droppedCards: droppedCards);
    return;
  }

  // This "loop" replaces any number of excluded cards that happen to be dealt,
  // in succession, most commonly just the one that has arrived already. It
  // also replaces a card that is going out and would leave the Tableau empty.
  //
  // The function sends the outgoing card to its Pile, with no callback, then
  // it requests another card from the Stock Pile - using itself as a callback.
  //
  void _replaceTableauCard({List<CardView>droppedCards = const []}) {
    final rejects = world.piles[_excludedCardsPileIndex];
    final target = (_destinationPileIndex == -1) ? rejects :
        world.piles[_destinationPileIndex];
    _destinationPileIndex = -1; // Destination Pile can be used only once.

    if (droppedCards.isNotEmpty) {
      // Add dropped card back to empty Pile temporarily, but with no changes
      // of its position or other state. This ensures that the final card in a
      // Tableau can always be moved by the code below, no matter whether it
      // has been tapped or dragged away somewhere and dropped.
      _cards.add(droppedCards.first);
      droppedCards.clear();
    }
    if (_cards.isEmpty && _cardsToDeal.isEmpty) {
      return; // Do nothing: Tableau remains empty.
    }
    var moveType = Extra.none; // Default: just move top card to Rejects.
    if (_cards.isEmpty && droppedCards.isEmpty && _cardsToDeal.isNotEmpty) {
      moveType = Extra.toCardUp; // Deal a card from Stock.
    } else if (_cards.isNotEmpty && _cardsToDeal.isNotEmpty && (nCards <= 1)) {
      moveType = Extra.autoDealTableau;
    }

    if ((moveType == Extra.none) || (moveType == Extra.autoDealTableau)) {
      // Do normal animated Tableau-to-Reject move, no callback.
      final excludedCard = grabCards(1);
      target.receiveMovingCards(
        excludedCard,
        speed: 10.0,
        flipTime: 0.0, // No flip.
      );
      if (_storing && (moveType == Extra.none)) {
        int cardID = excludedCard.first.indexOfCard;
        world.gameplay.storeReplenishmentMove(this, target, moveType, cardID);
        return;
      }
    }
    if ((moveType == Extra.toCardUp) || (moveType == Extra.autoDealTableau)) {
      // Do deal from Stock or compound move from Stock, with callback.
      CardView nextCard = _cardsToDeal.removeAt(0);
      receiveMovingCards(
        [nextCard],
        speed: 10.0,
        flipTime: 0.3, // Flip card.
        onComplete: () {
          if (_cards.last.rank == world.gameSpec.excludedRank) {
            _replaceTableauCard();
          }
        },
      );
      if (_storing) { // Store Moves during Gameplay but not initial Deal.
        world.gameplay.storeReplenishmentMove(this, target, moveType,
            nextCard.indexOfCard);
      }
    }
  }

  List<Vector2> _calculatePositions(
      List<CardView> cards, { // List of all cards to be positioned.
      int nAdd = 0, // The number of animated cards to be received (if any).
      bool faceUp = false, // Whether the incoming cards will go face-up.
  }) {
    List<Vector2> positions = [];
    if (cards.isNotEmpty) {
      // Calculate where each card should sit in the Pile.
      int fanOutStart = 1;
      int cardCount = cards.length;
      if (isKlondikeDraw3Waste) {
        fanOutStart = (cardCount < 3) ? 1 : cardCount - 2;
      }
      if (!_hasFanOut) {
        fanOutStart = cardCount; // All cards go at Pile position.
      }
      for (int n = 0; n < cardCount; n++) {
        if (n < fanOutStart) {
          positions.add(Vector2(position.x, position.y));
        } else {
          bool up = (n < cardCount - nAdd + 1) ?
              cards[n - 1].isFaceUpView : faceUp;
          final diff = up ? _fanOutFaceUp : _fanOutFaceDown;
          positions.add(positions[n - 1] + diff);
        }
      }
    }
    return positions;
  }

  void _fanOutPileCards() {
    // Instantaneous fan out of whole Pile: used by grab, put and Undo/Redo.
    List<Vector2> positions = _calculatePositions(_cards);
    if (positions.isNotEmpty) {
      int n = 0;
      for (final CardView card in _cards) {
        card.position = positions[n];
        n++;
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
      // print('INITIALIZE FanOut... adding: $adding, '
          // '$_fanOutFaceUp $_fanOutFaceDown');
      return true; // FanOut changed.
    }
    if (isKlondikeDraw3Waste) {
      // Initialize Klondike Draw 3 Waste Pile fan out: no need to change it.
      // print('NO FanOut change: Pile is Klondike Draw 3 Waste');
      return false;
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
      Vector2 delta = Vector2(0.0, 0.0);
      if (_cards.length > 1) {
        CardView card = _cards.last;
        Vector2 end = card.isMoving ? card.newPosition : card.position;
        delta = Vector2((end.x - position.x).abs(), (end.y - position.y).abs());
      }
      size = Vector2(baseWidth + delta.x, baseHeight + delta.y);
    }
  }

  final List<List<int>> savedState = [[], []];

  void saveState(int stateNumber) {
    // Used before Redeal in Grandfather Game, to support Undo of that move.
    // final redealNumber = 2 - grandfatherRedeals;
    // print('SAVE STATE $stateNumber pile $pileIndex $pileType cards $_cards');
    savedState[stateNumber].clear();
    for (CardView card in _cards) {
      int cardID = card.indexOfCard;
      cardID = card.isFaceDownView ? -cardID : cardID;
      savedState[stateNumber].add(cardID);
    }
  }

  List<int> restoreState(int redealNumber) {
    // Used during Undo of a Redeal Move in a GrandFather Game.
    // print('UNDO/REDO REDEAL $redealNumber pile $pileIndex $pileType');
    // print('  Saved Values ${savedState[redealNumber - 1]}');
    final restoredCards = List<int>.from(savedState[redealNumber -1]);
    // print('  _cards $_cards');
    // print('  Cards to Restore $restoredCards');
    saveState(redealNumber - 1); // Save the previous State, for Undo or Redo.
    return restoredCards;
  }

  void showPileState(List<int> pileState) {
    // print('  showPileState $pileState');
    // print('  current _cards $_cards');
    _cards.clear();
    // print('  _cards $_cards');
    for (int cardID in pileState) {
      bool faceDown = (cardID < 0);
      final cardIndex = faceDown ? -cardID : cardID;
      CardView card = world.cards[cardIndex]; // Must have positive cardIndex.
      if (faceDown != card.isFaceDownView) {
        card.flipView();
      }
      put(card);
    }
    // print('  _cards $_cards');
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
