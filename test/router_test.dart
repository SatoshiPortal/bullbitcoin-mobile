import 'package:bb_mobile/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app router constructs without route configuration errors', () {
    // go_router asserts route name uniqueness (among other configuration
    // invariants) when the router is constructed in debug mode, so building
    // the full app router catches duplicate route names registered by any
    // feature router before they can crash the app at boot.
    expect(() => AppRouter.router, returnsNormally);
  });
}
