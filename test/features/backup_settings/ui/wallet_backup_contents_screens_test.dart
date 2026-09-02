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

import '../../wallet_backup/metadata/support/portable_settings_fixture.dart';

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
            keysOnDevice: true,
            derivationPath: "m/84'/0'/0'",
            seedPassphraseUsed: true,
          ),
          const WalletBackupWalletSummary(
            network: Network.bitcoinMainnet,
            provenance: WalletProvenance.bip85,
            keysOnDevice: true,
            derivationPath: "39'/0'/12'/101'",
          ),
          const WalletBackupWalletSummary(
            network: Network.bitcoinMainnet,
            provenance: WalletProvenance.defaultSeedPassphrase,
            keysOnDevice: false,
            derivationPath: "m/84'/0'/0'",
            seedPassphraseUsed: true,
          ),
          const WalletBackupWalletSummary(
            label: 'Instant Payments',
            network: Network.liquidMainnet,
            provenance: WalletProvenance.defaultSeed,
            keysOnDevice: true,
            derivationPath: "m/84'/1776'/0'",
            seedPassphraseUsed: false,
          ),
          const WalletBackupWalletSummary(
            network: Network.bitcoinMainnet,
            provenance: WalletProvenance.importedMnemonic,
            keysOnDevice: false,
            derivationPath: "m/84'/0'/0'",
          ),
          const WalletBackupWalletSummary(
            network: Network.bitcoinMainnet,
            provenance: WalletProvenance.watchOnly,
            keysOnDevice: false,
            descriptor: 'wpkh([12345678/84h/0h/0h]xpub-example/<0;1>/*)',
          ),
          const WalletBackupWalletSummary(
            network: Network.bitcoinMainnet,
            provenance: WalletProvenance.externalSigner,
            keysOnDevice: false,
            descriptor: 'wpkh([87654321/84h/0h/0h]xpub-signer/<0;1>/*)',
            signerDevice: SignerDeviceEntity.jade,
          ),
        ],
      ),
    );

    expect(find.text('Main wallet'), findsOneWidget);
    expect(find.text('Bitcoin Network'), findsWidgets);
    expect(find.text('On this device'), findsWidgets);
    expect(find.text('On this device but requires passphrase'), findsOneWidget);
    expect(find.text("m/84'/0'/0'"), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Instant Payments'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Instant Payments'), findsOneWidget);
    expect(find.text("m/84'/1776'/0'"), findsOneWidget);
    expect(find.text('Liquid Network'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Imported mnemonic wallet'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Imported mnemonic wallet'), findsOneWidget);
    expect(find.text('Original mnemonic required'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Jade'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Jade'), findsOneWidget);
    expect(find.text('Descriptor'), findsWidgets);
    expect(find.text('View'), findsWidgets);
    expect(find.text('Receive descriptor'), findsNothing);
    expect(find.text('Change descriptor'), findsNothing);
    expect(find.textContaining('Included in Bull backup'), findsNothing);
  });

  testWidgets('shows metadata counts and states what is excluded', (
    tester,
  ) async {
    await _pump(
      tester,
      WalletMetadataScreen(
        contents: WalletBackupContents(
          labelCount: 3,
          walletPreferenceCount: 2,
          frozenCoinCount: 1,
          settings: portableSettingsFixture(),
        ),
      ),
    );

    expect(find.text('Labels'), findsOneWidget);
    expect(find.text('Wallet preferences'), findsOneWidget);
    expect(find.text('Frozen coin state'), findsOneWidget);
    expect(find.text('App settings'), findsOneWidget);
    expect(find.textContaining('sats · USD · English · Dark'), findsOneWidget);
    expect(find.text('Electrum Server Settings'), findsOneWidget);
    expect(find.textContaining('Default Servers'), findsOneWidget);
    expect(find.text('Payjoin'), findsOneWidget);
    const excluded =
        'Balances and transaction history are rebuilt from the network and '
        'are not stored in this backup.';
    expect(find.text(excluded), findsWidgets);
  });

  testWidgets('keeps external descriptors shortened until View and Copy', (
    tester,
  ) async {
    const descriptor =
        'wpkh([12345678/84h/0h/0h]xpub-a-deliberately-long-public-key/<0;1>/*)';
    await _pump(
      tester,
      const WalletRecoveryManifestScreen(
        wallets: [
          WalletBackupWalletSummary(
            network: Network.bitcoinMainnet,
            provenance: WalletProvenance.watchOnly,
            keysOnDevice: false,
            descriptor: descriptor,
          ),
        ],
      ),
    );

    expect(find.text(descriptor), findsNothing);
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(find.text(descriptor), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
