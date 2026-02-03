import 'package:flutter_test/flutter_test.dart';
import 'package:simple_refresh_bus/simple_refresh_bus.dart';

void main() {
  group('Refresh', () {
    test('can be instantiated', () {
      const refresh = Refresh<String>();
      expect(refresh, isNotNull);
    });

    test('is const constructible', () {
      const refresh1 = Refresh<String>();
      const refresh2 = Refresh<String>();
      expect(identical(refresh1, refresh2), isTrue);
    });

    test('different types create different instances', () {
      const refresh1 = Refresh<String>();
      const refresh2 = Refresh<int>();
      expect(refresh1.runtimeType, isNot(equals(refresh2.runtimeType)));
    });
  });
}
