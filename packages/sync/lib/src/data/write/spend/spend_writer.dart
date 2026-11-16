import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../../../domain/bitcoin_spend.dart';
import '../../../domain/ports/input_reservation_port.dart';
import '../../../domain/ports/wallet_connection_port.dart';
import '../../../domain/public_wallet_descriptor.dart';
import '../../../domain/spend.dart';
import '../../../domain/sync_failure.dart';
import '../../../domain/wallet_key.dart';
import '../../../domain/wallet_revision.dart';
import '../../../domain/wallet_values.dart';
import '../../../domain/observed.dart';
import '../../bitcoin_transaction_decoder.dart';
import '../../chain/electrum_chain.dart';
import '../../datasources/revision_store_datasource.dart';
import '../../freeze_authority.dart';
import '../bitcoin_spend_gate.dart';
import '../writer_session.dart';
import 'native_spend.dart';

/// Sends a signed transaction and returns its txid. Production uses the
/// owner's connection port; tests substitute it.
typedef SpendTransport = Future<Result<String, SyncFailure>> Function(
  SignedTransaction transaction,
  Network network,
);

/// What a wallet handle may ask of the spend writer. Implemented by
/// [SpendWriter]; a test wallet without native stores refuses everything.
abstract interface class WalletSpender {
  Future<Result<UnsignedSpend, SyncFailure>> build(
    WalletKey key,
    int generation,
    SpendRequest request,
  );
  Future<Result<UnsignedSpend, SyncFailure>> bump(
    WalletKey key,
    int generation,
    BumpFeeRequest request,
  );
  Future<Result<List<UnsignedSpend>, SyncFailure>> consolidate(
    WalletKey key,
    int generation,
    ConsolidationRequest request,
  );
  Future<Result<SpendReceipt, SyncFailure>> broadcast(SignedSpend spend);
  Future<Result<BitcoinSpendStatus, SyncFailure>> check(
    WalletKey key,
    int generation, {
    String? replacing,
  });
  Observed<WalletValue<BitcoinSpendStatus>> readiness(WalletKey key);
  Future<Result<SignatureCheck, SyncFailure>> originalSignatures(
    WalletKey key,
    int generation,
    String txid,
  );
  Future<Result<String, SyncFailure>> annotate(
    WalletKey key,
    int generation,
    String psbt,
  );
  Future<Result<BigInt, SyncFailure>> liquidAmountToAddress(
    WalletKey key,
    int generation,
    String pset,
    String address,
  );

  Future<Result<LiquidPsetEffect, SyncFailure>> liquidEffect(
    WalletKey key,
    int generation,
    String pset,
  );
}

/// The protections a spend's inputs are checked against.
final class _Policy {
  final Set<Outpoint> frozen;

  /// Reserved by a session other than the spend's owner, or for another
  /// wallet: never spendable here.
  final Set<Outpoint> reserved;

  /// Reserved by the attested owner for this wallet only.
  final Set<Outpoint> owned;

  _Policy(this.frozen, this.reserved, Set<Outpoint> owned)
    : owned = owned.difference(reserved);

  Set<Outpoint> get excluded => {...frozen, ...reserved};

  /// Null when [inputs] may be spent; otherwise the protected ones. Owned
  /// reservations are exempt only within [exempt]; freezes never are.
  SyncProtectedInputsFailure? check(
    Iterable<Outpoint> inputs, {
    Set<Outpoint> exempt = const {},
  }) {
    final frozen = <Outpoint>{};
    final reserved = <Outpoint>{};
    for (final input in inputs) {
      if (this.frozen.contains(input)) frozen.add(input);
      if (this.reserved.contains(input) ||
          (owned.contains(input) && !exempt.contains(input))) {
        reserved.add(input);
      }
    }
    if (frozen.isEmpty && reserved.isEmpty) return null;
    return SyncProtectedInputsFailure(frozen: frozen, reserved: reserved);
  }
}

/// Native spends, as commands of the single writer.
///
/// Each command follows one order: admission of the writer and of the
/// generation (and, for Bitcoin, of the spend guard) → writer lock → durable
/// intent → native wallet opened fresh from its store → freezes and
/// reservations read → one build → check of the effective inputs, outputs,
/// network and owner → persistence of the native changes, refused build
/// included → native close → release → hand-out. A persistence failure
/// never hands a transaction out; no native wallet outlives its command.
final class SpendWriter implements WalletSpender {
  final WriterSession _session;
  final BitcoinSpendGate _gate;
  final FreezeAuthority _freezes;
  final InputReservationPort _reservations;
  final NativeSpendSessions _natives;
  final SpendTransport _send;
  final bool Function() _closed;
  final Map<WalletKey, _ReadinessCell> _readiness = {};

  /// The guard requests in flight, awaited by [close].
  final Set<Future<void>> _requests = {};
  late final StreamSubscription<WalletRevisionState> _changes;

  SpendWriter({
    required this._session,
    required this._gate,
    required this._freezes,
    required this._reservations,
    required this._natives,
    required this._send,
    required this._closed,
  }) {
    // A new revision may settle or create an obligation: ask the guard again
    // for every wallet whose readiness was asked for.
    _changes = _session.reader.changes.listen((state) {
      final cell = _readiness[state.stamp.key];
      if (cell != null) _refresh(state.stamp.key, cell);
    });
  }

  /// Broadcasts through the servers [connections] selects.
  static SpendTransport transport(WalletConnectionPort connections) =>
      (transaction, network) async => switch ((transaction, network)) {
        (SignedBitcoinTransaction(:final bytes), BitcoinNetwork network) =>
          broadcastBitcoinTransaction(
            bytes,
            network: network,
            connections: connections,
          ),
        (SignedPset(:final pset), LiquidNetwork network) =>
          broadcastLiquidTransaction(
            pset,
            network: network,
            connections: connections,
          ),
        _ => const Err(SyncInvalidTransactionFailure()),
      };

  RevisionStoreDatasource get _revisions => _session.revisions;

  Future<_Policy> _policy(WalletKey key, SpendOwner? owner) async {
    final frozen = WriterSession.value(await _freezes.forbiddenInputs());
    return _policyWith(key, owner, frozen);
  }

  Future<_Policy> _policyWith(
    WalletKey key,
    SpendOwner? owner,
    Set<Outpoint> frozen,
  ) async {
    final reserved = <Outpoint>{};
    final owned = <Outpoint>{};
    // A failed read is never an empty set: the spend is refused.
    for (final reservation in WriterSession.value(
      await _reservations.reservations(),
    )) {
      final mine =
          owner != null &&
          reservation.protocol == owner.protocol &&
          reservation.session == owner.session &&
          reservation.walletId == key.id &&
          reservation.network == key.network;
      (mine ? owned : reserved).add(reservation.outpoint);
    }
    return _Policy(frozen, reserved, owned);
  }

  /// Refuses while the Bitcoin guard does, and publishes its verdict.
  Future<void> _admitBitcoin(WalletKey key, {String? replacing}) async {
    final status = await _gate.statusUnderLock(key, replacing: replacing);
    _publish(key, status);
    if (status != BitcoinSpendStatus.ready) {
      throw WriterRefusal(SyncSpendBlockedFailure(status));
    }
  }

  /// Runs [operation] on a native wallet opened for this command only, then
  /// persists what it staged, even when [operation] refused, and closes it.
  Future<T> _command<T, N>(
    WalletKey key,
    RevisionRecord record,
    Future<N> Function() open,
    Future<T> Function(N native) operation, {
    required bool Function(N native) persist,
    required void Function(N native) close,
  }) async {
    _revisions.begin(key, WriteIntent.load);
    late final T result;
    SyncFailure? refusal;
    var persisted = false;
    try {
      final native = await open();
      try {
        try {
          result = await operation(native);
        } on SpendRefusal catch (error) {
          refusal = error.failure;
        }
        // Native changes are kept, a refused build's included; a failure
        // here propagates and nothing is handed out.
        persisted = persist(native);
      } finally {
        close(native);
      }
    } finally {
      // Only a persisted change commits a revision; otherwise the store is
      // as it was, whatever ended the command.
      if (persisted) {
        _session.finish(key);
      } else {
        _session.cancelUnchanged(key, record);
      }
    }
    if (refusal != null) throw WriterRefusal(refusal);
    return result;
  }

  Future<Result<T, SyncFailure>> _run<T>(
    WalletKey key,
    int generation,
    Future<T> Function(RevisionRecord record, PublicWalletDescriptor descriptor)
    operation,
  ) async {
    if (_closed()) return const Err(SyncClosedFailure());
    return _session.run(key, generation, WriteIntent.load, () async {
      final record = _session.active(key, generation);
      if (record.needsSync) {
        throw const WriterRefusal(SyncNeedsRepairFailure());
      }
      return operation(record, await _session.descriptor(key));
    }, spend: true);
  }

  WalletRevision _committed(WalletKey key) =>
      _revisions.record(key)?.state.stamp ??
      (throw const WriterRefusal(SyncNotFoundFailure()));

  @override
  Future<Result<UnsignedSpend, SyncFailure>> build(
    WalletKey key,
    int generation,
    SpendRequest request,
  ) => _run(key, generation, (record, descriptor) async {
    switch ((descriptor, request)) {
      case (
        final BitcoinWalletDescriptor bitcoin,
        final BitcoinSpendRequest request,
      ):
        await _admitBitcoin(key);
        final policy = await _policy(key, request.owner);
        if (request.selected case final selected?) {
          if (policy.check(selected, exempt: policy.owned) case final hit?) {
            throw WriterRefusal(hit);
          }
        }
        final excluded = {...policy.excluded, ...request.exclude};
        final built = await _command(
          key,
          record,
          () => _natives.bitcoin(bitcoin),
          (native) async {
            final built = native.build(request, excluded);
            if (policy.check(built.inputs, exempt: policy.owned)
                case final hit?) {
              throw SpendRefusal(hit);
            }
            if (built.inputs.any(request.exclude.contains) ||
                !native.paysAsRequested(built.encoded, request)) {
              throw const SpendRefusal(SyncSpendRefusedFailure());
            }
            return built;
          },
          persist: (native) => native.persist(),
          close: (native) => native.close(),
        );
        return UnsignedSpend(
          revision: _committed(key),
          encoded: built.encoded,
          inputs: built.inputs,
          owner: request.owner,
        );
      case (
        final LiquidWalletDescriptor liquid,
        final LiquidSpendRequest request,
      ):
        switch (await _natives.liquidAddressNetwork(request.address)) {
          case Ok(:final value) when value == key.network:
            break;
          case _:
            throw const WriterRefusal(SyncInvalidAddressFailure());
        }
        final policy = await _policy(key, null);
        final excluded = {...policy.excluded, ...request.exclude};
        final pset = await _command(
          key,
          record,
          () => _natives.liquid(liquid),
          (native) async {
            final coins = {
              for (final coin in await native.coins()) coin.outpoint,
            };
            final available = coins.difference(excluded);
            var inputs = request.selected;
            if (inputs != null) {
              if (policy.check(inputs) case final hit?) throw SpendRefusal(hit);
              if (inputs.isEmpty || !available.containsAll(inputs)) {
                throw const SpendRefusal(SyncNoSpendableInputsFailure());
              }
            } else if (coins.any(excluded.contains)) {
              // LWK's coin selection cannot exclude: name the others.
              inputs = available;
            }
            if (inputs != null && inputs.isEmpty) {
              throw const SpendRefusal(SyncNoSpendableInputsFailure());
            }
            final pset = await native.build(request, inputs);
            _checkLiquid(pset, policy, request.exclude);
            return pset;
          },
          persist: (_) => false,
          close: (native) => native.close(),
        );
        return UnsignedSpend(
          revision: _committed(key),
          encoded: pset,
          inputs: _liquidInputs(pset),
        );
      case _:
        throw const WriterRefusal(SyncUnsupportedNetworkFailure());
    }
  });

  List<Outpoint> _liquidInputs(String pset) => _natives.psetInputs(pset);

  void _checkLiquid(String pset, _Policy policy, Set<Outpoint> exclude) {
    final inputs = _liquidInputs(pset);
    if (policy.check(inputs) case final hit?) throw SpendRefusal(hit);
    if (inputs.any(exclude.contains)) {
      throw const SpendRefusal(SyncSpendRefusedFailure());
    }
  }

  @override
  Future<Result<UnsignedSpend, SyncFailure>> bump(
    WalletKey key,
    int generation,
    BumpFeeRequest request,
  ) => _run(key, generation, (record, descriptor) async {
    if (descriptor is! BitcoinWalletDescriptor) {
      throw const WriterRefusal(SyncUnsupportedNetworkFailure());
    }
    await _admitBitcoin(key, replacing: request.txid);
    final policy = await _policy(key, request.owner);
    final built = await _command(
      key,
      record,
      () => _natives.bitcoin(descriptor),
      (native) async {
        final check = await native.originalSignatures(request.txid);
        if (check != SignatureCheck.valid) {
          throw SpendRefusal(SyncOriginalSignaturesFailure(check));
        }
        final original = native.transactionInputs(request.txid);
        if (original == null) {
          throw const SpendRefusal(SyncSpendRefusedFailure());
        }
        final built = native.bumpFee(request.txid, request.fee);
        // Only the original's inputs may keep its owner's reservations; an
        // input the builder added faces every protection.
        if (policy.check(
              built.inputs,
              exempt: policy.owned.intersection(original.toSet()),
            )
            case final hit?) {
          throw SpendRefusal(hit);
        }
        if (!native.keepsPayees(built.encoded, request.txid)) {
          throw const SpendRefusal(SyncSpendRefusedFailure());
        }
        return built;
      },
      persist: (native) => native.persist(),
      close: (native) => native.close(),
    );
    return UnsignedSpend(
      revision: _committed(key),
      encoded: built.encoded,
      inputs: built.inputs,
      owner: request.owner,
      replacing: request.txid,
    );
  });

  @override
  Future<Result<List<UnsignedSpend>, SyncFailure>> consolidate(
    WalletKey key,
    int generation,
    ConsolidationRequest request,
  ) => _run(key, generation, (record, descriptor) async {
    if (descriptor is! LiquidWalletDescriptor) {
      throw const WriterRefusal(SyncUnsupportedNetworkFailure());
    }
    final policy = await _policy(key, null);
    final psets = await _command(
      key,
      record,
      () => _natives.liquid(descriptor),
      (native) async {
        final coins = await native.coins();
        final List<String> psets;
        if (coins.any((coin) => policy.excluded.contains(coin.outpoint))) {
          // LWK's helper cannot exclude: batch the others explicitly.
          final eligible = [
            for (final coin in coins)
              if (coin.confirmed && !policy.excluded.contains(coin.outpoint))
                coin.outpoint,
          ];
          if (eligible.length <= request.highUtxoThreshold) return <String>[];
          psets = await native.consolidate(request, eligible);
        } else {
          psets = await native.consolidateAll(request);
        }
        // Every batch is checked: one protected input refuses them all.
        for (final pset in psets) {
          _checkLiquid(pset, policy, const {});
        }
        return psets;
      },
      persist: (_) => false,
      close: (native) => native.close(),
    );
    final revision = _committed(key);
    return [
      for (final pset in psets)
        UnsignedSpend(
          revision: revision,
          encoded: pset,
          inputs: _liquidInputs(pset),
        ),
    ];
  });

  @override
  Future<Result<SignatureCheck, SyncFailure>> originalSignatures(
    WalletKey key,
    int generation,
    String txid,
  ) => _run(key, generation, (record, descriptor) async {
    if (descriptor is! BitcoinWalletDescriptor) {
      throw const WriterRefusal(SyncUnsupportedNetworkFailure());
    }
    return _command(
      key,
      record,
      () => _natives.bitcoin(descriptor),
      (native) => native.originalSignatures(txid),
      persist: (native) => native.persist(),
      close: (native) => native.close(),
    );
  });

  @override
  Future<Result<String, SyncFailure>> annotate(
    WalletKey key,
    int generation,
    String psbt,
  ) => _run(key, generation, (record, descriptor) async {
    if (descriptor is! BitcoinWalletDescriptor) {
      throw const WriterRefusal(SyncUnsupportedNetworkFailure());
    }
    return _command(
      key,
      record,
      () => _natives.bitcoin(descriptor),
      (native) async {
        try {
          return native.annotate(psbt);
        } on Exception {
          throw const SpendRefusal(SyncInvalidTransactionFailure());
        }
      },
      persist: (native) => native.persist(),
      close: (native) => native.close(),
    );
  });

  @override
  Future<Result<BigInt, SyncFailure>> liquidAmountToAddress(
    WalletKey key,
    int generation,
    String pset,
    String address,
  ) => _run(key, generation, (record, descriptor) async {
    if (descriptor is! LiquidWalletDescriptor) {
      throw const WriterRefusal(SyncUnsupportedNetworkFailure());
    }
    return _command(
      key,
      record,
      () => _natives.liquid(descriptor),
      (native) => native.amountToAddress(pset, address),
      persist: (_) => false,
      close: (native) => native.close(),
    );
  });

  @override
  Future<Result<LiquidPsetEffect, SyncFailure>> liquidEffect(
    WalletKey key,
    int generation,
    String pset,
  ) => _run(key, generation, (record, descriptor) async {
    if (descriptor is! LiquidWalletDescriptor) {
      throw const WriterRefusal(SyncUnsupportedNetworkFailure());
    }
    return _command(
      key,
      record,
      () => _natives.liquid(descriptor),
      (native) => native.effect(pset),
      persist: (_) => false,
      close: (native) => native.close(),
    );
  });

  @override
  Future<Result<BitcoinSpendStatus, SyncFailure>> check(
    WalletKey key,
    int generation, {
    String? replacing,
  }) async {
    if (_closed()) return const Err(SyncClosedFailure());
    if (key.network is! BitcoinNetwork) {
      return const Err(SyncUnsupportedNetworkFailure());
    }
    if (await _generationFailure(key, generation) case final failure?) {
      return Err(failure);
    }
    final status = await _gate.check(key, replacing: replacing);
    _publish(key, status);
    return Ok(status);
  }

  Future<SyncFailure?> _generationFailure(WalletKey key, int generation) async {
    switch (await _session.reader.read(key)) {
      case Ok(:final value)
          when value.stamp.generation == generation &&
              value.lifecycle != WalletLifecycle.deleted:
        return null;
      case Ok():
        return const SyncNotFoundFailure();
      case Err(:final failure):
        return failure;
    }
  }

  @override
  Observed<WalletValue<BitcoinSpendStatus>> readiness(WalletKey key) =>
      _cell(key);

  /// The first demand schedules the guard's verdict; `now` never asks it.
  _ReadinessCell _cell(WalletKey key) => _readiness.putIfAbsent(key, () {
    late final _ReadinessCell cell;
    cell = _ReadinessCell(() => _refresh(key, cell));
    _refresh(key, cell);
    return cell;
  });

  /// Asks the guard outside `now`, one request per wallet at a time, and
  /// publishes its verdict unless a command published a newer one meanwhile.
  void _refresh(WalletKey key, _ReadinessCell cell) {
    if (_closed() || cell.closed) return;
    if (cell.refreshing) {
      cell.again = true;
      return;
    }
    cell.refreshing = true;
    late final Future<void> request;
    request = Future.microtask(() async {
      try {
        do {
          cell.again = false;
          final published = cell.publications;
          if (key.network is! BitcoinNetwork) {
            cell.set(
              const WalletValue<BitcoinSpendStatus>.unavailable(
                SyncUnsupportedNetworkFailure(),
              ),
            );
            return;
          }
          final status = await _gate.check(key);
          if (_closed() || cell.closed) return;
          if (cell.publications == published) _publish(key, status);
        } while (cell.again);
      } finally {
        cell.refreshing = false;
        _requests.remove(request);
      }
    });
    _requests.add(request);
  }

  void _publish(WalletKey key, BitcoinSpendStatus status) {
    final stamp = _revisions.record(key)?.state.stamp;
    final cell = _cell(key);
    cell.publications++;
    cell.set(
      stamp == null
          ? WalletValue<BitcoinSpendStatus>.unavailable(
              const SyncNotFoundFailure(),
            )
          : WalletValue.ready(status, stamp),
    );
  }

  @override
  Future<Result<SpendReceipt, SyncFailure>> broadcast(SignedSpend spend) async {
    if (_closed()) return const Err(SyncClosedFailure());
    final key = spend.key;
    switch ((key.network, spend.transaction)) {
      case (final BitcoinNetwork network, SignedPsbt(:final psbt)):
        final DecodedBitcoinTransaction decoded;
        try {
          decoded = decodeBitcoinPsbt(psbt);
        } on FormatException {
          return const Err(SyncInvalidTransactionFailure());
        }
        return _broadcastBitcoin(
          spend,
          network,
          decoded.inputs,
          SignedBitcoinTransaction(decoded.bytes),
        );
      case (
        final BitcoinNetwork network,
        final SignedBitcoinTransaction transaction,
      ):
        final DecodedBitcoinTransaction decoded;
        try {
          decoded = decodeBitcoinTransaction(transaction.bytes);
        } on FormatException {
          return const Err(SyncInvalidTransactionFailure());
        }
        return _broadcastBitcoin(spend, network, decoded.inputs, transaction);
      case (final LiquidNetwork network, final SignedPset transaction):
        return _broadcastLiquid(spend, network, transaction);
      case _:
        return const Err(SyncInvalidTransactionFailure());
    }
  }

  /// The guard is held from admission to the receipt; the protections are
  /// read again under it, in the queue freezes change through.
  Future<Result<SpendReceipt, SyncFailure>> _broadcastBitcoin(
    SignedSpend spend,
    BitcoinNetwork network,
    List<Outpoint> inputs,
    SignedBitcoinTransaction transaction,
  ) async {
    final key = spend.key;
    final admission = await _gate.acquire(key, replacing: spend.replacing);
    if (admission case BitcoinSpendRefused(:final status)) {
      _publish(key, status);
      return Err(
        status == BitcoinSpendStatus.busy
            ? const SyncBusyFailure()
            : SyncSpendBlockedFailure(status),
      );
    }
    final lease = admission as BitcoinSpendAdmission;
    var accepted = false;
    try {
      if (lease.revision.generation != spend.generation) {
        return const Err(SyncNotFoundFailure());
      }
      final guarded = await _freezes.guard((frozen) async {
        final _Policy policy;
        try {
          policy = await _policyWith(key, spend.owner, frozen);
        } on WriterRefusal catch (error) {
          return Err<SpendReceipt, SyncFailure>(error.failure);
        }
        if (policy.check(inputs, exempt: policy.owned) case final hit?) {
          return Err<SpendReceipt, SyncFailure>(hit);
        }
        final sent = await _send(transaction, network);
        if (sent case Err(:final failure)) {
          return Err<SpendReceipt, SyncFailure>(failure);
        }
        accepted = true;
        final receipt = lease.accepted((sent as Ok<String, SyncFailure>).value);
        if (receipt.durable) {
          log.fine('Bitcoin accepted spend recorded');
        } else {
          log.warning(
            'Bitcoin accepted spend recording pending category=storage',
          );
        }
        return Ok<SpendReceipt, SyncFailure>(
          SpendReceipt(receipt.txid, durable: receipt.durable, guarded: true),
        );
      });
      return switch (guarded) {
        Ok(:final value) => value,
        Err(:final failure) => Err(failure),
      };
    } finally {
      try {
        lease.close();
      } on Exception {
        if (!accepted) rethrow;
        log.warning('Bitcoin accepted spend cleanup pending category=storage');
      }
      // The guard is pending after an acceptance: say so.
      if (accepted) _publish(key, BitcoinSpendStatus.pending);
    }
  }

  /// Liquid has no guard: the freezes are checked in their queue, and
  /// nothing is recorded.
  Future<Result<SpendReceipt, SyncFailure>> _broadcastLiquid(
    SignedSpend spend,
    LiquidNetwork network,
    SignedPset transaction,
  ) async {
    final key = spend.key;
    final List<Outpoint> inputs;
    try {
      inputs = _natives.psetInputs(transaction.pset);
    } on SpendRefusal catch (refusal) {
      return Err(refusal.failure);
    }
    if (await _generationFailure(key, spend.generation) case final failure?) {
      return Err(failure);
    }
    final guarded = await _freezes.guard((frozen) async {
      final hit = _Policy(frozen, const {}, const {}).check(inputs);
      if (hit != null) return Err<SpendReceipt, SyncFailure>(hit);
      return switch (await _send(transaction, network)) {
        Ok(:final value) => Ok<SpendReceipt, SyncFailure>(
          SpendReceipt(value, durable: false, guarded: false),
        ),
        Err(:final failure) => Err<SpendReceipt, SyncFailure>(failure),
      };
    });
    return switch (guarded) {
      Ok(:final value) => value,
      Err(:final failure) => Err(failure),
    };
  }

  /// Closes every readiness value, then waits for the guard requests in
  /// flight, so none reads a store closed under it.
  Future<void> close() async {
    for (final cell in _readiness.values) {
      cell.close();
    }
    await _changes.cancel();
    await Future.wait(_requests.toList());
  }
}

/// The guard's last verdict for one wallet, published without IO.
final class _ReadinessCell
    implements Observed<WalletValue<BitcoinSpendStatus>> {
  WalletValue<BitcoinSpendStatus> _value = const WalletValue.notLoaded();
  final _changes = StreamController<WalletValue<BitcoinSpendStatus>>.broadcast(
    sync: true,
  );

  /// Schedules the guard's verdict; never runs it inline.
  final void Function() _demand;

  /// Counts the verdicts published, so an older request never overwrites
  /// one a command published meanwhile.
  int publications = 0;
  bool refreshing = false;
  bool again = false;

  _ReadinessCell(this._demand);

  bool get closed => _changes.isClosed;

  void set(WalletValue<BitcoinSpendStatus> value) {
    if (value.samePublication(_value) && value.revision == _value.revision) {
      return;
    }
    _value = value;
    _changes.add(value);
  }

  void close() {
    _value = const WalletValue.closed();
    _changes.add(_value);
    unawaited(_changes.close());
  }

  @override
  WalletValue<BitcoinSpendStatus> get now => _value;

  @override
  Stream<WalletValue<BitcoinSpendStatus>> watch() {
    late final StreamController<WalletValue<BitcoinSpendStatus>> controller;
    StreamSubscription<WalletValue<BitcoinSpendStatus>>? subscription;
    controller = StreamController(
      onListen: () {
        // Subscribe in the same turn as the first value: nothing is lost.
        controller.add(_value);
        if (_changes.isClosed) {
          unawaited(controller.close());
          return;
        }
        subscription = _changes.stream.listen(
          controller.add,
          onDone: controller.close,
        );
        if (_value.status == ValueStatus.notLoaded && !refreshing) _demand();
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }
}
