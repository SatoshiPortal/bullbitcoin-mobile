import 'package:address_view/address_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labels/labels.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show WalletInventory;
import 'package:sync/sync.dart' show Keychain;
import 'package:sync/write.dart' show WalletNativeLifecycle;

class _Labels extends Mock implements Labels {}

class _Inventory extends Mock implements WalletInventory {}

class _Native extends Mock implements WalletNativeLifecycle {}

AddressView _addressView(Labels labels) => AddressView.open(
  labels: labels,
  inventory: _Inventory(),
  native: _Native(),
  loadWallet: (_) async => throw StateError('Unexpected wallet read'),
);

void main() {
  const address = '1BoatSLRHtKNngkdXEeobR76b53LETtpyT';
  final label = Label.addr(id: 1, address: address, label: 'Savings');
  final entry = WalletAddress(
    walletId: 'wallet',
    index: 7,
    address: address,
    keyChain: Keychain.internal,
    balanceSat: 21000,
    nrOfTransactions: 2,
    createdAt: DateTime.utc(2026, 11, 20),
    updatedAt: DateTime.utc(2026, 11, 22),
  );

  test('attaches labels without changing the resolved address', () async {
    final labels = _Labels();
    when(() => labels.fetch(reference: address))
        .thenAnswer((_) async => Ok([label]));

    final result = await _addressView(labels).attachLabels(entry);

    expect(result, entry.copyWith(labels: [label]));
    verify(() => labels.fetch(reference: address)).called(1);
  });

  test('the resolved address still works when label storage fails', () async {
    final labels = _Labels();
    when(() => labels.fetch(reference: address))
        .thenAnswer((_) async => const Err(LabelUnexpectedFailure()));

    final result = await _addressView(labels)
        .attachLabels(entry.copyWith(labels: [label]));

    expect(result, entry);
    verify(() => labels.fetch(reference: address)).called(1);
  });
}
