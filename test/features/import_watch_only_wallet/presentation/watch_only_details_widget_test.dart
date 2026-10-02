import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_state.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/watch_only_details_widget.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullInputText;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class _MockImportWatchOnlyCubit extends Mock implements ImportWatchOnlyCubit {}

class _MockWatchOnlyDescriptor extends Mock
    implements satoshifier.WatchOnlyDescriptor {}

class _MockDescriptor extends Mock implements satoshifier.Descriptor {}

Future<_MockImportWatchOnlyCubit> _pumpDetails(
  WidgetTester tester, {
  required satoshifier.Network network,
}) async {
  final descriptor = _MockDescriptor();
  when(() => descriptor.network).thenReturn(network);
  when(() => descriptor.combined).thenReturn('wpkh(test)');
  when(() => descriptor.derivation).thenReturn(satoshifier.Derivation.bip84);

  final watchOnlyDescriptor = _MockWatchOnlyDescriptor();
  when(() => watchOnlyDescriptor.descriptor).thenReturn(descriptor);

  final wallet = WatchOnlyWalletEntity.descriptor(
    watchOnlyDescriptor: watchOnlyDescriptor,
    signerDevice: SignerDeviceEntity.seedsigner,
  );
  final cubit = _MockImportWatchOnlyCubit();
  when(
    () => cubit.state,
  ).thenReturn(ImportWatchOnlyState(watchOnlyWallet: wallet));
  when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
  when(() => cubit.import()).thenAnswer((_) async {});

  await tester.pumpWidget(
    BlocProvider<ImportWatchOnlyCubit>.value(
      value: cubit,
      child: MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: WatchOnlyDetailsWidget(watchOnlyWallet: wallet),
          ),
        ),
      ),
    ),
  );

  return cubit;
}

void main() {
  testWidgets('reviews descriptor details and delegates import actions', (
    tester,
  ) async {
    final cubit = await _pumpDetails(
      tester,
      network: satoshifier.Network.bitcoinMainnet,
    );

    expect(find.text('Network: Bitcoin Mainnet'), findsOneWidget);
    expect(find.text('Descriptor'), findsOneWidget);
    expect(find.text('wpkh(test)'), findsOneWidget);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text(satoshifier.Derivation.bip84.label), findsOneWidget);
    expect(find.text('Signing Device'), findsOneWidget);
    expect(
      find.text(SignerDeviceEntity.seedsigner.displayName),
      findsOneWidget,
    );
    expect(find.text('Label'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);

    final labelInput = find.byWidgetPredicate(
      (widget) => widget is BullInputText && !widget.disabled,
    );
    expect(labelInput, findsOneWidget);
    await tester.enterText(
      find.descendant(of: labelInput, matching: find.byType(EditableText)),
      'Savings',
    );
    verify(() => cubit.updateLabel('Savings')).called(1);

    await tester.ensureVisible(find.text('Import'));
    await tester.tap(find.text('Import'));
    verify(() => cubit.import()).called(1);
  });

  for (final (network, label) in [
    (satoshifier.Network.bitcoinTestnet, 'Network: Bitcoin Testnet'),
  ]) {
    testWidgets('shows the localized ${network.name} label', (tester) async {
      await _pumpDetails(tester, network: network);

      expect(find.text(label), findsOneWidget);
    });
  }
}
