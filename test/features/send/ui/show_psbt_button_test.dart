import 'package:signers/routes.dart';
import 'package:bb_mobile/features/send/public/send_psbt_handoff.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, Sats, ScriptType;
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:signers/signers.dart';
import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/presentation/send_wallet_view.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/localizations.dart';
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
    final wallet = Wallet(
      origin: 'watch-signer',
      network: Network.bitcoinTestnet,
      xpubFingerprint: '00000000',
      scriptType: ScriptType.bip84,
      xpub: '',
      externalPublicDescriptor: '',
      internalPublicDescriptor: '',
      signer: SignerEntity.remote,
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
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

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
