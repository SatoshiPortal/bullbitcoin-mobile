import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_vaults_model.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_vault_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_bullvault_backup.dart';

void main() {
  const codec = WalletBackupVaultsCodec(inspect: fakeVaultInspector);

  test('round-trips entries and orders them lineage then generation', () {
    final encoded = codec.encode([
      fakeVaultEntry(walletRef: 'b-1', lineageId: 'b', vaultGeneration: 1),
      fakeVaultEntry(walletRef: 'a-1', lineageId: 'a', vaultGeneration: 1),
      fakeVaultEntry(
        walletRef: 'a-0',
        lineageId: 'a',
        vaultGeneration: 0,
        status: 'migrating',
        label: 'Everyday',
      ),
    ]);

    final decoded = codec.decode(encoded);

    expect(decoded.map((entry) => entry.walletRef), ['a-0', 'a-1', 'b-1']);
    expect(decoded.first.label, 'Everyday');
    expect(decoded.first.status, 'migrating');
    expect(codec.encode(decoded), encoded);
  });

  test('carries the package bytes verbatim', () {
    final entry = fakeVaultEntry(walletRef: 'v', lineageId: 'l');
    final decoded = codec.decode(codec.encode([entry])).single;

    expect(decoded.recoveryPackage, entry.recoveryPackage);
  });

  test('rejects a package the vault feature does not recognise', () {
    const unknown = WalletBackupVaultsCodec(inspect: noVaultInspector);
    final encoded = codec.encode([fakeVaultEntry(walletRef: 'v')]);

    expect(() => unknown.decode(encoded), throwsA(isA<FormatException>()));
  });

  test('rejects framing facts that disagree with the package', () {
    final encoded = codec.encode([
      fakeVaultEntry(walletRef: 'v', lineageId: 'real', vaultGeneration: 2),
    ]);

    expect(
      () => codec.decode(
        encoded.replaceFirst('"vaultGeneration":2', '"vaultGeneration":3'),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => codec.decode(
        encoded.replaceFirst(
          '"network":"bitcoinMainnet","lineageId"',
          '"network":"bitcoinTestnet","lineageId"',
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects duplicate wallet refs, unknown fields and too many vaults', () {
    expect(
      () => codec.encode([
        fakeVaultEntry(walletRef: 'v', lineageId: 'a'),
        fakeVaultEntry(walletRef: 'v', lineageId: 'b'),
      ]),
      throwsA(isA<FormatException>()),
    );
    final encoded = codec.encode([fakeVaultEntry(walletRef: 'v')]);
    expect(
      () =>
          codec.decode(encoded.replaceFirst('"status"', '"extra":1,"status"')),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => codec.encode([
        for (
          var index = 0;
          index <= WalletBackupVaultsCodec.maxEntries;
          index++
        )
          fakeVaultEntry(walletRef: 'v-$index', lineageId: 'l-$index'),
      ]),
      throwsA(isA<FormatException>()),
    );
  });

  test('an entry keeps only public facts and bounds its package', () {
    expect(
      () => WalletBackupVaultEntry(
        walletRef: 'v',
        status: 'active',
        network: Network.bitcoinMainnet,
        lineageId: 'l',
        vaultGeneration: 0,
        recoveryPackage: 'x' * (WalletBackupVaultEntry.maxPackageLength + 1),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
