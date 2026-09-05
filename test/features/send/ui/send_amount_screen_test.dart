import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSendCubit extends Mock implements SendCubit {}

Wallet _wallet({required int balanceSat}) => Wallet(
  origin: 'wallet-id',
  label: 'Wallet',
  network: Network.bitcoinTestnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(balanceSat),
);

void main() {
  testWidgets('renders after the selected wallet balance refreshes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Device.screen = const Size(390, 844);

    final listedWallet = _wallet(balanceSat: 1000);
    final refreshedSelection = _wallet(balanceSat: 2000);
    final state = SendState(
      step: SendStep.amount,
      sendType: SendType.bitcoin,
      wallets: [listedWallet],
      selectedWallet: refreshedSelection,
      bitcoinUnit: BitcoinUnit.sats,
      inputAmountCurrencyCode: BitcoinUnit.sats.code,
      fiatCurrencyCodes: const ['CAD'],
    );
    final cubit = _MockSendCubit();
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SendCubit>.value(
          value: cubit,
          child: const SendAmountScreen(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });
}
