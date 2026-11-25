import '../testing/send_test_localizations.dart';

import 'package:send/setup.dart' show SendLocalizations;
import 'package:secrets/secrets.dart' show WalletSigner;

import '../testing/send_source_fixture.dart';

import 'package:signers/routes.dart';
import 'package:send/src/payment/public/send_psbt_handoff.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Sats;
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:signers/signers.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:send/send.dart';
import 'package:send/src/payment/presentation/bloc/send_cubit.dart';
import 'package:send/src/payment/presentation/bloc/send_state.dart';
import 'package:send/src/payment/presentation/send_wallet_view.dart';
import 'package:send/src/payment/ui/screens/send_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockSendCubit extends Mock implements SendCubit {}

void main() {
  const psbt =
      'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9////'
      'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
      'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

  // Regression (Pixel 6a, Coldcard Q watch-signer): Show PSBT handed the
  // router the send screen's wallet view instead of the wallet, so the route
  // pattern never matched and the screen said "Oops! Something went wrong".
  // A Mk4 stands in for the Q: its screen has no animated QR to wire up.
  testWidgets('Show PSBT carries the reviewed spend and network to the reader', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);
    final wallet = sendSourceFixture(
      id: 'watch-signer',
      network: BitcoinNetwork.testnet,
      signer: WalletSigner.remote,
      signerDevice: SignerDevice.coldcardMk4,
      balanceSat: BigInt.from(100000),
    );
    final cubit = _MockSendCubit();
    final prepared = SpendFixtures.preparedBitcoin(
      unsignedPsbt: psbt,
      fee: Sats.zero,
    );
    when(() => cubit.preparedBitcoin).thenReturn(prepared);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.state).thenReturn(
      SendState(
        step: SendStep.confirm,
        selectedWallet: SendWalletBitcoin(wallet),
        unsignedPsbt: psbt,
      ),
    );
    Object? broadcastExtra;
    final services = GetIt.asNewInstance();
    addTearDown(services.reset);
    String? written;
    String? nfcTitle;
    final feature = SignersFeature.mount(
      services: services,
      writeNfc: (_, title, data, onSuccess) async {
        nfcTitle = title;
        written = data;
        onSuccess();
      },
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: BlocProvider<SendCubit>.value(
              value: cubit,
              child: SendPsbtHandoff(
                openReader: (context, prepared, network) =>
                    context.pushNamed<String>(
                      BroadcastSignedTxRoute.broadcastHome.name,
                      extra: (prepared: prepared, network: network),
                    ),
                child: const ShowPsbtButton(),
              ),
            ),
          ),
        ),
        ...feature.routes,
        // Stands in for the broadcast route so the hand-off record is visible.
        GoRoute(
          name: BroadcastSignedTxRoute.broadcastHome.name,
          path: BroadcastSignedTxRoute.broadcastHome.path,
          builder: (context, state) {
            broadcastExtra = state.extra;
            return const Scaffold();
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: sendTestLocalizationsDelegates,
        supportedLocales: SendLocalizations.supportedLocales,
      ),
    );
    final l10n = await SendLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byType(ShowPsbtButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.oopsSomethingWentWrong), findsNothing);
    final signersLoc = await SignersLocalizations.delegate.load(
      const Locale('en'),
    );
    final nfc = find.text(signersLoc.psbtFlowSignViaNfc);
    expect(nfc, findsOneWidget);
    expect(GoRouterState.of(tester.element(nfc)).uri.path, '/show-psbt');

    await tester.tap(nfc);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(written, psbt);
    expect(
      nfcTitle,
      signersLoc.psbtFlowSignViaNfcSheetTitle(
        SignerDevice.coldcardMk4.displayName,
      ),
    );
    expect(
      broadcastExtra,
      isA<({PreparedBitcoinSpend prepared, BitcoinNetwork network})>()
          .having((extra) => extra.prepared, 'preparation', same(prepared))
          .having((extra) => extra.network, 'network', BitcoinNetwork.testnet),
    );
  });
}
