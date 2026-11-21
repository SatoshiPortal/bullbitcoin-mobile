import 'package:bb_mobile/features/wallet/data/ark_funding_signing_guard.dart';
import 'package:bb_mobile/features/wallet/data/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/features/wallet/data/payjoin_wallet_adapter.dart';
import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_spend_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart';

import 'ark_funding_test_fixture.dart';

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Values extends Mock implements SyncWalletValuesDatasource {}

class _CheckingStorage extends FakeSecureStoragePlatform {
  final bool Function() markerCommitted;
  bool sawCommittedMarker = false;
  _CheckingStorage(this.markerCommitted);
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    expect(
      markerCommitted(),
      isTrue,
      reason: 'possible handoff must commit before the first Secrets read',
    );
    sawCommittedMarker = true;
    return super.read(key: key, options: options);
  }
}

void main() {
  late FundingFixture fixture;
  late _Metadata metadata;
  late FakeSecureStoragePlatform keystore;
  late ArkFundingSigningGuard guard;
  int nativeAccesses = 0;

  BitcoinWalletRepository generic() => BitcoinWalletRepository(
    walletMetadataDatasource: metadata,
    secrets: Secrets(scratchDirectory: () async => fixture.directory.path),
    wallet: (_) async => throw StateError('no native access expected'),
    walletValuesDatasource: _Values(),
    arkFundingGuard: guard,
  );
  PayjoinWalletAdapter payjoin() => PayjoinWalletAdapter(
    Secrets(scratchDirectory: () async => fixture.directory.path),
    (_) async {
      nativeAccesses++;
      throw StateError('annotation must not occur');
    },
    (_) async => BitcoinSpendStatus.ready,
    _Values(),
    metadata,
    guard,
  );
  setUp(() {
    fixture = FundingFixture();
    metadata = _Metadata();
    nativeAccesses = 0;
    keystore = FakeSecureStoragePlatform().install();
    guard = ArkFundingSigningGuard(Ok(fixture.store));
    when(() => metadata.fetch(any())).thenAnswer(
      (i) async =>
          fundingMetadata.copyWith(id: i.positionalArguments.single as String),
    );
  });
  tearDown(() => fixture.close());

  for (final variant in ['exact', 'changed-txid-overlap', 'wallet-alias']) {
    test(
      'both ordinary signing channels refuse Ark $variant before Secrets',
      () async {
        await fixture.reserve('ark');
        final encoded = variant == 'changed-txid-overlap'
            ? otherUnsignedTransaction()
            : publicFundingPsbt;
        sourceOk(inspectBitcoinPsbt(encoded));
        final id = variant == 'wallet-alias' ? 'alias' : fundingWalletId;
        await expectLater(
          generic().signPsbt(encoded, walletId: id),
          throwsA(isA<WalletSpendBlockedException>()),
        );
        await expectLater(
          payjoin().signPsbt(
            walletId: id,
            network: BitcoinNetwork.regtest,
            psbt: encoded,
          ),
          throwsA(isA<PayjoinSpendBlockedException>()),
        );
        expect(keystore.reads, 0);
        expect(nativeAccesses, 0);
      },
    );
  }
  test(
    'unavailable authority blocks both signers rather than bypassing the guard',
    () async {
      guard = const ArkFundingSigningGuard(Err(SyncStorageFailure()));
      await expectLater(
        generic().signPsbt(publicFundingPsbt, walletId: fundingWalletId),
        throwsA(isA<WalletSpendBlockedException>()),
      );
      await expectLater(
        payjoin().signPsbt(
          walletId: fundingWalletId,
          network: BitcoinNetwork.regtest,
          psbt: publicFundingPsbt,
        ),
        throwsA(isA<PayjoinSpendBlockedException>()),
      );
      expect(keystore.reads, 0);
      expect(nativeAccesses, 0);
    },
  );
  test('ordinary unrelated signer reaches real Secrets only after the exact marker commits', () async {
    final checking = _CheckingStorage(() {
      final db = sqlite3.open(fixture.path);
      try {
        return db.select(
              'SELECT txid FROM ark_ordinary_signing WHERE network=?',
              ['regtest'],
            ).length ==
            1;
      } finally {
        db.close();
      }
    })..install();
    // The real Secrets finds no stored seed and fails. No fake signer is used.
    await expectLater(
      generic().signPsbt(publicFundingPsbt, walletId: fundingWalletId),
      throwsException,
    );
    expect(checking.sawCommittedMarker, isTrue);
    expect(checking.reads, greaterThan(0));
  });
  test('marker persistence contention cannot reach the key store', () async {
    final db = sqlite3.open(fixture.path);
    try {
      db.execute('BEGIN IMMEDIATE');
      await expectLater(
        generic().signPsbt(publicFundingPsbt, walletId: fundingWalletId),
        throwsA(isA<WalletSpendBlockedException>()),
      );
      expect(keystore.reads, 0);
      db.execute('ROLLBACK');
    } finally {
      db.close();
    }
  });
}
