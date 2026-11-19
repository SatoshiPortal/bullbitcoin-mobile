import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:sync/src/data/chain/broadcast_replies.dart';
import 'package:sync/sync.dart';

void main() {
  const rejected = SyncBroadcastRejectedFailure();
  const alreadyInChain = SyncAlreadyInChainFailure();
  const connection = SyncConnectionFailure();
  const unknown = SyncOutcomeUnknownFailure();

  group('bitcoinBroadcastFailure', () {
    final cases = <(Object, SyncFailure)>[
      (bdk.ProtocolElectrumException('{"code":-26}'), rejected),
      (
        bdk.ProtocolElectrumException(
          '{"code":2,"message":"sendrawtransaction RPC error -26: refused"}',
        ),
        rejected,
      ),
      (bdk.ProtocolElectrumException('{"code":-27}'), alreadyInChain),
      (
        // The reply captured on electrum.blockstream.info:60002 for a
        // confirmed testnet transaction.
        bdk.ProtocolElectrumException(
          '{"code":2,"message":"sendrawtransaction RPC error -27: Transaction outputs already in utxo set"}',
        ),
        alreadyInChain,
      ),
      // Raised once the client is connected, during or after the send: the
      // server may have relayed the transaction.
      (bdk.IoExceptionElectrumException('private.invalid'), unknown),
      (bdk.SharedIoExceptionElectrumException('private.invalid'), unknown),
      (
        bdk.CouldNotCreateConnectionElectrumException('private.invalid'),
        unknown,
      ),
      (bdk.AllAttemptsErroredElectrumException(), unknown),
      (bdk.ProtocolElectrumException('{"code":-26.0}'), unknown),
      (bdk.ProtocolElectrumException('{"code":"-26"}'), unknown),
      (bdk.ProtocolElectrumException('{"code":-27.0}'), unknown),
      (
        bdk.ProtocolElectrumException(
          '{"code":2,"message":"prefix sendrawtransaction RPC error -26: refused"}',
        ),
        unknown,
      ),
      (
        bdk.ProtocolElectrumException(
          '{"code":2,"message":"prefix sendrawtransaction RPC error -27: x"}',
        ),
        unknown,
      ),
      (
        bdk.ProtocolElectrumException('{"code":-25,"message":"RPC -26"}'),
        unknown,
      ),
      (bdk.ProtocolElectrumException('not JSON'), unknown),
      (
        bdk.ProtocolElectrumException('{"code":-26,"message":"${'x' * 4096}"}'),
        unknown,
      ),
      (Exception('{"code":-26}'), unknown),
      (const lwk.LwkError(msg: 'ClientError(IOError(x))'), unknown),
    ];
    for (var i = 0; i < cases.length; i++) {
      final (error, expected) = cases[i];
      test('bounded classification case $i', () {
        expect(bitcoinBroadcastFailure(error), same(expected));
      });
    }
  });

  group('liquidBroadcastFailure', () {
    final cases = <(Object, SyncFailure)>[
      (
        const lwk.LwkError(
          msg: 'ClientError(Protocol(Object {"code": Number(2), "message": String("sendrawtransaction RPC error -26: refused")}))',
        ),
        rejected,
      ),
      (
        const lwk.LwkError(
          msg: 'ClientError(Protocol(Object {"code": Number(-26)}))',
        ),
        rejected,
      ),
      (
        const lwk.LwkError(
          msg: 'ClientError(Protocol(Object {"code": Number(-26), "message": String("x")}))',
        ),
        rejected,
      ),
      (
        const lwk.LwkError(
          msg: 'ClientError(IOError(Custom { kind: TimedOut, error: "private.invalid" }))',
        ),
        connection,
      ),
      (
        const lwk.LwkError(msg: 'ClientError(SharedIOError(private.invalid))'),
        connection,
      ),
      (
        const lwk.LwkError(
          msg: 'ClientError(CouldNotCreateConnection(private.invalid))',
        ),
        connection,
      ),
      (
        const lwk.LwkError(
          msg: 'ClientError(Protocol(Object {"code": Number(-25), "message": String("Number(-26)")}))',
        ),
        unknown,
      ),
      (
        const lwk.LwkError(msg: 'Generic("ClientError(IOError(fake))")'),
        unknown,
      ),
      (const lwk.LwkError(msg: 'ClientError(IOError('), unknown),
      (lwk.LwkError(msg: 'ClientError(IOError(${'x' * 4096}))'), unknown),
      (bdk.ProtocolElectrumException('{"code":-26}'), unknown),
      (Exception('ClientError(IOError(x))'), unknown),
    ];
    for (var i = 0; i < cases.length; i++) {
      final (error, expected) = cases[i];
      test('bounded classification case $i', () {
        expect(liquidBroadcastFailure(error), same(expected));
      });
    }
  });

  group('combineBroadcastAttempts', () {
    final cases = <(List<SyncFailure>, SyncFailure)>[
      ([rejected], rejected),
      ([rejected, rejected], rejected),
      ([connection, connection], connection),
      ([alreadyInChain, alreadyInChain], alreadyInChain),
      ([rejected, connection], unknown),
      ([connection, rejected], unknown),
      ([connection, alreadyInChain], unknown),
      ([alreadyInChain, connection], unknown),
      ([alreadyInChain, rejected], unknown),
      ([], unknown),
    ];
    for (final (attempts, expected) in cases) {
      test('${attempts.map((a) => a.logCode)} reads ${expected.logCode}', () {
        expect(combineBroadcastAttempts(attempts), same(expected));
      });
    }
  });

  group('isUnknownTransactionReply', () {
    for (final (reply, expected) in [
      ('{"code":-32603,"message":"missing transaction"}', true),
      (
        "daemon error: DaemonError({'code': -5, 'message': 'No such mempool "
            "or blockchain transaction. Use gettransaction for wallet "
            "transactions.'})",
        true,
      ),
      // A confirmed transaction may be unavailable without txindex.
      (
        'No such mempool transaction. Use -txindex or provide a block hash',
        false,
      ),
      ('excessive resource usage', false),
    ]) {
      test('"$reply" is ${expected ? '' : 'not '}an absence', () {
        expect(isUnknownTransactionReply(reply), expected);
      });
    }
  });
}
