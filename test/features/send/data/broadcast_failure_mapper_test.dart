import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/features/send/data/broadcast_failure_mapper.dart';
import 'package:bb_mobile/features/send/domain/broadcast_failure.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';

void main() {
  AllElectrumServersFailedException fallback(List<Object> errors) =>
      AllElectrumServersFailedException([
        for (final error in errors)
          ElectrumServerAttempt(
            url: 'ssl://private.invalid',
            isCustom: true,
            error: error,
          ),
      ]);
  final rejected = bdk.ProtocolElectrumException('{"code":-26}');
  final connection = TimeoutException('private.invalid');
  final cases = <(Object, BroadcastFailureCategory)>[
    (rejected, BroadcastFailureCategory.rejected),
    (
      bdk.ProtocolElectrumException(
        '{"code":2,"message":"sendrawtransaction RPC error -26: refused"}',
      ),
      BroadcastFailureCategory.rejected,
    ),
    (connection, BroadcastFailureCategory.connection),
    (
      const SocketException('private.invalid'),
      BroadcastFailureCategory.connection,
    ),
    (
      bdk.SharedIoExceptionElectrumException('private.invalid'),
      BroadcastFailureCategory.connection,
    ),
    (
      bdk.CouldNotCreateConnectionElectrumException('private.invalid'),
      BroadcastFailureCategory.connection,
    ),
    (
      bdk.AllAttemptsErroredElectrumException(),
      BroadcastFailureCategory.unexpected,
    ),
    (
      bdk.ProtocolElectrumException('{"code":-26.0}'),
      BroadcastFailureCategory.unexpected,
    ),
    (
      bdk.ProtocolElectrumException('{"code":"-26"}'),
      BroadcastFailureCategory.unexpected,
    ),
    (
      bdk.ProtocolElectrumException(
        '{"code":2,"message":"prefix sendrawtransaction RPC error -26: refused"}',
      ),
      BroadcastFailureCategory.unexpected,
    ),
    (
      bdk.ProtocolElectrumException('{"code":-25,"message":"RPC -26"}'),
      BroadcastFailureCategory.unexpected,
    ),
    (
      bdk.ProtocolElectrumException('not JSON'),
      BroadcastFailureCategory.unexpected,
    ),
    (
      bdk.ProtocolElectrumException('{"code":-26,"message":"${'x' * 4096}"}'),
      BroadcastFailureCategory.unexpected,
    ),
    (Exception('{"code":-26}'), BroadcastFailureCategory.unexpected),
    (
      const lwk.LwkError(
        msg:
            'ClientError(Protocol(Object {"code": Number(2), "message": String("sendrawtransaction RPC error -26: refused")}))',
      ),
      BroadcastFailureCategory.rejected,
    ),
    (
      const lwk.LwkError(msg: 'ClientError(SharedIOError(private.invalid))'),
      BroadcastFailureCategory.connection,
    ),
    (
      const lwk.LwkError(
        msg:
            'ClientError(Protocol(Object {"code": Number(-25), "message": String("Number(-26)")}))',
      ),
      BroadcastFailureCategory.unexpected,
    ),
    (
      const lwk.LwkError(msg: 'Generic("ClientError(IOError(fake))")'),
      BroadcastFailureCategory.unexpected,
    ),
    (
      const lwk.LwkError(msg: 'ClientError(IOError('),
      BroadcastFailureCategory.unexpected,
    ),
    (fallback([rejected, rejected]), BroadcastFailureCategory.rejected),
    (fallback([connection, connection]), BroadcastFailureCategory.connection),
    (fallback([rejected, connection]), BroadcastFailureCategory.unexpected),
    (fallback([]), BroadcastFailureCategory.unexpected),
    (fallback(List.filled(65, rejected)), BroadcastFailureCategory.unexpected),
    (
      CategorizedBroadcastException(BroadcastFailureCategory.authorization),
      BroadcastFailureCategory.authorization,
    ),
  ];
  for (var i = 0; i < cases.length; i++) {
    final (error, expected) = cases[i];
    test('bounded classification case $i', () {
      expect(mapBroadcastFailure(error), expected);
    });
  }
  test('deep or cyclic fallback data is bounded', () {
    Object error = rejected;
    for (var i = 0; i < 8; i++) {
      error = fallback([error]);
    }
    expect(mapBroadcastFailure(error), BroadcastFailureCategory.unexpected);
    final attempts = <ElectrumServerAttempt>[];
    final cyclic = AllElectrumServersFailedException(attempts);
    attempts.add(ElectrumServerAttempt(url: '', isCustom: true, error: cyclic));
    expect(mapBroadcastFailure(cyclic), BroadcastFailureCategory.unexpected);
  });
}
