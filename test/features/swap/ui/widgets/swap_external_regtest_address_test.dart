import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_external_address_input.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/public/payment_destination.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_sdk/bull_sdk.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullPaymentDestinationInput, bullUiLocalizationsDelegate;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Transfer extends MockBloc<TransferEvent, TransferState>
    implements TransferBloc {}

void main() {
  setUpAll(BullSdk.init);
  tearDownAll(BullSdk.dispose);
  const address = 'bcrt1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3lgth6c';
  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets(
      'Swap regtest paste keeps valid card and Transfer error priority ${theme.name}',
      (tester) async {
        final wallet = Wallet(
          origin: 'regtest-source',
          network: Network.liquidRegtest,
          xpubFingerprint: 'public-fixture',
          scriptType: ScriptType.bip84,
          xpub: 'public-fixture',
          externalPublicDescriptor: 'public-fixture',
          internalPublicDescriptor: 'public-fixture',
          signer: SignerEntity.local,
          signerDevice: null,
          isDefault: false,
          balanceSat: BigInt.zero,
        );
        final initial = TransferState(fromWallet: wallet, sendToExternal: true);
        final states = StreamController<TransferState>();
        final bloc = _Transfer();
        whenListen(bloc, states.stream, initialState: initial);
        addTearDown(() async {
          await states.close();
          await bloc.close();
        });
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async =>
              call.method == 'Clipboard.getData' ? {'text': address} : null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.pumpWidget(
          BlocProvider<TransferBloc>.value(
            value: bloc,
            child: MaterialApp(
              theme: AppTheme.themeData(theme),
              locale: const Locale('en'),
              localizationsDelegates: [
                ...appLocalizationsDelegates,
                bullUiLocalizationsDelegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: SwapExternalAddressInput()),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Paste'));
        await tester.pumpAndSettle();
        verify(
          () => bloc.add(const TransferEvent.externalAddressChanged(address)),
        ).called(1);
        expect(find.byType(AddressViewer), findsOneWidget);
        final viewer = tester.widget<AddressViewer>(find.byType(AddressViewer));
        expect(viewer.data, address);
        expect(viewer.clipboardText, address);
        expect(
          tester
              .widget<BullPaymentDestinationInput>(
                find.byType(BullPaymentDestinationInput),
              )
              .error,
          isNull,
        );
        final accepted = initial.copyWith(externalAddress: address);
        states.add(accepted);
        await tester.pumpAndSettle();
        expect(
          find.text('Enter or scan a valid Bitcoin address.'),
          findsNothing,
        );
        states.add(
          accepted.copyWith(
            externalAddressError: const SwapInvalidExternalAddressFailure(
              expectsBitcoin: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Please enter a valid Bitcoin address'),
          findsOneWidget,
        );
        states.add(accepted);
        await tester.pumpAndSettle();
        expect(find.text('Please enter a valid Bitcoin address'), findsNothing);
        expect(find.byType(AddressViewer), findsOneWidget);
        expect(
          find.text('Enter or scan a valid Bitcoin address.'),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
