import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/sqlite_ark_reminder_repository.dart';
import 'package:bull_ark/src/domain/ark_expiry_warning.dart';
import 'package:bull_ark/src/domain/usecases/update_ark_expiry_warning_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_durable_stores_test.dart' show value, Notifications;
import 'ark_expiry_warning_test.dart' show observed, vtxo;
import 'ark_operations_test.dart' show account;

void main() {
  for (final scenario in [
    (ArkVtxoState.locked, true, false, false),
    (ArkVtxoState.locked, true, true, false),
    (ArkVtxoState.locked, true, false, true),
    (ArkVtxoState.spendable, true, false, false),
    (ArkVtxoState.locked, false, false, false),
  ]) {
    test(
      'renewal retirement requires an admitted replacement bound: $scenario',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'ark-retirement-',
        );
        final gateway = Notifications();
        final store = value(
          SqliteArkReminderRepository.open(
            path: '${directory.path}/ledger',
            notifications: gateway,
            title: 'Urgent',
            body: 'Open Ark',
            foreground: true,
            initializeNew: true,
          ),
        );
        try {
          if (scenario.$3) {
            final raw = sqlite3.open('${directory.path}/ledger');
            final at = DateTime.utc(2026, 11, 14).microsecondsSinceEpoch;
            final hash = sha256.convert(utf8.encode('vtxo:old')).toString();
            raw.execute('INSERT INTO ark_reminders VALUES(?,?,?,?,?,?,?)', [
              account().canonical,
              -1,
              1,
              100,
              List.filled(64, 'a').join(),
              at,
              jsonEncode({hash: at}),
            ]);
            raw.close();
          }
          final update = UpdateArkExpiryWarningUsecase(store);
          expect(
            await update.execute(observed(vtxos: [vtxo('old', 200)])),
            isA<Ok>(),
          );
          final original = gateway.scheduled.single;
          final replacement = observed(
            revision: 6,
            tip: 110,
            vtxos: [
              ArkVtxo(
                id: 'replacement',
                amount: Sats.fromInt(1000),
                expiryHeight: 500,
                state: scenario.$1,
              ),
              if (scenario.$4) vtxo('other-output', 700),
              vtxo('unrelated-late', 2000),
            ],
            boards: scenario.$2
                ? [
                    ArkPendingBoard(
                      vtxoId: 'replacement',
                      fundingTxid: 'not-vtxo-id',
                      amount: Sats.fromInt(1000),
                      expiryHeight: 111,
                    ),
                  ]
                : [],
            movements: [
              ArkMovement(
                id: 'renew',
                kind: ArkMovementKind.renewal,
                status: ArkMovementStatus.successful,
                inputVtxoIds: ['old'],
                outputVtxoIds: ['replacement', if (scenario.$4) 'other-output'],
              ),
            ],
          );
          final warning = ArkExpiryWarning.fromSnapshot(replacement);
          expect(await update.execute(replacement), isA<Ok>());
          final excluded = scenario.$1 == ArkVtxoState.locked && scenario.$2;
          if (excluded) {
            expect(gateway.scheduled.last.at, original.at);
            expect(warning?.retiredKeys, isNot(contains('vtxo:old')));
            expect(warning?.expiries, {
              if (scenario.$4) 'vtxo:other-output': 700,
              'vtxo:unrelated-late': 2000,
            });
          } else {
            expect(gateway.scheduled.last.at, warning?.notifyAt);
            expect(gateway.scheduled.last.at.isAfter(original.at), true);
            expect(warning?.retiredKeys, contains('vtxo:old'));
            expect(warning?.expiries, {
              'vtxo:replacement': 500,
              'vtxo:unrelated-late': 2000,
            });
          }
          expect(gateway.scheduled.last.id, original.id);
          expect(gateway.cancelled, isNot(contains(original.id)));
        } finally {
          await store.close();
          directory.deleteSync(recursive: true);
        }
      },
    );
  }
}
