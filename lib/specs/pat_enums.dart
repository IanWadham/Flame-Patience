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
