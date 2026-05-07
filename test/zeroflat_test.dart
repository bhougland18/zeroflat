import 'package:flutter_test/flutter_test.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;

void main() {
  test('Generated FlatBuffer types can be imported', () {
    // Verify we can access generated types
    expect(fbs.Brightness.values, isNotEmpty);
  });
}
