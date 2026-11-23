import 'package:primitives/primitives.dart' show ScriptType;

import 'dart:async';

import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_amount_input.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Receive extends Mock implements ReceiveBloc {}

void main() {
  for (final scenario in ['debounce', 'invalid', 'lightning', 'disposed']) {
    testWidgets('live confirmation: $scenario', (tester) async {
      final bloc = _Receive();
      final stream = StreamController<ReceiveState>.broadcast();
      addTearDown(stream.close);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final wallet = Wallet(
        origin: 'live',
        network: Network.bitcoinMainnet,
        xpubFingerprint: '00000000',
        scriptType: ScriptType.bip84,
        xpub: '',
        externalPublicDescriptor: '',
        internalPublicDescriptor: '',
        signer: SignerEntity.local,
        signerDevice: null,
        balanceSat: BigInt.zero,
      );
      var state = ReceiveState(
        type: ReceiveType.bitcoin,
        wallet: wallet,
        walletAdmitted: true,
        inputAmountCurrencyCode: 'sats',
        fiatCurrencyCode: 'CAD',
      );
      when(() => bloc.state).thenAnswer((_) => state);
      when(() => bloc.stream).thenAnswer((_) => stream.stream);
      when(() => bloc.isClosed).thenReturn(false);
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
            child: Scaffold(
              body: ReceiveAmountInput(
                focusNode: focus,
                live: true,
                inCard: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      state = state.copyWith(inputAmount: '1000');
      stream.add(state);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      verifyNever(() => bloc.add(const ReceiveAmountConfirmed()));
      state = state.copyWith(inputAmount: '2000');
      stream.add(state);
      await tester.pump();
      if (scenario == 'invalid') {
        state = state.copyWith(amountEntryValid: false);
        stream.add(state);
        await tester.pump();
      } else if (scenario == 'lightning') {
        state = state.copyWith(type: ReceiveType.lightning);
        stream.add(state);
        await tester.pump();
      } else if (scenario == 'disposed') {
        await tester.pumpWidget(const SizedBox());
      }
      await tester.pump(const Duration(milliseconds: 299));
      verifyNever(() => bloc.add(const ReceiveAmountConfirmed()));
      await tester.pump(const Duration(milliseconds: 1));
      if (scenario == 'debounce') {
        verify(() => bloc.add(const ReceiveAmountConfirmed())).called(1);
      } else {
        verifyNever(() => bloc.add(const ReceiveAmountConfirmed()));
      }
    });
  }
}
