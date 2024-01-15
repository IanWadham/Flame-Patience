import 'pat_enums.dart';

// These typedefs give one-word names to definitions of Dart Record types. In
// each case, the actual `type` is everything that lies between `(` and `)`.
// Record type definitions resemble parameter definitions in a function,
// including the availability of named and positional fields, using `{}` to
// demarcate named fields. All the records defined in these typedefs use
// named fields exclusively, except for PileTrio which has positional fields.
//
// NOTE: When defining a Game, all the fields in all the Records MUST be given
//       values, regardless of whether the fields are named or positional. If
//       any is missing or misnamed, there will be compilation failures. Also,
//       field values based on `enums` must be drawn from those provided in
//       the `specs/pat_enums.dart` file.
//
//       All this implies that, when you add data for a Game, much of it is
//       automatically validated at compile-time. Some additional validation
//       is done at run_time, using `throw` statements, but the rest of the
//       testing and debugging of the new game is up to you.

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
  double fanOutX,
  double fanOutY,
});

class PatData {
  static const List<GameSpec> gameList = [
    ( // GameSpec
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
        ( // GamePileSpec
          pileSpec: standardStock,
          nPilesSpec: 1,
          pileTrios: [
            (0, 0, 24),
          ]
        ),
        ( // GamePileSpec
          pileSpec: standardWaste,
          nPilesSpec: 1,
          pileTrios: [
            (0, 1, 0),
          ]
        ),
        ( // GamePileSpec
          pileSpec: standardFoundation,
          nPilesSpec: 4,
          pileTrios: [
            (0, 3, 0),
            (0, 4, 0),
            (0, 5, 0),
            (0, 6, 0),
          ]
        ),
        ( // GamePileSpec
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
    ( // GameSpec
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
        ( // GamePileSpec
          pileSpec: fortyAndEightStock,
          nPilesSpec: 1,
          pileTrios: [
            (4, 7, 72),
          ]
        ),
        ( // GamePileSpec
          pileSpec: fortyAndEightWaste,
          nPilesSpec: 1,
          pileTrios: [
            (4, 6, 0),
          ]
        ),
        ( // GamePileSpec
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
        ( // GamePileSpec
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
    ( // GameSpec
      gameID: PatGameID.mod3,
      gameName: 'Mod 3',
      nPacks: 2,
      nCellsWide: 9,
      nCellsHigh: 5,
      hasStockPile: true,
      hasWastePile: false,
      dealerRow: 2,
      dealerCol: 9,
      dealSequence: DealSequence.wholePileAtOnce,
      gamePilesSpec: [
        ( // GamePileSpec
          pileSpec: standardStock,
          nPilesSpec: 1,
          pileTrios: [
            (3, 8, 74),
          ]
        ),
        // ( // GamePileSpec
          // pileSpec: standardWaste,
          // nPilesSpec: 1,
          // pileTrios: [
            // (0, 1, 0),
          // ]
        // ),
        ( // GamePileSpec
          pileSpec: mod3Foundation2J,
          nPilesSpec: 8,
          pileTrios: [
            (0, 0, 1),
            (0, 1, 1),
            (0, 2, 1),
            (0, 3, 1),
            (0, 4, 1),
            (0, 5, 1),
            (0, 6, 1),
            (0, 7, 1),
          ]
        ),
        ( // GamePileSpec
          pileSpec: mod3Foundation3Q,
          nPilesSpec: 8,
          pileTrios: [
            (1, 0, 1),
            (1, 1, 1),
            (1, 2, 1),
            (1, 3, 1),
            (1, 4, 1),
            (1, 5, 1),
            (1, 6, 1),
            (1, 7, 1),
          ]
        ),
        ( // GamePileSpec
          pileSpec: mod3Foundation4K,
          nPilesSpec: 8,
          pileTrios: [
            (2, 0, 1),
            (2, 1, 1),
            (2, 2, 1),
            (2, 3, 1),
            (2, 4, 1),
            (2, 5, 1),
            (2, 6, 1),
            (2, 7, 1),
          ]
        ),
        ( // GamePileSpec
          pileSpec: mod3Tableau,
          nPilesSpec: 8,
          pileTrios: [
            (3, 0, 1),
            (3, 1, 1),
            (3, 2, 1),
            (3, 3, 1),
            (3, 4, 1),
            (3, 5, 1),
            (3, 6, 1),
            (3, 7, 1),
          ]
        ),
      ],
    ),
  ]; // End List<GameSpec> gameList

  // Ready-made configurations of Piles, as used in the above games.

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
    fanOutX: 0.0,
    fanOutY: 0.0,
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
    fanOutX: 0.0,
    fanOutY: 0.0,
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
    fanOutX: 0.0,
    fanOutY: 0.0,
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
    fanOutX: -0.18,
    fanOutY: 0.0,
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
    fanOutX: 0.0,
    fanOutY: 0.25,
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
    fanOutX: 0.0,
    fanOutY: 0.25,
  );

  static const PileSpec mod3Tableau = (
    pileType: PileType.tableau,
    pileName: 'mod3Tableau',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    putRule: PutRule.putNotAllowed,
    putFirst: 0, // Any card.
    dealFaceRule: DealFaceRule.faceUp,
    fanOutX: 0.0,
    fanOutY: 0.1,
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
    fanOutX: 0.0,
    fanOutY: 0.0,
  );

  static const PileSpec mod3Foundation2J = (
    pileType: PileType.foundation,
    pileName: 'mod3Foundation',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    putRule: PutRule.ascendingSameSuitBy3,
    putFirst: 2, // Two.
    dealFaceRule: DealFaceRule.faceUp,
    fanOutX: 0.0,
    fanOutY: 0.05,
  );

  static const PileSpec mod3Foundation3Q = (
    pileType: PileType.foundation,
    pileName: 'mod3Foundation',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    putRule: PutRule.ascendingSameSuitBy3,
    putFirst: 3, // Three.
    dealFaceRule: DealFaceRule.faceUp,
    fanOutX: 0.0,
    fanOutY: 0.05,
  );

  static const PileSpec mod3Foundation4K = (
    pileType: PileType.foundation,
    pileName: 'mod3Foundation',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    putRule: PutRule.ascendingSameSuitBy3,
    putFirst: 4, // Four.
    dealFaceRule: DealFaceRule.faceUp,
    fanOutX: 0.0,
    fanOutY: 0.05,
  );

  static const PileSpec unusedPile = (
    // Initialization possibility for games that have unused PileTypes.
    pileType: PileType.notUsed,
    pileName: 'unusedPile',
    hasBaseCard: false,
    dragRule: DragRule.dragNotAllowed,
    tapRule: TapRule.tapNotAllowed,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    putRule: PutRule.putNotAllowed,
    putFirst: 0,
    dealFaceRule: DealFaceRule.notUsed,
    fanOutX: 0.0,
    fanOutY: 0.0,
  );
}

/*
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
*/
