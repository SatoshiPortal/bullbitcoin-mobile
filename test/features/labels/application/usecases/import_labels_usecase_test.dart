import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/labels/adapters/labels_repository_adapter.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/wallet_freeze_port.dart';
import 'package:bb_mobile/features/labels/domain/decoded_labels.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:bb_mobile/features/labels/label_change_notifier.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Converter extends Mock implements LabelsConverterPort {}

class _Freezes extends Mock implements WalletFreezePort {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final txid = List.filled(64, 'a').join();
  final file = FormattedLabelsBIP329(jsonl: 'fixture parsed by converter');

  for (final failure in ['none', 'lookup', 'freeze', 'label storage']) {
    test('notifies committed labels when $failure fails', () async {
      final database = SqliteDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftLabelsRepositoryAdapter(database: database);
      final converter = _Converter();
      final freezes = _Freezes();
      final notifier = LabelChangeNotifier();
      var notifications = 0;
      final subscription = notifier.changes.listen((_) => notifications++);
      addTearDown(subscription.cancel);
      when(() => converter.convertFrom(file)).thenReturn(
        DecodedLabels(
          labels: [
            NewLabel(
              type: LabelType.transaction,
              reference: txid,
              label: 'Imported',
            ),
            if (failure == 'label storage')
              NewLabel(
                type: LabelType.transaction,
                reference: 'invalid',
                label: 'Rejected',
              ),
          ],
          frozen: [(walletId: 'wallet', txId: txid, vout: 0)],
        ),
      );
      when(() => freezes.getOwnedOutpoints(walletId: 'wallet')).thenAnswer((
        _,
      ) async {
        if (failure == 'lookup') {
          throw Exception('Ownership lookup unavailable');
        }
        return [(txId: txid, vout: 0)];
      });
      when(() => freezes.freeze(any())).thenAnswer((_) async {
        if (failure == 'freeze') {
          throw Exception('Freeze storage unavailable');
        }
      });
      final usecase = ImportLabelsUsecase(
        labelRepository: repository,
        labelConverter: converter,
        walletFreeze: freezes,
        changeNotifier: notifier,
      );
      if (failure == 'none') {
        expect(await usecase.call(file, importFreezes: true), 1);
      } else {
        await expectLater(
          usecase.call(file, importFreezes: true),
          throwsA(isA<ImportLabelsError>()),
        );
      }
      if (failure == 'label storage') {
        expect(await repository.fetchAll(), isEmpty);
        expect(notifications, 0);
        verifyZeroInteractions(freezes);
      } else {
        final stored = (await repository.fetchAll()).single;
        expect(stored.reference, txid);
        expect(stored.label, 'Imported');
        expect(notifications, 1);
      }
    });
  }
}
