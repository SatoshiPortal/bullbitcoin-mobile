import 'package:bb_mobile/features/broadcast_signed_tx/type.dart';
import 'package:bb_mobile/features/send/ui/widgets/send_action_buttons.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/psbt_flow/psbt_router.dart';
import 'package:bb_mobile/features/psbt_flow/show_psbt/show_psbt_screen.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/presentation/send_wallet_view.dart';
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

  testWidgets('QR signing returns the result to the current send session', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);
    final wallet = Wallet(
      origin: 'watch-signer',
      network: Network.bitcoinTestnet,
      scriptType: ScriptType.bip84,
      balanceSat: BigInt.from(100000),
      signers: [
        WalletSigner.single(
          masterFingerprint: '',
          xpubFingerprint: '00000000',
          xpub: '',
          signer: SignerEntity.remote,
          signerDevice: SignerDeviceEntity.coldcardMk4,
        ),
      ],
      publicDescriptor: '',
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
    Object? collectionRequest;
    when(() => cubit.applyExternalBitcoinSigningResult('signed'))
        .thenAnswer((_) async => true);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: BlocProvider<SendCubit>.value(
              value: cubit,
              child: ShowPsbtButton(signer: wallet.signers.single),
            ),
          ),
        ),
        PsbtRouterConfig.route,
        // Stands in for the broadcast route so the hand-off record is visible.
        GoRoute(
          name: BroadcastSignedTxRoute.broadcastHome.name,
          path: BroadcastSignedTxRoute.broadcastHome.path,
          builder: (context, state) {
            collectionRequest = state.extra;
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
    expect(screen.psbt, psbt);
    expect(screen.signerDevice, SignerDeviceEntity.coldcardMk4);

    await tester.tap(find.text(l10n.importSignedPsbtTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      collectionRequest,
      isA<BroadcastSignedTxRequest>().having(
        (request) => request.unsignedPsbt,
        'unsigned PSBT',
        psbt,
      ),
    );
    router.pop('signed');
    await tester.pumpAndSettle();
    verify(() => cubit.applyExternalBitcoinSigningResult('signed')).called(1);
  });
}
