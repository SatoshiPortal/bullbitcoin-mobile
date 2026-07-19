import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/invoices/data/private_invoice_link_repository_impl.dart';
import 'package:bb_mobile/features/invoices/domain/entities/encrypted_private_invoice.dart';
import 'package:bb_mobile/features/invoices/domain/entities/prepared_private_invoice_create.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/private_invoice_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pending operation survives a repository restart byte-identically',
    () async {
      final storage = _MemoryStorage();
      final first = _repository(storage);
      final operation = _operation();
      await first.savePending(operation);

      final restored = await _repository(storage).getPending();

      expect(restored, isNotNull);
      expect(
        restored!.encrypted.clientRequestId,
        operation.encrypted.clientRequestId,
      );
      expect(
        restored.encrypted.presentationEnvelope,
        operation.encrypted.presentationEnvelope,
      );
      expect(restored.encrypted.viewingKey, operation.encrypted.viewingKey);
      expect(restored.liquidAddress, operation.liquidAddress);
      expect(restored.reservationLabelIds, [41]);
    },
  );

  test('delete ignores a different request id', () async {
    final storage = _MemoryStorage();
    final repository = _repository(storage);
    await repository.savePending(_operation());

    await repository.deletePending('different');

    expect(await repository.getPending(), isNotNull);
  });

  test(
    'retained link survives restart without enumerating secure storage',
    () async {
      final storage = _MemoryStorage();
      final invoiceId = InvoiceId('inv-1');
      final link = PrivateInvoiceLink.fromServer(
        invoiceUrl: 'https://pay2.bull-wallet.com/invoice/inv-1',
        expectedInvoiceId: invoiceId,
        viewingKey: 'A' * 43,
        expectedOrigin: Uri.parse('https://pay2.bull-wallet.com'),
      );
      await _repository(storage).retainLink(link);

      final restored = await _repository(storage).getRetainedLink(invoiceId);

      expect(restored?.value, link.value);
      expect(storage.getAllCalls, 0);
    },
  );

  test('corrupt pending state fails with a redacted format error', () async {
    final storage = _MemoryStorage()
      ..values['private_invoice_pending_v1'] = '{}';
    final repository = _repository(storage);

    expect(
      repository.getPending,
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'invalid private invoice pending state',
        ),
      ),
    );
  });

  test('invalid persisted reservation ids fail closed', () async {
    final storage = _MemoryStorage();
    final repository = _repository(storage);
    await repository.savePending(_operation());
    storage.values['private_invoice_pending_v1'] = storage
        .values['private_invoice_pending_v1']!
        .replaceFirst(
          '"reservation_label_ids":[41]',
          '"reservation_label_ids":[-1]',
        );

    expect(
      repository.getPending,
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'invalid private invoice pending state',
        ),
      ),
    );
  });

  test('retained link rejects a different origin', () async {
    final storage = _MemoryStorage()
      ..values['private_invoice_link_v1_inv-1'] =
          'https://evil.example/invoice/inv-1#v1.${'A' * 43}';

    expect(
      () => _repository(storage).getRetainedLink(InvoiceId('inv-1')),
      throwsArgumentError,
    );
  });
}

PrivateInvoiceLinkRepositoryImpl _repository(_MemoryStorage storage) =>
    PrivateInvoiceLinkRepositoryImpl(
      storage: storage,
      expectedOrigin: Uri.parse('https://pay2.bull-wallet.com'),
    );

PreparedPrivateInvoiceCreate _operation() => PreparedPrivateInvoiceCreate(
  encrypted: EncryptedPrivateInvoice(
    clientRequestId: '00000000-0000-4000-8000-000000000000',
    presentationEnvelope: 'E' * 5500,
    viewingKey: 'A' * 43,
  ),
  amountSat: 2500,
  acceptBtc: false,
  acceptLn: true,
  acceptLiquid: true,
  liquidAddress: 'lq1address',
  liquidBlindingKeyHex: 'ab' * 32,
  reservationLabelIds: const [41],
);

class _MemoryStorage implements KeyValueStorageDatasource<String> {
  final Map<String, String> values = {};
  int getAllCalls = 0;

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<void> deleteValue(String key) async => values.remove(key);

  @override
  Future<Map<String, String>> getAll() async {
    getAllCalls++;
    return Map.of(values);
  }

  @override
  Future<String?> getValue(String key) async => values[key];

  @override
  Future<bool> hasValue(String key) async => values.containsKey(key);

  @override
  Future<void> saveValue({required String key, required String value}) async {
    values[key] = value;
  }
}
