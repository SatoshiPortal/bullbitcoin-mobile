import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_completion_steps.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saves recovery data before confirmation', (tester) async {
    var saveCalls = 0;
    var confirmCalls = 0;
    final localization = AppLocalizationsEn();

    await _pump(
      tester,
      BullVaultRecoveryPackageStep(
        exported: false,
        confirmed: false,
        onSave: () async => saveCalls++,
        onConfirm: () async => confirmCalls++,
      ),
    );

    expect(find.text('Save recovery data'), findsOneWidget);
    expect(
      find.text(localization.bullVaultRecoveryPackageConfirmation),
      findsNothing,
    );

    await tester.tap(find.text('Save recovery data'));
    expect(saveCalls, 1);

    await _pump(
      tester,
      BullVaultRecoveryPackageStep(
        exported: true,
        confirmed: false,
        onSave: () async => saveCalls++,
        onConfirm: () async => confirmCalls++,
      ),
    );
    await tester.tap(
      find.text(localization.bullVaultRecoveryPackageConfirmation),
    );
    expect(confirmCalls, 1);
  });

  testWidgets('starts hardware setup for the selected signer', (tester) async {
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

    await _pump(
      tester,
      BullVaultHardwareSetupStep(
        signers: [signer],
        completedSignerIds: const {},
        onSetUp: (value) async => selected = value,
      ),
    );

    expect(
      find.text(SignerDeviceEntity.ledgerNanoX.displayName),
      findsOneWidget,
    );
    await tester.tap(find.text(SignerDeviceEntity.ledgerNanoX.displayName));
    expect(selected, same(signer));
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
