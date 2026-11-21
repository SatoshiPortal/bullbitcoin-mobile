import 'package:primitives/primitives.dart' show NetworkEnv, ScriptType;
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/bitbox/ui/bitbox_router.dart';
import 'package:bb_mobile/features/bitbox/ui/screens/bitbox_action_screen.dart';
import 'package:bb_mobile/features/ledger/ui/ledger_router.dart';
import 'package:bb_mobile/features/ledger/ui/screens/ledger_action_screen.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_qr_screen.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Receive extends Mock implements ReceiveBloc {}

void main() {
  for (final ledger in [true, false]) {
    testWidgets(
      'named ${ledger ? 'Ledger' : 'BitBox'} verification preserves the address and path',
      (tester) async {
        final device = ledger
            ? SignerDeviceEntity.ledgerNanoX
            : SignerDeviceEntity.bitbox02;
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
        Object? parameters;
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
            GoRoute(
              path: '/verify',
              name: ledger
                  ? LedgerRoute.ledgerVerifyAddress.name
                  : BitBoxRoute.bitboxVerifyAddress.name,
              builder: (context, state) {
                parameters = state.extra;
                return const Scaffold(body: Text('Hardware route'));
              },
            ),
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
        expect(find.text('Hardware route'), findsOneWidget);
        if (ledger) {
          expect(parameters, isA<LedgerRouteParams>());
          final value = parameters as LedgerRouteParams;
          expect(value.network, NetworkEnv.mainnet);
          expect(value.address, 'bc1qpublic');
          expect(value.derivationPath, '${wallet.derivationPath}/0/7');
          expect(value.requestedDeviceType, device);
        } else {
          expect(parameters, isA<BitBoxRouteParams>());
          final value = parameters as BitBoxRouteParams;
          expect(value.network, NetworkEnv.mainnet);
          expect(value.address, 'bc1qpublic');
          expect(value.derivationPath, '${wallet.derivationPath}/0/7');
          expect(value.requestedDeviceType, device);
        }
      },
    );
  }
}
