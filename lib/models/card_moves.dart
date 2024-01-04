// import 'package:flame/components.dart';

import '../pat_world.dart';
import '../components/pile.dart';

typedef CardViewMove = ({
  Pile fromPile, // Starting Pile.
  Pile toPile,   // Finishing Pile.
  int  nCards,   // Number of Card(s) to move.
});

typedef CardMove = ({
  int fromPile, // Index of starting Pile.
  int leadCard, // Index of first card. Card(s) to move: [leadCard] - [length - 1].
  int toPile, // Index of finishing Pile.
  int strength, // Estimated strength of move (used only in solver).
});

class CardMoves {

  late List<Pile> _piles;
  var _noPiles = true;

  var _redoIndex = 0;
  final List<CardViewMove> _playerMoves = [];

  void init(List<Pile> piles) {
    _piles = piles;
    _noPiles = false;
  }

  void storeMove(
      {required Pile from,
      required Pile to,
      required int nCards}) {
      // ??????? required int lead,
      // ??????? int strength = 0}) {
    if (_noPiles) return;
    if (_redoIndex < _playerMoves.length) {
      // Remove range from redoIndex to end.
    }
    CardViewMove move = (fromPile: from, toPile: to, nCards: nCards);
    _playerMoves.add(move);
    _redoIndex = _playerMoves.length;
    int m = _piles.indexOf(from); int n = _piles.indexOf(to);
    print('Add Player Move: from $m ${from.pileType} to $n ${to.pileType} $nCards cards'); 
  }

  void makeMove(CardViewMove move) {
    CardViewMove move = _playerMoves.last;
    Pile from = move.fromPile;
    Pile to = move.toPile;
    int nCards = move.nCards;
    to.dropCards(from.grabCards(nCards));

    // ??????? int index = from.length - nCards;
    // ??????? for (int k = 0; k < nCards; k++) {
      // ??????? to.add(from[index]);
      // ??????? from.removeAt[index];
    // ??????? }
  }

  void moveBack(CardViewMove move) {
    CardViewMove move = _playerMoves.last;
    Pile from = move.fromPile;
    Pile to = move.toPile;
    int nCards = move.nCards;
    from.dropCards(to.grabCards(nCards));

    // ??????? int index = to.length - nCards;
    // ??????? for (int k = 0; k < nCards; k++) {
      // ??????? from.add(to[index]);
      // ??????? to.removeAt[index];
    // ??????? }
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
