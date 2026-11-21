import 'package:signers/signers.dart' show SignersLocalizations;
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/signers_psbt_routes.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/presentation/send_wallet_view.dart';
import 'package:bb_mobile/features/send/public/send_psbt_handoff.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show ScriptType;

class _Send extends Mock implements SendCubit {}

void main() {
  final wallet = Wallet(
    origin: 'public-fixture',
    network: Network.bitcoinTestnet,
    xpubFingerprint: '00000000',
    scriptType: ScriptType.bip84,
    xpub: '',
    externalPublicDescriptor: '',
    internalPublicDescriptor: '',
    signer: SignerEntity.remote,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );
  for (final confirm in [true, false]) {
    testWidgets(
      'Send ${confirm ? 'retains its original PSBT and wallet on confirmation' : 'does not open the reader on cancellation'}',
      (tester) async {
        final cubit = _Send();
        when(() => cubit.state).thenReturn(
          SendState(
            selectedWallet: SendWalletBitcoin(wallet),
            unsignedPsbt: 'original',
          ),
        );
        when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
        final requests = <(String, Wallet?)>[];
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: ShowPsbtButton()),
            ),
            PsbtRouterConfig.route,
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          BlocProvider<SendCubit>.value(
            value: cubit,
            child: SendPsbtHandoff(
              openReader: (_, psbt, source) async {
                requests.add((psbt, source));
              },
              child: MaterialApp.router(
                routerConfig: router,
                theme: ThemeData(extensions: testBullExtensions),
                localizationsDelegates: const [
                  bullUiLocalizationsDelegate,
                  ...appLocalizationsDelegates,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
              ),
            ),
          ),
        );
        final context = tester.element(find.byType(ShowPsbtButton));
        final loc = AppLocalizations.of(context);
        await tester.tap(find.text(loc.sendShowPsbt));
        await tester.pumpAndSettle();
        when(() => cubit.state).thenReturn(
          SendState(
            selectedWallet: SendWalletBitcoin(
              wallet.copyWith(origin: 'changed'),
            ),
            unsignedPsbt: 'changed',
          ),
        );
        if (confirm) {
          await tester.tap(
            find.text(SignersLocalizations.of(context).psbtFlowDone),
          );
        } else {
          router.pop();
        }
        await tester.pumpAndSettle();
        expect(requests, confirm ? [('original', wallet)] : isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
