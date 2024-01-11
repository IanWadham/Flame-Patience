import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Colors, Color;

import 'pat_world.dart';
import 'specs/pat_specs.dart';

enum Action { newDeal, sameDeal, newGame, undo, redo }

class PatGame extends FlameGame<PatWorld> {
  // The PatGame constructor creates the first PatWorld.
  PatGame() : super(world: PatWorld());

  // These three values persist between deals and are starting conditions
  // for the next deal to be played on PatWorld. The type of game being played
  // (gameIndex) stays the same between deals, unless Action.newGame is taken.
  // Action.newDeal triggers a shuffle and deal. Action.sameDeal re-deals the
  // same cards as before. The actual seed is computed in PatWorld, but is held
  // here in case the player chooses Action.sameDeal.

  int gameIndex = 0;
  int seed = 1;
  Action action = Action.newDeal;

  // The gameIndex is used to select a GameSpec from PatData.gameList in file
  // specs/pat_specs. GameSpecs are structures of const data which, together
  // with typedefs and enums (in file specs/pat_enums), provide all the info
  // required to construct layouts, deals and rules of play for many Patience
  // (Solitaire) games. GameSpecs depend heavily on the Dart 3 record concept.

  void changeGame() => // This can show a menu screen in later versions.
      gameIndex = (gameIndex < PatData.gameList.length - 1) ? ++gameIndex : 0;

  // Color settings for the playing area, board layout and action-buttons.
  static final Color screenBackground = Colors.amber.shade100;
  static final Color pileBackground = Colors.amberAccent.shade100;
  static final Color pileOutline = Colors.brown.shade600;
  static final Color buttonHighlight = Colors.red;
  static final Color stockPileHighlight = Colors.red;

  @override
  Color backgroundColor() => screenBackground;
}

  // static final Color pileBackground = Colors.lime.shade300;
  // static final Color pileBackground = Colors.lime.shade200;
  // static final Color pileBackground = Colors.amber.shade200;
  // static final Color pileBackground = Colors.brown.shade100;
  // static final Color pileOutline = Colors.brown.shade400;
