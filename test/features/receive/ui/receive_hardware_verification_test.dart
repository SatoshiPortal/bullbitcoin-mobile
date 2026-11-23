import 'package:signers/routes.dart';
import 'package:primitives/primitives.dart' show NetworkEnv, ScriptType;
import 'package:signers/signers.dart';
import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/address_view/domain/wallet_address.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_qr_screen.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../features/signers/test/verify_address_route_expectations.dart';

class _Receive extends Mock implements ReceiveBloc {}

void main() {
  for (final ledger in [true, false]) {
    testWidgets(
      'named ${ledger ? 'Ledger' : 'BitBox'} verification passes the request to the mounted route',
      (tester) async {
        final device = ledger
            ? SignerDevice.ledgerNanoX
            : SignerDevice.bitbox02;
        final wallet = Wallet(
          origin: 'hardware',
          network: Network.bitcoinMainnet,
          xpubFingerprint: '00000000',
          scriptType: ScriptType.bip84,
          xpub: '',
          externalPublicDescriptor: '',
          internalPublicDescriptor: '',
          signer: SignerEntity.remote,
          signerDevice: device,
          balanceSat: BigInt.zero,
        );
        final now = DateTime.utc(2026);
        final bloc = _Receive();
        when(() => bloc.state).thenReturn(
          ReceiveState(
            type: ReceiveType.bitcoin,
            wallet: wallet,
            bitcoinAddress: WalletAddress(
              walletId: wallet.id,
              index: 7,
              address: 'bc1qpublic',
              createdAt: now,
              updatedAt: now,
            ),
          ),
        );
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
        final services = GetIt.asNewInstance();
        addTearDown(services.reset);
        final feature = SignersFeature.mount(
          services: services,
          writeNfc: (_, _, _, _) async {},
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: ledger
                    ? const VerifyAddressOnLedgerButton()
                    : const VerifyAddressOnBitBoxButton(),
              ),
            ),
            ...feature.routes,
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          BlocProvider<ReceiveBloc>.value(
            value: bloc,
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.themeData(AppThemeType.light),
              localizationsDelegates: const [
                bullUiLocalizationsDelegate,
                ...appLocalizationsDelegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.tap(
          find.text(ledger ? 'Verify on Ledger' : 'Verify on BitBox'),
        );
        await tester.pumpAndSettle();
        final loc = await SignersLocalizations.delegate.load(
          const Locale('en'),
        );
        final title = find.text(
          ledger ? loc.ledgerVerifyTitle : loc.bitboxActionVerifyAddressTitle,
        );
        expect(title, findsOneWidget);
        expect(
          GoRouterState.of(tester.element(title)).uri.path,
          ledger ? '/ledger-verify-address' : '/bitbox-verify-address',
        );
        expectVerifyAddressRequest(
          tester,
          network: NetworkEnv.mainnet,
          address: 'bc1qpublic',
          derivationPath: '${wallet.derivationPath}/0/7',
          requestedDeviceType: device,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
