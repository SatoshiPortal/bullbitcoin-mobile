import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/data_backup_contents.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../wallet_backup/backup_snapshot_fixture.dart';

void main() {
  final loc = AppLocalizationsEn();
  final base = backupSnapshotFixture(
    BackupCredential.fromWords(backupFixtureWords),
  );
  final wallet = base.manifest.wallets.single;
  final snapshot = WalletBackupSnapshot(
    manifest: KeychainManifest(
      sourceFingerprint: base.manifest.sourceFingerprint,
      wallets: [
        BackupWallet(
          reference: wallet.reference,
          network: wallet.network,
          publicDescriptor: wallet.publicDescriptor,
          isDefault: wallet.isDefault,
          isHidden: wallet.isHidden,
          label: wallet.label,
          birthday: wallet.birthday,
          signers: [
            WalletSigner.single(
              masterFingerprint: '1234abcd',
              xpubFingerprint: '8765abcd',
              xpub: 'public-xpub-fixture',
              signer: SignerEntity.local,
              signerDevice: null,
            ),
          ],
        ),
      ],
      derivations: base.manifest.derivations,
      nostrKeys: base.manifest.nostrKeys,
      backupIdentities: base.manifest.backupIdentities,
    ),
    metadata: base.metadata,
    vaults: base.vaults,
  );
  Future<void> pump(
    WidgetTester tester,
    DataBackupContentsSource source,
  ) async {
    await tester.binding.setSurfaceSize(const Size(440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: DataBackupContents(snapshot: snapshot, source: source),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expand(WidgetTester tester, String key) async {
    final tile = find.byKey(ValueKey(key));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  testWidgets('source signer metadata never claims the key is on this device', (
    tester,
  ) async {
    await pump(tester, DataBackupContentsSource.server);
    await tester.tap(find.text('Savings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('1234abcd'));
    await tester.tap(find.text('1234abcd'));
    await tester.pumpAndSettle();
    expect(find.text(loc.bullVaultKeyOnDevice), findsNothing);
    expect(find.text(loc.dataBackupSourceFingerprint), findsOneWidget);
  });
  for (final source in DataBackupContentsSource.values) {
    testWidgets('contents identifies the selected $source copy', (
      tester,
    ) async {
      await pump(tester, source);
      expect(
        find.text(switch (source) {
          DataBackupContentsSource.local => loc.dataBackupSourceLocal,
          DataBackupContentsSource.server => loc.dataBackupSourceServer,
          DataBackupContentsSource.file => loc.dataBackupSourceFile,
        }),
        findsOneWidget,
      );
    });
  }
  testWidgets(
    'all portable settings are visible, including network values and server priority',
    (tester) async {
      await pump(tester, DataBackupContentsSource.server);
      await tester.ensureVisible(find.text(loc.settingsAppSettingsTitle));
      await tester.tap(find.text(loc.settingsAppSettingsTitle));
      await tester.pumpAndSettle();
      expect(find.text(loc.themeDark), findsOneWidget);
      expect(find.text('100000 sats'), findsOneWidget);
      expect(find.text('200000 sats'), findsOneWidget);
      expect(find.text('0.5%'), findsOneWidget);
      expect(find.text('10000 sats'), findsOneWidget);
      expect(find.text('86400 seconds'), findsOneWidget);
      for (final network in [
        'bitcoinMainnet',
        'bitcoinTestnet',
        'liquidMainnet',
        'liquidTestnet',
      ]) {
        await expand(tester, 'data-contents-electrum-$network');
        expect(
          find.byKey(ValueKey('data-contents-electrum-settings-$network')),
          findsOneWidget,
        );
        await expand(tester, 'data-contents-mempool-$network');
        expect(
          find.byKey(ValueKey('data-contents-mempool-settings-$network')),
          findsOneWidget,
        );
      }
      expect(find.text('ssl://electrum.example:50002'), findsOneWidget);
      expect(find.text('https://mempool.example'), findsNWidgets(4));
      expect(find.text('2'), findsWidgets);
    },
  );
  testWidgets(
    'labels retain type and origin and every frozen output keeps wallet attribution',
    (tester) async {
      await pump(tester, DataBackupContentsSource.local);
      await expand(tester, 'data-contents-labels');
      expect(find.text('Invoice'), findsOneWidget);
      expect(find.text('Recipient'), findsOneWidget);
      expect(find.text('a' * 64), findsOneWidget);
      expect(find.text('payjoin'), findsOneWidget);
      await expand(tester, 'data-contents-frozen');
      expect(find.text('${'b' * 64}:3'), findsOneWidget);
      expect(find.text('source-wallet'), findsWidgets);
    },
  );
}
