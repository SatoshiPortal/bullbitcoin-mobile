import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bb_mobile/features/send/domain/usecases/recognize_ark_address_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/presentation/send_ark_cubit.dart';
import 'package:bb_mobile/features/send/presentation/send_wallet_view.dart';
import 'package:bb_mobile/features/send/ui/widgets/send_ark_routing_actions.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' as wallet;
import 'package:bull_ark/ark_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../domain/usecases/recognize_ark_address_usecase_test.dart'
    show Fixture, address;

class Send extends Mock implements SendCubit {}

class Wallet extends Mock implements wallet.Wallet {}

void main() {
  late Fixture fixture;
  late Send send;
  late SendArkCubit ark;
  late StreamController<SendState> changes;
  late SendState state;
  late ArkAccountId account;
  setUp(() {
    fixture = Fixture();
    account = ArkAccountId(
      parent: Fingerprint('00112233'),
      network: BitcoinNetwork.mainnet,
      serverIdentity: 'public-server',
    );
    when(() => fixture.registry.list()).thenAnswer(
      (_) async => Ok([
        ArkAccountConfig(
          id: account,
          arkUrl: Uri.parse('https://ark.example'),
          primaryEsploraUrl: Uri.parse('https://chain.example'),
        ),
      ]),
    );
    when(() => fixture.preferences.isEnabled(account))
        .thenAnswer((_) async => const Ok(true));
    final source = Wallet();
    when(() => source.network).thenReturn(wallet.Network.bitcoinMainnet);
    state = SendState(
      copiedRawPaymentRequest: address,
      selectedWallet: SendWalletBitcoin(source),
    );
    send = Send();
    changes = StreamController<SendState>.broadcast();
    when(() => send.state).thenAnswer((_) => state);
    when(() => send.stream).thenAnswer((_) => changes.stream);
    when(() => send.isSpMode).thenReturn(false);
    ark = SendArkCubit(RecognizeArkAddressUsecase(fixture.facade));
  });
  tearDown(() async {
    await ark.close();
    await changes.close();
  });
  Widget providers(Widget app) => MultiBlocProvider(
    providers: [
      BlocProvider<SendCubit>.value(value: send),
      BlocProvider<SendArkCubit>.value(value: ark),
    ],
    child: app,
  );
  Widget app() => providers(
    MaterialApp(
      theme: ThemeData(extensions: testBullExtensions),
      home: const Scaffold(
        body: SendArkRoutingActions(fallback: Text('ordinary send')),
      ),
    ),
  );
  testWidgets(
    'recipient changes remove the old Ark choice and restore ordinary controls',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(ArkSendEntryButton), findsOneWidget);
      state = state.copyWith(copiedRawPaymentRequest: 'bitcoin:bc1qexample');
      changes.add(state);
      await tester.pumpAndSettle();
      expect(find.byType(ArkSendEntryButton), findsNothing);
      expect(find.text('ordinary send'), findsOneWidget);
      verifyZeroInteractions(fixture.client);
    },
  );
  testWidgets(
    'new sweep restriction removes Ark routing before any new inventory read',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(ArkSendEntryButton), findsOneWidget);
      state = state.copyWith(
        sweepOutpoints: {(txId: 'public-outpoint', vout: 0)},
      );
      changes.add(state);
      await tester.pumpAndSettle();
      expect(find.byType(ArkSendEntryButton), findsNothing);
      expect(
        find.text('This Ark action is unavailable in this build.'),
        findsOneWidget,
      );
      expect(find.text('ordinary send'), findsNothing);
      verify(() => fixture.registry.list()).called(1);
      verifyZeroInteractions(fixture.client);
    },
  );
  testWidgets(
    'explicit choice navigates with the captured Ark account and destination',
    (tester) async {
      ArkPaymentEntry? captured;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, state) => const Scaffold(
              body: SendArkRoutingActions(fallback: Text('ordinary send')),
            ),
          ),
          GoRoute(
            path: '/ark/pay',
            builder: (_, state) {
              captured = state.extra as ArkPaymentEntry?;
              return const Scaffold(body: Text('Ark payment entry'));
            },
          ),
        ],
      );
      await tester.pumpWidget(
        providers(
          MaterialApp.router(
            theme: ThemeData(extensions: testBullExtensions),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send from Ark (00112233)'));
      await tester.pumpAndSettle();
      expect(captured?.account, account);
      expect(captured?.destination, address);
      verifyZeroInteractions(fixture.client);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    },
  );
}
