import '../components/pile.dart';
import '../specs/pat_enums.dart';

enum Flips {
  noChange,
  fromUp,
  toUp, /* bothUp, */
}

typedef CardViewMove = ({
  int fromPile, // Starting Pile.
  int toPile, // Finishing Pile.
  int nCards, // Number of Card(s) to move.
  Flips flips, // 0 no changes, 1 from -> up, 2 to -> up, 3 both -> up.
  String lead, // DEBUG: Name of first card.
});

typedef CardMove = ({
  int fromPile, // Index of starting Pile.
  int leadCard, // Index of first card. Card(s) to move: [leadCard] - [length - 1].
  int toPile, // Index of finishing Pile.
  Flips flips, // 0 no changes, 1 from -> up, 2 to -> up, 3 both -> up.
  int strength, // Estimated strength of move (used only in solver).
});

class CardMoves {
  final List<Pile> _piles = [];

  var _redoIndex = 0;
  final List<CardViewMove> _playerMoves = [];

  void init(List<Pile> piles) {
    _piles.addAll(piles);
  }

  void storeMove({
    required Pile from,
    required Pile to,
    required int nCards,
    required Flips flips,
    String lead = '',
  }) {
    if (_redoIndex < _playerMoves.length) {
      // Remove range from redoIndex to end.
      _playerMoves.removeRange(_redoIndex, _playerMoves.length);
    }
    CardViewMove move = (
      fromPile: from.pileIndex,
      toPile: to.pileIndex,
      nCards: nCards,
      lead: lead,
      flips: flips
    );
    _playerMoves.add(move);
    _redoIndex = _playerMoves.length;
    print('Move: ${from.pileIndex} ${from.pileType} to ${to.pileIndex} '
        '${to.pileType} $nCards cards $lead flip ${flips.index}');
  }

  void makeMove(CardViewMove move) {
    CardViewMove move = _playerMoves.last;
    Pile from = _piles[move.fromPile];
    Pile to = _piles[move.toPile];
    print(
        'Redo: ${move.fromPile} ${from.pileType} to ${move.toPile} ${to.pileType} '
        'redo $_redoIndex list ${_playerMoves.length}');
    if ((from.pileType == PileType.waste) && (to.pileType == PileType.stock)) {
      from.turnPileOver(to);
      return;
    }
    to.dropCards(from.grabCards(move.nCards));
    switch (move.flips) {
      case Flips.fromUp:
        from.setTopFaceUp(true);
      case Flips.toUp:
        to.setTopFaceUp(true);
      case Flips.noChange:
        break;
    }
  }

  void moveBack(CardViewMove move) {
    Pile from = _piles[move.fromPile];
    Pile to = _piles[move.toPile];
    print(
        'Back: ${move.fromPile} ${from.pileType} to ${move.toPile} ${to.pileType} '
        'redo $_redoIndex list ${_playerMoves.length}');
    if ((from.pileType == PileType.waste) && (to.pileType == PileType.stock)) {
      to.turnPileOver(from);
      return;
    }
    switch (move.flips) {
      case Flips.fromUp:
        from.setTopFaceUp(false);
      case Flips.toUp:
        to.setTopFaceUp(false);
      case Flips.noChange:
        break;
    }
    from.dropCards(to.grabCards(move.nCards));
  }

  void undoMove() {
    if (_redoIndex < 1) {
      return;
    }
    moveBack(_playerMoves[--_redoIndex]);
  }

  void redoMove() {
    // Same as makeMove(), except that storeMove() clears the tail of the redo List.
    if (_redoIndex >= _playerMoves.length) {
      return;
    }
    makeMove(_playerMoves[_redoIndex++]);
  }

  List<CardMove> getPossibleMoves() {
    List<CardMove> possibleMoves = [];
    return possibleMoves;
  }
}
