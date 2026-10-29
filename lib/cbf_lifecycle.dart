import 'package:bb_mobile/core/background_tasks/cbf_background_sync.dart'
    show stopActiveCbfBackgroundSync, CbfForegroundPresence;
import 'package:primitives/primitives.dart' show Err, Ok;
import 'dart:async';

import 'package:bb_mobile/core/wallet/data/bitcoin_sync_routing.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Foreground composition: observation only; the package owns node lifetimes.
final class CbfLifecycle {
  final BitcoinSyncRouting routing;
  final WalletMetadataDatasource metadata;
  final Stream<void>? transportChanges;
  final TargetPlatform _platform;
  bool get _desktop =>
      _platform == TargetPlatform.linux ||
      _platform == TargetPlatform.macOS ||
      _platform == TargetPlatform.windows;
  StreamSubscription<List<WalletMetadataModel>>? _wallets;
  StreamSubscription<void>? _transports;
  bool _resumed = false;
  final _presence = CbfForegroundPresence();
  int _revision = 0;
  List<WalletMetadataModel> _current = [];
  String? _policy;

  CbfLifecycle({
    required this.routing,
    required this.metadata,
    this.transportChanges,
    TargetPlatform? platform,
  }) : _platform = platform ?? defaultTargetPlatform;

  void start(AppLifecycleState? state) {
    routing.facade.setCbfNativeOwnerMonitor(_presence.trackNativeNode);
    _resumed =
        (_desktop && state != AppLifecycleState.detached) ||
        state == null ||
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    unawaited(_presence.setActive(_resumed));
    routing.facade.setCbfForegroundActive(false);
    _transports = transportChanges?.listen((_) => refresh());
    _wallets = metadata.watchSyncPolicies().listen(
      (wallets) {
        final selected =
            wallets
                .where(
                  (wallet) =>
                      wallet.isBitcoin &&
                      wallet.bitcoinSyncSource ==
                          BitcoinSyncSource.compactBlockFilters,
                )
                .toList()
              ..sort((a, b) => a.id.compareTo(b.id));
        final policy = selected
            .map(
              (wallet) =>
                  '${wallet.id}:${wallet.birthday?.toIso8601String()}:${wallet.externalPublicDescriptor}:${wallet.internalPublicDescriptor}',
            )
            .join('|');
        if (_policy == policy) return;
        _policy = policy;
        _current = selected;
        refresh();
      },
      onError: (Object _) {
        unawaited(routing.facade.stopCbfNodes());
        log.warning('Unable to load compact filter wallet policies');
      },
    );
  }

  void onStateChange(AppLifecycleState state) {
    // Focus loss (notification shade, system prompts) keeps the app visible.
    // Preserve either foreground or background ownership until visibility changes.
    if (state == AppLifecycleState.inactive) return;
    final resumed =
        state == AppLifecycleState.resumed ||
        (_desktop && state != AppLifecycleState.detached);
    if (_resumed == resumed) return;
    _resumed = resumed;
    refresh();
  }

  void refresh() {
    final revision = ++_revision;
    final presence = _presence.setActive(true);
    // Publish foreground ownership before the headless stop lookup. Otherwise
    // a worker can pass both presence checks after that lookup but before the
    // asynchronous claim, leaving two generations admitted.
    final headlessStopped = presence.then<bool>(
      (owns) => owns ? stopActiveCbfBackgroundSync() : false,
    );
    routing.facade.setCbfForegroundActive(false);
    // Stop intent precedes async route verification and invalidates late batches.
    final stopped = routing.facade.pauseCbfNodes();
    unawaited(() async {
      try {
        final result = await stopped;
        final headlessJoined = await headlessStopped;
        final ownsPresence = await presence;
        if (revision != _revision) return;
        if (result is Ok) await _presence.nativeStopped();
        if (revision != _revision) return;
        if (result is Err || !headlessJoined || !ownsPresence) {
          unawaited(_retryAfterTermination(revision));
          return;
        }
        if (!_resumed) {
          await _presence.setActive(false);
          return;
        }
        if (!await _presence.armNative() ||
            revision != _revision ||
            !_resumed) {
          return;
        }
        routing.facade.setCbfForegroundActive(true);
        final registrations = <WalletSourceRegistration>[];
        for (final wallet in _current) {
          registrations.add(await routing.registration(wallet));
          if (revision != _revision || !_resumed) return;
        }
        final started = await routing.facade.reconcileCbfWallets(registrations);
        if (started is Err) log.warning('Unable to start compact filter nodes');
      } on Exception {
        log.warning('Unable to start compact filter nodes');
      }
    }());
  }

  Future<void> _retryAfterTermination(int revision) async {
    while (revision == _revision) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (revision != _revision) return;
      final stopped = await routing.facade.stopCbfNodes();
      final headlessJoined = await stopActiveCbfBackgroundSync();
      if (stopped is Ok && headlessJoined && revision == _revision) {
        refresh();
        return;
      }
    }
  }

  Future<void> dispose() async {
    _resumed = false;
    _revision++;
    await _wallets?.cancel();
    await _transports?.cancel();
    while (await routing.facade.stopCbfNodes() is Err) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    await _presence.nativeStopped();
    await _presence.dispose();
  }
}
