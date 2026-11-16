import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/sqlite_ark_reminder_repository.dart';
import 'package:bull_ark/src/domain/ark_expiry_warning.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:crypto/crypto.dart';
import 'package:bull_ark/src/presentation/ark_failure_l10n.dart';
import 'package:bull_ark/generated/l10n/ark_localizations.dart';
import 'package:material_ui/material_ui.dart' hide Row;
import 'package:notifications/notifications.dart';
import 'package:bull_ark/src/domain/ark_reminder_policy_evidence.dart';
import 'package:bull_ark/src/domain/usecases/update_ark_expiry_warning_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import 'ark_durable_stores_test.dart' show value, Notifications;
import 'ark_expiry_warning_test.dart' show observed, vtxo;
import 'ark_operations_test.dart' show account;

String hash(String key) => sha256.convert(utf8.encode(key)).toString();

class Gateway extends Notifications {
  final actions = <String>[];
  bool fail = false;
  int? failId;
  @override
  Future<Result<void, NotificationsFailure>> schedule(
    LocalNotification notification, {
    required int platformId,
    required DateTime at,
  }) async {
    actions.add('schedule:$platformId');
    await super.schedule(notification, platformId: platformId, at: at);
    return fail || failId == platformId
        ? const Err(NotificationsGatewayFailure())
        : const Ok(null);
  }

  @override
  Future<Result<void, NotificationsFailure>> cancelScheduled(int id) {
    actions.add('cancel:$id');
    return super.cancelScheduled(id);
  }
}

void main() {
  late Directory directory;
  late String path;
  late Gateway gateway;
  late SqliteArkReminderRepository store;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('ark-policy-');
    path = '${directory.path}/ledger';
    gateway = Gateway();
    store = value(
      SqliteArkReminderRepository.open(
        path: path,
        notifications: gateway,
        title: 'Urgent',
        body: 'Open Ark',
        foreground: true,
        initializeNew: true,
      ),
    );
  });
  tearDown(() async {
    await store.close();
    directory.deleteSync(recursive: true);
  });

  List<Row> rows() {
    final raw = sqlite3.open(path);
    try {
      return raw.select('SELECT * FROM ark_reminders ORDER BY platform_id');
    } finally {
      raw.close();
    }
  }

  final oldAt = DateTime.utc(2026, 11, 15).microsecondsSinceEpoch;
  String seed(Map<String, int> bounds) {
    final original = jsonEncode(bounds);
    final raw = sqlite3.open(path);
    raw.execute('INSERT INTO ark_reminders VALUES(?,?,?,?,?,?,?)', [
      account().canonical,
      -1,
      1,
      100,
      List.filled(64, 'a').join(),
      bounds.values.reduce((a, b) => a < b ? a : b),
      original,
    ]);
    raw.close();
    return original;
  }

  Future<Result<void, ArkFailure>> apply(ArkSnapshot snapshot) =>
      UpdateArkExpiryWarningUsecase(store).execute(snapshot);
  Map<String, dynamic> payload(Row row) =>
      jsonDecode(row['deadline_bounds'] as String) as Map<String, dynamic>;
  void reopen() {
    store = value(
      SqliteArkReminderRepository.open(
        path: path,
        notifications: gateway,
        title: 'Urgent',
        body: 'Open Ark',
        foreground: false,
      ),
    );
  }

  ArkPendingBoard board(String id) => ArkPendingBoard(
    vtxoId: id,
    fundingTxid: 'not-a-vtxo',
    amount: Sats.fromInt(1000),
  );

  for (final pendingBoard in [true, false]) {
    test('removed funding contribution pendingBoard=$pendingBoard', () {
      final board = ArkPendingBoard(
        vtxoId: 'pending',
        fundingTxid: 'funding-tx',
        amount: Sats.fromInt(1000),
        expiryHeight: 110,
      );
      final operation = ArkOperation(
        id: 'operation',
        kind: ArkOperationKind.board,
        status: ArkOperationStatus.prepared,
        chainSource: Uri.parse('https://example.com'),
        configGeneration: 1,
        boardFunding: ArkBoardFundingDetails(
          address: 'public',
          keypairIndex: 1,
          expiryHeight: 110,
        ),
      );
      expect(
        ArkExpiryWarning.fromSnapshot(
          pendingBoard
              ? observed(boards: [board])
              : observed(operations: [operation]),
        ),
        isNull,
      );
    });
  }

  test('unresolved legacy keeps evidence but cannot block a new earlier VTXO intent', () async {
    final oldAt = DateTime.utc(2026, 11, 20).microsecondsSinceEpoch;
    final original = jsonEncode({hash('not-identifiable'): oldAt});
    final raw = sqlite3.open(path);
    raw.execute('INSERT INTO ark_reminders VALUES(?,?,?,?,?,?,?)', [
      account().canonical,
      -1,
      1,
      100,
      List.filled(64, 'a').join(),
      oldAt,
      original,
    ]);
    raw.close();
    final warning = ArkExpiryWarning.fromSnapshot(
      observed(vtxos: [vtxo('known', 200)]),
    );
    expect(warning, isNotNull);
    final result = await store.reconcile(
      account: account(),
      warning: warning,
      authoritativeEmpty: false,
      revision: 5,
      tipHeight: 100,
    );
    expect(result, isA<Err<void, ArkFailure>>());
    expect(gateway.scheduled.single.id, isNot(-1));
    expect(gateway.scheduled.single.at, warning?.notifyAt);
    final check = sqlite3.open(path);
    expect(check.select('SELECT * FROM ark_reminders'), hasLength(2));
    check.close();
    expect(gateway.cancelled, isEmpty);
  });
  test(
    'exact funding namespace is policy-cancelled without a VTXO replacement',
    () async {
      final original = seed({hash('board:b'): oldAt});
      expect(await apply(observed(boards: [board('b')])), isA<Ok>());
      expect(gateway.actions, ['cancel:-1']);
      expect(rows().single['platform_id'], -1);
      expect(payload(rows().single)['original'], original);
      expect(payload(rows().single)['funding'], [hash('board:b')]);
      expect(payload(rows().single)['vtxo'], isEmpty);
      final raw = sqlite3.open(path);
      raw.execute(
        'UPDATE ark_reminders SET signature=?,scheduled_at=?,deadline_bounds=?',
        [
          List.filled(64, 'a').join(),
          oldAt,
          jsonEncode({hash('funding:op'): oldAt}),
        ],
      );
      raw.close();
      final op = ArkOperation(
        id: 'op',
        kind: ArkOperationKind.board,
        status: ArkOperationStatus.outcomeUnknown,
        chainSource: Uri.parse('https://example.com'),
        configGeneration: 1,
      );
      expect(await apply(observed(revision: 6, operations: [op])), isA<Ok>());
      expect(payload(rows().single)['funding'], [hash('funding:op')]);
      expect(gateway.actions, ['cancel:-1', 'cancel:-1']);
    },
  );
  test('mixed intent commits before held failed schedule; reopen applies replacement before cancel', () async {
    final original = seed({hash('vtxo:v'): oldAt, hash('board:b'): oldAt});
    gateway
      ..hold = Completer<void>()
      ..fail = true;
    final pending = apply(
      observed(vtxos: [vtxo('v', 900)], boards: [board('b')]),
    );
    await Future<void>.delayed(Duration.zero);
    expect(rows(), hasLength(2));
    expect(payload(rows().last)['original'], original);
    expect(payload(rows().last)['intent'], 'cancel');
    expect(gateway.actions, ['schedule:-2']);
    expect(gateway.cancelled, isEmpty);
    gateway.hold?.complete();
    expect(
      await pending,
      isA<Err<void, ArkFailure>>().having(
        (r) => r.failure,
        'platform failure',
        isA<ArkReminderUnavailableFailure>(),
      ),
    );
    await store.close();
    gateway
      ..fail = false
      ..hold = null;
    reopen();
    expect(await store.reapplyStored(), isA<Ok>());
    expect(gateway.actions, ['schedule:-2', 'schedule:-2', 'cancel:-1']);
    expect(gateway.scheduled.last.at.microsecondsSinceEpoch, oldAt);
    expect(payload(rows().last)['original'], original);
  });
  test(
    'transferred VTXO is not recopied after positive linked retirement',
    () async {
      seed({hash('vtxo:old'): oldAt});
      await apply(observed(vtxos: [vtxo('old', 200)]));
      final replacement = observed(
        revision: 6,
        vtxos: [vtxo('new', 1000)],
        movements: [
          ArkMovement(
            id: 'renew',
            kind: ArkMovementKind.renewal,
            status: ArkMovementStatus.successful,
            inputVtxoIds: ['old'],
            outputVtxoIds: ['new'],
          ),
        ],
      );
      expect(await apply(replacement), isA<Ok>());
      final later = gateway.scheduled.last.at;
      expect(later.microsecondsSinceEpoch, greaterThan(oldAt));
      expect(
        await apply(observed(revision: 7, vtxos: [vtxo('new', 1000)])),
        isA<Ok>(),
      );
      expect(gateway.scheduled.last.at, later);
      expect(
        (payload(rows().first)['bounds'] as Map).containsKey(hash('vtxo:old')),
        false,
      );
    },
  );
  test(
    'raw unknown pending-board VTXO cannot erase earlier held VTXO bound',
    () async {
      await apply(observed(vtxos: [vtxo('held', 200)]));
      final first = gateway.scheduled.single;
      final unknown = ArkVtxo(
        id: 'held',
        amount: Sats.fromInt(1000),
        expiryHeight: 900,
        state: ArkVtxoState.unknown,
      );
      expect(
        await apply(
          observed(revision: 6, vtxos: [unknown], boards: [board('held')]),
        ),
        isA<Ok>(),
      );
      expect(gateway.scheduled.last, first);
      expect(gateway.cancelled, isEmpty);
      expect(
        ArkExpiryWarning.fromSnapshot(
          observed(vtxos: [vtxo('held', 200)], boards: [board('held')]),
        )?.expiries,
        {'vtxo:held': 200},
      );
      expect(
        await apply(observed(revision: 7, boards: [board('held')])),
        isA<Ok>(),
      );
      expect(gateway.cancelled, [first.id]);
    },
  );
  test('unknown legacy is skipped on replay while known VTXOs and another account progress', () async {
    final original = seed({hash('vtxo:not-a-vtxo'): oldAt});
    expect(
      await apply(observed(vtxos: [vtxo('v', 900)], boards: [board('b')])),
      isA<Err<void, ArkFailure>>().having(
        (r) => r.failure,
        'partial',
        isA<ArkReminderMigrationFailure>(),
      ),
    );
    final other = ArkAccountId(
      parent: Fingerprint('44556677'),
      network: BitcoinNetwork.mainnet,
      serverIdentity: account().serverIdentity,
    );
    expect(
      await apply(observed(owner: other, vtxos: [vtxo('v', 800)])),
      isA<Ok>(),
    );
    await store.close();
    reopen();
    gateway.actions.clear();
    expect(await store.reapplyStored(), isA<Err<void, ArkFailure>>());
    expect(gateway.actions, ['schedule:-2', 'schedule:-3']);
    gateway
      ..actions.clear()
      ..failId = -2;
    expect(
      await store.reapplyStored(),
      isA<Err<void, ArkFailure>>().having(
        (r) => r.failure,
        'platform failure precedes partial',
        isA<ArkReminderUnavailableFailure>(),
      ),
    );
    expect(gateway.actions, ['schedule:-2', 'schedule:-3']);
    expect(payload(rows().last)['original'], original);
    expect(rows().last['platform_id'], -1);
    expect(gateway.cancelled, isEmpty);
  });
  test(
    'warning and policy account/revision/tip mismatches refuse before effects',
    () async {
      final other = ArkAccountId(
        parent: Fingerprint('44556677'),
        network: BitcoinNetwork.mainnet,
        serverIdentity: account().serverIdentity,
      );
      for (final bad in [
        observed(revision: 4),
        observed(tip: 101),
        observed(owner: other),
      ]) {
        for (final useWarning in [true, false]) {
          final result = await store.reconcile(
            account: account(),
            warning: useWarning
                ? ArkExpiryWarning.fromSnapshot(
                    observed(
                      owner: bad.account,
                      revision: bad.revision,
                      tip: bad.tipHeight,
                      vtxos: [vtxo('v', 900)],
                    ),
                  )
                : null,
            authoritativeEmpty: false,
            revision: 5,
            tipHeight: 100,
            policyEvidence: useWarning
                ? null
                : ArkReminderPolicyEvidence.fromSnapshot(bad),
          );
          expect(
            result,
            isA<Err<void, ArkFailure>>().having(
              (r) => r.failure,
              'incoherent observation',
              isA<ArkInvalidRequestFailure>(),
            ),
          );
        }
      }
      expect(rows(), isEmpty);
      expect(gateway.actions, isEmpty);
    },
  );
  test('either purpose record rejects regressing revision or tip before classification', () async {
    seed({hash('board:b'): oldAt, hash('unknown'): oldAt});
    await apply(observed(revision: 10, tip: 110, vtxos: [vtxo('v', 900)]));
    final before = rows().map((r) => r.values.toList()).toList();
    final count = gateway.actions.length;
    for (final s in [
      observed(revision: 9, tip: 111, boards: [board('b')]),
      observed(revision: 11, tip: 109, boards: [board('b')]),
    ]) {
      expect(await apply(s), isA<Err<void, ArkFailure>>());
    }
    expect(rows().map((r) => r.values.toList()).toList(), before);
    expect(gateway.actions.length, count);
  });
  test('classification commit failure rolls back both intents before any platform effect', () async {
    final original = seed({hash('vtxo:v'): oldAt});
    final raw = sqlite3.open(path);
    raw.execute(
      "CREATE TRIGGER refuse_policy BEFORE UPDATE ON ark_reminders BEGIN SELECT RAISE(ABORT,'cut'); END",
    );
    raw.close();
    expect(
      await apply(observed(vtxos: [vtxo('v', 900)], boards: [board('b')])),
      isA<Err<void, ArkFailure>>(),
    );
    expect(rows(), hasLength(1));
    expect(rows().single['deadline_bounds'], original);
    expect(gateway.actions, isEmpty);
  });
  test(
    'strict payload families/classification/linkage refuse without reset',
    () async {
      final original = seed({hash('vtxo:v'): oldAt});
      final envelope = {
        'format': 2,
        'family': 'legacy',
        'original': original,
        'vtxo': [hash('vtxo:v')],
        'funding': <String>[],
        'intent': 'cancel',
      };
      for (final invalid in [
        {...envelope, 'format': 3},
        {...envelope, 'format': 2.0},
        {
          ...envelope,
          'funding': [hash('vtxo:v')],
        },
        envelope,
        {
          'format': 2,
          'family': 'vtxo',
          'bounds': {hash('vtxo:v'): oldAt},
        },
      ]) {
        final raw = sqlite3.open(path);
        final encoded = jsonEncode(invalid);
        raw.execute(
          'UPDATE ark_reminders SET deadline_bounds=?,scheduled_at=NULL',
          [encoded],
        );
        raw.close();
        expect(await store.reapplyStored(), isA<Err<void, ArkFailure>>());
        expect(rows().single['deadline_bounds'], encoded);
        expect(gateway.actions, isEmpty);
      }
    },
  );
  test(
    'old cancellation replays and its negative ID is never recycled',
    () async {
      seed({hash('anything'): oldAt});
      final raw = sqlite3.open(path);
      raw.execute(
        'UPDATE ark_reminders SET signature=NULL,scheduled_at=NULL,deadline_bounds=NULL',
      );
      raw.close();
      expect(await store.reapplyStored(), isA<Ok>());
      expect(await apply(observed(vtxos: [vtxo('v', 900)])), isA<Ok>());
      expect(gateway.actions, ['cancel:-1', 'schedule:-2', 'cancel:-1']);
      expect(rows().map((r) => r['platform_id']), [-2, -1]);
    },
  );
  for (final language in ['en', 'fr']) {
    testWidgets('partial migration is specifically localized in $language', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Localizations(
            locale: Locale(language),
            delegates: const [
              DefaultWidgetsLocalizations.delegate,
              ArkLocalizations.delegate,
            ],
            child: Builder(
              builder: (context) => Text(
                const ArkReminderMigrationFailure().toTranslated(context),
              ),
            ),
          ),
        ),
      );
      expect(
        find.text(
          language == 'en'
              ? 'Some older Ark reminders remain unresolved. New VTXO reminders can still be scheduled. Open Ark regularly.'
              : 'Certains anciens rappels Ark restent non résolus. De nouveaux rappels VTXO peuvent encore être programmés. Ouvrez Ark régulièrement.',
        ),
        findsOneWidget,
      );
    });
  }
}
