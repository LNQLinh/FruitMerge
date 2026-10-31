import 'package:flutter_test/flutter_test.dart';
import 'package:fruit_fusion/game/fruit_types.dart';

void main() {
  test('each tier is bigger and worth more than the previous one', () {
    for (var i = 1; i < fruitTypes.length; i++) {
      expect(fruitTypes[i].radius, greaterThan(fruitTypes[i - 1].radius));
      expect(fruitTypes[i].points, greaterThan(fruitTypes[i - 1].points));
    }
  });

  test('the biggest fruit fits in the jar', () {
    expect(fruitTypes.last.radius * 2, lessThan(6.0));
  });
}
