import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Public master key from the official BIP85 test vectors.
const _masterXprv =
    'xprv9s21ZrQH143K2LBWUUQRFXhucrQqBpKdRRxNVq2zBqsx8HVqFk2uYo8kmbaLLHRdqtQpUm98uKfu3vca1LqdGhUtyoFnCNkfmXRyPXLjbKb';

void main() {
  const registry = Bip85RegistryFacade();

  test('publishes one immutable BTCPay wallet-seed reservation', () {
    final reservation = registry.btcpayWalletSeed;

    expect(registry.reservations, same(registry.reservations));
    expect(registry.reservations, [same(reservation)]);
    expect(reservation.id, 'btcpay_wallet_seed');
    expect(reservation.owner, Bip85ReservationOwner.btcpay);
    expect(reservation.purpose, Bip85ReservationPurpose.walletSeed);
    expect(reservation.application.number, 39);
    expect(reservation.scope.segmentValue('language'), 0);
    expect(reservation.scope.segmentValue('words'), 12);
    expect(reservation.walletIndex, 100);
    expect(reservation.scope.exactPath, "39'/0'/12'/100'");
    expect(registry.reservationById(reservation.id), same(reservation));
    expect(registry.reservationById('unknown'), isNull);

    expect(
      () => registry.reservations.add(reservation),
      throwsA(isA<UnsupportedError>()),
    );
    expect(
      () => reservation.scope.segments.add(
        const Bip85PathSegment(name: 'unexpected', value: 1),
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('publishes immutable wallet-seed exclusion sets', () {
    final indices = registry.reservedWalletSeedIndices;
    final paths = registry.reservedWalletSeedPaths;

    expect(indices, {100});
    expect(paths, {"39'/0'/12'/100'"});
    expect(() => indices.add(101), throwsA(isA<UnsupportedError>()));
    expect(
      () => paths.add("39'/0'/12'/101'"),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('index 100 encodes and derives the pinned reserved mnemonic', () async {
    final database = SqliteDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final datasource = Bip85Datasource(sqlite: database);
    final reservation = registry.btcpayWalletSeed;

    final preview = await datasource.deriveMnemonicPreview(
      xprvBase58: _masterXprv,
      length: bip39.MnemonicLength.words12,
      index: reservation.walletIndex,
    );

    expect(preview.derivation, reservation.scope.exactPath);
    expect(
      preview.mnemonic.sentence,
      'nurse knock brief chronic category music mosquito sell clean proud '
      'useful soon',
    );
    expect(await datasource.fetch(preview.derivation), isNull);
  });
}
