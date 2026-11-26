import 'package:ark/ark.dart';
import 'package:bull_ark/bull_ark.dart' show ArkAccountsFacade;
import 'package:electrum/electrum.dart';
import 'package:fees/fees.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:send/send.dart' show SendArkRouteUnavailableFailure;
import 'package:send/setup.dart';
import 'package:send/src/payment/presentation/send_ark_cubit.dart';
import 'package:spend/testing.dart';

/// Classifier-only regtest HRP/checksum fixture; not native payment validity.
const address =
    'tark1pwh9vsmezqqpharv69q4z8m6x364d5m5prnmcalcalq9pdmzw0y7mpveck4pcfhezqypczkrrj3lkx5ue4qrf4jc7ztpt9htdttmh2judhqnu7aue8p0y9mq47jn9z';

class _Electrum extends Mock implements Electrum {}

class _Transactions extends Mock implements ElectrumTransactions {}

class _Fees extends Mock implements Fees {}

class _Environment extends Mock implements ActiveEnvironmentReader {}

void main() {
  final account = ArkAccountId(
    parent: Fingerprint('00112233'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );

  Future<SendArkState> pasteArkAddress(
    WidgetTester tester, {
    ArkAccountsFacade? accounts,
  }) async {
    final electrum = _Electrum();
    when(() => electrum.transactions).thenReturn(_Transactions());
    final routes = SendFeature.mount(
      spend: FakeSpend(),
      fees: _Fees(),
      electrum: electrum,
      environment: _Environment(),
      goToWalletHome: (_) {},
      broadcastSuccessImage: const AssetImage('unused-success'),
      missingWalletRedirect: '/wallet',
      selectBalanceSat: (_, _) => 0,
      payment: () => throw StateError('Unexpected Bitcoin payment setup'),
      openCoins: (_, _) {},
      orderUnderReview: (_) => const SizedBox.shrink(),
      pollSettlement: (_, {required isActive}) async {},
      arkAccounts: () => accounts,
    );
    final payment = routes.payment;
    if (payment is! GoRoute) throw StateError('Expected a Send payment route');
    final router = GoRouter(
      initialLocation: payment.path,
      routes: [
        GoRoute(
          path: payment.path,
          builder: (context, state) {
            final scope = payment.builder?.call(context, state);
            if (scope is! MultiBlocProvider) {
              throw StateError('Expected the mounted Send payment scope');
            }
            // Mount the route's real providers around a probe. Reading only Ark
            // leaves the separate, lazy Bitcoin payment cubit unopened.
            return MultiBlocProvider(
              providers: [scope],
              child: const SizedBox(key: ValueKey('ark-probe')),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final cubit = tester
        .element(find.byKey(const ValueKey('ark-probe')))
        .read<SendArkCubit>();
    await cubit.resolve(
      input: address,
      network: BitcoinNetwork.regtest,
      coinControl: false,
      sweep: false,
      silentPayments: false,
      multipleRecipients: false,
    );
    return cubit.state;
  }

  testWidgets(
    'mounted Send routes a pasted Ark address to an enabled account',
    (tester) async {
      final state = await pasteArkAddress(
        tester,
        accounts: ArkAccountsFacade((network) async {
          expect(network, BitcoinNetwork.regtest);
          return Ok([account]);
        }),
      );
      expect(
        state,
        isA<SendArkReady>().having(
          (state) => state.request.accounts,
          'enabled accounts',
          [account],
        ),
      );
    },
  );

  testWidgets('mounted Send reports Ark unavailable without an account host', (
    tester,
  ) async {
    final state = await pasteArkAddress(tester);
    expect(
      state,
      isA<SendArkUnavailable>().having(
        (state) => state.failure,
        'reason',
        isA<SendArkRouteUnavailableFailure>(),
      ),
    );
  });
}
