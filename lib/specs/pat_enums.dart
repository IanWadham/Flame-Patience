enum PatGameID {
  klondikeDraw1,
  klondikeDraw3,
  fortyAndEight,
  mod3,
  noSuchGame,
}

enum PileType {
  stock,
  waste,
  tableau,
  foundation,
  excludedCards,
}

enum MoveResult {
  valid,
  pileEmpty,
  notValid,
}

enum DealSequence {
  notUsed,
  pilesInTurn,
  wholePileAtOnce,
}

enum DragRule {
  dragNotAllowed,
  fromTop,
  fromAnywhere,
  fromAnywhereViaEmptySpace,
}

enum PutRule {
  putNotAllowed,
  ascendingSameSuitBy1,
  ascendingSameSuitBy3,
  descendingSameSuitBy1,
  descendingAlternateColorsBy1,
  sameRank,
}

enum TapRule {
  tapNotAllowed,
  turnOver1,
  turnOver3,
  goOut,
}

enum TapEmptyRule {
  tapNotAllowed,
  turnOverWasteOnce,
  turnOverWasteUnlimited,
}

enum DealFaceRule {
  notUsed,
  faceDown,
  faceUp,
  lastFaceUp,
}

enum Extra {
  // Actions that might follow card-moves from pile to pile. Having this
  // enum allows multiple Moves to be treated as one in undo/redo and will
  // also simplify the proposed Solver's task.

  none, // The Move is a simple transfer of cards from one pile to another.
  fromCardUp, // The last card of the "from" pile turns Face Up at the finish.
  toCardUp, // The card turns Face Up as it arrives (e.g. Stock-to-Waste).
  stockToTableaus, // Cards are moved successively from Stock to Tableau Piles.
  replaceExcluded, // An excluded card leaving a Tableau is replaced from Stock.
}
