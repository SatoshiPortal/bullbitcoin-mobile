import 'dart:io';

import 'package:bb_mobile/core/electrum/data/electrum_socket_connector.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_backup_codec.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_backup_electrum_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_backup_wallet_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_descriptor_backup_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bitcoin_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/fetch_bitcoin_backup_usecase.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/bip138_prototype_fixture.dart';
import '../support/bitcoin_backup_fixture.dart';

const connection = ElectrumConnection(
  url: 'tcp://127.0.0.1:51401',
  retry: 0,
  timeout: 2,
  stopGap: 20,
  validateDomain: true,
  isCustom: true,
);

class FixtureElectrum extends BitcoinBackupElectrumDatasource {
  final Object history;
  final Map<String, String> transactions;
  FixtureElectrum(this.history, this.transactions)
    : super(const ElectrumSocketConnector());
  @override
  Future<Object?> request(
    ElectrumConnection connection,
    String method,
    List<Object> params,
    DescriptorBackupSession session,
  ) async {
    if (method.endsWith('get_history')) return history;
    final raw = transactions[params.first];
    if (raw == null) throw const SocketException('missing');
    return raw;
  }
}

void main() {
  final fixture = Bip138PrototypeFixture();
  const network = BitcoinBackupNetwork.regtest;
  BitcoinDescriptorBackupRepositoryImpl repository(FixtureElectrum source) =>
      BitcoinDescriptorBackupRepositoryImpl(
        source,
        BitcoinBackupWalletDatasource(() async => '/unused'),
      );

  test(
    'fetch usecase preserves two generations and ignores spender-only history',
    () async {
      final first = BitcoinBackupCodec.prepare(fixture.descriptor(), network);
      final second = BitcoinBackupCodec.prepare(
        fixture.descriptor(generation: 1),
        network,
      );
      final transactions = [
        backupTransaction(fixture, first.payload),
        backupTransaction(fixture, second.payload),
        backupTransaction(fixture, [1, 2, 3], includeMarkers: false),
      ];
      final source = FixtureElectrum(
        [
          for (final tx in transactions)
            {'tx_hash': backupTxid(tx), 'height': 102},
        ],
        {for (final tx in transactions) backupTxid(tx): hex.encode(tx)},
      );
      for (final signer in fixture.signers) {
        final result = await FetchBitcoinBackupUsecase(repository(source))
            .execute(
              input: signer.accountKey.xpub,
              network: network,
              connection: connection,
              session: DescriptorBackupSession(),
            );
        expect(result, isA<Ok<BitcoinBackupFetch, dynamic>>());
        final value = (result as Ok).value as BitcoinBackupFetch;
        expect(value.candidates.map((c) => c.descriptor), [
          first.descriptor,
          second.descriptor,
        ]);
        expect(value.incomplete, isFalse);
        expect(value.rejectedTransactions, 0);
      }
    },
  );

  test(
    'missing raw transaction and malformed history never become complete empty success',
    () async {
      final source = FixtureElectrum([
        {'tx_hash': 'a' * 64, 'height': 10},
        {'bad': true},
      ], {});
      final result = await repository(source).fetch(
        fixture.signers.first.accountKey.xpub,
        network,
        connection,
        DescriptorBackupSession(),
      );
      expect(result, isA<Ok<BitcoinBackupFetch, dynamic>>());
      final value = (result as Ok).value as BitcoinBackupFetch;
      expect(value.incomplete, isTrue);
      expect(value.rejectedTransactions, 2);
    },
  );

  test('history cap is explicitly incomplete', () async {
    final tx = backupTransaction(fixture, [1, 2, 3]);
    final txid = backupTxid(tx);
    final source = FixtureElectrum(
      List.filled(129, {'tx_hash': txid, 'height': 1}),
      {txid: hex.encode(tx)},
    );
    final result = await repository(source).fetch(
      fixture.signers.first.accountKey.xpub,
      network,
      connection,
      DescriptorBackupSession(),
    );
    expect(((result as Ok).value as BitcoinBackupFetch).incomplete, isTrue);
  });

  test(
    'connection validation preserves TLS default and rejects onion without proxy',
    () {
      ElectrumConnection to(String url) => ElectrumConnection(
        url: url,
        retry: 0,
        timeout: 2,
        stopGap: 20,
        validateDomain: true,
        isCustom: true,
      );
      expect(
        BitcoinBackupElectrumDatasource.validate(
          to('example.org:50002'),
        ).scheme,
        'ssl',
      );
      for (final url in [
        'https://example.org:443',
        'tcp://example.org:0',
        'ssl://secret@example.org:50002',
        'tcp://a.onion:50001',
      ]) {
        expect(
          () => BitcoinBackupElectrumDatasource.validate(to(url)),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'RPC rejects mismatched IDs, server errors and oversized frames',
    () async {
      for (final reply in [
        '{"id":2,"result":[]}',
        '{"id":1,"error":{"code":1}}',
        'x' * 2100001,
      ]) {
        final server = await ServerSocket.bind('127.0.0.1', 0);
        final sockets = <Socket>[];
        final subscription = server.listen((socket) {
          sockets.add(socket);
          socket.listen((_) => socket.writeln(reply));
        });
        final to = ElectrumConnection(
          url: 'tcp://127.0.0.1:${server.port}',
          retry: 0,
          timeout: 2,
          stopGap: 20,
          validateDomain: true,
          isCustom: true,
        );
        final session = DescriptorBackupSession();
        try {
          await expectLater(
            const BitcoinBackupElectrumDatasource(
              ElectrumSocketConnector(),
            ).request(to, 'blockchain.scripthash.get_history', [
              '0' * 64,
            ], session),
            throwsFormatException,
          );
        } finally {
          session.cancel();
          for (final socket in sockets) {
            socket.destroy();
          }
          await subscription.cancel();
          await server.close();
        }
      }
    },
  );

  test('socket cancellation terminates a silent request', () async {
    final server = await ServerSocket.bind('127.0.0.1', 0);
    final sockets = <Socket>[];
    final subscription = server.listen(sockets.add);
    final session = DescriptorBackupSession();
    final to = ElectrumConnection(
      url: 'tcp://127.0.0.1:${server.port}',
      retry: 0,
      timeout: 2,
      stopGap: 20,
      validateDomain: true,
      isCustom: true,
    );
    try {
      final pending = const BitcoinBackupElectrumDatasource(
        ElectrumSocketConnector(),
      ).request(to, 'blockchain.scripthash.get_history', ['0' * 64], session);
      final expectation = expectLater(pending, throwsFormatException);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      session.cancel();
      await expectation.timeout(const Duration(seconds: 1));
    } finally {
      for (final socket in sockets) {
        socket.destroy();
      }
      await subscription.cancel();
      await server.close();
    }
  });
}
