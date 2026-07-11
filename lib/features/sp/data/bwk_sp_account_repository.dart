import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_balance_mapper.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_coin_mapper.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_network_mapper.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_notification_mapper.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_payment_mapper.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_recipient_mapper.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_tx_draft_mapper.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart' as dom;
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart'
    as dom;
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_update.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';

/// Secondary (driven) adapter that owns the single live `SpAccount` FFI
/// session and implements [SpAccountRepository].
///
/// Registered as a `lazySingleton`, so there is exactly one owner of the live
/// session per app lifetime / data dir. This absorbs what used to be split
/// across `SpWalletEntity` (notification stream + dispose retry/memo),
/// `GetSpWalletUsecase` (sentinel/db checks + `SpAccount.load`), the setup
/// cubit (`SpAccount.createFromMnemonic`), and the SP cubit (send-flow FFI
/// calls). FFI view types are mapped to domain entities at this boundary.
class BwkSpAccountRepository implements SpAccountRepository {
  SpAccount? _account;

  // Notification stream plumbing (single-take Rust receiver -> mapped
  // broadcast of domain notifications).
  Stream<dom.SpNotification>? _notifications;
  StreamSubscription<SpNotification>? _sourceSub;
  StreamController<dom.SpNotification>? _broadcastController;
  bool _notifTornDown = false;
  Future<void>? _pendingDispose;

  // Always-on stream of pure cross-feature update signals (balance changes,
  // setup created/revoked). Independent of the session lifecycle; never
  // closed (this adapter is a lazySingleton living for the app's lifetime).
  final StreamController<SpUpdate> _updates =
      StreamController<SpUpdate>.broadcast();

  void _emit(SpUpdate update) {
    if (!_updates.isClosed) _updates.add(update);
  }

  // Scanning flag tracked from notifications (no FFI), so reads/dispose can be
  // skipped while a scan holds the inner lock and would block the UI isolate.
  bool _scanning = false;

  // Set around a recreate/revoke teardown so a self-heal establishment (fired
  // when the notification stream closes mid-teardown) is refused instead of
  // racing the create. See SpAccountRepository.teardownInProgress.
  bool _teardownInProgress = false;

  // Debug console: bounded notification log + a live broadcast of new lines.
  // Never cleared on session recycle; the controller lives for the app.
  static const int _notifLogCap = 200;
  final List<SpNotifLogLine> _notifLog = [];
  final StreamController<SpNotifLogLine> _notifLogController =
      StreamController<SpNotifLogLine>.broadcast();

  Future<String> get _dataDir async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    return appDocsDir.path;
  }

  Future<Directory> _accountDir() async {
    final dataDir = await _dataDir;
    return Directory('$dataDir/${SpConfig.accountName}');
  }

  File _sentinelFile(Directory accountDir) =>
      File('${accountDir.path}/${SpConfig.revokedSentinelFile}');

  // Write the `.revoked` sentinel into the account dir. With [skipIfPresent] it
  // leaves an existing sentinel untouched (used on the partial-delete recovery).
  void _writeRevokedSentinel(Directory accountDir, {bool skipIfPresent = false}) {
    final sentinel = _sentinelFile(accountDir);
    if (skipIfPresent && sentinel.existsSync()) return;
    final timestamp = DateTime.now().toUtc().toIso8601String();
    sentinel.writeAsStringSync('revoked-at: $timestamp\n', flush: true);
  }

  // Backup dir a recreate moved the account aside to, so a failed create can be
  // rolled back. Set by backupAccountDir, cleared by restore/discard.
  Directory? _recreateBackupDir;

  // Confirmed FFI simulations pinned for the live session, keyed by draft id.
  // The simulation must round-trip UNCHANGED from preparePsbt into finalize, so
  // it stays here (never crosses the domain boundary) and is cleared on dispose.
  final Map<String, TxSimulation> _simulations = {};
  int _nextDraftId = 0;

  SpAccount get _live {
    final account = _account;
    if (account == null) {
      throw StateError('SpAccountRepository: no live SP session');
    }
    return account;
  }

  // Single boundary that turns a raw FFI throw into a typed [SpFailure]. The
  // raw string is kept only as `logMessage` (logs, never UI).
  //
  // FIXME: string sniffing. bwk raises these as plain strings with no typed
  // variant ("transaction inputs changed since confirmation: ... please
  // re-confirm", "dispose timed out", "scanner already running"). Replace once
  // bwk upstream exposes typed errors (upstream issue to be filed).
  SpFailure _mapFfiError(Object e) {
    final s = e.toString();
    final lower = s.toLowerCase();
    if (lower.contains('inputs changed')) return SpSimulationDrifted(s);
    if (lower.contains('dispose timed out')) return SpSessionBusy(s);
    if (lower.contains('scanner already running')) return SpScanBusy(s);
    return SpUnexpected(s);
  }

  @override
  bool get hasSession => _account != null;

  @override
  bool get teardownInProgress => _teardownInProgress;

  @override
  void beginTeardown() => _teardownInProgress = true;

  @override
  void endTeardown() => _teardownInProgress = false;

  @override
  Future<bool> hasRevokedSentinel() async {
    final accountDir = await _accountDir();
    return _sentinelFile(accountDir).existsSync();
  }

  @override
  Future<void> revokeOnDisk() async {
    final accountDir = await _accountDir();

    // Sentinel BEFORE any teardown, so a self-heal racing the teardown sees a
    // revoked dir and refuses to reload it (T1.3).
    if (accountDir.existsSync()) {
      try {
        _writeRevokedSentinel(accountDir);
      } catch (e, st) {
        log.severe(
          message: 'Failed to write SP revoke sentinel',
          error: e,
          trace: st,
        );
        rethrow;
      }
    }

    // Dispose so the sqlite handle is released before the delete. A dispose
    // timeout must NOT abort the revoke (that would leave the wallet
    // undeletable), so log and proceed on failure.
    if (hasSession) {
      try {
        await dispose();
      } catch (e) {
        log.warning(
          'SpAccountRepository.revokeOnDisk: dispose failed, proceeding: $e',
        );
      }
    }

    // Recursive delete. On failure re-create the sentinel (the delete may have
    // removed it before failing on a locked child) and tell observers to drop
    // the SP card, then rethrow so the caller can surface it.
    if (accountDir.existsSync()) {
      try {
        accountDir.deleteSync(recursive: true);
      } catch (e, st) {
        log.severe(
          message:
              'Failed to delete SP account directory; sentinel left in '
              'place so wallet will not be loaded',
          error: e,
          trace: st,
        );
        try {
          if (accountDir.existsSync()) {
            _writeRevokedSentinel(accountDir, skipIfPresent: true);
          }
        } catch (sentinelErr, sentinelSt) {
          log.severe(
            message:
                'Failed to re-create SP revoke sentinel after delete '
                'failure; on-disk wallet may still be reloadable',
            error: sentinelErr,
            trace: sentinelSt,
          );
        }
        _emit(const SpSetupChanged());
        Error.throwWithStackTrace(e, st);
      }
    }
  }

  @override
  Future<bool> backupAccountDir() async {
    final accountDir = await _accountDir();
    if (!accountDir.existsSync()) {
      _recreateBackupDir = null;
      return false;
    }
    final backupDir = Directory(
      '${accountDir.path}.backup-${DateTime.now().microsecondsSinceEpoch}',
    );
    accountDir.renameSync(backupDir.path);
    _recreateBackupDir = backupDir;
    return true;
  }

  @override
  Future<bool> restoreAccountDir() async {
    final accountDir = await _accountDir();
    if (accountDir.existsSync()) {
      accountDir.deleteSync(recursive: true);
    }
    final backupDir = _recreateBackupDir;
    if (backupDir == null || !backupDir.existsSync()) return false;
    backupDir.renameSync(accountDir.path);
    _recreateBackupDir = null;
    return true;
  }

  @override
  Future<void> discardBackup() async {
    final backupDir = _recreateBackupDir;
    _recreateBackupDir = null;
    if (backupDir == null || !backupDir.existsSync()) return;
    try {
      backupDir.deleteSync(recursive: true);
    } on FileSystemException {
      // The active recreated wallet is already installed. A stale backup dir is
      // harmless and can be cleaned manually.
    }
  }

  @override
  Future<void> wipeStaleAccountDir() async {
    final accountDir = await _accountDir();
    if (accountDir.existsSync()) {
      accountDir.deleteSync(recursive: true);
    }
  }

  @override
  Future<void> createFromMnemonic({
    required dom.SpNetwork network,
    required String mnemonic,
    required String blindbitUrl,
    required String electrumUrl,
  }) async {
    // Single-owner guard: the adapter holds exactly one live SpAccount, so a
    // create over an existing session would leak the old Rust notif thread,
    // electrum socket and sqlite handle. Callers dispose first; hitting this
    // means a teardown+create race slipped past EnsureSpSessionUsecase.
    if (_account != null) {
      throw StateError(
        'SpAccountRepository: createFromMnemonic called while a session is '
        'live; dispose the current session first',
      );
    }
    final dataDir = await _dataDir;
    _resetNotificationState();
    _scanning = false;
    // Clear any lingering advisory lock. On mobile (single process) a present
    // lock is a disposed session whose Rust handle is not GC'd yet, so it can
    // never be a real second owner; the in-app single-establishment guard
    // (EnsureSpSessionUsecase) keeps two live sessions from ever racing.
    final lock = File('$dataDir/${SpConfig.accountName}/${SpConfig.lockFile}');
    if (lock.existsSync()) {
      try {
        lock.deleteSync();
      } catch (e) {
        log.warning('SpAccountRepository: stale lock delete failed: $e');
      }
    }
    final account = SpAccount.createFromMnemonic(
      name: SpConfig.accountName,
      network: SpNetworkMapper.toFfi(network),
      mnemonic: mnemonic,
      blindbitUrl: blindbitUrl,
      electrumUrl: electrumUrl,
      dataDir: dataDir,
    );
    _account = account;
    // Start the always-on taproot sub-account electrum listener so incoming txs
    // are pushed without a manual scan. createFromMnemonic does not propagate the
    // electrum URL into the sub-account, so set it first (mirrors the silent
    // wallet). The URL is non-empty by the SpBackendConfig invariant. Failures
    // here must not abort session setup.
    try {
      account.setElectrumUrl(url: electrumUrl);
      // Fire-and-forget: starting the listener must never block (or hang)
      // session establishment. Errors are logged, not fatal.
      unawaited(
        account.startElectrum().catchError((Object e) {
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
  }

  @override
  SpWallet snapshot() {
    final account = _live;
    return SpWallet(
      spAddress: account.spAddress(),
      balance: SpBalanceMapper.toDomain(account.unifiedBalance()),
      isScanning: account.isScanning(),
      lastScannedHeight: account.lastScannedHeight(),
    );
  }

  @override
  Future<Result<String, SpFailure>> generateTaprootAddress() async {
    try {
      return Ok(await _live.newTaprootAddress());
    } catch (e) {
      return Err(_mapFfiError(e));
    }
  }

  @override
  SpBalance balance() => SpBalanceMapper.toDomain(_live.unifiedBalance());

  @override
  bool get isScanning => _live.isScanning();

  @override
  int? get lastScannedHeight => _live.lastScannedHeight();

  @override
  bool get isScanningCached => _scanning;

  @override
  Future<Result<List<SpPayment>, SpFailure>> history() async {
    try {
      final views = await _live.unifiedHistory();
      return Ok(views.map(SpPaymentMapper.toDomain).toList());
    } catch (e) {
      return Err(_mapFfiError(e));
    }
  }

  @override
  Future<Result<List<SpCoin>, SpFailure>> coins() async {
    try {
      final views = await _live.unifiedCoins();
      return Ok(views.map(SpCoinMapper.toDomain).toList());
    } catch (e) {
      return Err(_mapFfiError(e));
    }
  }

  // USER-TRIGGERED ONLY. This is the single Dart call site of `scanOnce`; it is
  // reached only via `ScanSpWalletUsecase`. Do not add other callers; the
  // no-auto-scan invariant depends on it.
  @override
  Future<Result<void, SpFailure>> scanOnce({int? startHeight}) async {
    // Set scanning synchronously, before the first await, so the WalletBloc's
    // isSpScanning gate has no blind window between scan_once returning (it
    // spawns a background thread) and the first ScanStarted notification.
    // Cleared on the terminal notification in _recordNotification.
    _scanning = true;
    try {
      await _live.scanOnce(startHeight: startHeight);
      return const Ok(null);
    } catch (e) {
      _scanning = false;
      return Err(_mapFfiError(e));
    }
  }

  @override
  Future<void> stopScan() => _live.stopScan();

  @override
  Future<void> restartElectrum() async {
    final account = _account;
    if (account == null) return;
    await account.restartElectrum();
  }

  @override
  int minBirthdayHeight() => _live.minBirthdayHeight();

  @override
  Future<Result<SpTxDraft, SpFailure>> preparePsbt({
    required List<SpRecipient> recipients,
    required BigInt feerateSatVb,
  }) async {
    try {
      final simulation = await _live.preparePsbt(
        recipients: recipients.map(SpRecipientMapper.toFfi).toList(),
        feerateSatVb: feerateSatVb,
      );
      final id = (_nextDraftId++).toString();
      _simulations[id] = simulation;
      return Ok(SpTxDraftMapper.toDomain(simulation, id));
    } catch (e) {
      return Err(_mapFfiError(e));
    }
  }

  @override
  Future<Result<String, SpFailure>> finalizeSignBroadcast({
    required SpTxDraft draft,
  }) async {
    final simulation = _simulations[draft.id];
    if (simulation == null) {
      // The pinned simulation is gone (the session was recycled since confirm),
      // so the tx can no longer be rebuilt from what the Confirm page showed.
      return const Err(
        SpSimulationDrifted('pinned simulation no longer available'),
      );
    }
    try {
      return Ok(await _finalizeSignBroadcast(simulation: simulation));
    } catch (e) {
      return Err(_mapFfiError(e));
    }
  }

  Future<String> _finalizeSignBroadcast({
    required TxSimulation simulation,
  }) async {
    final account = _live;
    // The Rust side pins inputs+outputs to the confirmed simulation and fails
    // loudly if the coin store drifted, so we never broadcast a tx whose
    // inputs differ from what was shown on the Confirm page.
    final psbtBytes = await account.finalizePsbt(simulation: simulation);
    final signedBytes = await account.signPsbt(psbt: psbtBytes);
    final txHex = signedBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    // changeSat lets bwk net the SP change into the unconfirmed send amount so
    // history shows sent + fee before the change is scanned back in.
    final txid = await account.broadcast(
      txHex: txHex,
      changeSat: simulation.changeSat,
    );
    // The tx is now irreversible. Log the txid before returning so it always
    // survives in the device log even if the caller was torn down mid-await.
    log.info('SpAccountRepository: broadcast succeeded txid=$txid');
    return txid;
  }

  @override
  dom.SpNetwork? network() {
    // Distinguish "no session yet" (null, a genuine unknown) from an FFI read
    // failure (rethrown), so the wrong-network address guard can fail closed on
    // a transient error instead of silently skipping validation.
    final account = _account;
    if (account == null) return null;
    return SpNetworkMapper.toDomain(account.network());
  }

  @override
  bool backendOnline() {
    try {
      return _live.backendOnline();
    } catch (e) {
      log.warning('SpAccountRepository.backendOnline: $e');
      return false;
    }
  }

  @override
  int? chainTip() {
    try {
      return _live.blockHeight();
    } catch (e) {
      log.warning('SpAccountRepository.chainTip: $e');
      return null;
    }
  }

  @override
  Stream<dom.SpNotification> get notifications => _ensureNotifications();

  // Set up the Rust notification forwarding (init) + source listener exactly
  // once per session. Called from createFromMnemonic so recording (and electrum
  // pushes) flow as soon as a session exists, independent of any UI subscriber;
  // `init()` is taken-once per account, so doing it here avoids the double-init
  // ("receiver already taken") that broke recording. Each FFI notification is
  // mapped to a domain notification before it leaves the boundary.
  Stream<dom.SpNotification> _ensureNotifications() {
    final existing = _notifications;
    if (existing != null) return existing;

    final source = _live.init();
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
    final affectsBalance =
        n is dom.SpNewOutput ||
        n is dom.SpOutputSpent ||
        n is dom.SpElectrumTx ||
        n is dom.SpScanCompleted;
    if (!affectsBalance) return;
    // Skip the per-event balance read during a scan to avoid churn; the
    // ScanCompleted event reconciles the balance once the scan ends.
    if (_scanning) return;
    try {
      _emit(SpBalanceChanged(balance().confirmedSat));
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
    if (n is dom.SpScanStarted) {
      _scanning = true;
    } else if (n is dom.SpScanCompleted ||
        n is dom.SpScanStopped ||
        n is dom.SpScanFailed) {
      _scanning = false;
    }
    final line = SpNotifLogLine(
      time: DateTime.now(),
      text: formatSpNotification(n),
    );
    _notifLog.add(line);
    if (_notifLog.length > _notifLogCap) _notifLog.removeAt(0);
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
  Future<void> dispose() async {
    if (!hasSession) return;
    final pending = _pendingDispose;
    if (pending != null) return pending;
    final future = _runDispose();
    _pendingDispose = future;
    try {
      await future;
    } finally {
      _pendingDispose = null;
    }
  }

  // Tears down the Rust session and drops the reference. Rethrows "dispose timed
  // out" if the inner lock is still held, in which case the reference is kept.
  // Protected so a test can override it (the live session is an FFI type).
  @protected
  @visibleForTesting
  Future<void> disposeCurrentSession() async {
    final account = _account;
    if (account != null) {
      await account.dispose();
      _account = null;
      _notifications = null;
      _simulations.clear();
    }
  }

  // Whether the Dart notification plumbing has been torn down. Test-only view of
  // the internal flag so a timed-out dispose can be asserted not to tear it down.
  @visibleForTesting
  bool get notifStreamTornDown => _notifTornDown;

  Future<void> _runDispose() async {
    // Tear down the Rust session FIRST. This flips the notif-thread shutdown
    // flag, stops the electrum listener, and releases the sqlite handle/.lock.
    // It MUST happen before cancelling the Dart notification subscription:
    // cancelling an FRB stream subscription while the Rust notif thread is
    // still actively producing (electrum flood) deadlocks, which previously
    // wedged the whole revoke/delete flow. Only tear down the Dart plumbing
    // after a clean dispose, so a timed-out dispose keeps the live session's
    // streams intact.
    await disposeCurrentSession();
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

  void _resetNotificationState() {
    _notifications = null;
    _sourceSub = null;
    _broadcastController = null;
    _notifTornDown = false;
  }
}
