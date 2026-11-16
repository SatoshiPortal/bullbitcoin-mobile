import 'dart:io';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/sqlite_ark_reminder_repository.dart';
import 'package:bull_ark/src/domain/usecases/update_ark_expiry_warning_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_operations_test.dart' show account;
import 'ark_expiry_warning_test.dart' show vtxo;
import 'ark_durable_stores_test.dart' show value, Notifications;

void main() {
  test(
    'partial stale B observation cannot postpone previously urgent A',
    () async {
      final dir = Directory.systemTemp.createTempSync('ark-partial-ledger-');
      final gateway = Notifications();
      final store = value(
        SqliteArkReminderRepository.open(
          path: '${dir.path}/ledger',
          notifications: gateway,
          title: 'Urgent',
          body: 'Open Ark',
          foreground: true,
          initializeNew: true,
        ),
      );
      try {
        final update = UpdateArkExpiryWarningUsecase(store);
        final now = DateTime.utc(2026, 11, 16);
        expect(
          await update.execute(
            ArkSnapshot(
              account: account(),
              revision: 1,
              observedAt: now,
              tipHeight: 100,
              stale: false,
              vtxoCompleteness: ArkSectionCompleteness.complete,
              vtxos: [vtxo('A', 200), vtxo('B', 1000)],
            ),
          ),
          isA<Ok>(),
        );
        final original = gateway.scheduled.single;
        for (var pass = 2; pass <= 3; pass++) {
          expect(
            await update.execute(
              ArkSnapshot(
                account: account(),
                revision: pass,
                observedAt: now.add(Duration(hours: pass)),
                tipHeight: 110,
                stale: true,
                vtxoCompleteness: ArkSectionCompleteness.incomplete,
                vtxos: [vtxo('B', 1000)],
              ),
            ),
            isA<Ok>(),
          );
          expect(gateway.scheduled.last.id, original.id);
          expect(gateway.scheduled.last.at, original.at);
        }
        expect(await store.reapplyStored(), isA<Ok>());
        expect(gateway.scheduled.last.at, original.at);
      } finally {
        await store.close();
        dir.deleteSync(recursive: true);
      }
    },
  );
  test(
    'removed board expiry cannot postpone the admitted VTXO bound',
    () async {
      final dir = Directory.systemTemp.createTempSync('ark-partial-board-');
      final gateway = Notifications();
      final store = value(
        SqliteArkReminderRepository.open(
          path: '${dir.path}/ledger',
          notifications: gateway,
          title: 'Urgent',
          body: 'Open Ark',
          foreground: true,
          initializeNew: true,
        ),
      );
      try {
        final update = UpdateArkExpiryWarningUsecase(store);
        final now = DateTime.utc(2026, 11, 16);
        ArkSnapshot observation(int revision, int? expiry) => ArkSnapshot(
          account: account(),
          revision: revision,
          observedAt: now,
          tipHeight: 100,
          stale: revision > 1,
          vtxoCompleteness: ArkSectionCompleteness.incomplete,
          vtxos: [vtxo('B', 1000)],
          pendingBoards: [
            ArkPendingBoard(
              vtxoId: 'board-A',
              fundingTxid: 'public-txid',
              amount: Sats.fromInt(5000),
              expiryHeight: expiry,
            ),
          ],
        );
        expect(await update.execute(observation(1, 200)), isA<Ok>());
        final original = gateway.scheduled.single;
        expect(
          original.at,
          now
              .add(const Duration(minutes: 9000))
              .subtract(const Duration(hours: 24)),
        );
        expect(await update.execute(observation(2, null)), isA<Ok>());
        expect(gateway.scheduled.last.id, original.id);
        expect(gateway.scheduled.last.at, original.at);
        expect(await store.reapplyStored(), isA<Ok>());
        expect(gateway.scheduled.last.at, original.at);
      } finally {
        await store.close();
        dir.deleteSync(recursive: true);
      }
    },
  );
}
