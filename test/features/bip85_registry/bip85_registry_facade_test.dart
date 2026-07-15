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

  test('exposes reserved first-party derivations', () {
    expect(registry.reservations, same(registry.reservations));
    expect(registry.reservations.map((reservation) => reservation.id), [
      'btcpay_wallet_seed',
      'lightning_address_wallet_seed',
      'payment_page_wallet_seed',
      'nostr_wallet_manifest_key',
      'nostr_bullnym_server_auth_key',
      'nostr_nip05_public_nym_verification_key',
    ]);
    for (final reservation in registry.reservations) {
      expect(registry.reservationById(reservation.id), same(reservation));
      expect(
        () => reservation.scope.segments.add(
          const Bip85PathSegment(name: 'unexpected', value: 1),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    }
    expect(registry.reservationById('unknown_reservation'), isNull);
    expect(
      () => registry.reservations.add(registry.btcpayWalletSeed),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('models Get Paid receive wallets as BIP39 child mnemonic paths', () {
    final reservations = [
      _walletSeedReservation('btcpay_wallet_seed'),
      _walletSeedReservation('lightning_address_wallet_seed'),
      _walletSeedReservation('payment_page_wallet_seed'),
    ];

    expect(reservations.map((reservation) => reservation.scope.exactPath), [
      "39'/0'/12'/100'",
      "39'/0'/12'/101'",
      "39'/0'/12'/102'",
    ]);
    expect(reservations.map((reservation) => reservation.walletIndex), [
      100,
      101,
      102,
    ]);
    for (final reservation in reservations) {
      expect(reservation.application.number, 39);
      expect(reservation.purpose, Bip85ReservationPurpose.walletSeed);
      expect(reservation.scope.segments.map((segment) => segment.name), [
        'language',
        'words',
        'index',
      ]);
      expect(reservation.scope.segmentValue('language'), 0);
      expect(reservation.scope.segmentValue('words'), 12);
      expect(reservation.scope.segmentValue('index'), reservation.walletIndex);
    }
  });

  test('models Nostr role keys as index-free reserved policy only', () {
    final reservations = [
      _keyReservation('nostr_wallet_manifest_key'),
      _keyReservation('nostr_bullnym_server_auth_key'),
      _keyReservation('nostr_nip05_public_nym_verification_key'),
    ];

    expect(reservations.map((reservation) => reservation.scope.exactPath), [
      "9000'/1'/1'",
      "9000'/2'/1'",
      "9000'/3'/1'",
    ]);
    expect(
      reservations.map(
        (reservation) => reservation.scope.segmentValue('identity'),
      ),
      [1, 2, 3],
    );
    for (final reservation in reservations) {
      expect(reservation.owner, Bip85ReservationOwner.nostr);
      expect(reservation.purpose, Bip85ReservationPurpose.nonWalletNostrKey);
      expect(reservation.application.number, 9000);
      expect(reservation.scope.segments.map((segment) => segment.name), [
        'identity',
        'account',
      ]);
      expect(reservation.scope.segmentValue('account'), 1);
      // Key reservations carry no wallet index; even asking for one is a
      // programming error rather than a value.
      expect(() => reservation.scope.segmentValue('index'), throwsStateError);
    }
  });

  test('rejects mis-shaped reservation scopes at construction', () {
    expect(
      () => Bip85WalletSeedReservation(
        id: 'malformed_wallet_seed',
        deterministicAlias: 'Malformed',
        owner: Bip85ReservationOwner.btcpay,
        application: const Bip85ApplicationSpec(number: 39),
        segments: const [Bip85PathSegment(name: 'language', value: 0)],
      ),
      throwsArgumentError,
    );
    expect(
      () => Bip85KeyReservation(
        id: 'malformed_key',
        deterministicAlias: 'Malformed',
        owner: Bip85ReservationOwner.nostr,
        purpose: Bip85ReservationPurpose.nonWalletNostrKey,
        application: const Bip85ApplicationSpec(number: 9000),
        segments: const [Bip85PathSegment(name: 'index', value: 1)],
      ),
      throwsArgumentError,
    );
    expect(
      () => Bip85KeyReservation(
        id: 'malformed_purpose',
        deterministicAlias: 'Malformed',
        owner: Bip85ReservationOwner.nostr,
        purpose: Bip85ReservationPurpose.walletSeed,
        application: const Bip85ApplicationSpec(number: 9000),
        segments: const [Bip85PathSegment(name: 'identity', value: 1)],
      ),
      throwsArgumentError,
    );
  });

  test('keeps reservation ids and exact paths unique', () {
    final ids = registry.reservations.map((reservation) => reservation.id);
    final paths = registry.reservations.map(
      (reservation) => reservation.scope.exactPath,
    );

    expect(ids.toSet(), hasLength(registry.reservations.length));
    expect(paths.toSet(), hasLength(registry.reservations.length));
  });

  test('exposes the reserved wallet-seed exclusion sets for the allocator', () {
    // The dev screen and the next-index allocator consume these to never
    // allocate, re-derive, or expose a product spend seed (KI-1/KI-2). The set
    // is registry-driven: adding the LN (101) and Payment Page (102) wallet
    // seeds must extend it automatically, with no allocator change (R2-KI1b).
    final indices = registry.reservedWalletSeedIndices;
    final paths = registry.reservedWalletSeedPaths;
    expect(indices, {100, 101, 102});
    expect(paths, {"39'/0'/12'/100'", "39'/0'/12'/101'", "39'/0'/12'/102'"});
    expect(() => indices.add(103), throwsA(isA<UnsupportedError>()));
    expect(
      () => paths.add("39'/0'/12'/103'"),
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

  test('all reserved wallet paths match datasource derivations', () async {
    final database = SqliteDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final datasource = Bip85Datasource(sqlite: database);

    for (final reservation in [
      _walletSeedReservation('btcpay_wallet_seed'),
      _walletSeedReservation('lightning_address_wallet_seed'),
      _walletSeedReservation('payment_page_wallet_seed'),
    ]) {
      final preview = await datasource.deriveMnemonicPreview(
        xprvBase58: _masterXprv,
        length: bip39.MnemonicLength.words12,
        index: reservation.walletIndex,
      );
      expect(preview.derivation, reservation.scope.exactPath);
    }
  });
}

Bip85WalletSeedReservation _walletSeedReservation(String id) {
  const registry = Bip85RegistryFacade();
  final reservation = registry.reservationById(id);
  expect(reservation, isA<Bip85WalletSeedReservation>());
  return reservation! as Bip85WalletSeedReservation;
}

Bip85KeyReservation _keyReservation(String id) {
  const registry = Bip85RegistryFacade();
  final reservation = registry.reservationById(id);
  expect(reservation, isA<Bip85KeyReservation>());
  return reservation! as Bip85KeyReservation;
}
