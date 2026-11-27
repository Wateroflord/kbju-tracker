import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/life/training.dart';

void main() {
  test('блины на штангу', () {
    final a = platesFor(100);
    expect(a.perSide, [25, 15]);
    expect(a.total, 100);
    expect(platesFor(62.5).perSide, [20, 1.25]);
    expect(platesFor(20).perSide, isEmpty);
    expect(platesFor(15, bar: 20).total, 20);
    final odd = platesFor(61);
    expect(odd.total, 60); // ровно 61 не собрать — ближайшее меньшее
    expect(platesFor(50, bar: 15).perSide, [15, 2.5]);
  });
}
