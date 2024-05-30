import 'dart:core';

import '../components/card_view.dart';
import '../components/pile.dart';
import '../specs/pat_enums.dart';

// TODO - Automate Undo/Redo of sequences of moves involving moves of Excluded
//        cards to/from the ExcludedCards Pile, Combine with Stock-to-Tableaus.
//        Would need to bring back some values from GamePlay to track these.
// TODO - Another idea would be to have "Forced" flags for multiple Moves that
//        have to be undone/redone as one.

typedef CardMove = ({
  int fromPile, // Starting PileIndex.
  int toPile, // Finishing PileIndex.
  int nCards, // Number of Card(s) to move.
  Extra extra, // See enum definition in specs/pat_enums.dart.
  int strength, // Reserved for use in Solver, default = 0.
  int leadCard, // For DEBUG: index number of first card (if known).
});

// The basic Move is to take one or more cards from the end of one pile and
// add it/them to the end of another pile, working within the rules of the
// current game and remembering any card flips that were required. All moves
// can be undone or redone any number of times. The validity of each Move is
// checked just once, during the Tap or DragAndDrop callback that accepted,
// created and stored the Move.

// There is also a special Move to turn over the whole Stock or Waste Pile and
// another to record a Redeal in a Grandfather Game.

class CardMoves {
  CardMoves(this._cards, this._piles, this._tableaus, this._stockPileIndex);

  final List<CardView> _cards;
  final List<Pile> _piles;
  final _stockPileIndex; // -1 means "no Stock Pile": not all Games have one.
  final List<Pile> _tableaus;

  var _redoIndex = 0;
  final List<CardMove> _playerMoves = [];

  void storeMove({
    // Needs to be called every time a new Move is made by the player, whether
    // the Move is animated or not. Animation mostly follows storeMove() in real
    // time, but moving cards cannot be moved again if they are "in flight".
    required Pile from,
    required Pile to,
    required int nCards,
    required Extra extra,
    int leadCard = 0,
    int strength = 0,
  }) {
    // print('MOVE LIST before storeMove() index $_redoIndex:'); printMoves();
    if (_redoIndex < _playerMoves.length) {
      // Remove range from redoIndex to end.
      _playerMoves.removeRange(_redoIndex, _playerMoves.length);
      // print('MOVE LIST after PRUNING, index $_redoIndex:'); printMoves();
    }
    assert(nCards > 0, 'storeMove(): BAD VALUE OF nCards = $nCards.');
    CardMove move = (
      fromPile: from.pileIndex,
      toPile: to.pileIndex,
      nCards: nCards,
      extra: extra,
      leadCard: leadCard,
      strength: strength,
    );
    _playerMoves.add(move);
    _redoIndex = _playerMoves.length;
    print('MOVE LIST after storeMove() index $_redoIndex:'); printMoves();
    print ('Stored Move: ${move.fromPile} ${move.toPile} n${move.nCards} '
          '${_cards[move.leadCard]} e${move.extra.index}');
    print('Move: ${from.pileIndex} ${from.pileType} to ${to.pileIndex} '
        '${to.pileType} $nCards cards ${_cards[leadCard]} $extra');
  }

  UndoRedoResult undoMove() {
    if (_redoIndex < 1) {
      return UndoRedoResult.atStart;
    }
    // print('MOVE LIST before undoMove() index $_redoIndex:'); printMoves();
    return moveBack(_playerMoves[--_redoIndex]);
    // print('MOVE LIST after undoMove() index $_redoIndex:'); printMoves();
  }

  UndoRedoResult redoMove() {
    // Same as makeMove(), except storeMove() clears the tail of the redo List.
    if (_redoIndex >= _playerMoves.length) {
      return UndoRedoResult.atEnd;
    }
    // print('MOVE LIST before redoMove() index $_redoIndex:'); printMoves();
    return makeMove(_playerMoves[_redoIndex++]);
    // print('MOVE LIST after redoMove() index $_redoIndex:'); printMoves();
  }

  UndoRedoResult makeMove(CardMove move) {
    // This is a "redo" of a stored Move. The original Move was validated and
    // executed after a Tap or Drag fron the player, then stored. We just "go
    // through the motions" this time around.
    print('Redo Index $_redoIndex $move');
    assert((_redoIndex >= 0) && (_redoIndex <= _playerMoves.length));
    Pile from = _piles[move.fromPile];
    Pile to = _piles[move.toPile];
    print(
        '\n\n\n\nREDO: ${move.fromPile} ${from.pileType} to ${move.toPile} '
       '${to.pileType} redo $_redoIndex list ${_playerMoves.length} '
       '${move.nCards})');

    // SPECIAL CASE: Turn Waste Pile over, back onto Stock (tap on empty Stock).
    if ((from.pileType == PileType.waste) && (to.pileType == PileType.stock)) {
      from.turnPileOver(to); // Do/redo turn over of Waste Pile to Stock.
      return UndoRedoResult.done;
    }
    switch (move.extra) {
      case Extra.none:
        // Normal Tap or Drag move from one pile to another, with no flips.
        to.dropCards(from.grabCards(move.nCards));
      case Extra.fromCardUp:
        // Normal Tap or Drag from one pile to another, but "from" pile flips
        // its next card to face-up (e.g. move card(s) from Klondike Tableau).
        to.dropCards(from.grabCards(move.nCards));
        from.setTopFaceUp(true);
      case Extra.toCardUp:
        // Normal Tap or Drag from one pile to another, but "to" pile flips
        // its new card to face-up (e.g. move card from Stock to Waste).
        to.dropCards(from.grabCards(move.nCards));
        to.setTopFaceUp(true);
      case Extra.stockToTableaus:
        // One card from Stock to each Tableau, OR until nCards is exhausted.
        var n = 0;
        final nMax = move.nCards;
        assert (from.nCards >= nMax);
        print('Tableau Indices: $_tableaus');
        from.dump();
        for (final pile in _tableaus) {
          pile.dropCards(from.grabCards(1));
          pile.setTopFaceUp(true);
          if (++n >= nMax) break;
        }
        from.dump();
      case Extra.replaceExcluded:
        // From Tableau to Excluded, PLUS from Stock to Tableau (replacement).
        to.dropCards(from.grabCards(1));
        assert(_stockPileIndex >= 0);
        Pile stock = _piles[_stockPileIndex];
        assert (stock.nCards >= 1);
        from.dropCards(stock.grabCards(1));
        from.setTopFaceUp(true);
      case Extra.redeal:
        // Redo Grandfather Redeal: set the Tableaus to their post-redeal state.
        switchTableauStates(move.nCards);
        return UndoRedoResult.redidRedeal;
    }
    return UndoRedoResult.done;
  }

  UndoRedoResult moveBack(CardMove move) {
    // This the reverse (or "undo") of a previously stored Move. For comments
    // on the switch() cases, see makeMove() above.
    Pile from = _piles[move.fromPile];
    Pile to = _piles[move.toPile];
    print('\n\n\n\nUNDO: ${move.fromPile} ${from.pileType} to ${move.toPile} '
        '${to.pileType} undo $_redoIndex list ${_playerMoves.length} '
        'nCards ${move.nCards}');

    if ((from.pileType == PileType.waste) && (to.pileType == PileType.stock)) {
      to.turnPileOver(from); // Undo (return cards to Waste Pile from Stock).
      return UndoRedoResult.done;
    }
    switch (move.extra) {
      case Extra.none:
        from.dropCards(to.grabCards(move.nCards));
      case Extra.fromCardUp:
        from.setTopFaceUp(false);
        from.dropCards(to.grabCards(move.nCards));
      case Extra.toCardUp:
        to.setTopFaceUp(false);
        from.dropCards(to.grabCards(move.nCards));
      case Extra.stockToTableaus:
        final nMax = move.nCards;
        for (int n = nMax - 1; n >= 0; n--) {
          // A card is removed from each of the first nMax Tableaus
          // (in reverse order) and returned to the Stock Pile.
          final pile = _tableaus[n];
          assert (pile.nCards >= 1);
          pile.setTopFaceUp(false);
          from.dropCards(pile.grabCards(1));
        }
      case Extra.replaceExcluded:
        assert(_stockPileIndex >= 0);
        Pile stock = _piles[_stockPileIndex];
        from.setTopFaceUp(false);
        stock.dropCards(from.grabCards(1));
        from.dropCards(to.grabCards(1));
      case Extra.redeal:
        // Undo Grandfather Redeal: set the Tableaus to how they were before.
        switchTableauStates(move.nCards);
        return UndoRedoResult.undidRedeal;
    }
    return UndoRedoResult.done;
  }

  List<CardMove> getPossibleMoves() {
    // TODO - Implement getPossibleMoves().
    List<CardMove> possibleMoves = [];
    return possibleMoves;
  }

  void switchTableauStates(int redealNumber) {
    List<List<int>> tableauStates = [];
    _tableaus[1].dump();
    for (final tableau in _tableaus) {
      tableauStates.add(tableau.restoreState(redealNumber));
    }
    _tableaus[1].dump();
    int n = 0;
    for (final tableau in _tableaus) {
      tableau.showPileState(tableauStates[n]);
      n++;
    }
    _tableaus[1].dump();
    tableauStates.clear();
  }

  void dump() {
    print('DUMP ${_playerMoves.length} MOVES: redo index $_redoIndex');
  }

  void printMoves() {
    List<String> moves = [];
    for (CardMove move in _playerMoves) {
      moves.add('${move.fromPile} ${move.toPile} n${move.nCards} '
          '${_cards[move.leadCard]} e${move.extra.index}');
    }
    print(moves);
  }
}

/*
import 'dart:typed_data';

  // EXPERIMENTAL CODE - Might need to use ByteData in proposed Solver.

  final ByteData _b = ByteData(100);

    print('START 1,000,000,000 ${DateTime.now().toString()}');
    for (int k = 0; k < 1000000000; k++) {
    for (int n = 1; n <= 100; n++) {
      _b.setUint8(n - 1, n);
    }
    }
    print('DONE ${DateTime.now().toString()}');
    // One billion repeats of the inner loop of 100 took 1 min 25 sec.
    // Happily accepts ByteData size of 1 to 4 billion bytes.
    // Has Range Checking on setUint8() and presumably getUint8().
    print('Element length _b ${_b.elementSizeInBytes} ByteData length ${_b.lengthInBytes}');
    print('_b ByteBuffer size ${_b.buffer.lengthInBytes}');
    print('_b[41] ${_b.getUint8(41)}');
    // _b.setUint8(100, 3); // Dart throws a RangeError...
*/
