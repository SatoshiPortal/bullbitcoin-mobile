import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/psbt_flow/psbt_router.dart';
import 'package:bb_mobile/features/psbt_flow/show_psbt/show_psbt_screen.dart';
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
  testWidgets('Show PSBT carries the sending wallet through to the broadcast', (
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
      signerDevice: SignerDeviceEntity.coldcardMk4,
      balanceSat: BigInt.from(100000),
    );
    final cubit = _MockSendCubit();
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.state).thenReturn(
      SendState(
        step: SendStep.confirm,
        selectedWallet: SendWalletBitcoin(wallet),
        unsignedPsbt: psbt,
      ),
    );
    Object? broadcastExtra;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: BlocProvider<SendCubit>.value(
              value: cubit,
              child: const ShowPsbtButton(),
            ),
          ),
        ),
        PsbtRouterConfig.route,
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
    expect(find.byType(ShowPsbtScreen), findsOneWidget);
    final screen = tester.widget<ShowPsbtScreen>(find.byType(ShowPsbtScreen));
    expect(screen.wallet, same(wallet));
    expect(screen.psbt, psbt);
    expect(screen.signerDevice, SignerDeviceEntity.coldcardMk4);

    await tester.tap(find.text(l10n.psbtFlowDone));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      broadcastExtra,
      isA<({String psbt, Wallet? wallet})>()
          .having((extra) => extra.psbt, 'psbt', psbt)
          .having((extra) => extra.wallet, 'wallet', same(wallet)),
    );
  });
}
