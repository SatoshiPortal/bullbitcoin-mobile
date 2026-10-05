import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';

/// The three sync watchers the wallet home arms, each emitting a `Result`
/// rather than throwing.
///
/// The shared core watchers can throw on subscribe and push errors into the
/// stream; the `await for` covers both. Without this the bloc needed a
/// `try/catch` around arming them and an `onError` on every listener (#1895).
class WatchWalletSyncEventsUsecase {
  final WatchStartedWalletSyncsUsecase _watchStarted;
  final WatchFinishedWalletSyncsUsecase _watchFinished;
  final WatchElectrumSyncResultsUsecase _watchElectrum;

  const WatchWalletSyncEventsUsecase({
    required this._watchStarted,
    required this._watchFinished,
    required this._watchElectrum,
  });

  Stream<Result<Wallet, WalletFailure>> started() =>
      _guard(() => _watchStarted.execute(), 'watch sync started');

  Stream<Result<Wallet, WalletFailure>> finished() =>
      _guard(() => _watchFinished.execute(), 'watch sync finished');

  Stream<Result<ElectrumSyncResult, WalletFailure>> electrumResults() =>
      _guard(() => _watchElectrum.execute(), 'watch electrum results');

  /// Turns stream errors into `Err` events **without ending the stream**.
  ///
  /// An `await for` would rethrow and terminate the subscription on the first
  /// error, so a single hiccup would freeze the sync indicators until the
  /// screen was rebuilt. A transformer keeps the subscription alive so later
  /// events still arrive. A throw on subscribe still ends it — there is no
  /// stream to stay attached to in that case.
  Stream<Result<T, WalletFailure>> _guard<T>(
    Stream<T> Function() open,
    String what,
  ) {
    final Stream<T> source;
    try {
      source = open();
    } catch (e) {
      return Stream.value(Err(WalletSyncFailure('$what: ${e.runtimeType}')));
    }

    return source.transform(
      StreamTransformer<T, Result<T, WalletFailure>>.fromHandlers(
        handleData: (event, sink) => sink.add(Ok(event)),
        handleError: (error, stackTrace, sink) =>
            sink.add(Err(WalletSyncFailure('$what: ${error.runtimeType}'))),
      ),
    );
  }
}
