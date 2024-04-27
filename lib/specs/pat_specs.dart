import 'pat_enums.dart';
import 'rule_book.dart';

// These typedefs give names to definitions of Dart Record types. In each case,
// the actual `type` is `(`, `)` and everything that lies between the parentheses.
//
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
//       testing and debugging of the new game's data is up to you.

typedef GameSpec = ({
  PatGameID gameID,
  String gameName,
  int nPacks,
  int nCellsWide,
  int nCellsHigh,
  double cardPadX,
  double cardPadY,
  bool hasStockPile,
  bool hasWastePile,
  int excludedRank,
  bool redealEmptyTableau,
  DealSequence dealSequence,
  List<GamePileSpec> gamePilesSpec,
  List<String> gameRules,
  List<String> gameTips,
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
  MultiCardsRule multiCardsRule,
  PutRule putRule,
  int putFirst,
  DealFaceRule dealFaceRule,
  double fanOutX,
  double fanOutY,
  int growthCols, // Usually 0, can be +ve for fan out R or -ve for fan out L.
  int growthRows, // Usually 0, can be +ve for fan out Down, -ve unlikely.
});

class PatData {
  static const List<GameSpec> gameList = [
    ( // GameSpec
      gameID: PatGameID.klondikeDraw1,
      gameName: 'Klondike - Draw 1',
      nPacks: 1,
      nCellsWide: 7,
      nCellsHigh: 4,
      cardPadX: 200,
      cardPadY: 200, // 100,
      hasStockPile: true,
      hasWastePile: true,
      dealSequence: DealSequence.wholePileAtOnce,
      excludedRank: 0, // Deal ALL cards.
      redealEmptyTableau: false,
      gameRules: RuleBook.klondikeDraw1Rules,
      gameTips: RuleBook.klondikeDraw1Tips,
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
      cardPadX: 200,
      cardPadY: 100,
      hasStockPile: true,
      hasWastePile: true,
      dealSequence: DealSequence.wholePileAtOnce,
      excludedRank: 0, // Deal ALL cards.
      redealEmptyTableau: false,
      gameRules: RuleBook.fortyAndEightRules,
      gameTips: RuleBook.fortyAndEightTips,
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
      cardPadX: 200, // 100,
      cardPadY: 200,
      hasStockPile: true,
      hasWastePile: false,
      dealSequence: DealSequence.wholePileAtOnce,
      excludedRank: 1, // Exclude Aces.
      redealEmptyTableau: true,
      gameRules: RuleBook.mod3Rules,
      gameTips: RuleBook.mod3Tips,
      gamePilesSpec: [
        ( // GamePileSpec
          pileSpec: standardStock,
          nPilesSpec: 1,
          pileTrios: [
            (3, 8, 74),
          ]
        ),
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
        ( // GamePileSpec
          // Holds discarded Aces.
          pileSpec: mod3ExcludedCards,
          nPilesSpec: 1,
          pileTrios: [
            (1, 8, 0),
          ]
        ),
      ],
    ),
    ( // GameSpec
      gameID: PatGameID.simpleSimon,
      gameName: 'Simple Simon',
      nPacks: 1,
      nCellsWide: 10,
      nCellsHigh: 5,
      cardPadX: 100,
      cardPadY: 50,
      hasStockPile: false,
      hasWastePile: false,
      dealSequence: DealSequence.wholePileAtOnce,
      excludedRank: 0, // Deal ALL cards.
      redealEmptyTableau: false,
      gameRules: RuleBook.simpleSimonRules,
      gameTips: RuleBook.simpleSimonTips,
      gamePilesSpec: [
        ( // GamePileSpec
          pileSpec: simpleSimonFoundation,
          nPilesSpec: 4,
          pileTrios: [
            (0, 3, 0),
            (0, 4, 0),
            (0, 5, 0),
            (0, 6, 0),
          ]
        ),
        ( // GamePileSpec
          pileSpec: simpleSimonTableau,
          nPilesSpec: 10,
          pileTrios: [
            (1, 0, 8),
            (1, 1, 8),
            (1, 2, 8),
            (1, 3, 7),
            (1, 4, 6),
            (1, 5, 5),
            (1, 6, 4),
            (1, 7, 3),
            (1, 8, 2),
            (1, 9, 1),
          ]
        ),
      ],
    ),
    ( // GameSpec
      gameID: PatGameID.yukon,
      gameName: 'Yukon',
      nPacks: 1,
      nCellsWide: 8,
      nCellsHigh: 4,
      cardPadX: 200,
      cardPadY: 200, // 100,
      hasStockPile: false,
      hasWastePile: false,
      dealSequence: DealSequence.wholePileAtOnce,
      excludedRank: 0, // Deal ALL cards.
      redealEmptyTableau: false,
      gameRules: RuleBook.yukonRules,
      gameTips: RuleBook.yukonTips,
      gamePilesSpec: [
        ( // GamePileSpec
          pileSpec: standardFoundation,
          nPilesSpec: 4,
          pileTrios: [
            (0, 7, 0),
            (1, 7, 0),
            (2, 7, 0),
            (3, 7, 0),
          ]
        ),
        ( // GamePileSpec
          pileSpec: yukonTableau,
          nPilesSpec: 7,
          pileTrios: [
            (0, 0, 1),
            (0, 1, 6),
            (0, 2, 7),
            (0, 3, 8),
            (0, 4, 9),
            (0, 5, 10),
            (0, 6, 11),
          ]
        ),
      ],
    ),
    ( // GameSpec
      gameID: PatGameID.klondikeDraw3,
      gameName: 'Klondike - Draw 3',
      nPacks: 1,
      nCellsWide: 7,
      nCellsHigh: 4,
      cardPadX: 200,
      cardPadY: 200, // 100,
      hasStockPile: true,
      hasWastePile: true,
      dealSequence: DealSequence.wholePileAtOnce,
      excludedRank: 0, // Deal ALL cards.
      redealEmptyTableau: false,
      gameRules: RuleBook.klondikeDraw3Rules,
      gameTips: RuleBook.klondikeDraw3Tips,
      gamePilesSpec: [
        ( // GamePileSpec
          pileSpec: standardStock,
          nPilesSpec: 1,
          pileTrios: [
            (0, 0, 24),
          ]
        ),
        ( // GamePileSpec
          pileSpec: klondike3Waste,
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
      gameID: PatGameID.freecell,
      gameName: 'Freecell',
      nPacks: 1,
      nCellsWide: 8,
      nCellsHigh: 4,
      cardPadX: 200,
      cardPadY: 200, // 100,
      hasStockPile: false,
      hasWastePile: false,
      dealSequence: DealSequence.wholePileAtOnce,
      excludedRank: 0, // Deal ALL cards.
      redealEmptyTableau: false,
      gameRules: RuleBook.freecellRules,
      gameTips: RuleBook.freecellTips,
      gamePilesSpec: [
        ( // GamePileSpec
          pileSpec: freecell,
          nPilesSpec: 4,
          pileTrios: [
            (0, 0, 0),
            (0, 1, 0),
            (0, 2, 0),
            (0, 3, 0),
          ]
        ),
        ( // GamePileSpec
          pileSpec: standardFoundation,
          nPilesSpec: 4,
          pileTrios: [
            (0, 4, 0),
            (0, 5, 0),
            (0, 6, 0),
            (0, 7, 0),
          ]
        ),
        ( // GamePileSpec
          pileSpec: freecellTableau,
          nPilesSpec: 8,
          pileTrios: [
            (1, 0, 7),
            (1, 1, 7),
            (1, 2, 7),
            (1, 3, 7),
            (1, 4, 6),
            (1, 5, 6),
            (1, 6, 6),
            (1, 7, 6),
          ]
        ),
      ],
    ),
    ( // GameSpec
      gameID: PatGameID.gypsy,
      gameName: 'Gypsy',
      nPacks: 2,
      nCellsWide: 10,
      nCellsHigh: 5,
      cardPadX: 200,
      cardPadY: 100,
      hasStockPile: true,
      hasWastePile: false,
      dealSequence: DealSequence.wholePileAtOnce,
      excludedRank: 0, // Deal ALL cards.
      redealEmptyTableau: false,
      gameRules: RuleBook.gypsyRules,
      gameTips: RuleBook.gypsyTips,
      gamePilesSpec: [
        ( // GamePileSpec
          pileSpec: standardStock,
          nPilesSpec: 1,
          pileTrios: [
            (4, 9, 80),
          ]
        ),
        ( // GamePileSpec
          pileSpec: standardFoundation,
          nPilesSpec: 8,
          pileTrios: [
            (0, 8, 0),
            (1, 8, 0),
            (2, 8, 0),
            (3, 8, 0),
            (0, 9, 0),
            (1, 9, 0),
            (2, 9, 0),
            (3, 9, 0),
          ]
        ),
        ( // GamePileSpec
          pileSpec: gypsyTableau,
          nPilesSpec: 8,
          pileTrios: [
            (0, 0, 3),
            (0, 1, 3),
            (0, 2, 3),
            (0, 3, 3),
            (0, 4, 3),
            (0, 5, 3),
            (0, 6, 3),
            (0, 7, 3),
          ]
        ),
      ],
    ),
    ( // GameSpec
      gameID: PatGameID.grandfather,
      gameName: 'Grandfather',
      nPacks: 1,
      nCellsWide: 7,
      nCellsHigh: 4,
      cardPadX: 200,
      cardPadY: 200, // 100,
      hasStockPile: true,
      hasWastePile: false,
      dealSequence: DealSequence.wholePileAtOnce,
      excludedRank: 0, // Deal ALL cards.
      redealEmptyTableau: false,
      gameRules: RuleBook.grandfatherRules,
      gameTips: RuleBook.grandfatherTips,
      gamePilesSpec: [
        ( // GamePileSpec
          pileSpec: standardStock,
          nPilesSpec: 1,
          pileTrios: [
            (0, 0, 0),
          ]
        ),
        ( // GamePileSpec
          pileSpec: standardFoundation,
          nPilesSpec: 4,
          pileTrios: [
            (0, 2, 0),
            (0, 3, 0),
            (0, 4, 0),
            (0, 5, 0),
          ]
        ),
        ( // GamePileSpec
          pileSpec: grandfatherTableau,
          nPilesSpec: 7,
          pileTrios: [
            (1, 0, 1),
            (1, 1, 7),
            (1, 2, 9),
            (1, 3, 11),
            (1, 4, 10),
            (1, 5, 8),
            (1, 6, 6),
          ]
        ),
      ],
    ),
  ]; // End List<GameSpec> gameList

  // Specifications of Piles, as used in the above games.

  static const PileSpec standardStock = (
    pileType: PileType.stock,
    pileName: 'standardStock',
    hasBaseCard: true,
    dragRule: DragRule.dragNotAllowed,
    tapRule: TapRule.turnOver1,
    tapEmptyRule: TapEmptyRule.turnOverWasteUnlimited,
    multiCardsRule: MultiCardsRule.multiCardsNotAllowed,
    putRule: PutRule.putNotAllowed,
    putFirst: 0,
    dealFaceRule: DealFaceRule.faceDown,
    fanOutX: 0.0,
    fanOutY: 0.0,
    growthCols: 0,
    growthRows: 0,
  );

  static const PileSpec fortyAndEightStock = (
    pileType: PileType.stock,
    pileName: 'fortyAndEightStock',
    hasBaseCard: true,
    dragRule: DragRule.dragNotAllowed,
    tapRule: TapRule.turnOver1,
    tapEmptyRule: TapEmptyRule.turnOverWasteOnce,
    multiCardsRule: MultiCardsRule.multiCardsNotAllowed,
    putRule: PutRule.putNotAllowed,
    putFirst: 0,
    dealFaceRule: DealFaceRule.faceDown,
    fanOutX: 0.0,
    fanOutY: 0.0,
    growthCols: 0,
    growthRows: 0,
  );

  static const PileSpec standardWaste = (
    pileType: PileType.waste,
    pileName: 'standardWaste',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.multiCardsNotAllowed,
    putRule: PutRule.putNotAllowed,
    putFirst: 0,
    dealFaceRule: DealFaceRule.faceUp,
    fanOutX: 0.0,
    fanOutY: 0.0,
    growthCols: 0,
    growthRows: 0,
  );

  static const PileSpec fortyAndEightWaste = (
    pileType: PileType.waste,
    pileName: 'fortyAndEightWaste',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.multiCardsNotAllowed,
    putRule: PutRule.putNotAllowed,
    putFirst: 0,
    dealFaceRule: DealFaceRule.faceUp,
    fanOutX: -0.2,
    fanOutY: 0.0,
    growthCols: -6,
    growthRows: 0,
  );

  static const PileSpec klondike3Waste = (
    pileType: PileType.waste,
    pileName: 'klondike3Waste',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.multiCardsNotAllowed,
    putRule: PutRule.putNotAllowed,
    putFirst: 0,
    dealFaceRule: DealFaceRule.faceUp,
    fanOutX: 0.28,
    fanOutY: 0.0,
    growthCols: 1,
    growthRows: 0,
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
    multiCardsRule: MultiCardsRule.descendingAlternateColorsBy1,
    fanOutX: 0.0,
    fanOutY: 0.25,
    growthCols: 0,
    growthRows: 3,
  );

  static const PileSpec fortyAndEightTableau = (
    pileType: PileType.tableau,
    pileName: 'fortyAndEightTableau',
    hasBaseCard: false,
    dragRule: DragRule.fromAnywhereViaEmptySpace,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.descendingSameSuitBy1,
    putRule: PutRule.descendingSameSuitBy1,
    putFirst: 0, // Any card.
    dealFaceRule: DealFaceRule.faceUp,
    fanOutX: 0.0,
    fanOutY: 0.25,
    growthCols: 0,
    growthRows: 2,
  );

  static const PileSpec mod3Tableau = (
    pileType: PileType.tableau,
    pileName: 'mod3Tableau',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    putRule: PutRule.putNotAllowed,
    multiCardsRule: MultiCardsRule.multiCardsNotAllowed,
    putFirst: 0, // Any card.
    dealFaceRule: DealFaceRule.faceUp,
    fanOutX: 0.0,
    fanOutY: 0.18,
    growthCols: 0,
    growthRows: 1,
  );

  static const PileSpec simpleSimonTableau = (
    pileType: PileType.tableau,
    pileName: 'simpleSimonTableau',
    hasBaseCard: false,
    dragRule: DragRule.fromAnywhere,
    tapRule: TapRule.tapNotAllowed,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.descendingSameSuitBy1,
    putRule: PutRule.descendingAnySuitBy1,
    putFirst: 0, // Any card.
    dealFaceRule: DealFaceRule.faceUp,
    fanOutX: 0.0,
    fanOutY: 0.25,
    growthCols: 0,
    growthRows: 3,
  );

  static const PileSpec yukonTableau = (
    pileType: PileType.tableau,
    pileName: 'yukonTableau',
    hasBaseCard: false,
    dragRule: DragRule.fromAnywhere,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.inAnyOrder,
    putRule: PutRule.descendingAlternateColorsBy1,
    putFirst: 13, // King.
    dealFaceRule: DealFaceRule.last5FaceUp,
    fanOutX: 0.0,
    fanOutY: 0.25,
    growthCols: 0,
    growthRows: 3,
  );

  static const PileSpec freecellTableau = (
    pileType: PileType.tableau,
    pileName: 'freecellTableau',
    hasBaseCard: false,
    dragRule: DragRule.fromAnywhereViaEmptySpace,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.descendingAlternateColorsBy1,
    putRule: PutRule.descendingAlternateColorsBy1,
    putFirst: 0, // Any card.
    dealFaceRule: DealFaceRule.faceUp,
    fanOutX: 0.0,
    fanOutY: 0.25,
    growthCols: 0,
    growthRows: 2,
  );

  static const PileSpec gypsyTableau = (
    pileType: PileType.tableau,
    pileName: 'gypsyTableau',
    hasBaseCard: false,
    dragRule: DragRule.fromAnywhere,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.descendingAlternateColorsBy1,
    putRule: PutRule.descendingAlternateColorsBy1,
    putFirst: 0, // Any card.
    dealFaceRule: DealFaceRule.last2FaceUp,
    fanOutX: 0.0,
    fanOutY: 0.25,
    growthCols: 0,
    growthRows: 4,
  );

  static const PileSpec grandfatherTableau = (
    pileType: PileType.tableau,
    pileName: 'grandfatherTableau',
    hasBaseCard: false,
    dragRule: DragRule.fromAnywhere,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.inAnyOrder,
    putRule: PutRule.descendingSameSuitBy1,
    putFirst: 13, // King.
    dealFaceRule: DealFaceRule.notUsed, // Grandfather has its own special deal.
    fanOutX: 0.0,
    fanOutY: 0.25,
    growthCols: 0,
    growthRows: 3,
  );

  static const PileSpec standardFoundation = (
    pileType: PileType.foundation,
    pileName: 'standardFoundation',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.tapNotAllowed,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.multiCardsNotAllowed,
    putRule: PutRule.ascendingSameSuitBy1,
    putFirst: 1, // Ace.
    dealFaceRule: DealFaceRule.notUsed,
    fanOutX: 0.0,
    fanOutY: 0.0,
    growthCols: 0,
    growthRows: 0,
  );

  static const PileSpec simpleSimonFoundation = (
    pileType: PileType.foundation,
    pileName: 'simpleSimonFoundation',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.tapNotAllowed,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.multiCardsNotAllowed,
    putRule: PutRule.wholeSuit,
    putFirst: 13, // King.
    dealFaceRule: DealFaceRule.notUsed,
    fanOutX: 0.0,
    fanOutY: 0.0,
    growthCols: 0,
    growthRows: 0,
  );

  static const PileSpec mod3Foundation2J = (
    pileType: PileType.foundation,
    pileName: 'mod3Foundation',
    hasBaseCard: false,
    dragRule: DragRule.dragNotAllowed,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.multiCardsNotAllowed,
    putRule: PutRule.ascendingSameSuitBy3,
    putFirst: 2, // Two.
    dealFaceRule: DealFaceRule.faceUp,
    fanOutX: 0.0,
    fanOutY: 0.1,
    growthCols: 0,
    growthRows: 0,
  );

  static const PileSpec mod3Foundation3Q = (
    pileType: PileType.foundation,
    pileName: 'mod3Foundation',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.multiCardsNotAllowed,
    putRule: PutRule.ascendingSameSuitBy3,
    putFirst: 3, // Three.
    dealFaceRule: DealFaceRule.faceUp,
    fanOutX: 0.0,
    fanOutY: 0.1,
    growthCols: 0,
    growthRows: 0,
  );

  static const PileSpec mod3Foundation4K = (
    pileType: PileType.foundation,
    pileName: 'mod3Foundation',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.multiCardsNotAllowed,
    putRule: PutRule.ascendingSameSuitBy3,
    putFirst: 4, // Four.
    dealFaceRule: DealFaceRule.faceUp,
    fanOutX: 0.0,
    fanOutY: 0.1,
    growthCols: 0,
    growthRows: 0,
  );

  static const PileSpec mod3ExcludedCards = (
    // Holds cards that have been dealt out of the Mod 3 game.
    pileType: PileType.excludedCards,
    pileName: 'excludedCardsPile',
    hasBaseCard: false,
    dragRule: DragRule.dragNotAllowed,
    tapRule: TapRule.tapNotAllowed,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.multiCardsNotAllowed,
    putRule: PutRule.sameRank,
    putFirst: 1,
    dealFaceRule: DealFaceRule.faceUp,
    fanOutX: 0.0,
    fanOutY: 0.22,
    growthCols: 0,
    growthRows: 1,
  );

  static const PileSpec freecell = (
    // Used in Freecell game: can hold one card only.
    pileType: PileType.freecell,
    pileName: 'freecell',
    hasBaseCard: false,
    dragRule: DragRule.fromTop,
    tapRule: TapRule.goOut,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.multiCardsNotAllowed,
    putRule: PutRule.ifEmptyAnyCard,
    putFirst: 0,
    dealFaceRule: DealFaceRule.notUsed,
    fanOutX: 0.0,
    fanOutY: 0.0,
    growthCols: 0,
    growthRows: 0,
  );

  static const PileSpec dealerStock = (
    // Reserved for the Dealer, in games that do not use a Stock Pile.
    pileType: PileType.stock,
    pileName: 'dealerStock',
    hasBaseCard: true,
    dragRule: DragRule.dragNotAllowed,
    tapRule: TapRule.tapNotAllowed,
    tapEmptyRule: TapEmptyRule.tapNotAllowed,
    multiCardsRule: MultiCardsRule.multiCardsNotAllowed,
    putRule: PutRule.putNotAllowed,
    putFirst: 0,
    dealFaceRule: DealFaceRule.faceDown,
    fanOutX: 0.0,
    fanOutY: 0.0,
    growthCols: 0,
    growthRows: 0,
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
