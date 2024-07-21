import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import '../components/card_view.dart';

typedef SpriteData = ({
  int rank,
  int suit,
  double sourceX,
  double sourceY,
  double width,
  double height,
});

class ImageSpecs {

  SpriteData fill = (
    rank: -1,
    suit: -1,
    sourceX: -1.0,
    sourceY: -1.0,
    width: -1.0,
    height: -1.0,
  );

  List<CardView> loadCards(
      String dataName, String dataString, int nImages, int nPacks) {
    List<SpriteData> spriteData = parseImageData(dataName, dataString, nImages);
    // print('Length of spriteData = ${spriteData.length}');
    List<CardView> cards = [];
    SpriteData data = spriteData.last;
    String cacheName = '$dataName.png';
    Sprite backSprite = Sprite(
      Flame.images.fromCache(cacheName),
      srcPosition: Vector2(data.sourceX, data.sourceY),
      srcSize: Vector2(data.width, data.height),
    );

    // Card zero is the Base Card, used as a tappable base for the Stock Pile.
    // It has two Sprites, for compatibility with other cards, but they are not
    // used. The Base Card in never played and is rendered only as an outline.
    final baseCard = CardView(0, backSprite, backSprite, isBaseCard: true);
    baseCard.priority = 0;
    cards.add(baseCard);

    // Create nPacks * 52 cards and give them index values 1 to nPacks * 52.
    Sprite faceSprite;
    for (int n = 0; n < nPacks; n++) {
      for (int index = 0; index < (nImages - 1); index++) {
        SpriteData data = spriteData[index];
        if (data.rank < 0 ||
            data.suit < 0 ||
            data.sourceX < 0.0 ||
            data.sourceY < 0.0 ||
            data.width < 0.0 ||
            data.height < 0.0) {
          faceSprite = backSprite;
        } else {
          faceSprite = Sprite(
            Flame.images.fromCache(cacheName),
            srcPosition: Vector2(data.sourceX, data.sourceY),
            srcSize: Vector2(data.width, data.height),
          );
        }
        final card = CardView(n * 52 + index + 1, faceSprite, backSprite);
        card.priority = cards.length; // Card's priority will be at least 1.
        cards.add(card);
      }
    }
    return cards;
  }

  List<SpriteData> parseImageData(String dataName, String dataString, int n) {
    List<SpriteData> spriteData = List.filled(n, fill);
    // print('Parsing "$dataName" data');
    List<String> lines = dataString.split('\n');
    if (lines.last.isEmpty) {
      lines.removeLast();
    }
    if (lines.length != n) {
      final String errorMessage = 'ERROR: Found ${lines.length} image specs: '
          'should be $n, last line: ${lines.last}|';
      throw RangeError(errorMessage);
    }
    RegExp spaces = RegExp('\\s+');
    for (String line in lines) {
      // print('Line: $line');
      List<String> fields = line.split(spaces);
      // print('Fields: $fields');
      String rankCode = fields[0];
      String suitCode = fields[1];
      int rank = 'A23456789TJQKF'.indexOf(rankCode) + 1;
      int suit = (rankCode == 'F') ? 0 : 'hdcs'.indexOf(suitCode);
      double x = double.tryParse(fields[2]) ?? -1.0;
      double y = double.tryParse(fields[3]) ?? -1.0;
      double width = double.tryParse(fields[4]) ?? -1.0;
      double height = double.tryParse(fields[5]) ?? -1.0;
      // TODO - Throw a RangeError if any Image Spec field fails to parse.
      // print('Rank: $rank Suit: $suit Pos: ($x, $y) W: $width H: $height');
      int index = 4 * (rank - 1) + suit;
      spriteData[index] = (
        rank: rank,
        suit: suit,
        sourceX: x,
        sourceY: y,
        width: width,
        height: height
      );
    }
    return spriteData;
  }
}
