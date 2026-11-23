import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:signers/signers.dart' show SignerDevice;
import 'package:signers/src/bitbox_flow/ui/screens/bitbox_action_screen.dart';
import 'package:signers/src/ledger_flow/ui/screens/ledger_action_screen.dart';

void expectVerifyAddressRequest(
  WidgetTester tester, {
  required NetworkEnv network,
  required String address,
  required String derivationPath,
  required SignerDevice requestedDeviceType,
}) {
  final request = requestedDeviceType == SignerDevice.bitbox02
      ? tester.widget<BitBoxActionScreen>(find.byType(BitBoxActionScreen))
      : tester.widget<LedgerActionScreen>(find.byType(LedgerActionScreen));
  final (
    actualNetwork,
    actualAddress,
    actualPath,
    actualDevice,
  ) = switch (request) {
    BitBoxActionScreen(:final parameters) => (
      parameters.network,
      parameters.address,
      parameters.derivationPath,
      parameters.requestedDeviceType,
    ),
    LedgerActionScreen(:final parameters) => (
      parameters.network,
      parameters.address,
      parameters.derivationPath,
      parameters.requestedDeviceType,
    ),
    _ => throw StateError('Expected a mounted hardware verification screen'),
  };

  expect(actualNetwork, network);
  expect(actualAddress, address);
  expect(actualPath, derivationPath);
  expect(actualDevice, requestedDeviceType);
}
