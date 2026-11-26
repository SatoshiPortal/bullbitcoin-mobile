import 'dart:convert';

import 'package:ark/ark.dart';
import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart'
    show SyncStorageFailure, bitcoinScriptAddress, inspectBitcoinPsbt;

import 'ark_funding_test_fixture.dart';

void main() {
  final account = ArkAccountId(
    parent: Fingerprint('00112233'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'public-server',
  );
  late FundingFixture fixture;
  late WalletArkBoardAbandonment adapter;
  setUp(() {
    fixture = FundingFixture();
    adapter = WalletArkBoardAbandonment(Ok(fixture.store));
  });
  tearDown(() => fixture.close());

  Future<ArkFundingBinding> prepared() async {
    final context = jsonEncode({
      'version': 1,
      'account': account.canonical,
      'amount': '100000',
      'net': '99670',
      'arkFee': '330',
    });
    final binding = await fixture.reserve(
      'op',
      context: context,
      account: account.canonical,
    );
    final facts = sourceOk(inspectBitcoinPsbt(binding.unsignedPsbt));
    final address = sourceOk(
      bitcoinScriptAddress(
        facts.outputs.single.scriptPubkey,
        BitcoinNetwork.regtest,
      ),
    );
    sourceOk(
      await fixture.store.saveBoardReview(
        'op',
        jsonEncode({
          'request': context,
          'address': address,
          'keypairIndex': 7,
          'expiryHeight': 5000,
          'minerFee': facts.feeSat,
        }),
      ),
    );
    return binding;
  }

  Future<ArkFundingBinding> closed() async {
    final binding = await prepared();
    sourceOk(
      await fixture.store.tombstoneNeverSigned(
        expected: binding,
        admittedRevision: fundingStamp,
      ),
    );
    return binding;
  }

  void sql(void Function(Database) action) {
    final db = sqlite3.open(fixture.path);
    try {
      action(db);
    } finally {
      db.close();
    }
  }

  test(
    'only a strict neverSigned receipt yields the exact immutable public tuple',
    () async {
      final binding = await prepared();
      expect(
        await adapter.readNeverSigned(
          account: account,
          operationId: 'op',
          fundingTxid: binding.unsignedTxid,
        ),
        isA<Ok>().having((r) => r.value, 'no proof before closure', isNull),
      );
      sourceOk(
        await fixture.store.tombstoneNeverSigned(
          expected: binding,
          admittedRevision: fundingStamp,
        ),
      );
      final result = await adapter.readNeverSigned(
        account: account,
        operationId: 'op',
        fundingTxid: binding.unsignedTxid,
      );
      switch (result) {
        case Ok(value: final proof?):
          expect(proof.account, account);
          expect(proof.operationId, 'op');
          expect(proof.fundingTxid, binding.unsignedTxid);
          expect(proof.keypairIndex, 7);
          expect(proof.expiryHeight, 5000);
          expect(proof.grossAmount, Sats.fromInt(100000));
          expect(proof.netAmount, Sats.fromInt(99670));
          final facts = sourceOk(inspectBitcoinPsbt(binding.unsignedPsbt));
          expect(
            proof.address,
            sourceOk(
              bitcoinScriptAddress(
                facts.outputs.single.scriptPubkey,
                account.network,
              ),
            ),
          );
        default:
          fail('Strict closed proof unavailable');
      }
      final reopened = sourceOk(
        SqliteArkFundingReservations.open(fixture.path, foreground: false),
      );
      try {
        expect(
          await WalletArkBoardAbandonment(Ok(reopened)).readNeverSigned(
            account: account,
            operationId: 'op',
            fundingTxid: binding.unsignedTxid,
          ),
          isA<Ok>(),
        );
      } finally {
        reopened.close();
      }
    },
  );

  test('missing operation and missing configured authority never prove abandonment', () async {
    final binding = await prepared();
    expect(
      await adapter.readNeverSigned(
        account: account,
        operationId: 'missing',
        fundingTxid: binding.unsignedTxid,
      ),
      isA<Ok>().having((r) => r.value, 'absent', isNull),
    );
    const unavailable = WalletArkBoardAbandonment(Err(SyncStorageFailure()));
    expect(
      await unavailable.readNeverSigned(
        account: account,
        operationId: 'op',
        fundingTxid: binding.unsignedTxid,
      ),
      isA<Err>(),
    );
  });

  test(
    'account, parent and funding txid scope cannot be substituted',
    () async {
      final binding = await closed();
      for (final other in [
        ArkAccountId(
          parent: account.parent,
          network: account.network,
          serverIdentity: 'other',
        ),
        ArkAccountId(
          parent: Fingerprint('ffeeddcc'),
          network: account.network,
          serverIdentity: account.serverIdentity,
        ),
        ArkAccountId(
          parent: account.parent,
          network: BitcoinNetwork.mainnet,
          serverIdentity: account.serverIdentity,
        ),
      ]) {
        expect(
          await adapter.readNeverSigned(
            account: other,
            operationId: 'op',
            fundingTxid: binding.unsignedTxid,
          ),
          isA<Err>(),
        );
      }
      expect(
        await adapter.readNeverSigned(
          account: account,
          operationId: 'op',
          fundingTxid: '00' * 32,
        ),
        isA<Err>(),
      );
    },
  );

  for (final corruption in [
    'version',
    'receipt-context',
    'address',
    'key-index',
    'expiry',
    'miner-fee',
    'phase',
  ]) {
    test('corrupt $corruption cannot become an eligible tuple', () async {
      final binding = await closed();
      sql((db) {
        final receipt = jsonDecode(
          db
                  .select('SELECT settlement FROM ark_funding_authority')
                  .single['settlement']
              as String,
        ) as Map<String, dynamic>;
        final payload = jsonDecode(
          db.select('SELECT payload FROM ark_board_reviews').single['payload']
              as String,
        ) as Map<String, dynamic>;
        switch (corruption) {
          case 'version':
            receipt['version'] = 1.0;
          case 'receipt-context':
            (receipt['binding'] as Map<String, dynamic>)['context'] =
                'substituted';
          case 'address':
            payload['address'] = 'not-the-funding-output';
          case 'key-index':
            payload['keypairIndex'] = 7.0;
          case 'expiry':
            payload['expiryHeight'] = -1;
          case 'miner-fee':
            payload['minerFee'] = 201;
          case 'phase':
            db.execute("UPDATE ark_board_reviews SET phase='signing'");
        }
        db.execute('UPDATE ark_funding_authority SET settlement=?', [
          jsonEncode(receipt),
        ]);
        db.execute('UPDATE ark_board_reviews SET payload=?', [
          jsonEncode(payload),
        ]);
      });
      expect(
        await adapter.readNeverSigned(
          account: account,
          operationId: 'op',
          fundingTxid: binding.unsignedTxid,
        ),
        isA<Err>(),
      );
    });
  }

  test(
    'a terminal label without its validated receipt supplies no proof',
    () async {
      final binding = await prepared();
      sql((db) {
        db.execute("UPDATE ark_funding_operations SET state='tombstoned'");
        db.execute("UPDATE ark_funding_authority SET signing='tombstoned'");
        db.execute('DELETE FROM ark_funding_inputs');
      });
      expect(
        await adapter.readNeverSigned(
          account: account,
          operationId: 'op',
          fundingTxid: binding.unsignedTxid,
        ),
        isA<Err>(),
      );
    },
  );

  test('read-only attestation succeeds while another connection holds a reserved write lock', () async {
    final binding = await closed();
    final writer = sqlite3.open(fixture.path);
    try {
      writer.execute('BEGIN IMMEDIATE');
      expect(
        await adapter.readNeverSigned(
          account: account,
          operationId: 'op',
          fundingTxid: binding.unsignedTxid,
        ),
        isA<Ok>(),
      );
      writer.execute('ROLLBACK');
    } finally {
      writer.close();
    }
  });
}
