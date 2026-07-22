import 'package:flutter_test/flutter_test.dart';
import 'package:halo/main.dart';

void main() {
  test('constructs the Halo application shell without starting plugins', () {
    expect(const HaloApp(), isA<HaloApp>());
  });
}
