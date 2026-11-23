import 'dart:io';
import 'dart:typed_data';

import 'package:backup_storage/backup_storage.dart';
import 'package:backup_metadata/backup_metadata_ui.dart';
import 'package:backup_metadata/backup_metadata.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show
        Brightness,
        MaterialApp,
        NavigatorState,
        RoundedRectangleBorder,
        Size,
        ThemeData,
        showDialog,
        showModalBottomSheet;

void _noop() {}
void _ignore<T>(T value) {}

void main() {
  setUpAll(() async {
    final font = [
      File('assets/fonts/GolosText.ttf'),
      File('../../assets/fonts/GolosText.ttf'),
    ].firstWhere((file) => file.existsSync());
    await (FontLoader(
      BullTypography.fontFamily,
    )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final dark in [false, true]) {
    for (final scenario in [
      'intro_android',
      'intro_ios',
      'wallets',
      'status_up_to_date',
      'status_waiting',
      'status_reconnect',
      'turn_off',
      'restore_prompt_android',
      'restore_prompt_ios',
      'restore_preview',
      'restore_done',
      'restore_partial',
    ]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('$scenario $mode golden and accessible targets', (
        tester,
      ) async {
        await _pump(tester, dark, scenario);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/${scenario}_$mode.png'),
        );
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });
    }
  }

  testWidgets('restore preserves local choices unless explicitly changed', (
    tester,
  ) async {
    final choices = <ConflictResolution>[];
    await _pump(tester, false, 'restore_preview', onChoose: choices.add);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Keep « Rent »')),
      isSemantics(
        label: 'Keep « Rent »',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.text('Use backup « Rent October »'));
    expect(choices, [ConflictResolution.useBackup]);
  });

  testWidgets('deleting previous backups starts unchecked', (tester) async {
    final choices = <bool>[];
    await _pump(tester, false, 'turn_off', onDeleteChanged: choices.add);
    final checkbox = find.bySemanticsLabel('Also delete the backups');
    expect(
      tester.getSemantics(checkbox),
      isSemantics(hasCheckedState: true, isChecked: false, hasTapAction: true),
    );
    expect(choices, isEmpty);

    await tester.tap(checkbox);
    expect(choices, [true]);
  });

  testWidgets(
    'restore prompt falls back to English in an untranslated locale',
    (tester) async {
      await _pump(
        tester,
        false,
        'restore_prompt_android',
        locale: const Locale('es'),
      );
      expect(find.text('Restore your labels?'), findsOneWidget);
      expect(find.text('Look in iCloud'), findsNothing);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  bool dark,
  String scenario, {
  Locale locale = const Locale('en'),
  ValueChanged<ConflictResolution> onChoose = _ignore,
  ValueChanged<bool> onDeleteChanged = _ignore,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final colors = dark
      ? testBullTheme.copyWith(
          background: const Color(0xff000000),
          surface: const Color(0xff1c1c1e),
          surfaceContainer: const Color(0xff2c2c2e),
          surfaceContainerHighest: const Color(0xff3c3c3e),
          secondary: const Color(0xffffffff),
          onSecondary: const Color(0xff15171c),
          onSurface: const Color(0xffffffff),
          text: const Color(0xffffffff),
          textMuted: const Color(0xff8e8e93),
          border: const Color(0xff58585a),
          outline: const Color(0xff58585a),
        )
      : testBullTheme;
  final type = BullTypography.standard.resolved(colors.text);
  final brightness = dark ? Brightness.dark : Brightness.light;
  final controller = GlobalKey<NavigatorState>();
  final view = _view(
    scenario,
    colors,
    onChoose,
    onDeleteChanged: onDeleteChanged,
  );
  final isDialog = scenario == 'turn_off';
  final isSheet = scenario.startsWith('restore_prompt');
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: controller,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: const [
        backupMetadataLocalizationsDelegate,
        ...bullUiLocalizationsDelegates,
      ],
      theme: ThemeData(
        platform: scenario.endsWith('ios')
            ? TargetPlatform.iOS
            : TargetPlatform.android,
        brightness: brightness,
        fontFamily: BullTypography.fontFamily,
        textTheme: type.toTextTheme(),
        extensions: bullUiExtensions(
          colors: colors,
          brightness: brightness,
          typography: type,
        ),
      ),
      home: isDialog
          ? _view('status_up_to_date', colors, onChoose)
          : isSheet
          ? BullSuccessScreen(
              title: 'Recovery',
              headline: 'Wallet recovered',
              onClose: _noop,
            )
          : view,
    ),
  );
  if (controller.currentContext case final context?) {
    if (isDialog) {
      showDialog<void>(
        context: context,
        barrierColor: colors.overlay.withValues(alpha: dark ? 0.6 : 0.45),
        builder: (_) => view,
      );
    } else if (isSheet) {
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: colors.background,
        barrierColor: colors.overlay.withValues(alpha: dark ? 0.6 : 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BullShapes.standard.sheet),
          ),
        ),
        builder: (_) => view,
      );
    }
  }
  await tester.pumpAndSettle();
}

Widget _view(
  String scenario,
  BullTheme colors,
  ValueChanged<ConflictResolution> onChoose, {
  ValueChanged<bool> onDeleteChanged = _ignore,
}) {
  if (scenario.startsWith('intro')) {
    return BackupMetadataIntroView(
      destinations: [
        BackupDestination.googleDrive,
        if (scenario.endsWith('ios')) BackupDestination.iCloud,
        BackupDestination.folder,
      ],
      selected: BackupDestination.googleDrive,
      onSelect: _ignore,
      onBack: _noop,
      onContinue: _noop,
    );
  }
  if (scenario.startsWith('status')) {
    final status = switch (scenario) {
      'status_waiting' => BackupMetadataStatus.changesWaiting,
      'status_reconnect' => BackupMetadataStatus.actionNeeded,
      _ => BackupMetadataStatus.upToDate,
    };
    return BackupMetadataStatusView(
      status: status,
      detail: switch (status) {
        BackupMetadataStatus.upToDate => 'Handed to Google Drive 2 min ago',
        BackupMetadataStatus.changesWaiting =>
          'Saved as soon as the phone is online. Last backup 2 h ago.',
        BackupMetadataStatus.actionNeeded =>
          'BULL can’t reach your Google Drive anymore. '
              '5 changes are kept on this phone until you reconnect.',
      },
      changesWaiting: 3,
      groups: [
        BackupMetadataGroupStatus(
          color: colors.onTertiary,
          name: 'Secure Bitcoin · Instant Payments',
          detail: '128 labels · previous version kept',
        ),
        BackupMetadataGroupStatus(
          color: colors.onTertiary,
          name: 'Savings',
          detail: '12 labels · previous version kept',
        ),
      ],
      walletTotal: 3,
      destination: BackupDestination.googleDrive,
      onBack: _noop,
      onReconnect: _noop,
      onBackUpNow: _noop,
      onWallets: _noop,
      onDestination: _noop,
      onRestore: _noop,
      onTurnOff: _noop,
    );
  }
  if (scenario.startsWith('restore_prompt')) {
    return BackupMetadataRestorePromptSheet(
      onLookInDrive: _noop,
      onLookInICloud: scenario.endsWith('ios') ? _noop : null,
      onChooseFile: _noop,
      onNotNow: _noop,
    );
  }
  return switch (scenario) {
    'wallets' => BackupMetadataWalletsView(
      rows: [
        BackupMetadataWalletRow(
          name: 'Secure Bitcoin · Instant Payments',
          subtitle: 'Same recovery phrase · 128 labels',
          color: colors.onTertiary,
          included: true,
          onChanged: _ignore,
        ),
        BackupMetadataWalletRow(
          name: 'Savings',
          subtitle: 'Imported phrase · 12 labels',
          color: colors.onTertiary,
          included: true,
          seedBackupVerified: false,
          onChanged: _ignore,
          onTestBackup: _noop,
        ),
        BackupMetadataWalletRow(
          name: 'Coldcard',
          subtitle: 'Watch-only · 40 labels',
          color: colors.secondary,
          included: false,
          watchOnly: true,
          onChanged: _ignore,
        ),
        BackupMetadataWalletRow(
          name: 'Silent Payments',
          subtitle: '',
          color: colors.onTertiary,
          included: false,
          supported: false,
        ),
      ],
      unattributedLabelCount: 2,
      onBack: _noop,
      onTurnOn: _noop,
    ),
    'turn_off' => BackupMetadataTurnOffDialog(
      deleteBackups: false,
      onDeleteBackupsChanged: onDeleteChanged,
      onCancel: _noop,
      onTurnOff: _noop,
    ),
    'restore_preview' => BackupMetadataRestorePreviewView(
      groupName: 'Secure Bitcoin · Instant Payments',
      destination: BackupDestination.googleDrive,
      versions: const [
        BackupMetadataVersionRow(
          title: 'Latest · Nov 19, 14:02',
          selected: true,
          onSelect: _noop,
        ),
        BackupMetadataVersionRow(
          title: 'Previous · Nov 18, 09:40',
          selected: false,
          onSelect: _noop,
        ),
      ],
      differences: [
        BackupMetadataDifference(
          title: 'Transaction 4f2a…91c0',
          localLabel: 'Rent',
          backupLabel: 'Rent October',
          onChoose: onChoose,
        ),
        BackupMetadataDifference(
          title: 'Address bc1q…7k3m',
          localLabel: 'Exchange',
          backupLabel: 'Bull withdrawal',
          choice: ConflictResolution.useBackup,
          onChoose: onChoose,
        ),
      ],
      labelsToAdd: 96,
      coinsToFreeze: 3,
      alreadySame: 30,
      onBack: _noop,
      onRestore: _noop,
    ),
    'restore_done' => const BackupMetadataRestoreResultView(
      labelsRestored: 98,
      differencesResolved: 2,
      coinsFrozen: 3,
      onDone: _noop,
      onEnableBackup: _noop,
    ),
    'restore_partial' => const BackupMetadataRestoreResultView(
      labelsRestored: 98,
      differencesResolved: 2,
      coinsFrozen: 0,
      coinsPending: 3,
      onDone: _noop,
      onRetryFreezes: _noop,
    ),
    _ => throw ArgumentError.value(scenario),
  };
}
