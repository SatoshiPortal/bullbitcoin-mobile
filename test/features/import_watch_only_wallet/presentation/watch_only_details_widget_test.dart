import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'dart:async';
import 'package:bb_mobile/features/wallet_sync/public/wallet_sync_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
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

class _Choices extends Fake implements WalletSyncFacade {
  final pending = Completer<WalletSyncSelection?>();
  int calls = 0;

  @override
  Future<WalletSyncSelection?> choose(
    BuildContext context, {
    BitcoinNetwork? network,
    bool askScriptType = false,
    WalletSyncSelection initial = const WalletSyncSelection(),
    bool changingSource = false,
  }) {
    calls++;
    return pending.future;
  }
}

Future<_MockImportWatchOnlyCubit> _pumpDetails(
  WidgetTester tester, {
  required satoshifier.Network network,
}) async {
  locator.registerSingleton<WalletSyncFacade>(_Choices());
  final descriptor = _MockDescriptor();
  when(() => descriptor.network).thenReturn(network);
  when(() => descriptor.combined).thenReturn('wpkh(test)');
  when(() => descriptor.derivation).thenReturn(satoshifier.Derivation.bip84);

  final watchOnlyDescriptor = _MockWatchOnlyDescriptor();
  when(() => watchOnlyDescriptor.descriptor).thenReturn(descriptor);

  final wallet = WatchOnlyWalletEntity.descriptor(
    watchOnlyDescriptor: watchOnlyDescriptor,
    signerDevice: SignerDeviceEntity.seedsigner,
    label: 'Public fixture',
  );
  final cubit = _MockImportWatchOnlyCubit();
  when(
    () => cubit.state,
  ).thenReturn(ImportWatchOnlyState(watchOnlyWallet: wallet));
  when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
  when(() => cubit.isClosed).thenReturn(false);
  when(() => cubit.import()).thenAnswer((_) async {});
  when(() => cubit.validateImport()).thenAnswer((_) async => true);

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
  setUp(() async {
    await locator.reset();
  });
  tearDown(locator.reset);
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
    await tester.pump();
    verifyNever(() => cubit.import());
    final choices = locator<WalletSyncFacade>();
    if (choices is _Choices) {
      expect(choices.calls, 1);
      choices.pending.complete(const WalletSyncSelection());
    }
    await tester.pumpAndSettle();
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

  testWidgets('changing the key while choosing sync cancels the old import', (
    tester,
  ) async {
    final cubit = await _pumpDetails(
      tester,
      network: satoshifier.Network.bitcoinMainnet,
    );
    await tester.ensureVisible(find.text('Import'));
    await tester.tap(find.text('Import'));
    await tester.pump();
    final choices = locator<WalletSyncFacade>();
    when(() => cubit.state).thenReturn(const ImportWatchOnlyState());
    if (choices is _Choices) {
      choices.pending.complete(const WalletSyncSelection());
    }
    await tester.pumpAndSettle();
    verifyNever(() => cubit.import());
  });
}
