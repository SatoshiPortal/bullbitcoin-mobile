import 'package:primitives/primitives.dart' show ScriptType;
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_balance_row.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, bullUiLocalizationsDelegate;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _MockTransferBloc extends Mock implements TransferBloc {}

void main() {
  for (final max in <int?>[null, 0, 2500]) {
    testWidgets('Max uses canonical event only when available ($max)', (
      tester,
    ) async {
      final bloc = _MockTransferBloc();
      when(() => bloc.state).thenReturn(
        TransferState(
          maxAmountSat: max,
          fromWallet: Wallet(
            origin: 'synthetic',
            network: Network.bitcoinMainnet,
            xpubFingerprint: '00000000',
            scriptType: ScriptType.bip84,
            xpub: '',
            externalPublicDescriptor: '',
            internalPublicDescriptor: '',
            signer: SignerEntity.local,
            signerDevice: null,
            balanceSat: BigInt.from(10000),
          ),
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
          home: BlocProvider<TransferBloc>.value(
            value: bloc,
            child: const Scaffold(body: SwapBalanceRow()),
          ),
        ),
      );
      final action = find.byType(BullButton);
      final enabled = max != null && max > 0;
      expect(tester.widget<BullButton>(action).disabled, !enabled);
      await tester.tap(action, warnIfMissed: false);
      if (enabled) {
        verify(() => bloc.add(const TransferEvent.maxSelected())).called(1);
      } else {
        verifyNever(() => bloc.add(const TransferEvent.maxSelected()));
      }
      verifyNever(
        () => bloc.add(const TransferEvent.receiveExactAmountToggled(false)),
      );
    });
  }
}
