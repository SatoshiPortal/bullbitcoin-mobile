import 'package:primitives/primitives.dart';
import 'package:swaps/src/data/swap_route_setting_repository_impl.dart';
import 'package:swaps/swaps.dart' show SwapRouteOverride, SwapsFailure;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SwapRouteSettingRepositoryImpl repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = SwapRouteSettingRepositoryImpl();
  });

  test('the exchange fallback is off until the user turns it on', () async {
    final before = await repository.isExchangeFallbackEnabled();
    expect((before as Ok<bool, SwapsFailure>).value, isFalse);

    final saved = await repository.setExchangeFallbackEnabled(true);
    final after = await repository.isExchangeFallbackEnabled();

    expect(saved, isA<Ok<void, SwapsFailure>>());
    expect((after as Ok<bool, SwapsFailure>).value, isTrue);
  });

  test('the route override defaults to auto and persists', () async {
    final before = await repository.getRouteOverride();
    expect(
      (before as Ok<SwapRouteOverride, SwapsFailure>).value,
      SwapRouteOverride.auto,
    );

    await repository.setRouteOverride(SwapRouteOverride.exchangeOnly);
    final after = await repository.getRouteOverride();

    expect(
      (after as Ok<SwapRouteOverride, SwapsFailure>).value,
      SwapRouteOverride.exchangeOnly,
    );
  });

  test('an unknown stored override reads as auto', () async {
    SharedPreferences.setMockInitialValues({'swaps.route_override': 'nope'});

    final result = await repository.getRouteOverride();

    expect(
      (result as Ok<SwapRouteOverride, SwapsFailure>).value,
      SwapRouteOverride.auto,
    );
  });
}
