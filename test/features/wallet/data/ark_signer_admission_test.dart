import 'dart:convert';
import 'dart:io';

import 'package:ark/funding.dart';
import 'package:transactions/testing.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart';

import 'ark_funding_test_fixture.dart';

class _Inventory extends Mock implements WalletInventory {}

void main() {
  late FundingFixture fixture;
  late _Inventory inventory;
  late FakeSecureStoragePlatform keystore;
  late ArkFundingSigningGuard guard;
  int nativeAccesses = 0;

  PayjoinWalletAdapter payjoin() => PayjoinWalletAdapter(
    Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => fixture.directory.path,
    ),
    (_) async {
      nativeAccesses++;
      throw StateError('annotation must not occur');
    },
    (_) async => BitcoinSpendStatus.ready,
    inventory,
    guard,
  );
  setUp(() {
    fixture = FundingFixture();
    inventory = _Inventory();
    when(() => inventory.readWallet(any())).thenAnswer(
      (invocation) async => Ok(
        walletRegistrationForTesting(
          id: invocation.positionalArguments.single as String,
          network: BitcoinNetwork.regtest,
          signer: WalletSigner.local,
          secretFingerprint: Fingerprint('00112233'),
        ),
      ),
    );
    nativeAccesses = 0;
    keystore = FakeSecureStoragePlatform().install();
    guard = ArkFundingSigningGuard(authority: fixture.store);
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
        expect(
          await guard.admit(
            walletId: id,
            network: BitcoinNetwork.regtest,
            unsignedPsbt: encoded,
          ),
          isA<Err>(),
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
      guard = const ArkFundingSigningGuard(authority: null);
      expect(
        await guard.admit(
          walletId: fundingWalletId,
          network: BitcoinNetwork.regtest,
          unsignedPsbt: publicFundingPsbt,
        ),
        isA<Err>(),
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
  test('ordinary signing admission commits the exact marker', () async {
    expect(
      await guard.admit(
        walletId: fundingWalletId,
        network: BitcoinNetwork.regtest,
        unsignedPsbt: publicFundingPsbt,
      ),
      isA<Ok>(),
    );
    final db = sqlite3.open(fixture.path);
    try {
      expect(
        db.select('SELECT txid FROM ark_ordinary_signing WHERE network=?', [
          'regtest',
        ]),
        hasLength(1),
      );
    } finally {
      db.close();
    }
  });
  test(
    'Payjoin never authorizes a public fingerprint as a local key',
    () async {
      when(() => inventory.readWallet(fundingWalletId)).thenAnswer(
        (_) async => Ok(
          walletRegistrationForTesting(
            id: fundingWalletId,
            network: BitcoinNetwork.regtest,
            signer: WalletSigner.none,
            masterFingerprint: Fingerprint('00112233'),
          ),
        ),
      );

      await expectLater(
        payjoin().signPsbt(
          walletId: fundingWalletId,
          network: BitcoinNetwork.regtest,
          psbt: otherUnsignedTransaction(),
        ),
        throwsA(
          isA<Exception>().having(
            (failure) => failure.toString(),
            'reason',
            contains('local mnemonic'),
          ),
        ),
      );
      expect(keystore.reads, 0);
      expect(nativeAccesses, 0);
    },
  );

  test('unavailable native wallet raises a recoverable sync exception before signing', () async {
    final storage = FakeSecureStoragePlatform(
      entries: {
        'seed_73c5da0a': jsonEncode({
          'mnemonicWords': [...List.filled(11, 'abandon'), 'about'],
          'passphrase': null,
          'runtimeType': 'mnemonic',
        }),
      },
    )..install();
    when(() => inventory.readWallet(fundingWalletId)).thenAnswer(
      (_) async => Ok(
        walletRegistrationForTesting(
          id: fundingWalletId,
          network: BitcoinNetwork.regtest,
          signer: WalletSigner.local,
          secretFingerprint: Fingerprint('73c5da0a'),
        ),
      ),
    );
    var opens = 0;
    final adapter = PayjoinWalletAdapter(
      Secrets(
        authority: unlockedSessionAuthority(),
        scratchDirectory: () async => fixture.directory.path,
      ),
      (_) async {
        opens++;
        return const Err(SyncStorageFailure());
      },
      (_) async => BitcoinSpendStatus.ready,
      inventory,
      guard,
    );
    await expectLater(
      adapter.signPsbt(
        walletId: fundingWalletId,
        network: BitcoinNetwork.regtest,
        psbt: publicFundingPsbt,
      ),
      throwsA(
        isA<WalletSnapshotException>().having(
          (error) => error.failure,
          'failure',
          isA<SyncStorageFailure>(),
        ),
      ),
    );
    expect(opens, 1);
    expect(storage.reads, greaterThan(0));
  });
  test('Spend checks Ark admission before reading a signing secret', () {
    final source = File('packages/spend/lib/src/spend_operations.dart')
        .readAsStringSync();
    final signStart = source.indexOf(
      'Future<Result<String, SpendFailure>> _signBitcoin(',
    );
    final signEnd = source.indexOf(
      'Future<Result<SignedBitcoinSpend, SpendFailure>> signBitcoin(',
      signStart,
    );
    expect(signStart, greaterThanOrEqualTo(0));
    expect(signEnd, greaterThan(signStart));
    final method = source.substring(signStart, signEnd);
    final admission = method.indexOf('_arkFunding.admit(');
    final secrets = method.indexOf('_secrets.fetch(');
    expect(admission, greaterThanOrEqualTo(0));
    expect(secrets, greaterThan(admission));
  });

  test('marker persistence contention cannot reach the key store', () async {
    final db = sqlite3.open(fixture.path);
    try {
      db.execute('BEGIN IMMEDIATE');
      expect(
        await guard.admit(
          walletId: fundingWalletId,
          network: BitcoinNetwork.regtest,
          unsignedPsbt: publicFundingPsbt,
        ),
        isA<Err>(),
      );
      expect(keystore.reads, 0);
      db.execute('ROLLBACK');
    } finally {
      db.close();
    }
  });
}
