import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors, Color;

import 'pat_menu_world.dart';

enum Action { newDeal, sameDeal, newGame, undo, redo, showRules, showMoves }

class PatBaseWorld extends World with HasGameReference<PatGame> {
// An empty parent-World from which two very different worlds inherit.
}

class PatGame extends FlameGame<PatBaseWorld> {
  // The PatGame constructor creates the first PatMenuWorld. It replaces itself
  // with a PatWorld for gameplay after the player has selected a game-type.
  PatGame() : super(world: PatMenuWorld());

  // Constant used when creating seed for Random class.
  static const int maxInt = 0xFFFFFFFE; // (2 to the power 32) - 1

  // These three values persist between deals and are starting conditions
  // for the next deal to be played on PatWorld. The type of game being played
  // (gameIndex) stays the same between deals, unless Action.newGame is taken.
  // Action.newDeal triggers a shuffle and deal. Action.sameDeal re-deals the
  // same cards as before. The actual seed is computed in PatWorld, but is held
  // here in case the player chooses Action.sameDeal.

  var gameIndex = 0;
  var seed = 0;
  var action = Action.newDeal;

  final testSeed = 0; // The Game starts with a randomly-generated seed.

  // final testSeed = 1567865991; // Mod 3 deal: 3 Aces in Tableaus 26 and 27.
  // final testSeed = 3922659694; // Yukon deal: hard but solvable.
  // final testSeed = 3528308832; // Freecell deal: hard, bl 4s rd 5s same pile.
  //   "     "  "   =    "  "     // 48 deal: 5 Aces buried, hard but solvable.
  // final testSeed = 3116355471; // Yukon deal: fairly easy, 2 Sp appears late.
  // final testSeed = 2868337660; // Mod3 deal: easy, despite only 1 space.
  // final testSeed = 1480193452; // 48 deal: hard, C D H blocks, 1 Ace buried.

  // The gameIndex is used to select a GameSpec from PatData.gameList in file
  // specs/pat_specs. GameSpecs are structures of const data which, together
  // with typedefs and enums (in file specs/pat_enums), provide all the info
  // required to construct layouts, deals and rules of play for many Patience
  // (Solitaire) games. GameSpecs depend heavily on the Dart 3 record concept.

  void changeGame() => world = PatMenuWorld(); // Show the menu-world screen.

  // Color settings for the playing area, board layout and action-buttons.
  // The Screen Background is amber.shade300, but darkened manually. That is
  // not the same as shade400, etc. of Flutter's amber swatch.
  static const Color screenBackground = Color(0xffe7c31d);
  static final Color pileBackground = Colors.amberAccent.shade100;
  static final Color pileOutline = Colors.brown.shade800;
  static final Color faintOutline = Colors.brown.shade300;
  static const Color buttonHighlight = Colors.red;
  static const Color stockPileHighlight = Colors.red;

  @override
  Color backgroundColor() => screenBackground;
}
