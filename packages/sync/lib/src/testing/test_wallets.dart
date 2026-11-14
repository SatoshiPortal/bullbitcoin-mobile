import 'dart:async';
import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';

import '../data/read/wallet_frame_mapper.dart';
import '../data/wallet_projections.dart';
import '../domain/ports/wallet_revision_reader_port.dart';
import '../domain/sync_failure.dart';
import '../domain/wallet_key.dart';
import '../domain/wallet_revision.dart';
import '../domain/wallet_values.dart';
import '../public/sync.dart';

/// A loaded wallet publishing the given values at revision 0.
Future<Wallet> testWallet({
  required WalletKey key,
  Balances? balances,
  List<Coin> coins = const [],
  List<ChainTransaction> transactions = const [],
  AddressBook? addresses,
  List<Uint8List> ownedScripts = const [],
  List<Outpoint> ownedOutpoints = const [],
  bool stale = false,
}) {
  final revision = WalletRevision(key: key, generation: 0, revision: 0);
  return _loaded(
    key,
    (_) async => WalletFrame(
      revision: revision,
      stale: stale,
      balances:
          balances ??
          Balances(
            confirmedSat: BigInt.zero,
            immatureSat: BigInt.zero,
            trustedPendingSat: BigInt.zero,
            untrustedPendingSat: BigInt.zero,
            spendableSat: BigInt.zero,
            totalSat: BigInt.zero,
          ),
      coins: CoinList(coins),
      transactions: ChainTransactionList(transactions),
      addresses:
          addresses ??
          AddressBook(
            receiveIndex: -1,
            changeIndex: -1,
            receive: const [],
            change: const [],
          ),
      ownership: OwnershipIndex(
        revision: revision,
        scripts: ownedScripts,
        outpoints: ownedOutpoints,
      ),
    ),
  );
}

/// A loaded wallet mapped from a `bdk.Wallet` or `lwk.Wallet` the test built,
/// with the production mapper. The test keeps ownership of [native].
Future<Wallet> testWalletFromNative(Object native, {required WalletKey key}) {
  final revision = WalletRevision(key: key, generation: 0, revision: 0);
  return _loaded(key, (_) async {
    return switch (native) {
      final bdk.Wallet wallet => bitcoinFrame(wallet, revision, stale: false),
      final lwk.Wallet wallet => await liquidFrame(
        wallet,
        revision,
        stale: false,
      ),
      _ => throw ArgumentError('Not a native wallet: ${native.runtimeType}'),
    };
  }, derive: native);
}

Future<Wallet> _loaded(
  WalletKey key,
  Future<WalletFrame> Function(WalletKey) frame, {
  Object? derive,
}) async {
  final projections = WalletProjections(
    revisions: _Revisions(key),
    changes: const Stream.empty(),
    source: _Source(frame, derive),
  );
  final wallet = walletOver(projections, key, 0);
  switch (await wallet.load()) {
    case Ok():
      return wallet;
    case Err(:final failure):
      throw StateError('Test wallet failed to load: ${failure.logCode}');
  }
}

final class _Revisions implements WalletRevisionReaderPort {
  final WalletRevisionState _state;

  _Revisions(WalletKey key)
    : _state = WalletRevisionState(
        stamp: WalletRevision(key: key, generation: 0, revision: 0),
        lifecycle: WalletLifecycle.active,
        initializedSchema: 1,
      );

  @override
  Future<Result<WalletRevisionState, SyncFailure>> read(WalletKey key) async =>
      Ok(_state);

  @override
  Stream<WalletRevisionState> watch(WalletKey key) => const Stream.empty();
}

final class _Source implements FrameSource {
  final Future<WalletFrame> Function(WalletKey) _frame;
  final Object? _native;

  _Source(this._frame, this._native);

  @override
  Future<Result<WalletFrame, SyncFailure>> load(
    WalletKey key,
    WalletFrame? current,
  ) async => Ok(current ?? await _frame(key));

  @override
  Future<Result<DerivedAddress, SyncFailure>> derive(
    WalletKey key,
    Keychain keychain,
    int index,
  ) async => switch (_native) {
    final bdk.Wallet wallet => Ok(bitcoinAddress(wallet, keychain, index)),
    final lwk.Wallet wallet => Ok(await liquidAddress(wallet, index)),
    _ => const Err(SyncNotFoundFailure()),
  };
}
