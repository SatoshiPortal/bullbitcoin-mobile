import 'package:address_view/address_view.dart';
import 'package:address_view/routes.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labels/labels.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;

class _Inventory extends Mock implements WalletInventory {}

class _Labels extends Mock implements Labels {}

class _Native extends Mock implements WalletNativeLifecycle {}

void main() {
  testWidgets('opens the address view in the existing settings slot', (
    tester,
  ) async {
    late BuildContext settings;
    final inventory = _Inventory();
    when(
      () => inventory.readWallet('wallet-1'),
    ).thenAnswer((_) async => const Err(WalletRegistrationNotFoundFailure()));
    final native = _Native();
    final feature = AddressViewFeature.mount(
      labels: _Labels(),
      inventory: inventory,
      native: native,
      loadWallet: (_) async => throw StateError('Unexpected Sync read'),
      revisions: const Stream.empty(),
    );
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, _) {
            settings = context;
            return const SizedBox.shrink();
          },
          routes: [feature.route],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: AddressViewLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    final pushed = AddressViewNavigation.open(settings, walletId: 'wallet-1');
    await tester.pumpAndSettle();
    expect(
      router.state.uri.path,
      '/settings/wallet-details/wallet-1/addresses',
    );
    expect(router.state.pathParameters, {'walletId': 'wallet-1'});
    expect(find.text('This wallet could not be found.'), findsOneWidget);
    verifyZeroInteractions(native);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    await pushed;
  });
}
