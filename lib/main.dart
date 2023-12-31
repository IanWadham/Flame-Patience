import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'pat_game.dart';

void main() {
  final game = PatGame();
  runApp(GameWidget(game: game));
}
