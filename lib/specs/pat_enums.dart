enum PatGameID {
  klondikeDraw1,
  klondikeDraw3,
  fortyAndEight,
  mod3,
  simpleSimon,
  yukon,
  freecell,
  gypsy,
  grandfather,
  noSuchGame,
}

enum PileType {
  stock,
  waste,
  tableau,
  foundation,
  excludedCards,
  freecell,
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

enum MultiCardsRule {
  multiCardsNotAllowed,
  inAnyOrder,
  descendingSameSuitBy1,
  descendingAlternateColorsBy1,
}

enum PutRule {
  putNotAllowed,
  ascendingSameSuitBy1,
  ascendingSameSuitBy3,
  descendingSameSuitBy1,
  descendingAlternateColorsBy1,
  descendingAnySuitBy1,
  sameRank,
  wholeSuit,
  ifEmptyAnyCard,
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
  last2FaceUp,
  last5FaceUp,
}

enum Extra {
  // Actions that might happen after card-moves from pile to pile. Having
  // this enum allows multiple Moves to be treated as one in undo/redo and
  // will also simplify the proposed Solver's task.

  none, // The Move is a simple transfer of cards from one pile to another.
  fromCardUp, // The last card of the "from" pile turns Face Up at the finish.
  toCardUp, // The card turns Face Up as it arrives (e.g. Stock-to-Waste).
  stockToTableaus, // Cards are moved successively from Stock to Tableau Piles.
  autoDealTableau, // The last card to leave a Tableau is replaced from Stock.
  redeal, // Redeal Move in Grandfather Game.
}

enum UndoRedoResult {
  done, // Undo/Redo succeeded.
  atStart, // There are no more Moves to Undo.
  atEnd, // There are no more Moves to Redo.
  cantUndo, // There is no code to Undo this Move.
  cantRedo, // There is no code to Redo this Move.
  undidRedeal, // CardMoves undid a Grandfather Redeal.
  redidRedeal, // CardMoves redid a Grandfather Redeal.
}
