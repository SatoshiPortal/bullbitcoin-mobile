import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:drift/isolate.dart' show DriftRemoteException;

import 'package:primitives/primitives.dart';

import '../domain/payment.dart';
import '../domain/payment_ledger.dart';
import '../domain/payment_ledger_failure.dart';
import 'payment_database.dart';

/// Inactive foundation. Every mutation is a local persistence command; callers
/// must never replay an external effect in response to contention or stale data.
final class DriftPaymentLedger implements PaymentLedger {
  final PaymentDatabase _db;

  DriftPaymentLedger(this._db);

  Future<Result<T, PaymentLedgerFailure>> _guard<T>(
    Future<T> Function() action,
  ) async {
    try {
      return Ok(await action());
    } on _Rollback catch (error) {
      return Err(error.failure);
    } on FormatException {
      return const Err(PaymentLedgerFailure.recoveryRequired);
    } on Exception catch (error) {
      Object? cause = error;
      // Native background connections can wrap a migration failure twice.
      while (cause is DriftRemoteException || cause is DriftWrappedException) {
        cause = switch (cause) {
          DriftRemoteException(:final remoteCause) => remoteCause,
          DriftWrappedException(:final cause) => cause,
          _ => cause,
        };
      }
      if (cause is Error) Error.throwWithStackTrace(cause, StackTrace.current);
      if (cause is _Rollback) return Err(cause.failure);
      if (cause is FormatException || cause is CouldNotRollBackException) {
        return const Err(PaymentLedgerFailure.recoveryRequired);
      }
      final failure = cause is SqliteException
          ? switch (cause.resultCode) {
              5 || 6 => PaymentLedgerFailure.busy,
              11 || 26 => PaymentLedgerFailure.recoveryRequired,
              19 => PaymentLedgerFailure.conflict,
              _ => PaymentLedgerFailure.storage,
            }
          : PaymentLedgerFailure.storage;
      return Err(failure);
    }
  }

  List<Variable> _key(PaymentKey key) => [
    Variable<String>(key.network.name),
    Variable<String>(key.hash),
  ];

  Future<List<QueryRow>> _rows(String sql, List<Variable> variables) =>
      _db.customSelect(sql, variables: variables).get();

  Future<int> _write(String sql, List<Variable> variables) =>
      _db.customUpdate(sql, variables: variables);

  Never _fail(PaymentLedgerFailure failure) => throw _Rollback(failure);
  void _one(int count) {
    if (count != 1) _fail(PaymentLedgerFailure.stale);
  }

  int _int(QueryRow row, String column) {
    final value = row.data[column];
    if (value is! int) _fail(PaymentLedgerFailure.recoveryRequired);
    return value;
  }

  String _text(QueryRow row, String column) {
    final value = row.data[column];
    if (value is! String) _fail(PaymentLedgerFailure.recoveryRequired);
    return value;
  }

  int? _nullableInt(QueryRow row, String column) =>
      row.data[column] == null ? null : _int(row, column);
  String? _nullableText(QueryRow row, String column) =>
      row.data[column] == null ? null : _text(row, column);

  String _sources(PaymentReview review) => jsonEncode([
    for (final source in review.sources)
      {
        'wallet': source.walletId,
        'rail': source.rail,
        'ceiling': source.maxDebitSat,
      },
  ]);

  Future<void> _insertReview(
    PaymentKey key,
    int id,
    PaymentReview review,
  ) async {
    _one(
      await _write(
        '''INSERT INTO payment_reviews
      (network, hash, id, policy, sources) VALUES (?, ?, ?, ?, ?)''',
        [
          ..._key(key),
          Variable<int>(id),
          Variable<String>(review.policyId),
          Variable<String>(_sources(review)),
        ],
      ),
    );
  }

  @override
  Future<Result<PaymentSnapshot?, PaymentLedgerFailure>> read(PaymentKey key) =>
      _guard(() => _db.transaction(() => _read(key)));

  Future<PaymentSnapshot> _required(PaymentKey key) async {
    final payment = await _read(key);
    if (payment == null) _fail(PaymentLedgerFailure.recoveryRequired);
    return payment;
  }

  Future<PaymentSnapshot?> _read(PaymentKey key) async {
    final payments = await _rows(
      'SELECT * FROM payments WHERE network = ? AND hash = ?',
      _key(key),
    );
    if (payments.isEmpty) return null;
    final row = payments.single;
    final reviewId = _int(row, 'review_id');
    final reviews = await _rows(
      '''SELECT * FROM payment_reviews
      WHERE network = ? AND hash = ? AND id = ?''',
      [..._key(key), Variable<int>(reviewId)],
    );
    if (reviews.length != 1) _fail(PaymentLedgerFailure.recoveryRequired);
    final reviewRow = reviews.single;
    final rawSources = jsonDecode(_text(reviewRow, 'sources'));
    if (rawSources is! List) _fail(PaymentLedgerFailure.recoveryRequired);
    final sources = <PaymentSource>[];
    for (final raw in rawSources) {
      if (raw is! Map ||
          raw['wallet'] is! String ||
          raw['rail'] is! String ||
          raw['ceiling'] is! int) {
        _fail(PaymentLedgerFailure.recoveryRequired);
      }
      sources.add(
        PaymentSource(
          raw['wallet'] as String,
          raw['rail'] as String,
          raw['ceiling'] as int,
        ),
      );
    }
    final review = PaymentReview(_text(reviewRow, 'policy'), sources);
    final attemptRows = await _rows('''SELECT * FROM payment_attempts
      WHERE network = ? AND hash = ? ORDER BY ordinal''', _key(key));
    final attempts = <PaymentAttempt>[];
    for (final a in attemptRows) {
      final ordinal = _int(a, 'ordinal');
      final source = PaymentSource(
        _text(a, 'wallet'),
        _text(a, 'rail'),
        _int(a, 'ceiling'),
      );
      final stage = _stage(_text(a, 'stage'));
      final operation = _text(a, 'operation_id');
      final backend = _nullableText(a, 'backend');
      final receipt = _nullableText(a, 'receipt');
      if (ordinal != attempts.length + 1 ||
          ordinal > sources.length ||
          _int(a, 'review_id') != reviewId ||
          operation.isEmpty ||
          !_sameSource(source, sources[ordinal - 1]) ||
          stage == PaymentStage.reviewed ||
          backend == '' ||
          receipt == '' ||
          ({
                PaymentStage.preflight,
                PaymentStage.preflightRefused,
                PaymentStage.creating,
              }.contains(stage) &&
              backend != null) ||
          ({
                PaymentStage.preflight,
                PaymentStage.creating,
                PaymentStage.created,
                PaymentStage.fundingSealed,
              }.contains(stage) &&
              receipt != null) ||
          (stage == PaymentStage.unknown &&
              receipt != null &&
              backend == null) ||
          ({
                PaymentStage.created,
                PaymentStage.fundingSealed,
                PaymentStage.pending,
                PaymentStage.paid,
              }.contains(stage) &&
              backend == null) ||
          ({
                PaymentStage.preflightRefused,
                PaymentStage.pending,
                PaymentStage.paid,
              }.contains(stage) &&
              receipt == null)) {
        _fail(PaymentLedgerFailure.recoveryRequired);
      }
      attempts.add(
        PaymentAttempt(
          ordinal: ordinal,
          operationId: operation,
          reviewId: reviewId,
          source: source,
          stage: stage,
          backendReference: backend,
          receiptReference: receipt,
        ),
      );
    }
    final count = _int(row, 'attempt_count');
    final active = _nullableInt(row, 'active_ordinal');
    final stage = _stage(_text(row, 'stage'));
    final revision = _int(row, 'revision');
    if (reviewId < 1 ||
        revision < 1 ||
        count != attempts.length ||
        (active == null && stage != PaymentStage.reviewed) ||
        (active != null &&
            (stage == PaymentStage.reviewed ||
                stage == PaymentStage.preflightRefused ||
                active != count ||
                count == 0 ||
                attempts.last.stage != stage)) ||
        attempts
            .take(active == null ? count : count - 1)
            .any((a) => a.stage != PaymentStage.preflightRefused)) {
      _fail(PaymentLedgerFailure.recoveryRequired);
    }
    return PaymentSnapshot(
      request: BoundPaymentRequest(
        key,
        _text(row, 'request'),
        _int(row, 'amount_msat'),
      ),
      review: review,
      reviewId: reviewId,
      revision: revision,
      attemptCount: count,
      stage: stage,
      attempts: List.unmodifiable(attempts),
      activeOrdinal: active,
    );
  }

  PaymentStage _stage(String value) => PaymentStage.values.firstWhere(
    (stage) => stage.name == value,
    orElse: () => _fail(PaymentLedgerFailure.recoveryRequired),
  );

  bool _sameSource(PaymentSource a, PaymentSource b) =>
      a.walletId == b.walletId &&
      a.rail == b.rail &&
      a.maxDebitSat == b.maxDebitSat;

  @override
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> createOrReadReview(
    BoundPaymentRequest request,
    PaymentReview review,
  ) => _guard(
    () => _db.transaction(() async {
      // First operation is a write, avoiding deferred read-to-write upgrades.
      final inserted = await _write(
        '''INSERT INTO payments
        (network, hash, request, amount_msat, revision, review_id, attempt_count, stage)
        VALUES (?, ?, ?, ?, 1, 1, 0, 'reviewed')
        ON CONFLICT(network, hash) DO NOTHING''',
        [
          ..._key(request.key),
          Variable<String>(request.request),
          Variable<int>(request.amountMsat),
        ],
      );
      if (inserted == 1) await _insertReview(request.key, 1, review);
      final result = await _required(request.key);
      if (result.request.request != request.request ||
          result.request.amountMsat != request.amountMsat) {
        _fail(PaymentLedgerFailure.conflict);
      }
      return result;
    }),
  );

  @override
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> replaceUnadmittedReview(
    PaymentKey key,
    int revision,
    PaymentReview review,
  ) => _guard(
    () => _db.transaction(() async {
      _one(
        await _write(
          """UPDATE payments SET revision = revision
      WHERE network = ? AND hash = ? AND revision = ? AND active_ordinal IS NULL
      AND attempt_count = 0 AND stage = 'reviewed'""",
          [..._key(key), Variable<int>(revision)],
        ),
      );
      final current = await _required(key);
      _one(
        await _write(
          """UPDATE payments SET revision = revision + 1, review_id = review_id + 1
      WHERE network = ? AND hash = ? AND revision = ? AND active_ordinal IS NULL
      AND attempt_count = 0 AND stage = 'reviewed'""",
          [..._key(key), Variable<int>(revision)],
        ),
      );
      await _insertReview(key, current.reviewId + 1, review);
      return _required(key);
    }),
  );

  @override
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> beginPreflight(
    PaymentKey key,
    int revision,
    PaymentSource source,
    String operationId,
  ) => _guard(
    () => _db.transaction(() async {
      if (operationId.isEmpty) _fail(PaymentLedgerFailure.conflict);
      _one(
        await _write(
          """UPDATE payments SET revision = revision
      WHERE network = ? AND hash = ? AND revision = ? AND active_ordinal IS NULL
      AND stage = 'reviewed'""",
          [..._key(key), Variable<int>(revision)],
        ),
      );
      final current = await _required(key);
      if (current.attemptCount >= current.review.sources.length ||
          !_sameSource(source, current.review.sources[current.attemptCount])) {
        _fail(PaymentLedgerFailure.conflict);
      }
      final ordinal = current.attemptCount + 1;
      _one(
        await _write(
          """UPDATE payments SET revision = revision + 1,
      attempt_count = attempt_count + 1, active_ordinal = attempt_count + 1, stage = 'preflight'
      WHERE network = ? AND hash = ? AND revision = ? AND active_ordinal IS NULL
      AND stage = 'reviewed'""",
          [..._key(key), Variable<int>(revision)],
        ),
      );
      _one(
        await _write(
          """INSERT INTO payment_attempts
      (network, hash, ordinal, operation_id, review_id, wallet, rail, ceiling, stage)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'preflight')""",
          [
            ..._key(key),
            Variable<int>(ordinal),
            Variable<String>(operationId),
            Variable<int>(current.reviewId),
            Variable<String>(source.walletId),
            Variable<String>(source.rail),
            Variable<int>(source.maxDebitSat),
          ],
        ),
      );
      return _required(key);
    }),
  );

  Future<PaymentSnapshot> _transition(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
    Set<PaymentStage> predecessors,
    PaymentStage target, {
    String? backend,
    String? receipt,
    bool clear = false,
  }) => _db.transaction(() async {
    final key = expected.request.key;
    if (!predecessors.contains(expected.stage) ||
        expected.activeOrdinal != attempt.ordinal ||
        expected.reviewId != attempt.reviewId ||
        !predecessors.contains(attempt.stage)) {
      _fail(PaymentLedgerFailure.stale);
    }
    _one(
      await _write(
        """UPDATE payments SET revision = revision
      WHERE network = ? AND hash = ? AND revision = ? AND review_id = ?
      AND active_ordinal = ? AND stage = ?""",
        [
          ..._key(key),
          Variable<int>(expected.revision),
          Variable<int>(attempt.reviewId),
          Variable<int>(attempt.ordinal),
          Variable<String>(expected.stage.name),
        ],
      ),
    );
    await _required(key);
    _one(
      await _write(
        '''UPDATE payments SET revision = revision + 1, stage = ?, active_ordinal = ?
      WHERE network = ? AND hash = ? AND revision = ? AND review_id = ?
      AND active_ordinal = ? AND stage = ?''',
        [
          Variable<String>(clear ? 'reviewed' : target.name),
          Variable<int>(clear ? null : attempt.ordinal),
          ..._key(key),
          Variable<int>(expected.revision),
          Variable<int>(attempt.reviewId),
          Variable<int>(attempt.ordinal),
          Variable<String>(expected.stage.name),
        ],
      ),
    );
    _one(
      await _write(
        '''UPDATE payment_attempts SET stage = ?, backend = COALESCE(backend, ?), receipt = COALESCE(?, receipt)
      WHERE network = ? AND hash = ? AND ordinal = ? AND operation_id = ?
      AND review_id = ? AND stage = ? AND wallet = ? AND rail = ? AND ceiling = ?
      AND (backend IS NULL OR backend = ?)''',
        [
          Variable<String>(target.name),
          Variable<String>(backend),
          Variable<String>(receipt),
          ..._key(key),
          Variable<int>(attempt.ordinal),
          Variable<String>(attempt.operationId),
          Variable<int>(attempt.reviewId),
          Variable<String>(attempt.stage.name),
          Variable<String>(attempt.source.walletId),
          Variable<String>(attempt.source.rail),
          Variable<int>(attempt.source.maxDebitSat),
          Variable<String>(backend ?? attempt.backendReference),
        ],
      ),
    );
    return _required(key);
  });

  @override
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> closePreflightRefused(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
    PreflightRefusal refusal,
  ) => _guard(() {
    if (refusal.network != expected.request.key.network ||
        refusal.operationId != attempt.operationId ||
        refusal.walletId != attempt.source.walletId) {
      _fail(PaymentLedgerFailure.conflict);
    }
    return _transition(
      expected,
      attempt,
      {PaymentStage.preflight},
      PaymentStage.preflightRefused,
      receipt: '${refusal.reason.name}:${refusal.reference}',
      clear: true,
    );
  });

  @override
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> sealCreate(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
  ) => _guard(
    () => _transition(expected, attempt, {
      PaymentStage.preflight,
    }, PaymentStage.creating),
  );

  @override
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> linkCreated(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
    String backendReference,
  ) => _guard(() {
    if (backendReference.isEmpty) _fail(PaymentLedgerFailure.conflict);
    return _transition(
      expected,
      attempt,
      {PaymentStage.creating, PaymentStage.unknown},
      expected.stage == PaymentStage.unknown
          ? PaymentStage.unknown
          : PaymentStage.created,
      backend: backendReference,
    );
  });

  @override
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> sealFunding(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
  ) => _guard(
    () => _transition(
      expected,
      attempt,
      {PaymentStage.created},
      PaymentStage.fundingSealed,
      backend: attempt.backendReference,
    ),
  );

  @override
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> recordUnknown(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
  ) => _guard(
    () => _transition(
      expected,
      attempt,
      {
        PaymentStage.creating,
        PaymentStage.created,
        PaymentStage.fundingSealed,
        PaymentStage.pending,
      },
      PaymentStage.unknown,
      backend: attempt.backendReference,
    ),
  );

  void _correlate(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
    PaymentReceipt receipt,
  ) {
    if (receipt.network != expected.request.key.network ||
        receipt.operationId != attempt.operationId ||
        receipt.walletId != attempt.source.walletId ||
        receipt.backendReference != attempt.backendReference) {
      _fail(PaymentLedgerFailure.conflict);
    }
  }

  @override
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> recordPending(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
    PaymentReceipt receipt,
  ) => _guard(() {
    _correlate(expected, attempt, receipt);
    return _transition(
      expected,
      attempt,
      {PaymentStage.fundingSealed},
      PaymentStage.pending,
      backend: receipt.backendReference,
      receipt: receipt.reference,
    );
  });

  @override
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> recordPaid(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
    PaymentReceipt receipt,
  ) => _guard(() async {
    _correlate(expected, attempt, receipt);
    final current = await _db.transaction(() => _read(expected.request.key));
    if (current != null && current.stage == PaymentStage.paid) {
      final paid = current.active;
      if (paid == null) _fail(PaymentLedgerFailure.recoveryRequired);
      if (paid.operationId == receipt.operationId &&
          paid.source.walletId == receipt.walletId &&
          paid.backendReference == receipt.backendReference &&
          paid.receiptReference == receipt.reference) {
        return current;
      }
      _fail(PaymentLedgerFailure.conflict);
    }
    return _transition(
      expected,
      attempt,
      {PaymentStage.fundingSealed, PaymentStage.pending, PaymentStage.unknown},
      PaymentStage.paid,
      backend: receipt.backendReference,
      receipt: receipt.reference,
    );
  });
}

/// Used only to abort the transaction before conversion to a domain failure.
final class _Rollback implements Exception {
  final PaymentLedgerFailure failure;

  const _Rollback(this.failure);
}
