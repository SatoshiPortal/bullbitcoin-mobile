import 'package:secrets/secrets.dart' show Secret;
import 'package:primitives/primitives.dart';

import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/sp/data/datasources/bwk_sp_account_datasource.dart';
import 'package:bb_mobile/features/sp/data/datasources/sp_account_files_datasource.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_balance_mapper.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_coin_mapper.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_header_checkpoint_mapper.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_network_mapper.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_notification_mapper.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_payment_mapper.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_recipient_mapper.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_tx_draft_mapper.dart';
import 'package:bb_mobile/features/sp/data/sp_payment_join.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart'
    as dom;
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_payments_port.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_scan_control_port.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_scan_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_update.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:rust_bindings/bwk.dart';
import 'package:meta/meta.dart';

/// Secondary (driven) adapter that owns the single live `SpAccount` FFI
/// session and implements [SpAccountRepository].
///
/// Registered as a `lazySingleton`, so there is exactly one owner of the live
/// session per app lifetime / data dir. This absorbs what used to be split
/// across `SpWalletEntity` (notification stream + dispose retry/memo),
/// `GetSpWalletUsecase` (sentinel/db checks + `SpAccount.load`), the setup
/// cubit (`SpAccount.createFromMnemonic`), and the SP cubit (send-flow FFI
/// calls). The two external systems it speaks to sit behind one datasource
/// each: the bwk FFI and the account directory on disk. FFI view types are
/// mapped to domain entities at this boundary.
/// One live `SpAccount` per data dir, exposed through the account repository
/// and the four capability ports so each consumer is handed only what it needs.
/// `scanOnce` lives alone on [SpScanPort] and reaches only
/// `ScanSpWalletUsecase`.
class BwkSpAccountRepository
    implements
        SpAccountRepository,
        SpScanPort,
        SpScanControlPort,
        SpPaymentsPort {
  final BwkSpAccountDatasource _ffi;
  // Only for opening an account: the data dir and the stale-lock sweep. The
  // account directory itself is owned by SpAccountFilesRepository, which shares
  // this same instance.
  final SpAccountFilesDatasource _files;

  BwkSpAccountRepository({required this._ffi, required this._files});

  // Notification stream plumbing (single-take Rust receiver -> mapped
  // broadcast of domain notifications).
  Stream<dom.SpNotification>? _notifications;
  StreamSubscription<SpNotification>? _sourceSub;
  StreamController<dom.SpNotification>? _broadcastController;
  dom.SpNotification? _latestHeaderNotification;
  // The Started that opened the current run, kept separately: it carries the
  // origin the progress bar measures from, and a subscriber that joins mid-sync
  // would otherwise only ever see a Progress.
  dom.SpHeaderProgressStarted? _latestHeaderStarted;
  int? _latestHeaderTip;
  bool _notifTornDown = false;
  Future<Result<void, SpFailure>>? _pendingOpen;
  Future<void>? _pendingDispose;

  // Always-on stream of pure cross-feature update signals (balance changes,
  // setup created/revoked). Independent of the session lifecycle; never
  // closed (this adapter is a lazySingleton living for the app's lifetime).
  final StreamController<SpUpdate> _updates =
      StreamController<SpUpdate>.broadcast();

  // Scanning flag tracked from notifications (no FFI), so reads/dispose can be
  // skipped while a scan holds the inner lock and would block the UI isolate.
  bool _scanning = false;
  // A queued automatic decision belongs to the session and scan state it read.
  int _scanRevision = 0;
  String? _sessionDataDir;
  ({int? startHeight, bool isPaused})? _pendingScan;
  Future<Result<void, SpFailure>>? _scanLaunch;
  Future<Result<void, SpFailure>>? _scanControl;
  Future<void> _pendingScanWrite = Future.value();
  // Set around an electrum restart, which holds the same lock across a
  // blocking connect.
  bool _restarting = false;
  bool _balanceSkippedDuringRestart = false;

  // Last good values of the two sync FFI reads the SP shell makes on every
  // entry. Both are fixed for the life of a session, and the reads take the
  // account's inner mutex which a scan can hold for around 30 seconds, so the
  // cached value is served while a scan or a restart runs. `snapshot()` is
  // deliberately not cached: it carries the live scan progress.
  BitcoinNetwork? _cachedNetwork;
  int? _cachedMinBirthdayHeight;

  // Held above zero around a recreate/revoke teardown so a self-heal
  // establishment (fired when the notification stream closes mid-teardown) is
  // refused instead of racing the create. A depth rather than a flag: revoke
  // and recreate are reachable concurrently, and whichever finished first would
  // otherwise clear it for the one still running.
  // See SpAccountRepository.teardownInProgress.
  int _teardownDepth = 0;

  // Debug console: bounded notification log + a live broadcast of new lines.
  // Never cleared on session recycle; the controller lives for the app.
  final List<SpNotifLogLine> _notifLog = [];
  final StreamController<SpNotifLogLine> _notifLogController =
      StreamController<SpNotifLogLine>.broadcast();

  void _emit(SpUpdate update) {
    if (!_updates.isClosed) _updates.add(update);
  }

  // Single boundary that turns a raw FFI throw into a typed [SpFailure]. The
  // raw string is kept only as `logMessage` (logs, never UI).
  //
  // bwk-dart returns a typed `SpError` over FRB, so the cases the UI branches
  // on are matched by variant. A non-SpError throw is a genuine surprise
  // (a panic, a codec failure) and collapses to the catch-all.
  SpFailure _mapFfiError(Object e) => switch (e) {
    SpError_SimulationDrifted(:final detail) => SpSimulationDrifted(detail),
    SpError_DisposeTimedOut() => SpSessionBusy('$e'),
    SpError_ScannerAlreadyRunning() => SpScanBusy('$e'),
    SpError_Other(:final message) => SpUnexpected(message),
    _ => SpUnexpected('$e'),
  };

  /// The two guards every bwk call goes through: run the body, and turn a
  /// thrown FFI error into a typed failure at this one boundary.
  Result<T, SpFailure> _guard<T>(T Function() body) {
    try {
      return Ok(body());
    } catch (e) {
      return Err(_mapFfiError(e));
    }
  }

  Future<Result<T, SpFailure>> _guardAsync<T>(Future<T> Function() body) async {
    try {
      return Ok(await body());
    } catch (e) {
      return Err(_mapFfiError(e));
    }
  }

  @override
  bool get hasSession => _ffi.hasSession;

  @override
  bool get teardownInProgress => _teardownDepth > 0;

  @override
  void beginTeardown() => _teardownDepth++;

  @override
  void endTeardown() {
    // Clamped, so an unbalanced extra call cannot drive the depth negative and
    // leave a later teardown unable to hold the guard.
    if (_teardownDepth > 0) _teardownDepth--;
  }

  @override
  Future<Result<void, SpFailure>> createFromSecret({
    required BitcoinNetwork network,
    required Secret secret,
    required String blindbitUrl,
    required String electrumUrl,
    int fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
    int matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
    int minScanAmountSat = SpConfig.defaultMinScanAmountSat,
  }) async {
    // Single-owner guard: the adapter holds exactly one live SpAccount, so a
    // create over an existing session would leak the old Rust notif thread,
    // electrum socket and sqlite handle. Callers dispose first; hitting this
    // means a teardown+create race slipped past EnsureSpSessionUsecase.
    if (hasSession || _pendingOpen != null || _pendingDispose != null) {
      return const Err(
        SpSessionBusy('SP account is already open, opening, or closing'),
      );
    }
    _scanRevision++;
    final opening = _openAccount(
      network: network,
      secret: secret,
      blindbitUrl: blindbitUrl,
      electrumUrl: electrumUrl,
      fetchConcurrencyFactor: fetchConcurrencyFactor,
      matchConcurrencyFactor: matchConcurrencyFactor,
      minScanAmountSat: minScanAmountSat,
    );
    _pendingOpen = opening;
    try {
      return await opening;
    } finally {
      _pendingOpen = null;
    }
  }

  Future<Result<void, SpFailure>> _openAccount({
    required BitcoinNetwork network,
    required Secret secret,
    required String blindbitUrl,
    required String electrumUrl,
    required int fetchConcurrencyFactor,
    required int matchConcurrencyFactor,
    required int minScanAmountSat,
  }) async {
    // The account is opened inside package:secrets, which hands the words to
    // bwk; this layer never holds them. Failures still return fixed text.
    final String dataDir;
    try {
      dataDir = await _files.dataDir();
    } catch (_) {
      return const Err(SpUnexpected('SP data dir lookup failed'));
    }
    try {
      _pendingScan = await _files.readPendingScan(dataDir);
    } on Exception catch (_) {
      _pendingScan = null;
      log.warning('SP could not read pending scan');
    }
    _resetNotificationState();
    _scanning = false;
    _clearReadCaches();
    // Clear any lingering advisory locks. On mobile (single process) a present
    // lock is a disposed session whose Rust handle is not GC'd yet, so it can
    // never be a real second owner; the in-app single-establishment guard
    // (EnsureSpSessionUsecase) keeps two live sessions from ever racing. The
    // header store locks its own sentinel, so missing it fails the create with
    // "already opened by another instance".
    final checkpoint = SpConfig.headerCheckpoint(network);
    try {
      await _files.clearStaleLocks();
      await _ffi.createFromSecret(
        network: SpNetworkMapper.toFfi(network),
        secret: secret,
        blindbitUrl: blindbitUrl,
        electrumUrl: electrumUrl,
        dataDir: dataDir,
        fetchConcurrencyFactor: fetchConcurrencyFactor,
        matchConcurrencyFactor: matchConcurrencyFactor,
        minScanAmountSat: minScanAmountSat,
        headerCheckpoint: checkpoint == null
            ? null
            : SpHeaderCheckpointMapper.toFfi(checkpoint),
      );
    } catch (_) {
      // Fixed text on purpose: see the note above.
      return const Err(SpUnexpected('SP account create failed'));
    }
    _sessionDataDir = dataDir;
    // Start the always-on taproot sub-account electrum listener so incoming txs
    // are pushed without a manual scan. createFromSecret does not propagate the
    // electrum URL into the sub-account, so set it first (mirrors the silent
    // wallet). The URL is non-empty by the SpBackendConfig invariant. Failures
    // here must not abort session setup.
    try {
      _ffi.setElectrumUrl(electrumUrl);
      // Fire-and-forget: starting the listener must never block (or hang)
      // session establishment. Errors are logged, not fatal.
      unawaited(
        _ffi.startElectrum().catchError((Object e) {
          log.warning('SpAccountRepository: start electrum failed: $e');
        }),
      );
    } catch (e) {
      log.warning('SpAccountRepository: set electrum url failed: $e');
    }
    // Prime the notification listener now (single init() per session) so every
    // Rust notification is recorded as soon as the session exists, regardless
    // of whether the UI has subscribed yet.
    _ensureNotifications();
    // Setup just completed; observers (the wallet) must re-evaluate and load.
    _emit(const SpSetupChanged());
    return const Ok(null);
  }

  @override
  Result<SpWallet, SpFailure> snapshot() => _guard(() {
    final balance = _ffi.unifiedBalance();
    return SpWallet(
      spAddress: _ffi.spAddress(),
      balance: SpBalanceMapper.toDomain(balance),
      isScanning: _scanning,
      hasPendingScan: _pendingScan != null,
      isPendingScanPaused: _pendingScan?.isPaused ?? false,
      lastScannedHeight: balance.lastScannedHeight,
      scanRevision: _scanRevision,
    );
  });

  @override
  Future<Result<String, SpFailure>> generateTaprootAddress() =>
      _guardAsync(_ffi.newTaprootAddress);

  @override
  Result<SpBalance, SpFailure> balance() =>
      _guard(() => SpBalanceMapper.toDomain(_ffi.unifiedBalance()));

  @override
  bool get isScanningCached => _scanning;

  @override
  Future<Result<List<SpPayment>, SpFailure>> history() => _guardAsync(() async {
    final history = (await _ffi.unifiedHistory())
        .map(SpPaymentMapper.toDomain)
        .toList();
    // bwk reports history and coins separately, so the link between them is
    // made here, where both reads live.
    final coins = (await _ffi.unifiedCoins())
        .map(SpCoinMapper.toDomain)
        .toList();
    return SpPaymentJoin.markSpOutputs(history, coins);
  });

  @override
  Future<Result<List<SpCoin>, SpFailure>> coins() => _guardAsync(() async {
    final views = await _ffi.unifiedCoins();
    return views.map(SpCoinMapper.toDomain).toList();
  });

  @override
  Result<void, SpFailure> restampMissingTimestamps() {
    if (!_ffi.hasSession || _scanOrRestartRunning) return const Ok(null);
    return _guard(_ffi.restampMissingTimestamps);
  }

  // This is the single Dart call site of `scanOnce`; it is
  // reached only via `ScanSpWalletUsecase`. Do not add other callers; the
  // audited scan policy depends on it.
  @override
  Future<Result<void, SpFailure>> scanOnce({
    int? startHeight,
    SpAutomaticScanAdmission? automatic,
  }) async {
    if (teardownInProgress || _pendingDispose != null) {
      return const Err(SpSessionBusy());
    }
    if (!_canLaunchAutomatic(automatic)) return const Ok(null);
    if (_scanning || _scanLaunch != null || _scanControl != null) {
      return const Err(SpScanBusy());
    }
    final launch = _launchScan(startHeight, automatic);
    _scanLaunch = launch;
    try {
      return await launch;
    } finally {
      _scanLaunch = null;
    }
  }

  bool _canLaunchAutomatic(SpAutomaticScanAdmission? automatic) =>
      automatic == null ||
      (automatic.revision == _scanRevision &&
          _pendingScan?.isPaused != true &&
          automatic.isAllowed());

  Future<Result<void, SpFailure>> _launchScan(
    int? startHeight,
    SpAutomaticScanAdmission? automatic,
  ) async {
    try {
      await _pendingScanWrite;
      if (!_canLaunchAutomatic(automatic)) return const Ok(null);
      if (teardownInProgress || _pendingDispose != null) {
        return const Err(SpSessionBusy());
      }
      final previous = _pendingScan;
      final selectedHeight = startHeight ?? previous?.startHeight;
      final last = previous == null || startHeight != null
          ? null
          : _ffi.lastScannedHeight();
      final effectiveStart =
          selectedHeight != null && (last == null || last < selectedHeight)
          ? selectedHeight
          : null;
      final pending = (startHeight: selectedHeight, isPaused: false);
      if (pending != previous) await _setPendingScan(pending);
      // Saving the marker yields to lifecycle changes, Stop, and teardown.
      final isClosing = teardownInProgress || _pendingDispose != null;
      if (isClosing || !_canLaunchAutomatic(automatic)) {
        if (pending != previous) await _setPendingScan(previous);
        return isClosing ? const Err(SpSessionBusy()) : const Ok(null);
      }
      _scanning = true;
      await _ffi.scanOnce(startHeight: effectiveStart);
      return const Ok(null);
    } catch (e) {
      _scanning = false;
      return Err(_mapFfiError(e));
    }
  }

  Future<Result<void, SpFailure>> _controlScan(
    Future<void> Function() action,
  ) async {
    if (teardownInProgress || _pendingDispose != null) {
      return const Err(SpSessionBusy());
    }
    if (_scanControl != null) return const Err(SpScanBusy());
    _scanRevision++;
    final control = _guardAsync(action);
    _scanControl = control;
    try {
      return await control;
    } finally {
      _scanControl = null;
    }
  }

  @override
  Future<Result<void, SpFailure>> stopScan() => _controlScan(() async {
    await _scanLaunch;
    await _pendingScanWrite;
    if (_pendingScan case final pending? when !pending.isPaused) {
      await _setPendingScan((startHeight: pending.startHeight, isPaused: true));
    }
    await _ffi.stopScan();
  });

  @override
  Future<Result<void, SpFailure>> clearScanState() {
    if (_scanning || _scanLaunch != null) {
      return Future.value(const Err(SpScanBusy()));
    }
    return _controlScan(() async {
      await _setPendingScan(null);
      await _ffi.clearScanState();
    });
  }

  Future<void> _setPendingScan(({int? startHeight, bool isPaused})? pending) {
    final dataDir = _sessionDataDir;
    final write = _pendingScanWrite.then((_) async {
      if (dataDir != null) await _files.writePendingScan(dataDir, pending);
      _pendingScan = pending;
    });
    _pendingScanWrite = write.catchError((Object _) {
      log.warning('SP could not save pending scan');
    });
    return write;
  }

  @override
  Future<Result<void, SpFailure>> restartElectrum() async {
    if (teardownInProgress || !_ffi.hasSession) return const Ok(null);
    _restarting = true;
    try {
      return await _guardAsync(_ffi.restartElectrum);
    } finally {
      _restarting = false;
      if (_balanceSkippedDuringRestart) {
        _balanceSkippedDuringRestart = false;
        _readAndEmitBalance();
      }
    }
  }

  bool get _scanOrRestartRunning => _scanning || _restarting;

  @override
  Result<int, SpFailure> minBirthdayHeight() {
    final cached = _cachedMinBirthdayHeight;
    if (_scanOrRestartRunning && cached != null) return Ok(cached);
    return _guard(() {
      final height = _ffi.minBirthdayHeight();
      _cachedMinBirthdayHeight = height;
      return height;
    });
  }

  @override
  Future<Result<SpTxDraft, SpFailure>> preparePsbt({
    required List<SpRecipient> recipients,
    required BigInt feerateSatVb,
  }) => _guardAsync(() async {
    final (id, simulation) = await _ffi.preparePsbt(
      recipients: recipients.map(SpRecipientMapper.toFfi).toList(),
      feerateSatVb: feerateSatVb,
      changeDustThreshold: BigInt.from(SpConfig.changeDustThresholdSat),
    );
    return SpTxDraftMapper.toDomain(simulation, id);
  });

  @override
  Future<Result<String, SpFailure>> finalizeSignBroadcast({
    required SpTxDraft draft,
  }) async {
    final simulation = _ffi.pinnedSimulation(draft.id);
    if (simulation == null) {
      // The pinned simulation is gone (the session was recycled since confirm),
      // so the tx can no longer be rebuilt from what the Confirm page showed.
      return const Err(
        SpSimulationDrifted('pinned simulation no longer available'),
      );
    }
    try {
      return Ok(await _finalizeSignBroadcast(simulation: simulation));
    } on _BroadcastOutcomeUnknown catch (e) {
      return Err(SpBroadcastUncertain('$e'));
    } catch (e) {
      return Err(_mapFfiError(e));
    }
  }

  Future<String> _finalizeSignBroadcast({
    required TxSimulation simulation,
  }) async {
    final txHex = await _ffi.finalizeAndSignToHex(simulation);
    // Listen before broadcasting, and on the session stream itself rather than
    // the header-replay wrapper: that wrapper is an async generator, so it only
    // reaches the underlying stream a few microtasks after listen. An outcome
    // landing in that window is gone for good (nothing buffers a broadcast
    // stream) and a sent transaction would be reported as uncertain.
    final outcome = Completer<dom.SpNotification>();
    final subscription = _ensureNotifications().listen(
      (n) {
        if (outcome.isCompleted) return;
        if (n is dom.SpBroadcasted || n is dom.SpBroadcastFailed) {
          outcome.complete(n);
        }
      },
      onError: (Object e) {
        if (!outcome.isCompleted) outcome.completeError(e);
      },
      onDone: () {
        if (!outcome.isCompleted) {
          outcome.completeError(
            StateError('notification stream closed before the outcome'),
          );
        }
      },
    );
    // Registers an error handler, so a throw from broadcast below cannot leave
    // this future orphaned with an unhandled error.
    outcome.future.ignore();
    try {
      await _ffi.broadcast(txHex: txHex);
      // Only the wait is uncertain: the tx is on the wire by here, so a timeout
      // or a stream closed with the session says nothing about whether it
      // landed. Failures before this point mean nothing was sent.
      final dom.SpNotification result;
      try {
        result = await outcome.future.timeout(SpConfig.broadcastTimeout);
      } on TimeoutException catch (e) {
        throw _BroadcastOutcomeUnknown('SP broadcast timed out: $e');
      } on StateError catch (e) {
        throw _BroadcastOutcomeUnknown('SP broadcast outcome unknown: $e');
      }
      final txid = switch (result) {
        dom.SpBroadcasted(:final txid) => txid,
        dom.SpBroadcastFailed(:final message) => throw Exception(message),
        _ => throw StateError('unreachable broadcast notification'),
      };
      // The tx is now irreversible, so record the txid before returning even if
      // the caller was torn down mid-await.
      log.info('SpAccountRepository: broadcast succeeded txid=$txid');
      return txid;
    } finally {
      unawaited(subscription.cancel());
    }
  }

  @override
  Result<BitcoinNetwork?, SpFailure> network() {
    // Distinguish "no session yet" (Ok(null), a genuine unknown) from an FFI
    // read failure (Err), so the wrong-network address guard can fail closed on
    // a transient error instead of silently skipping validation.
    if (!_ffi.hasSession) return const Ok(null);
    final cached = _cachedNetwork;
    if (_scanOrRestartRunning && cached != null) return Ok(cached);
    return _guard(() {
      final network = SpNetworkMapper.toDomain(_ffi.network());
      _cachedNetwork = network;
      return network;
    });
  }

  @override
  int? chainTip() {
    return _latestHeaderTip;
  }

  @override
  Future<Result<int, SpFailure>> currentBlockHeight() =>
      _guardAsync(_ffi.blockHeight);

  @override
  Stream<dom.SpNotification> get notifications =>
      Stream<dom.SpNotification>.multi((controller) {
        final started = _latestHeaderStarted;
        final latestHeader = _latestHeaderNotification;
        if (started != null && !identical(started, latestHeader)) {
          controller.add(started);
        }
        if (latestHeader != null) controller.add(latestHeader);
        try {
          final subscription = _ensureNotifications().listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
          );
          controller.onCancel = subscription.cancel;
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
          unawaited(controller.close());
        }
      });

  // Set up the Rust notification forwarding (init) + source listener exactly
  // once per session. Called from createFromSecret so recording (and electrum
  // pushes) flow as soon as a session exists, independent of any UI subscriber;
  // `init()` is taken-once per account, so doing it here avoids the double-init
  // ("receiver already taken") that broke recording. Each FFI notification is
  // mapped to a domain notification before it leaves the boundary.
  Stream<dom.SpNotification> _ensureNotifications() {
    final existing = _notifications;
    if (existing != null) return existing;

    final source = _ffi.init();
    final controller = StreamController<dom.SpNotification>.broadcast();
    _broadcastController = controller;
    _notifTornDown = false;
    _sourceSub = source.listen(
      (frbN) {
        final n = SpNotificationMapper.toDomain(frbN);
        _recordNotification(n);
        controller.add(n);
        _maybeEmitBalanceChange(n);
      },
      onError: controller.addError,
      onDone: () {
        if (!controller.isClosed) unawaited(controller.close());
      },
    );
    _notifications = controller.stream;
    return _notifications!;
  }

  // Forward coin-affecting notifications to the cross-feature update stream as
  // a lightweight balance signal (no session reload). Scan progress/start are
  // ignored; only events that change the coin set move the balance.
  void _maybeEmitBalanceChange(dom.SpNotification n) {
    if (!n.affectsBalance) return;
    // Skip the per-event balance read during a scan to avoid churn; the
    // ScanCompleted event reconciles the balance once the scan ends.
    if (_scanning) return;
    // A restart holds the account lock, so the read would block the UI isolate
    // until it returns; the restart reads the balance once it ends instead.
    if (_restarting) {
      _balanceSkippedDuringRestart = true;
      return;
    }
    _readAndEmitBalance();
  }

  void _readAndEmitBalance() {
    try {
      if (balance() case Ok(:final value)) {
        _emit(SpBalanceChanged(value.totalUnifiedSat));
      }
    } on StateError catch (_) {
      // No live session, expected during teardown; not an error worth a
      // warning (a real FFI failure is a different type, handled below).
      log.fine('SpAccountRepository: balance read skipped (no session)');
    } catch (e) {
      log.warning(
        'SpAccountRepository: balance read on notification failed: $e',
      );
    }
  }

  // Track scanning (no FFI) and append to the debug console log. Runs for every
  // notification the single source emits, before fan-out. The one-shot scan
  // runs on a background thread (returns immediately), so the scanning window is
  // ScanStarted..ScanCompleted, which gates WalletBloc from disposing mid-scan.
  void _recordNotification(dom.SpNotification n) {
    if (n.isHeaderProgress) {
      _latestHeaderNotification = n;
      if (n is dom.SpHeaderProgressStarted) _latestHeaderStarted = n;
      final tip = n.headerTip;
      final latest = _latestHeaderTip;
      // Extending the chain down to older coins reports a range below the tip
      // (same phase as the first sync), so the tip only ever moves up.
      if (tip != null && (latest == null || tip > latest)) {
        _latestHeaderTip = tip;
        _emit(SpChainTipChanged(tip));
      }
    }
    _scanning = n.scanRunningAfter ?? _scanning;
    if (n is dom.SpScanCompleted && _pendingScan != null) {
      _pendingScan = null;
      unawaited(_setPendingScan(null).catchError((Object _) {}));
    }
    final line = SpNotifLogLine(time: DateTime.now(), notification: n);
    _notifLog.add(line);
    if (_notifLog.length > spNotifLogCap) _notifLog.removeAt(0);
    if (!_notifLogController.isClosed) _notifLogController.add(line);
  }

  @override
  List<SpNotifLogLine> get notificationLog => List.unmodifiable(_notifLog);

  @override
  Stream<SpNotifLogLine> get notificationLogStream =>
      _notifLogController.stream;

  @override
  Stream<SpUpdate> get updates => _updates.stream;

  @override
  void notifySetupChanged() => _emit(const SpSetupChanged());

  @override
  void notifyBalanceChanged(Sats totalUnifiedSat) {
    _emit(SpBalanceChanged(totalUnifiedSat));
  }

  @override
  Future<Result<void, SpFailure>> dispose() async {
    final opening = _pendingOpen;
    if (opening != null) await opening;
    if (!hasSession) return const Ok(null);
    final pending = _pendingDispose;
    if (pending != null) {
      // Join the in-flight teardown rather than starting a second one.
      try {
        await pending;
        return const Ok(null);
      } catch (e) {
        return Err(_mapFfiError(e));
      }
    }
    final future = _runDispose();
    _pendingDispose = future;
    try {
      await future;
      return const Ok(null);
    } catch (e) {
      // A dispose timeout keeps the session; callers decline to reopen on Err.
      return Err(_mapFfiError(e));
    } finally {
      _pendingDispose = null;
    }
  }

  // Whether the Dart notification plumbing has been torn down. Test-only view of
  // the internal flag so a timed-out dispose can be asserted not to tear it down.
  @visibleForTesting
  bool get notifStreamTornDown => _notifTornDown;

  Future<void> _runDispose() async {
    _scanRevision++;
    await _scanLaunch;
    await _scanControl;
    // Tear down the Rust session FIRST. This flips the notif-thread shutdown
    // flag, stops the electrum listener, and releases the sqlite handle/.lock.
    // It MUST happen before cancelling the Dart notification subscription:
    // cancelling an FRB stream subscription while the Rust notif thread is
    // still actively producing (electrum flood) deadlocks, which previously
    // wedged the whole revoke/delete flow. Only tear down the Dart plumbing
    // after a clean dispose, so a timed-out dispose keeps the live session's
    // streams intact. A dispose that times out throws "dispose timed out" from
    // here and the session reference is kept.
    if (_ffi.hasSession) {
      await _ffi.dispose();
      _notifications = null;
    }
    await _pendingScanWrite;
    _sessionDataDir = null;
    _pendingScan = null;
    // Only reached on a clean dispose: a timed-out dispose throws above, so a
    // session that stays live keeps its state.
    _scanning = false;
    _latestHeaderNotification = null;
    _latestHeaderStarted = null;
    _latestHeaderTip = null;
    _clearReadCaches();
    // Best-effort Dart-stream cleanup. NOT awaited: the session is already torn
    // down (its source is done), and cancel/close must never be allowed to
    // block dispose() and stall revoke.
    if (!_notifTornDown) {
      _notifTornDown = true;
      final sub = _sourceSub;
      _sourceSub = null;
      if (sub != null) {
        unawaited(
          sub.cancel().catchError((Object e) {
            log.warning(
              'SpAccountRepository.dispose: source cancel failed: $e',
            );
          }),
        );
      }
      final controller = _broadcastController;
      _broadcastController = null;
      if (controller != null && !controller.isClosed) {
        unawaited(
          controller.close().catchError((Object e) {
            log.warning(
              'SpAccountRepository.dispose: controller close failed: $e',
            );
          }),
        );
      }
    }
  }

  void _clearReadCaches() {
    _cachedNetwork = null;
    _cachedMinBirthdayHeight = null;
  }

  void _resetNotificationState() {
    _notifications = null;
    _sourceSub = null;
    _broadcastController = null;
    _latestHeaderNotification = null;
    _latestHeaderStarted = null;
    _latestHeaderTip = null;
    _notifTornDown = false;
  }
}

/// The tx was broadcast but its outcome never came back, so it may or may not
/// have landed. Kept apart from a failure before the send, where nothing went
/// out and the user can safely retry.
class _BroadcastOutcomeUnknown implements Exception {
  final String message;

  const _BroadcastOutcomeUnknown(this.message);

  @override
  String toString() => message;
}
