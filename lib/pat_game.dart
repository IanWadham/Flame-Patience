import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'pat_world.dart';
import 'specs/pat_specs.dart';

enum Action { newDeal, sameDeal, newGame, undo, redo }

class PatGame extends FlameGame<PatWorld> {
  // The PatGame constructor creates the first PatWorld.
  PatGame() : super(world: PatWorld());

  // These three values persist between deals and are starting conditions
  // for the next deal to be played on PatWorld. The type of game being played
  // (gameID) stays the same between deals, unless Action.newGame is taken, in
  // which case we must first go to a menu screen. Action.newDeal triggers a
  // shuffle and deal. Action.sameDeal re-deals the same cards as before. The
  // actual seed is computed in KlondikeWorld, but is held here in case the
  // player chooses Action.sameDeal.
  int gameIndex = 0;
  int seed = 1;
  Action action = Action.newDeal;

  static final Color screenBackground = Colors.amber.shade100;
  static final Color pileBackground = Colors.lime.shade300;
  static final Color pileOutline = Colors.brown.shade400;

  void changeGame() =>
      gameIndex = (gameIndex < PatData.gameList.length - 1) ? ++gameIndex : 0;

  @override
  Color backgroundColor() => screenBackground;
}
