import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/wallet_metadata_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/wallet_recovery_manifest_screen.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows each wallet recovery classification without identifiers', (
    tester,
  ) async {
    await _pump(
      tester,
      WalletRecoveryManifestScreen(
        wallets: [
          const WalletBackupWalletSummary(
            label: 'Main wallet',
            network: Network.bitcoinMainnet,
            provenance: WalletProvenance.defaultSeed,
            seedPassphraseUsed: true,
          ),
          const WalletBackupWalletSummary(
            network: Network.bitcoinMainnet,
            provenance: WalletProvenance.bip85,
          ),
          const WalletBackupWalletSummary(
            network: Network.bitcoinMainnet,
            provenance: WalletProvenance.importedMnemonic,
          ),
          const WalletBackupWalletSummary(
            network: Network.liquidMainnet,
            provenance: WalletProvenance.watchOnly,
          ),
          const WalletBackupWalletSummary(
            network: Network.bitcoinMainnet,
            provenance: WalletProvenance.externalSigner,
            signerDevice: SignerDeviceEntity.jade,
          ),
        ],
      ),
    );

    expect(find.text('Main wallet'), findsOneWidget);
    expect(find.text('Main seed'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump();
    expect(find.text('Imported mnemonic wallet'), findsOneWidget);
    expect(find.text('Unknown'), findsWidgets);
    expect(find.text('Not included for Liquid yet'), findsOneWidget);
    expect(find.text('Jade'), findsOneWidget);
    expect(find.textContaining('wpkh('), findsNothing);
  });

  testWidgets('shows metadata counts and states what is excluded', (
    tester,
  ) async {
    await _pump(
      tester,
      WalletMetadataScreen(
        metadata: [
          WalletBackupMetadataSummary(
            recordType: 'labels.bip329',
            recordCount: 3,
          ),
          WalletBackupMetadataSummary(
            recordType: 'wallet.preferences',
            recordCount: 2,
          ),
          WalletBackupMetadataSummary(
            recordType: 'wallet.utxo_freeze',
            recordCount: 1,
          ),
        ],
      ),
    );

    expect(find.text('Labels'), findsOneWidget);
    expect(find.text('Wallet preferences'), findsOneWidget);
    expect(find.text('Frozen coin state'), findsOneWidget);
    expect(
      find.textContaining('Balances and transaction history'),
      findsOneWidget,
    );
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    ),
  );
  await tester.pump();
}
