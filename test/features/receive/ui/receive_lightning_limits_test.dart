import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_amount_screen.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, ScriptType;
import 'package:swaps/swaps.dart';

class _Receive extends Mock implements ReceiveBloc {}

void main() {
  for (final protocolError in [false, true]) {
    testWidgets(
      protocolError
          ? 'protocol errors do not also show a provider range error'
          : 'an explicit zero shows the minimum range feedback',
      (tester) async {
        final bloc = _Receive();
        when(() => bloc.state).thenReturn(
          ReceiveState(
            type: ReceiveType.lightning,
            wallet: Wallet(
              origin: 'limits',
              network: Network.bitcoinMainnet,
              xpubFingerprint: '00000000',
              scriptType: ScriptType.bip84,
              xpub: '',
              externalPublicDescriptor: '',
              internalPublicDescriptor: '',
              signer: SignerEntity.local,
              signerDevice: null,
              balanceSat: BigInt.zero,
            ),
            walletAdmitted: true,
            bitcoinUnit: BitcoinUnit.sats,
            inputAmountCurrencyCode: 'sats',
            inputAmount: protocolError ? '2100000000000001' : '0',
            amountEntryValid: !protocolError,
            failure: protocolError
                ? const ReceiveAmountAboveProtocolLimitFailure(
                    limitAmountSat: 2100000000000000,
                  )
                : null,
            swapRoute: SwapRoute.boltz,
            swapLimits: const SwapLimits(min: 1000, max: 1000000),
          ),
        );
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: const [
              bullUiLocalizationsDelegate,
              ...appLocalizationsDelegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<ReceiveBloc>.value(
              value: bloc,
              child: const Scaffold(body: ReceiveAmountScreen()),
            ),
          ),
        );
        if (protocolError) {
          expect(
            find.textContaining('Amount is above the maximum possible Bitcoin'),
            findsOneWidget,
          );
          expect(find.text('Enter no more than 1,000,000 sats'), findsNothing);
        } else {
          expect(find.text('Enter at least 1,000 sats'), findsOneWidget);
        }
      },
    );
  }
}
