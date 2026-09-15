import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_completion_steps.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'export and checkbox cannot certify a descriptor; an actual copy can',
    (tester) async {
      var saveCalls = 0;
      final confirmed = <String>[];
      final clipboard = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pump(
        tester,
        BullVaultRecoveryPackageStep(
          descriptor: 'public-descriptor-fixture',
          exported: false,
          confirmed: false,
          onSave: () async {
            saveCalls++;
          },
          onConfirm: (text) async {
            confirmed.add(text);
          },
          onImport: () async {},
        ),
      );
      expect(find.byType(CheckboxListTile), findsNothing);
      await tester.tap(find.text('Save recovery data'));
      await tester.pumpAndSettle();
      expect(saveCalls, 1);
      expect(confirmed, isEmpty);
      await tester.tap(find.text(AppLocalizationsEn().copyDialogButton));
      await tester.pumpAndSettle();
      expect(clipboard, ['public-descriptor-fixture']);
      expect(confirmed, ['public-descriptor-fixture']);
    },
  );

  testWidgets('offers hardware setup until the signer is registered', (
    tester,
  ) async {
    WalletSigner? selected;
    final signer = WalletSigner.single(
      masterFingerprint: 'deadbeef',
      xpubFingerprint: 'deadbeef',
      xpub: 'xpub-cold',
      derivationPath: "m/48'/0'/0'/2'",
      descriptorPath: '/<0;1>/*',
      signer: SignerEntity.remote,
      signerDevice: SignerDeviceEntity.ledgerNanoX,
      id: 'cold',
    );

    final otherSigner = WalletSigner.single(
      masterFingerprint: 'cafebabe',
      xpubFingerprint: 'cafebabe',
      xpub: 'xpub-other',
      signer: SignerEntity.remote,
      signerDevice: SignerDeviceEntity.ledgerNanoX,
      id: 'other',
    );
    final title =
        '${SignerDeviceEntity.ledgerNanoX.displayName} · ${signer.displayFingerprint}';
    await _pump(
      tester,
      BullVaultHardwareSetupStep(
        signers: [signer, otherSigner],
        completedSignerIds: const {},
        onSetUp: (value) async => selected = value,
      ),
    );

    expect(find.text(title), findsOneWidget);
    expect(
      find.text(
        '${SignerDeviceEntity.ledgerNanoX.displayName} · ${otherSigner.displayFingerprint}',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(title));
    expect(selected, same(signer));

    selected = null;
    await _pump(
      tester,
      BullVaultHardwareSetupStep(
        signers: [signer],
        completedSignerIds: {signer.id},
        onSetUp: (value) async => selected = value,
      ),
    );
    expect(
      find.text(AppLocalizationsEn().bullVaultHardwareSetupComplete),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
    await tester.tap(find.text(title));
    expect(selected, isNull);
  });

  testWidgets('shows deposit guidance only after setup is complete', (
    tester,
  ) async {
    final localization = AppLocalizationsEn();

    await _pump(tester, const BullVaultReadyStep(hasDeferredSetup: false));
    expect(find.text(localization.bullVaultTestDeposit), findsOneWidget);
    expect(
      find.text(localization.bullVaultDeferredSetupDescription),
      findsNothing,
    );

    await _pump(tester, const BullVaultReadyStep(hasDeferredSetup: true));
    expect(find.text(localization.bullVaultTestDeposit), findsNothing);
    expect(
      find.text(localization.bullVaultDeferredSetupDescription),
      findsOneWidget,
    );
  });
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  ),
);
