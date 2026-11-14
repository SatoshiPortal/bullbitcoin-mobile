import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/data/reserved_address_port_impl.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_system.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

final class _Labels implements LabelsRepositoryPort {
  List<LabelEntity> labels = [];
  bool fail = false;
  String? reference;
  @override
  Future<List<LabelEntity>> fetchByReference(String reference) async {
    this.reference = reference;
    if (fail) throw Exception('storage unavailable');
    return labels;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'only system labels reserve an address, irrespective of origin',
    () async {
      final labels = _Labels();
      final port = ReservedAddressPortImpl(labels);
      final key = WalletKey(id: 'wallet', network: LiquidNetwork.testnet);
      for (final name in [
        'my address',
        ...LabelSystem.values.map((value) => value.label),
      ]) {
        labels.labels = [
          LabelEntity(
            id: 1,
            type: LabelType.address,
            label: name,
            reference: 'address',
          ),
        ];
        final result = await port.isReserved(key, 'address');
        expect(
          (result as Ok<bool, TransactionSyncFailure>).value,
          name != 'my address',
        );
        expect(labels.reference, 'address');
      }
      labels.labels = [];
      expect(
        (await port.isReserved(key, 'address')
                as Ok<bool, TransactionSyncFailure>)
            .value,
        isFalse,
      );
      labels.fail = true;
      expect(
        await port.isReserved(key, 'address'),
        isA<Err<bool, TransactionSyncFailure>>(),
      );
    },
  );
}
