import 'package:secrets/secrets.dart' show Secret;
import 'package:primitives/primitives.dart';

import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:silent/src/data/datasources/bwk_sp_account_datasource.dart';
import 'package:silent/src/data/datasources/sp_account_files_datasource.dart';
import 'package:silent/src/data/mappers/sp_balance_mapper.dart';
import 'package:silent/src/data/mappers/sp_coin_mapper.dart';
import 'package:silent/src/data/mappers/sp_header_checkpoint_mapper.dart';
import 'package:silent/src/data/mappers/sp_network_mapper.dart';
import 'package:silent/src/data/mappers/sp_notification_mapper.dart';
import 'package:silent/src/data/mappers/sp_payment_mapper.dart';
import 'package:silent/src/data/mappers/sp_recipient_mapper.dart';
import 'package:silent/src/data/mappers/sp_tx_draft_mapper.dart';
import 'package:silent/src/data/sp_payment_join.dart';
import 'package:silent/src/domain/entities/sp_coin.dart';
import 'package:silent/src/domain/entities/sp_notification.dart' as dom;
import 'package:silent/src/domain/entities/sp_payment.dart';
import 'package:silent/src/domain/entities/sp_recipient.dart';
import 'package:silent/src/domain/entities/sp_tx_draft.dart';
import 'package:silent/src/domain/ports/sp_payments_port.dart';
import 'package:silent/src/domain/ports/sp_scan_control_port.dart';
import 'package:silent/src/domain/ports/sp_scan_port.dart';
import 'package:silent/src/domain/repositories/sp_account_repository.dart';
import 'package:silent/src/domain/entities/sp_balance.dart';
import 'package:silent/src/domain/sp_config.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/entities/sp_notif_log.dart';
import 'package:silent/src/domain/entities/sp_update.dart';
import 'package:silent/src/domain/entities/sp_wallet.dart';
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

  final bool Function()? _allowAutomaticScan;

  BwkSpAccountRepository({
    required this._ffi,
    required this._files,
    this._allowAutomaticScan,
  });

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
  bool _closing = false;
  Future<Result<void, SilentFailure>>? _pendingOpen;
  Future<void>? _pendingDispose;

  // Always-on stream of pure cross-feature update signals (balance changes,
  // setup created/revoked). Independent of the session lifecycle, until the
  // feature itself closes.
  final StreamController<SilentUpdate> _updates =
      StreamController<SilentUpdate>.broadcast();

  // Scanning flag tracked from notifications (no FFI), so reads/dispose can be
  // skipped while a scan holds the inner lock and would block the UI isolate.
  bool _scanning = false;
  // Where the pending-scan marker lives, and what it says. Only a manual scan
  // writes it (an automatic resume adopts the marker it already found); it is
  // deleted when the scan completes or the cursor is cleared, and flipped to
  // paused when the user stops the scan.
  String? _sessionDataDir;
  ({int? startHeight, bool isPaused})? _pendingScan;
  // A scan launch and a scan control (stop/clear) may not overlap; each future
  // is held so the other side can join it instead of racing.
  Future<Result<void, SilentFailure>>? _scanLaunch;
  Future<Result<void, SilentFailure>>? _scanControl;
  // Serializes marker writes: a launch must not overwrite a stop's pause with
  // its own fresh marker, and a dispose must see the last write finish.
  Future<void> _pendingScanWrite = Future.value();
  // A queued automatic decision belongs to the session and scan state it read.
  // Bumped whenever that state changes: a new session, a stop or clear, a
  // dispose, and every scan-state notification. See
  // SpAccountRepository.scanRevision.
  int _scanRevision = 0;
  bool _markerUnreadable = false;
  bool _automaticScanActive = false;
  bool _retryAutomaticScan = false;
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

  void _emit(SilentUpdate update) {
    if (!_updates.isClosed) _updates.add(update);
  }

  // Single boundary that turns a raw FFI throw into a typed [SilentFailure]. The
  // raw string is kept only as `logMessage` (logs, never UI).
  //
  // bwk-dart returns a typed `SpError` over FRB, so the cases the UI branches
  // on are matched by variant. A non-SpError throw is a genuine surprise
  // (a panic, a codec failure) and collapses to the catch-all.
  SilentFailure _mapFfiError(Object e) => switch (e) {
    SpError_SimulationDrifted(:final detail) => SilentSimulationDrifted(detail),
    SpError_DisposeTimedOut() => SilentSessionBusy('$e'),
    SpError_ScannerAlreadyRunning() => SilentScanBusy('$e'),
    SpError_Other(:final message) => SilentUnexpected(message),
    _ => SilentUnexpected('$e'),
  };

  /// The two guards every bwk call goes through: run the body, and turn a
  /// thrown FFI error into a typed failure at this one boundary.
  Result<T, SilentFailure> _guard<T>(T Function() body) {
    try {
      return Ok(body());
    } catch (e) {
      return Err(_mapFfiError(e));
    }
  }

  Future<Result<T, SilentFailure>> _guardAsync<T>(
    Future<T> Function() body,
  ) async {
    try {
      return Ok(await body());
    } catch (e) {
      return Err(_mapFfiError(e));
    }
  }

  @override
  bool get hasSession => _ffi.hasSession;

  @override
  bool get teardownInProgress => _closing || _teardownDepth > 0;

  @override
  void beginTeardown() => _teardownDepth++;

  @override
  void endTeardown() {
    // Clamped, so an unbalanced extra call cannot drive the depth negative and
    // leave a later teardown unable to hold the guard.
    if (_teardownDepth > 0) _teardownDepth--;
  }

  @override
  Future<Result<void, SilentFailure>> createFromSecret({
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
    if (_closing ||
        hasSession ||
        _pendingOpen != null ||
        _pendingDispose != null) {
      return const Err(
        SilentSessionBusy('Silent account already open, opening or closing'),
      );
    }
    _scanRevision++;
    final pending = _openFromSecret(
      network: network,
      secret: secret,
      blindbitUrl: blindbitUrl,
      electrumUrl: electrumUrl,
      fetchConcurrencyFactor: fetchConcurrencyFactor,
      matchConcurrencyFactor: matchConcurrencyFactor,
      minScanAmountSat: minScanAmountSat,
    );
    _pendingOpen = pending;
    try {
      return await pending;
    } finally {
      _pendingOpen = null;
    }
  }

  Future<Result<void, SilentFailure>> _openFromSecret({
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
      return const Err(SilentUnexpected('SP data dir lookup failed'));
    }
    _resetNotificationState();
    _scanning = false;
    _pendingScan = null;
    _markerUnreadable = false;
    _automaticScanActive = false;
    _retryAutomaticScan = false;
    _sessionDataDir = null;
    _clearReadCaches();
    // Clear any lingering advisory locks. On mobile (single process) a present
    // lock is a disposed session whose Rust handle is not GC'd yet, so it can
    // never be a real second owner; the in-app single-establishment guard
    // (EnsureSpSessionUsecase) keeps two live sessions from ever racing. The
    // header store locks its own sentinel, so missing it fails the create with
    // "already opened by another instance".
    await _files.clearStaleLocks();
    final checkpoint = SpConfig.headerCheckpoint(network);
    try {
      final opened = await _ffi.createFromSecret(
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
      if (opened case Err()) {
        return const Err(SilentUnexpected('SP account create failed'));
      }
    } on Exception {
      // Fixed text on purpose: see the note above.
      return const Err(SilentUnexpected('SP account create failed'));
    }
    // close() is waiting to dispose this account. Do not start or publish a
    // session that is already being shut down.
    if (_closing) return const Ok(null);
    _sessionDataDir = dataDir;
    // A manual scan that was interrupted by a restart left its resume marker
    // behind; adopt it before anything can read the snapshot.
    await _readPendingScan(dataDir);
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
    _emit(const SilentSetupChanged());
    return const Ok(null);
  }

  @override
  Result<SilentWallet, SilentFailure> snapshot() => _guard(() {
    final balance = _ffi.unifiedBalance();
    return SilentWallet(
      spAddress: _ffi.spAddress(),
      balance: SpBalanceMapper.toDomain(balance),
      // Tracked in Dart from notifications: the FFI read takes the account
      // lock, which a scan can hold for tens of seconds.
      isScanning: _scanning,
      hasPendingScan: _pendingScan != null,
      isPendingScanPaused: _pendingScan?.isPaused ?? false,
      lastScannedHeight: balance.lastScannedHeight,
    );
  });

  @override
  Future<Result<String, SilentFailure>> generateTaprootAddress() =>
      _guardAsync(_ffi.newTaprootAddress);

  @override
  Result<SilentBalance, SilentFailure> balance() =>
      _guard(() => SpBalanceMapper.toDomain(_ffi.unifiedBalance()));

  @override
  bool get isScanningCached => _scanning || _scanLaunch != null;

  @override
  Future<Result<List<SpPayment>, SilentFailure>> history() =>
      _guardAsync(() async {
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
  Future<Result<List<SpCoin>, SilentFailure>> coins() => _guardAsync(() async {
    final views = await _ffi.unifiedCoins();
    return views.map(SpCoinMapper.toDomain).toList();
  });

  @override
  Result<void, SilentFailure> restampMissingTimestamps() {
    if (!_ffi.hasSession || _scanOrRestartRunning) return const Ok(null);
    return _guard(_ffi.restampMissingTimestamps);
  }

  // This is the single Dart call site of `scanOnce`; it is
  // reached only via `ScanSpWalletUsecase`. Do not add other callers; the
  // audited scan policy depends on it.
  @override
  Future<Result<void, SilentFailure>> scanOnce({
    int? startHeight,
    SpAutomaticScanAdmission? automatic,
  }) async {
    if (teardownInProgress || _pendingDispose != null) {
      return const Err(SilentSessionBusy('SP session is closing'));
    }
    if (!_canLaunchAutomatic(automatic)) return const Ok(null);
    if (_scanning || _scanLaunch != null || _scanControl != null) {
      return const Err(SilentScanBusy('SP scan already scheduled'));
    }
    final launch = _launchScan(startHeight, automatic);
    _scanLaunch = launch;
    try {
      return await launch;
    } finally {
      _scanLaunch = null;
    }
  }

  // Recheck session state and live foreground/opt-in after the final await.
  bool _canLaunchAutomatic(SpAutomaticScanAdmission? automatic) =>
      automatic == null ||
      (automatic.revision == _scanRevision &&
          !_markerUnreadable &&
          _pendingScan?.isPaused != true &&
          (_allowAutomaticScan?.call() ?? true));

  Future<Result<void, SilentFailure>> _launchScan(
    int? startHeight,
    SpAutomaticScanAdmission? automatic,
  ) async {
    // Only a manual scan owns the marker. An automatic resume adopts what it
    // found and leaves it in place, so a process death mid-resume still leaves
    // the same thing to resume next time.
    final manual = automatic == null;
    ({int? startHeight, bool isPaused})? previous;
    var changedMarker = false;
    try {
      // A queued marker write has to land before this scan rewrites it.
      await _pendingScanWrite;
      if (!_canLaunchAutomatic(automatic)) return const Ok(null);
      if (teardownInProgress || _pendingDispose != null) {
        return const Err(SilentSessionBusy('SP session is closing'));
      }
      previous = _pendingScan;
      // Resume from the marker's height when the caller did not pick one, and
      // only if the cursor has not already passed it: bwk resumes from its own
      // cursor, so a lower explicit start would redo work.
      final selectedHeight = startHeight ?? previous?.startHeight;
      final last = previous == null || startHeight != null
          ? null
          : _ffi.lastScannedHeight();
      final effectiveStart =
          selectedHeight != null && (last == null || last < selectedHeight)
          ? selectedHeight
          : null;
      final pending = (startHeight: selectedHeight, isPaused: false);
      changedMarker = manual && pending != previous;
      if (changedMarker) await _savePendingScan(pending);
      // Saving the marker yields to lifecycle changes and teardown.
      if (teardownInProgress || _pendingDispose != null) {
        if (changedMarker) await _savePendingScan(previous);
        return const Err(SilentSessionBusy('SP session is closing'));
      }
      if (!_canLaunchAutomatic(automatic)) {
        if (changedMarker) await _savePendingScan(previous);
        return const Ok(null);
      }
      _scanning = true;
      _automaticScanActive = !manual;
      await _ffi.scanOnce(startHeight: effectiveStart);
      return const Ok(null);
    } catch (e) {
      _scanning = false;
      _automaticScanActive = false;
      // The scan did not start, so the marker must not claim it did: restore
      // the one this launch replaced (or drop the one it wrote).
      if (changedMarker) await _savePendingScan(previous);
      return Err(_mapFfiError(e));
    }
  }

  // Stop and clear share one guard: neither may start while the other runs,
  // and each joins a launch in flight instead of racing its marker write.
  Future<Result<void, SilentFailure>> _controlScan(
    Future<Result<void, SilentFailure>> Function() body,
  ) async {
    if (teardownInProgress || _pendingDispose != null) {
      return const Err(SilentSessionBusy('SP session is closing'));
    }
    if (_scanControl != null) {
      return const Err(SilentScanBusy('SP scan control already in progress'));
    }
    // Stop and clear change the scan state, so a decision queued before them
    // must not be launched afterwards.
    _scanRevision++;
    final control = _guardResult(body);
    _scanControl = control;
    try {
      return await control;
    } finally {
      // A decision may have read the entry revision while the control was
      // waiting on disk. Its snapshot is no longer valid after the control.
      _scanRevision++;
      _scanControl = null;
    }
  }

  Future<Result<void, SilentFailure>> _guardResult(
    Future<Result<void, SilentFailure>> Function() body,
  ) async {
    try {
      return await body();
    } catch (e) {
      return Err(_mapFfiError(e));
    }
  }

  @override
  Future<Result<void, SilentFailure>> stopScan() => _controlScan(() async {
    await _scanLaunch;
    await _pendingScanWrite;
    _retryAutomaticScan = false;
    _automaticScanActive = false;
    final previous = _pendingScan;
    final paused = (startHeight: previous?.startHeight, isPaused: true);
    // Keep the in-memory pause even if persisting it fails. The native stop
    // must still run, and the caller is told the pause may not survive.
    _pendingScan = paused;
    try {
      await _setPendingScan(paused);
    } on Exception {
      await _ffi.stopScan();
      return const Err(SilentUnexpected('SP scan pause could not be saved'));
    }
    await _ffi.stopScan();
    return const Ok(null);
  });

  @override
  Future<Result<void, SilentFailure>> clearScanState() {
    if (_scanning || _scanLaunch != null) {
      return Future.value(const Err(SilentScanBusy('SP scan is running')));
    }
    return _controlScan(() async {
      final previous = _pendingScan;
      // Persist a pause before clearing the cursor. If the process dies or
      // cleanup fails, there is no window in which an old resume marker can
      // authorize a fresh scan or a prior Stop can be lost.
      if (previous != null && !previous.isPaused) {
        await _setPendingScan((
          startHeight: previous.startHeight,
          isPaused: true,
        ));
      }
      final result = _guard(_ffi.clearScanState);
      if (result case Ok()) {
        _retryAutomaticScan = false;
        await _setPendingScan(null);
      } else if (previous != null && !previous.isPaused) {
        await _savePendingScan(previous);
      }
      return result;
    });
  }

  /// Adopt the marker a previous run left behind. A file this version cannot
  /// parse is deleted and treated as absent: it would fail on every open
  /// otherwise, and there is nothing to resume from.
  Future<void> _readPendingScan(String dataDir) async {
    try {
      _pendingScan = await _files.readPendingScan(dataDir);
    } on FormatException {
      _pendingScan = null;
      try {
        await _files.writePendingScan(dataDir, null);
      } on Exception {
        _markerUnreadable = true;
        log.warning('SP could not delete corrupt pending scan');
      }
    } on Exception {
      _pendingScan = null;
      _markerUnreadable = true;
      log.warning('SP could not read pending scan');
    }
  }

  /// Persist [pending] first, then publish it, so the in-memory marker never
  /// claims a recovery the disk does not have. The returned future throws when
  /// the write fails; see [_savePendingScan] for the best-effort path.
  Future<void> _setPendingScan(({int? startHeight, bool isPaused})? pending) {
    final dataDir = _sessionDataDir;
    final write = _pendingScanWrite.then((_) async {
      if (dataDir != null) await _files.writePendingScan(dataDir, pending);
      _pendingScan = pending;
      _markerUnreadable = false;
    });
    _pendingScanWrite = write.catchError((Object _) {});
    return write;
  }

  /// Starting a scan must never fail because the advisory marker could not be
  /// written: log it and keep going. The in-memory marker is left untouched by
  /// a failed write, so a restart simply has nothing extra to resume.
  Future<void> _savePendingScan(
    ({int? startHeight, bool isPaused})? pending,
  ) async {
    try {
      await _setPendingScan(pending);
    } catch (_) {
      log.warning('SP could not save pending scan');
    }
  }

  @override
  Future<Result<void, SilentFailure>> restartElectrum() async {
    if (!_ffi.hasSession) return const Ok(null);
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
  Result<int, SilentFailure> minBirthdayHeight() {
    final cached = _cachedMinBirthdayHeight;
    if (_scanOrRestartRunning && cached != null) return Ok(cached);
    return _guard(() {
      final height = _ffi.minBirthdayHeight();
      _cachedMinBirthdayHeight = height;
      return height;
    });
  }

  @override
  Future<Result<SilentTxDraft, SilentFailure>> preparePsbt({
    required List<SilentRecipient> recipients,
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
  Future<Result<String, SilentFailure>> finalizeSignBroadcast({
    required SilentTxDraft draft,
  }) async {
    final simulation = _ffi.pinnedSimulation(draft.id);
    if (simulation == null) {
      // The pinned simulation is gone (the session was recycled since confirm),
      // so the tx can no longer be rebuilt from what the Confirm page showed.
      return const Err(
        SilentSimulationDrifted('pinned simulation no longer available'),
      );
    }
    try {
      return Ok(await _finalizeSignBroadcast(simulation: simulation));
    } on _BroadcastOutcomeUnknown catch (e) {
      return Err(SilentBroadcastUncertain('$e'));
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
  Result<BitcoinNetwork?, SilentFailure> network() {
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
  int get scanRevision => _scanRevision;

  @override
  bool get canRetryAutomaticScan => _retryAutomaticScan;

  @override
  Future<Result<int, SilentFailure>> currentBlockHeight() =>
      _guardAsync(_ffi.blockHeight);

  @override
  Stream<dom.SpNotification> get notifications =>
      _notificationsWithHeaderReplay();

  Stream<dom.SpNotification> _notificationsWithHeaderReplay() async* {
    final started = _latestHeaderStarted;
    final latestHeader = _latestHeaderNotification;
    if (started != null && !identical(started, latestHeader)) yield started;
    if (latestHeader != null) yield latestHeader;
    yield* _ensureNotifications();
  }

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
        _emit(SilentBalanceChanged(value.totalUnifiedSat));
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
        _scanRevision++;
        _emit(SilentChainTipChanged(tip));
      }
    }
    _scanning = n.scanRunningAfter ?? _scanning;
    // Every scan-state event invalidates a decision queued before it.
    if (n.scanRunningAfter != null) _scanRevision++;
    // A completed scan reached its target: the resume marker is stale. Stop
    // keeps it, flipped to paused, so the gap it left is still known.
    if (n is dom.SpScanFailed && _automaticScanActive) {
      _retryAutomaticScan = true;
    }
    if (n is dom.SpScanCompleted || n is dom.SpScanStopped) {
      _retryAutomaticScan = false;
    }
    if (n.scanRunningAfter == false) _automaticScanActive = false;
    if (n is dom.SpScanCompleted &&
        _pendingScan != null &&
        _pendingScan?.isPaused != true) {
      _pendingScan = null;
      unawaited(_savePendingScan(null));
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
  Stream<SilentUpdate> get updates => _updates.stream;

  @override
  void notifySetupChanged() => _emit(const SilentSetupChanged());

  @override
  void notifyBalanceChanged(Sats totalUnifiedSat) {
    _emit(SilentBalanceChanged(totalUnifiedSat));
  }

  Future<Result<void, SilentFailure>> close() async {
    _closing = true;
    await _pendingOpen;
    final outcome = await dispose();
    if (outcome case Ok()) {
      unawaited(_updates.close());
      unawaited(_notifLogController.close());
    }
    return outcome;
  }

  @override
  Future<Result<void, SilentFailure>> dispose() async {
    await _pendingOpen;
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
    _markerUnreadable = false;
    _automaticScanActive = false;
    _retryAutomaticScan = false;
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
