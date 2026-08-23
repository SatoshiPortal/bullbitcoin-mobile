import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _masterXprv =
    'xprv9s21ZrQH143K2LBWUUQRFXhucrQqBpKdRRxNVq2zBqsx8HVqFk2uYo8kmbaLLHRdqtQpUm98uKfu3vca1LqdGhUtyoFnCNkfmXRyPXLjbKb';

void main() {
  const registry = Bip85RegistryFacade();

  test('locks unique first-party paths and wallet indices', () {
    expect(registry.reservations.map((item) => item.id), [
      'btcpay_wallet_seed',
      'lightning_address_wallet_seed',
      'payment_page_wallet_seed',
      'pos_wallet_seed',
      'nostr_wallet_backup_key',
      'nostr_bullnym_server_auth_key',
      'nostr_nip05_public_nym_verification_key',
      'wallet_backup_encryption_key',
    ]);
    expect(registry.reservedWalletSeedIndices, {100, 101, 102, 103});
    expect(registry.reservedWalletSeedPaths, {
      "39'/0'/12'/100'",
      "39'/0'/12'/101'",
      "39'/0'/12'/102'",
      "39'/0'/12'/103'",
    });
    expect(
      () => registry.reservedWalletSeedIndices.add(104),
      throwsA(isA<UnsupportedError>()),
    );
    expect(
      registry.reservations.map((item) => item.path).toSet(),
      hasLength(registry.reservations.length),
    );
  });

  test('separates user Nostr identities from the app-owned range', () {
    expect(registry.nostrUserKeyPath(1), "128002'/1'/1'");
    expect(registry.nostrUserKeyIdentity("128002'/99'/1'"), 99);
    expect(registry.isNostrUserKeyPath("128002'/200'/1'"), isTrue);
    expect(registry.nostrUserKeyIdentity("128002'/100'/1'"), isNull);
    expect(() => registry.nostrUserKeyPath(100), throwsArgumentError);
    expect(
      registry.reservationByExactPath("1642'/0'/1'")?.id,
      'wallet_backup_encryption_key',
    );
  });

  test('reserved index 100 keeps the pinned BIP85 derivation', () async {
    final database = SqliteDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final datasource = Bip85Datasource(sqlite: database);

    final preview = datasource.deriveMnemonicPreview(
      xprvBase58: _masterXprv,
      length: bip39.MnemonicLength.words12,
      index: registry.btcpayWalletSeed.walletIndex,
    );

    expect(preview.derivation, registry.btcpayWalletSeed.path);
    expect(
      preview.mnemonic.sentence,
      'nurse knock brief chronic category music mosquito sell clean proud useful soon',
    );
  });
}
