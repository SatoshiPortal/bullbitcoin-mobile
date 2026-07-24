import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/cbf_scan_type_resolver.dart';
import 'package:bb_mobile/core/wallet/data/mappers/cbf_wallet_sync_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/cbf_sync_activity_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:convert/convert.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

/// Native peer connections `CbfBuilder` targets per session. Matches the
/// value validated by the CBF spike
/// (`docs/compact-block-filters-spike-runbook.md`); not user-configurable in
/// V1.
const cbfConnections = 2;

/// Bound on waiting for the info/warning reader loops to notice
/// `shutdown()` and exit with `NodeStoppedCbfException`. Upstream peer
/// tasks can outlive `CbfClient.shutdown()` (a lifecycle limitation the
/// spike recorded), so Dart-side teardown does not wait on them forever.
const cbfReaderTeardownTimeout = Duration(seconds: 10);

/// Bound on [CbfWalletDatasource.cancelAndWait]'s wait for an in-flight
/// attempt to fully settle after requesting cancellation. Generous enough
/// to cover [cbfReaderTeardownTimeout] plus a native `update()`/persist
/// call, but still finite: a caller that needs this wallet's on-disk state
/// left alone (deleting it) must learn that the native session may still
/// be writing rather than block forever.
const cbfCancelAndWaitTimeout = Duration(seconds: 20);

/// One native CBF session's lifecycle, seamed out of [CbfWalletDatasource]
/// so tests can substitute a fake without constructing any FFI-backed
/// `bull_sdk` type. The default implementation ([CbfWalletDatasource]'s
/// internal session factory) is the only code that touches `CbfBuilder`,
/// `CbfComponents`, or `Wallet` directly.
abstract interface class CbfNativeSession {
  /// Starts the native node. Non-blocking; peer connection/scan work
  /// happens on the native side.
  void run();

  /// Awaits the next connection/handshake/progress/block info event. Throws
  /// `bdk.NodeStoppedCbfException` once [shutdown] has taken effect.
  Future<bdk.Info> nextInfo();

  /// Awaits the next recoverable warning. Throws
  /// `bdk.NodeStoppedCbfException` once [shutdown] has taken effect.
  Future<bdk.Warning> nextWarning();

  /// Whether the native node is still running; the reader loops use this to
  /// know when to stop pulling from [nextInfo]/[nextWarning].
  bool isRunning();

  /// Awaits the scan's update, applies it to the wallet, and persists the
  /// wallet. Deliberately one call rather than an `update()` step returning
  /// `bdk.Update` plus a separate apply step: `bdk.Update` is a native
  /// handle uniffi only knows how to free through another FFI call, so it
  /// must never cross this seam — a fake standing in for this session
  /// would have no safe value to hand back.
  Future<void> awaitAndApplyUpdate();

  /// Requests native shutdown. Implementations must be idempotent: the
  /// native client throws `NodeStoppedCbfException` on a second call rather
  /// than tolerating it, and callers here (cancellation racing normal
  /// completion) can legitimately call this twice.
  void shutdown();

  /// Applies [transaction] (a signed PSBT when [isPsbt], otherwise a raw
  /// hex-encoded transaction) directly to this session's already-loaded
  /// in-memory wallet and persists it — the fast path
  /// [CbfWalletDatasource.applyUnconfirmedTransactionIfActive] uses so a
  /// just-broadcast transaction becomes visible immediately without
  /// waiting on `BdkWalletDatasource`'s independently-loaded fallback
  /// (which serializes on this same wallet id and could otherwise block
  /// for as long as this session's scan is still running). Implementations
  /// must never construct a second `bdk.Wallet` handle for this wallet —
  /// two independently-loaded handles racing to persist the same sqlite db
  /// is exactly the lost-update this seam exists to avoid.
  Future<void> applyUnconfirmedTransaction({
    required String transaction,
    required bool isPsbt,
    required int lastSeen,
  });
}

/// Builds the native session for one wallet sync attempt. The default
/// factory ([CbfWalletDatasource.new]'s implicit default) owns every
/// `bull_sdk` call — building the public BDK wallet via [BdkFacade],
/// resolving this wallet's `dataDir`, and constructing `CbfBuilder`. Tests
/// inject a fake that never touches native code.
typedef CbfNativeSessionFactory =
    Future<CbfNativeSession> Function(WalletMetadataModel metadata);

/// Resolves the stable, per wallet/network `dataDir` CBF persists headers,
/// peers, and filters under. The default implementation is the only code
/// here that touches `path_provider`; tests inject a resolver pointed at a
/// temp directory instead.
typedef CbfDataDirResolver =
    Future<String> Function(WalletMetadataModel metadata);

/// Long-lived compact block filter (BIP157/158) sync datasource.
///
/// Owns at most one active native session per wallet: a call for a wallet
/// that already has an in-flight attempt joins that attempt's result
/// instead of starting a second native node. Which `bdk.ScanType` a session
/// starts with — [bdk.SyncScanType] or [bdk.RecoveryScanType] — is decided
/// per wallet by [CbfScanTypeResolver]; see that class for the selection
/// rule.
///
/// Session lifecycle policy: once started, an active session is never torn
/// down by app lifecycle transitions (foreground/background/inactive) or by
/// an ordinary/user-requested cancellation — it keeps running until it
/// settles naturally (completed or a native terminal error) or until this
/// process dies. The only exceptions, both deliberately narrow, are
/// [cancelAndWait] (wallet deletion — on-disk state must not be mutated by
/// a still-running session) and enabling Tor mid-session (security — see
/// [_onTorProxyChange]). This class has no dependency on `WidgetsBinding`
/// or `AppLifecycleState`; it never reacts to app lifecycle transitions.
///
/// Never logs a wallet id, peer, descriptor, transaction, or warning
/// payload: every log line here is a fixed, non-sensitive code or an
/// exception's `runtimeType`. No `socks5Proxy` is configured (V1 does not
/// support Tor for CBF — see `docs/compact-block-filters-pr-roadmap.md`)
/// and no P2P broadcast is performed; this datasource only reads chain data.
///
/// Also implements [CbfSyncActivityPort]: `_attempts` (below) is this
/// class's own authoritative record of which wallets currently have a
/// running session, so [isActive]/[waitUntilInactive] read straight off
/// it instead of a derived/observed proxy for it — see
/// [CbfSyncActivityPort]'s class doc for why a stream-derived
/// implementation is not an acceptable substitute.
class CbfWalletDatasource implements CbfSyncActivityPort {
  late final CbfNativeSessionFactory _sessionFactory;
  final CbfDataDirResolver _dataDirResolver;
  final CbfScanTypeResolver _scanTypeResolver;
  final Future<bool> Function() _isTorProxyEnabled;
  final _attempts = <String, _CbfSyncAttempt>{};
  final _progressController = StreamController<WalletSyncProgress>.broadcast();

  StreamSubscription<bool>? _torProxyChangeSubscription;

  CbfWalletDatasource({
    CbfNativeSessionFactory? sessionFactory,
    CbfDataDirResolver? dataDirResolver,
    CbfScanTypeResolver? scanTypeResolver,
    Stream<bool>? torProxyChangeStream,
    Future<bool> Function()? isTorProxyEnabled,
  }) : _dataDirResolver = dataDirResolver ?? _defaultDataDirPath,
       _scanTypeResolver =
           scanTypeResolver ?? const DefaultCbfScanTypeResolver(),
       _isTorProxyEnabled = isTorProxyEnabled ?? _torIsDisabled {
    _sessionFactory = sessionFactory ?? _buildDefaultSession;
    // A plain Dart stream subscription — never touches Flutter/
    // WidgetsBinding — so it is safe to attach eagerly here even when
    // constructed from a background context.
    if (torProxyChangeStream != null) {
      _torProxyChangeSubscription = torProxyChangeStream.listen(
        _onTorProxyChange,
      );
    }
  }

  Stream<WalletSyncProgress> watchProgress() => _progressController.stream;

  /// Whether [walletId] currently has an attempt registered in [_attempts]
  /// — set synchronously by [startSync], before this attempt's native
  /// session is even built, let alone before any [WalletSyncStarted]
  /// progress event is emitted. A caller checking this immediately after
  /// [startSync] is invoked (even without awaiting it) already observes
  /// `true`.
  @override
  bool isActive({required String walletId}) => _attempts.containsKey(walletId);

  /// Resolves immediately if [walletId] has no attempt registered right
  /// now; otherwise resolves once that attempt's [_CbfSyncAttempt.result]
  /// settles — completed, failed, or cancelled by something other than
  /// this call. Never itself requests cancellation: the attempt found
  /// here, if any, is left to run to its own conclusion.
  @override
  Future<void> waitUntilInactive({required String walletId}) async {
    final attempt = _attempts[walletId];
    if (attempt == null) return;
    await attempt.result;
  }

  /// Starts (or joins an already in-flight) CBF sync for the wallet
  /// described by [metadata]. See [CbfWalletDatasource] for the
  /// single-session-per-wallet guarantee.
  Future<Result<CbfSyncOutcome, WalletSyncFailure>> startSync({
    required WalletMetadataModel metadata,
  }) async {
    final walletId = metadata.id;
    final inFlight = _attempts[walletId];
    if (inFlight != null) {
      log.fine('CBF sync joined active attempt');
      return inFlight.result;
    }

    final attempt = _CbfSyncAttempt();
    _attempts[walletId] = attempt;
    log.fine('CBF sync requested');
    try {
      final result = await _run(metadata, attempt);
      attempt.complete(result);
      return result;
    } finally {
      if (identical(_attempts[walletId], attempt)) {
        _attempts.remove(walletId);
      }
    }
  }

  /// Deliberately a no-op. `WalletSyncRepository.cancelSync` requires this
  /// method to exist, and callers reachable through it — an ordinary
  /// user-requested "stop syncing" affordance, or an internal caller that
  /// merely wants this wallet's session out of the way — historically
  /// expected an in-flight attempt to actually stop. Under the long-lived
  /// session policy it no longer does: once started, a CBF session keeps
  /// running to completion regardless of this call. The only ways an
  /// active session is torn down are [cancelAndWait] (wallet deletion) and
  /// a mid-session Tor-enable (security — see [_onTorProxyChange]).
  Future<void> cancelSync({required String walletId}) async {
    if (_attempts.containsKey(walletId)) {
      log.fine('CBF sync cancellation request ignored: long-lived session');
    }
  }

  /// Cancels [walletId]'s in-flight session, if any, and waits for that
  /// attempt to fully settle — bounded by [cbfCancelAndWaitTimeout].
  ///
  /// A caller about to delete this wallet's on-disk state (BDK sqlite db,
  /// CBF `dataDir`) MUST call this first, and MUST NOT proceed with
  /// deletion if it throws: a native session that has not actually
  /// stopped yet can still be writing to those files, and deleting them
  /// out from under it risks a crash or a corrupt partial delete.
  ///
  /// A wallet with no active session resolves immediately. Never swallows
  /// a timeout silently: it is logged (a fixed, non-sensitive message) and
  /// rethrown as [CbfSessionTeardownTimeoutException], so the caller must
  /// explicitly decide how to handle "the session might still be alive"
  /// rather than deletion proceeding as if teardown were confirmed.
  Future<void> cancelAndWait({required String walletId}) async {
    final attempt = _attempts[walletId];
    if (attempt == null) return;

    attempt.cancel();
    try {
      await attempt.result.timeout(cbfCancelAndWaitTimeout);
    } on TimeoutException {
      log.warning('CBF cancelAndWait timed out waiting for session teardown');
      throw CbfSessionTeardownTimeoutException(
        'CBF session did not settle within $cbfCancelAndWaitTimeout of '
        'cancellation',
      );
    }
  }

  /// Deletes this wallet's persisted CBF `dataDir` (headers, peers,
  /// filters). Called only on wallet deletion, after [cancelAndWait]; a
  /// missing directory is not an error.
  Future<void> deleteDataDir({required WalletMetadataModel metadata}) async {
    final dir = Directory(await _dataDirResolver(metadata));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Applies [transaction] directly to [metadata]'s active CBF session, if
  /// one is currently running, so a just-broadcast transaction becomes
  /// visible immediately without the caller falling back to
  /// `BdkWalletDatasource`'s independently-loaded path — which serializes
  /// per wallet id behind [BdkFacade.walletLock], the same lock this
  /// wallet's active session already holds for its full run, and so could
  /// otherwise block the caller for as long as the scan is still going.
  ///
  /// Returns `true` once applied to the active session; `false` means no
  /// session is running for this wallet right now and the caller must use
  /// the `BdkWalletDatasource` fallback instead.
  Future<bool> applyUnconfirmedTransactionIfActive({
    required WalletMetadataModel metadata,
    required String transaction,
    required bool isPsbt,
  }) async {
    final session = _attempts[metadata.id]?.session;
    if (session == null) return false;

    await session.applyUnconfirmedTransaction(
      transaction: transaction,
      isPsbt: isPsbt,
      lastSeen: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    return true;
  }

  /// Releases the Tor-proxy subscription. Safe to call even if no
  /// subscription was ever attached (no `torProxyChangeStream` passed to
  /// the constructor). Safe to skip for the app-wide singleton instance
  /// (it lives for the process lifetime); provided for symmetry and for
  /// tests that construct their own instance. Never tears down an active
  /// session — see the class doc's long-lived session policy.
  void dispose() {
    unawaited(_torProxyChangeSubscription?.cancel());
    _torProxyChangeSubscription = null;
  }

  /// Cancels every active session the instant Tor is turned on
  /// mid-session: CBF sessions never route through Tor (V1 has no
  /// `socks5Proxy` support for CBF — see the class doc), so a session left
  /// running after the user enables the proxy would keep making direct P2P
  /// connections against the user's expectation. Only `true` triggers this
  /// — turning Tor back off does not need to interrupt anything.
  ///
  /// This is a deliberate, narrow exception to the "only process death (or
  /// wallet deletion) tears down an active session" policy: this
  /// datasource does not implement Tor support for CBF at all (no
  /// `socks5Proxy`), so leaving a session connected to clearnet peers
  /// running after the user opts into Tor would silently defeat that
  /// choice for this wallet's chain-data traffic. Retained as-is;
  /// tightening it further (e.g. to also stop reacting once a session's
  /// scan has produced results) was out of scope for this change.
  void _onTorProxyChange(bool useTorProxy) {
    if (!useTorProxy) return;
    if (_attempts.isNotEmpty) {
      log.fine('CBF sync cancelled: network configuration changed');
    }
    _cancelAllActiveSessions();
  }

  /// Iterates a snapshot since [_CbfSyncAttempt.cancel] does not mutate
  /// [_attempts] itself (removal happens in [startSync]'s `finally`).
  void _cancelAllActiveSessions() {
    for (final attempt in _attempts.values.toList()) {
      attempt.cancel();
    }
  }

  /// Runs the wallet's sync attempt under [BdkFacade.walletLock], held for
  /// this whole build→scan→apply→persist span. This is the same lock
  /// `BdkWalletDatasource.applyUnconfirmedTransaction`'s fallback path
  /// takes, so two independently-loaded `bdk.Wallet` handles for this
  /// wallet's sqlite db never race to persist and silently drop each
  /// other's change — see [applyUnconfirmedTransactionIfActive] for the
  /// fast path that avoids ever waiting on this lock while this session is
  /// active.
  Future<Result<CbfSyncOutcome, WalletSyncFailure>> _run(
    WalletMetadataModel metadata,
    _CbfSyncAttempt attempt,
  ) => BdkFacade.walletLock(
    metadata.id,
  ).synchronized(() => _runLocked(metadata, attempt));

  Future<Result<CbfSyncOutcome, WalletSyncFailure>> _runLocked(
    WalletMetadataModel metadata,
    _CbfSyncAttempt attempt,
  ) async {
    final walletId = metadata.id;

    // Recheck immediately before native session setup. A Tor change after
    // the router's asynchronous gate but before this point must not open a
    // direct peer connection; a later change cancels this registered attempt.
    if (await _isTorProxyEnabled()) {
      return const Err(WalletSyncTorUnsupportedFailure());
    }

    CbfNativeSession session;
    try {
      session = await _sessionFactory(metadata);
    } catch (e) {
      log.warning('CBF session setup failed: ${e.runtimeType}');
      _progressController.add(
        WalletSyncFailed(
          walletId,
          WalletSyncFailureCategory.compactBlockFilters,
        ),
      );
      return Err(WalletSyncCbfFailure('${e.runtimeType}'));
    }
    attempt.session = session;

    if (attempt.isCancelled) {
      // cancelAndWait() (or a mid-session Tor-enable) ran while the factory
      // above was still in flight, so `attempt.cancel()` found no session
      // to shut down yet (it was null). Now that one is assigned, shut it
      // down immediately: never call run(), never emit Started, and settle
      // as cancelled rather than Err — this is a deliberate teardown, not a
      // failure.
      _shutdownSafely(session);
      _progressController.add(WalletSyncCancelled(walletId));
      return const Ok(CbfSyncOutcome.cancelled);
    }

    _progressController.add(
      WalletSyncStarted(walletId, BitcoinSyncBackend.compactBlockFilters),
    );
    log.fine('CBF sync session started');

    try {
      session.run();
    } catch (e) {
      log.warning('CBF session run failed: ${e.runtimeType}');
      _progressController.add(
        WalletSyncFailed(
          walletId,
          WalletSyncFailureCategory.compactBlockFilters,
        ),
      );
      return Err(WalletSyncCbfFailure('${e.runtimeType}'));
    }

    final infoReader = _readInfo(session, walletId, attempt);
    final warningReader = _readWarnings(session, walletId, attempt);

    // Give the reader loops just started above a chance to drain and
    // classify any info/warning event the native session already had
    // buffered by the time run() returned — e.g. an initial ProgressInfo —
    // as genuine scanning progress before this attempt commits to the
    // one-shot applyingUpdate stage below. `_readInfo`/`_readWarnings` are
    // async and, for an already-available event, only resume via a
    // microtask; without this yield, the sticky flag below would always
    // already be true by the time that microtask runs, silently dropping
    // an event that was genuinely available before we started waiting on
    // the update. A microtask-level yield (not a timer) is deliberate: it
    // drains exactly the reader loops' already-queued continuations —
    // and nothing more — without adding a real delay to every sync
    // attempt, and without racing a caller's own `Future.delayed` (a real
    // timer only fires once every pending microtask has already drained).
    await Future<void>.microtask(() {});

    // Emitted once, immediately before the opaque update/apply/save call
    // below — see WalletSyncScanStage.applyingUpdate's doc. No further
    // progress signal is possible until that call settles, so this is the
    // last honest thing to report before either Completed or Failed. Set
    // the sticky flag first: `_readInfo` is already running concurrently
    // (started just above) and must stop classifying any info event it
    // reads after this point as a fresh scanning stage — see that flag's
    // doc for the reader-loop race this guards against.
    attempt.hasReachedApplyingUpdate = true;
    _progressController.add(
      WalletSyncScanning(
        walletId,
        stage: WalletSyncScanStage.applyingUpdate,
        receivedBlockCount: attempt.receivedBlockCount,
      ),
    );

    Object? syncError;
    try {
      await session.awaitAndApplyUpdate();
    } catch (e) {
      syncError = e;
    }

    // The scan is done (or failed) either way — stop the node so the reader
    // loops above can drain and exit.
    _shutdownSafely(session);
    syncError ??= await _awaitReaderTeardown(infoReader, warningReader);

    if (attempt.isCancelled) {
      // Cancellation is a settled, non-failure outcome: no Completed
      // progress event, no failure — WalletSyncCancelled instead, so a
      // foreground UI observing this wallet's progress can drop it rather
      // than being left showing a stale in-progress state. Never persisted
      // as `syncedAt` by `CbfWalletSyncRepository` — see [CbfSyncOutcome].
      _progressController.add(WalletSyncCancelled(walletId));
      log.fine('CBF sync cancelled');
      return const Ok(CbfSyncOutcome.cancelled);
    }

    if (syncError != null) {
      log.warning('CBF sync failed: ${syncError.runtimeType}');
      _progressController.add(
        WalletSyncFailed(
          walletId,
          WalletSyncFailureCategory.compactBlockFilters,
        ),
      );
      return Err(WalletSyncCbfFailure('${syncError.runtimeType}'));
    }

    _progressController.add(WalletSyncCompleted(walletId));
    log.fine('CBF sync completed');
    return const Ok(CbfSyncOutcome.completed);
  }

  /// Calls [CbfNativeSession.shutdown], never letting an exception escape.
  /// [CbfNativeShutdownGuard] already tolerates a repeated
  /// `NodeStoppedCbfException`, but this is the last line of defense against
  /// any other native teardown error reaching a caller as an unhandled
  /// exception — a shutdown failure must never crash the sync attempt.
  void _shutdownSafely(CbfNativeSession session) {
    try {
      session.shutdown();
    } catch (e) {
      log.warning('CBF session shutdown failed: ${e.runtimeType}');
    }
  }

  /// Never lets any exception escape *unhandled*: `awaitAndApplyUpdate()`
  /// can still be pending — for as long as this session's scan takes —
  /// when something other than the expected `NodeStoppedCbfException` is
  /// thrown here, so nothing awaits this Future yet at that point. Rather
  /// than swallowing the error, it is caught and returned as this Future's
  /// (non-error) result, so [_awaitReaderTeardown] can still fold it into
  /// the attempt's outcome — a progress-channel failure like this must
  /// still surface as [WalletSyncFailed]/`Err`, not silently complete —
  /// while never leaving this Future itself in an error state that could
  /// later be reported as unhandled.
  Future<Object?> _readInfo(
    CbfNativeSession session,
    String walletId,
    _CbfSyncAttempt attempt,
  ) async {
    try {
      while (session.isRunning()) {
        final info = await session.nextInfo();
        if (info is bdk.BlockReceivedInfo) {
          attempt.receivedBlockCount++;
        }
        if (info is bdk.SuccessfulHandshakeInfo) {
          attempt.peerHandshakeCount++;
        }
        final infoType = switch (info) {
          bdk.ProgressInfo() => 'progress',
          bdk.ConnectionsMetInfo() => 'connections',
          bdk.SuccessfulHandshakeInfo() => 'handshake',
          bdk.BlockReceivedInfo() => 'block',
          _ => 'unknown',
        };
        if (attempt.loggedInfoTypes.add(infoType)) {
          log.fine('CBF sync info: $infoType');
        }
        // The node keeps running (and this loop keeps draining
        // `nextInfo()`) until `shutdown()` takes effect, which only
        // happens after `awaitAndApplyUpdate()` settles — so an info event
        // already in flight (or queued natively) when the applyingUpdate
        // marker below was emitted can still surface here afterwards.
        // WalletSyncScanStage.applyingUpdate is "never derived from a
        // native info event" and is emitted exactly once, so once this
        // attempt has reached it, a late info event must be silently
        // dropped rather than reclassified into a WalletSyncScanning that
        // would regress a foreground observer's UI back to an earlier
        // stage.
        if (attempt.hasReachedApplyingUpdate) continue;
        final progress = CbfWalletSyncMapper.toScanningProgress(
          info,
          hasStartedDownloadingFilters: attempt.hasStartedDownloadingFilters,
        );
        attempt.hasStartedDownloadingFilters =
            progress.hasStartedDownloadingFilters;
        _progressController.add(
          WalletSyncScanning(
            walletId,
            stage: progress.stage,
            scannedPercent: progress.scannedPercent,
            chainHeight: progress.chainHeight,
            receivedBlockCount: attempt.receivedBlockCount,
            peerHandshakeCount: attempt.peerHandshakeCount,
          ),
        );
      }
      return null;
    } on bdk.NodeStoppedCbfException {
      // Expected once shutdown() takes effect.
      return null;
    } catch (e) {
      log.warning('CBF info reader failed: ${e.runtimeType}');
      return e;
    }
  }

  /// See [_readInfo]'s doc — same "never let an exception escape unhandled,
  /// but never swallow it either" rule.
  Future<Object?> _readWarnings(
    CbfNativeSession session,
    String walletId,
    _CbfSyncAttempt attempt,
  ) async {
    try {
      while (session.isRunning()) {
        final warning = CbfWalletSyncMapper.toWarning(
          await session.nextWarning(),
        );
        final code = warning.logMessage ?? 'cbf_unexpected_warning';
        if (attempt.loggedWarningCodes.add(code)) {
          log.fine('CBF sync warning: $code');
        }
        _progressController.add(WalletSyncWarningRaised(walletId, warning));
      }
      return null;
    } on bdk.NodeStoppedCbfException {
      // Expected once shutdown() takes effect.
      return null;
    } catch (e) {
      log.warning('CBF warning reader failed: ${e.runtimeType}');
      return e;
    }
  }

  /// Awaits both reader loops, bounded by [cbfReaderTeardownTimeout]. Returns
  /// null when both readers exit cleanly (or the bound trips); returns the
  /// first non-null reader error otherwise, so it can be folded into the
  /// attempt's result as a genuine failure instead of a reader error being
  /// silently completed over.
  Future<Object?> _awaitReaderTeardown(
    Future<Object?> infoReader,
    Future<Object?> warningReader,
  ) async {
    try {
      final errors = await Future.wait([
        infoReader,
        warningReader,
      ]).timeout(cbfReaderTeardownTimeout);
      return errors.firstWhere((e) => e != null, orElse: () => null);
    } on TimeoutException {
      // Bounded on purpose — see cbfReaderTeardownTimeout.
      return null;
    }
  }

  Future<CbfNativeSession> _buildDefaultSession(
    WalletMetadataModel metadata,
  ) async {
    final walletModel = WalletModel.fromMetadata(metadata);
    final wallet = await BdkFacade.createWallet(walletModel);
    final dataDir = await _dataDirResolver(metadata);
    await Directory(dataDir).create(recursive: true);
    // The wallet's own already-persisted local chain tip — the resolver's
    // only source for whether a real `Update` has ever been applied to
    // this specific `bdk.Wallet` handle, independent of (and, in the rare
    // case its sqlite db was lost, more trustworthy than) `syncedAt`. See
    // `CbfScanTypeResolver` for why this is what actually gates
    // `SyncScanType` vs `RecoveryScanType`.
    final scanType = _scanTypeResolver.resolve(
      metadata,
      walletLatestCheckpointHeight: wallet.latestCheckpoint().height,
    );
    final components = bdk.CbfBuilder()
        .connections(connections: cbfConnections)
        .dataDir(dataDir: dataDir)
        .scanType(scanType: scanType)
        .build(wallet: wallet);
    return _RealCbfNativeSession(
      wallet: wallet,
      components: components,
      walletIdHex: walletModel.hexId,
    );
  }

  /// Stable per wallet/network path under the app documents directory so a
  /// resumed session (and wallet deletion cleanup) can find the same
  /// `dataDir` again. Only the wallet's hex-encoded id and network are used
  /// — never a descriptor, xpub, or other wallet secret.
  static Future<String> _defaultDataDirPath(
    WalletMetadataModel metadata,
  ) async {
    final docs = await getApplicationDocumentsDirectory();
    final hexId = WalletModel.fromMetadata(metadata).hexId;
    final network = metadata.isTestnet ? 'testnet' : 'mainnet';
    return '${docs.path}/cbf/${hexId}_$network';
  }

  static Future<bool> _torIsDisabled() async => false;
}

/// Makes a native shutdown callback safe to call more than once.
///
/// `bdk.CbfClient.shutdown()` throws `NodeStoppedCbfException` on a second
/// call rather than tolerating it, but callers here can legitimately
/// trigger shutdown twice — e.g. [CbfWalletDatasource.cancelAndWait] (or a
/// mid-session Tor-enable) racing the unconditional shutdown a
/// completed/failed sync attempt already issues. This guard makes the
/// second (and every later) call a no-op instead of a thrown exception
/// reaching the caller.
class CbfNativeShutdownGuard {
  CbfNativeShutdownGuard(this._shutdown);

  final void Function() _shutdown;
  bool _isShutdown = false;

  void call() {
    if (_isShutdown) return;
    _isShutdown = true;
    try {
      _shutdown();
    } on bdk.NodeStoppedCbfException {
      // Already stopped between our idempotency check and this call.
    }
  }
}

/// Default [CbfNativeSession]: the only place that calls `bull_sdk`'s
/// `CbfBuilder`/`CbfComponents`/`Wallet` FFI-backed APIs.
class _RealCbfNativeSession implements CbfNativeSession {
  final bdk.Wallet _wallet;
  final bdk.CbfComponents _components;
  final String _walletIdHex;
  late final CbfNativeShutdownGuard _shutdownGuard;

  /// Serializes every touch of [_wallet] (the one in-memory handle this
  /// session owns) between the scan's own apply+persist step
  /// ([awaitAndApplyUpdate]) and an ad hoc [applyUnconfirmedTransaction]
  /// call — deliberately session-local (not
  /// [BdkFacade.walletLock]/[CbfWalletDatasource._run]'s cross-subsystem
  /// lock, which is held for this session's entire run): only held for the
  /// brief mutate+persist step itself, so
  /// [CbfWalletDatasource.applyUnconfirmedTransactionIfActive] never blocks
  /// for the scan's full duration.
  final _mutationLock = Lock();

  _RealCbfNativeSession({
    required this._wallet,
    required this._components,
    required this._walletIdHex,
  }) {
    _shutdownGuard = CbfNativeShutdownGuard(_components.client.shutdown);
  }

  @override
  void run() => _components.node.run();

  @override
  Future<bdk.Info> nextInfo() => _components.client.nextInfo();

  @override
  Future<bdk.Warning> nextWarning() => _components.client.nextWarning();

  @override
  bool isRunning() => _components.client.isRunning();

  @override
  Future<void> awaitAndApplyUpdate() async {
    final update = await _components.client.update();
    await _mutationLock.synchronized(() async {
      _wallet.applyUpdate(update: update);
      await BdkFacade.saveWallet(_wallet, _walletIdHex);
    });
  }

  @override
  Future<void> applyUnconfirmedTransaction({
    required String transaction,
    required bool isPsbt,
    required int lastSeen,
  }) async {
    await _mutationLock.synchronized(() async {
      final tx = isPsbt
          ? bdk.Psbt(psbtBase64: transaction).extractTx()
          : bdk.Transaction(
              transactionBytes: Uint8List.fromList(hex.decode(transaction)),
            );
      _wallet.applyUnconfirmedTxs(
        unconfirmedTxs: [bdk.UnconfirmedTx(tx: tx, lastSeen: lastSeen)],
      );
      await BdkFacade.saveWallet(_wallet, _walletIdHex);
    });
  }

  @override
  void shutdown() => _shutdownGuard();
}

/// Distinguishes a settled CBF sync attempt's two non-failure outcomes, so
/// a caller like `CbfWalletSyncRepository` can persist `syncedAt` only for
/// a genuine scan completion. A deliberate teardown (wallet deletion via
/// `cancelAndWait`, or a mid-session Tor enable) must never be recorded as
/// a successful sync — see `CbfScanTypeResolver`'s use of `syncedAt` to
/// pick the next run's scan type. `cancelSync` never produces this outcome
/// on its own: it is a no-op under the long-lived session policy — see
/// [CbfWalletDatasource].
enum CbfSyncOutcome { completed, cancelled }

/// Thrown by [CbfWalletDatasource.cancelAndWait] when the wallet's
/// in-flight session did not settle within [cbfCancelAndWaitTimeout] of
/// cancellation being requested. Callers must treat this as "the native
/// session may still be writing to this wallet's files" and must not
/// proceed with deleting them.
class CbfSessionTeardownTimeoutException extends BullException {
  CbfSessionTeardownTimeoutException(super.message);
}

/// Tracks one wallet's in-flight (or already-settled) sync attempt so a
/// second [CbfWalletDatasource.startSync] call for the same wallet joins
/// this attempt's [result] instead of starting a second native session, and
/// so [CbfWalletDatasource.cancelAndWait] (or a mid-session Tor-enable) has
/// a session to shut down.
class _CbfSyncAttempt {
  final _completer = Completer<Result<CbfSyncOutcome, WalletSyncFailure>>();
  final loggedInfoTypes = <String>{};
  final loggedWarningCodes = <String>{};
  int receivedBlockCount = 0;
  int peerHandshakeCount = 0;

  /// Sticky classification state for `CbfWalletSyncMapper.toScanningProgress`
  /// — see that method's `hasStartedDownloadingFilters` argument.
  bool hasStartedDownloadingFilters = false;
  CbfNativeSession? session;
  bool isCancelled = false;

  /// Sticky once true: this attempt has emitted its one-shot
  /// `WalletSyncScanStage.applyingUpdate` progress event. Guards
  /// `_readInfo` against reclassifying a late-arriving native info event
  /// (read while `awaitAndApplyUpdate()` is still pending) back into an
  /// earlier scanning stage — see that reader's doc.
  bool hasReachedApplyingUpdate = false;

  Future<Result<CbfSyncOutcome, WalletSyncFailure>> get result =>
      _completer.future;

  void complete(Result<CbfSyncOutcome, WalletSyncFailure> value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }

  void cancel() {
    isCancelled = true;
    // A session assigned after this call (cancel racing the still-pending
    // session factory) is shut down by `_run` itself once it notices
    // `isCancelled` — see CbfWalletDatasource._run. Any shutdown error here
    // is logged, never rethrown: cancellation must never surface as an
    // unhandled exception on the caller of `cancelAndWait`/the Tor-enable
    // handler — the only two callers of this method.
    try {
      session?.shutdown();
    } catch (e) {
      log.warning('CBF shutdown-on-cancel failed: ${e.runtimeType}');
    }
  }
}
