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
}

enum MoveMethod {
  drag,
  tap,
  deal,
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
}

enum PutRule {
  putNotAllowed,
  ascendingSameSuitBy1,
  ascendingSameSuitBy3,
  descendingSameSuitBy1,
  descendingAlternateColorsBy1
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

typedef GameSpec = ({
  PatGameID gameID,
  String gameName,
  int nPacks,
  int nCellsWide,
  int nCellsHigh,
  bool hasStockPile,
  bool hasWastePile,
  int dealerRow,
  int dealerCol,
  DealSequence dealSequence,
  List<GamePileSpec> gamePilesSpec,
});

typedef GamePileSpec = ({
  PileSpec pileSpec,
  int nPilesSpec,
  List<PileTrio> pileTrios,
});

typedef PileTrio = (int row, int col, int nDeal);

typedef PileSpec = ({
  PileType pileType,
  String pileName,
  bool hasBaseCard,
  DragRule dragRule,
  TapRule tapRule,
  TapEmptyRule tapEmptyRule,
  PutRule putRule,
  int putFirst,
  DealFaceRule dealFaceRule,
  FanOut faceDownFanOut,
  FanOut faceUpFanOut,
});

typedef FanOut = (double horizontal, double vertical);

class PatData {
  static const List<GameSpec> gameList = [
    (
      gameID: PatGameID.klondikeDraw1,
      gameName: 'Klondike - Draw 1',
      nPacks: 1,
      nCellsWide: 7,
      nCellsHigh: 4,
      hasStockPile: true,
      hasWastePile: true,
      dealerRow: 3,
      dealerCol: 0,
      dealSequence: DealSequence.wholePileAtOnce,
      gamePilesSpec: [
        (
          pileSpec: standardStock,
          nPilesSpec: 1,
          pileTrios: [
            (0, 0, 24),
          ]
        ),
        (
          pileSpec: standardWaste,
          nPilesSpec: 1,
          pileTrios: [
            (0, 1, 0),
          ]
        ),
        (
          pileSpec: standardFoundation,
          nPilesSpec: 4,
          pileTrios: [
            (0, 3, 0),
            (0, 4, 0),
            (0, 5, 0),
            (0, 6, 0),
          ]
        ),
        (
          pileSpec: klondikeTableau,
          nPilesSpec: 7,
          pileTrios: [
            (1, 0, 1),
            (1, 1, 2),
            (1, 2, 3),
            (1, 3, 4),
            (1, 4, 5),
            (1, 5, 6),
            (1, 6, 7),
          ]
        ),
      ],
    ),
    (
      gameID: PatGameID.fortyAndEight,
      gameName: 'Forty & Eight',
      nPacks: 2,
      nCellsWide: 8,
      nCellsHigh: 5,
      hasStockPile: true,
      hasWastePile: true,
      dealerRow: 3,
      dealerCol: 0,
      dealSequence: DealSequence.wholePileAtOnce,
      gamePilesSpec: [
        (
          pileSpec: fortyAndEightStock,
          nPilesSpec: 1,
          pileTrios: [
            (4, 7, 72),
          ]
        ),
        (
          pileSpec: fortyAndEightWaste,
          nPilesSpec: 1,
          pileTrios: [
            (4, 6, 0),
          ]
        ),
        (
          pileSpec: standardFoundation,
          nPilesSpec: 8,
          pileTrios: [
            (0, 0, 0),
            (0, 1, 0),
            (0, 2, 0),
            (0, 3, 0),
            (0, 4, 0),
            (0, 5, 0),
            (0, 6, 0),
            (0, 7, 0),
          ]
        ),
        (
          pileSpec: fortyAndEightTableau,
          nPilesSpec: 8,
          pileTrios: [
            (1, 0, 4),
            (1, 1, 4),
            (1, 2, 4),
            (1, 3, 4),
            (1, 4, 4),
            (1, 5, 4),
            (1, 6, 4),
            (1, 7, 4),
          ]
        ),
      ],
    ),
  ]; // End List<GameSpec> gameList

  static const PileSpec standardStock = (
    pileType: PileType.stock,
    pileName: 'standardStock',
    hasBaseCard: true,
    dragRule: DragRule.dragNotAllowed,
    tapRule: TapRule.turnOver1,
    tapEmptyRule: TapEmptyRule.turnOverWasteUnlimited,
    putRule: PutRule.putNotAllowed,
    putFirst: 0,
    dealFaceRule: DealFaceRule.faceDown,
    faceDownFanOut: (0.0, 0.0),
    faceUpFanOut: (0.0, 0.0),
  );

  static const PileSpec fortyAndEightStock = (
    pileType: PileType.stock,
    pileName: 'fortyAndEightStock',
    hasBaseCard: true,
    dragRule: DragRule.dragNotAllowed,
    tapRule: TapRule.turnOver1,
    tapEmptyRule: TapEmptyRule.turnOverWasteOnce,
    putRule: PutRule.putNotAllowed,
    putFirst: 0,
    dealFaceRule: DealFaceRule.faceDown,
    faceDownFanOut: (0.0, 0.0),
    faceUpFanOut: (0.0, 0.0),
  );

  static const PileSpec standardWaste = (
    pileType: PileType.waste,
    pileName: 'standardWaste',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    putRule: PutRule.putNotAllowed,
    putFirst: 0,
    dealFaceRule: DealFaceRule.faceUp,
    faceDownFanOut: (0.0, 0.0),
    faceUpFanOut: (0.0, 0.0),
  );

  static const PileSpec fortyAndEightWaste = (
    pileType: PileType.waste,
    pileName: 'fortyAndEightWaste',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    putRule: PutRule.putNotAllowed,
    putFirst: 0,
    dealFaceRule: DealFaceRule.faceUp,
    faceDownFanOut: (0.0, 0.0),
    faceUpFanOut: (-0.125, 0.0),
  );

  static const PileSpec klondikeTableau = (
    pileType: PileType.tableau,
    pileName: 'klondikeTableau',
    hasBaseCard: false,
    dragRule: DragRule.fromAnywhere,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    putRule: PutRule.descendingAlternateColorsBy1,
    putFirst: 13, // King.
    dealFaceRule: DealFaceRule.lastFaceUp,
    faceDownFanOut: (0.0, 0.075),
    faceUpFanOut: (0.0, 0.25),
  );

  static const PileSpec fortyAndEightTableau = (
    pileType: PileType.tableau,
    pileName: 'fortyAndEightTableau',
    hasBaseCard: false,
    dragRule: DragRule.fromAnywhere,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    putRule: PutRule.descendingSameSuitBy1,
    putFirst: 0, // Any card.
    dealFaceRule: DealFaceRule.faceUp,
    faceDownFanOut: (0.0, 0.0),
    faceUpFanOut: (0.0, 0.25),
  );

  static const PileSpec standardFoundation = (
    pileType: PileType.foundation,
    pileName: 'standardFoundation',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.tapNotAllowed,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    putRule: PutRule.ascendingSameSuitBy1,
    putFirst: 1, // Ace.
    dealFaceRule: DealFaceRule.faceDown,
    faceDownFanOut: (0.0, 0.0),
    faceUpFanOut: (0.0, 0.0),
  );
}

void printGameSpec(GameSpec game) {
  String gameSpec = ('\nGame Data:\n'
      '  Game ID     ${game.gameID}\n'
      '  Game Name   ${game.gameName}\n'
      '  N Packs     ${game.nPacks}\n'
      '  Deal Seq    ${game.dealSequence}\n'
      '  Cells High  ${game.nCellsHigh}\n'
      '  Cells Wide  ${game.nCellsWide}\n'
      '  List of Piles:\n');
  for (GamePileSpec pile in game.gamePilesSpec) {
    gameSpec += ('    ${pile.nPilesSpec} ${pile.pileSpec.pileType} '
        '"${pile.pileSpec.pileName}"\n');
    String s = '     ';
    for (int trio = 0; trio < pile.nPilesSpec; trio++) {
      if (trio > 0 && trio % 4 == 0) s += '\n     '; // Insert line-break.
      s += ' ${pile.pileTrios[trio]}';
    }
    gameSpec += '$s\n';
  }
  print(gameSpec);
}
