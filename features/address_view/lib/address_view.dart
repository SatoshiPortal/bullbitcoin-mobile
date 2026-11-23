import 'package:labels/labels.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;

import 'src/data/sync_address_repository.dart';
import 'src/domain/address_view_failure.dart';
import 'src/domain/resolve_address_wallet_usecase.dart';
import 'src/domain/wallet_address.dart';
import 'src/domain/wallet_address_repository.dart';

export 'src/domain/address_view_failure.dart';
export 'src/domain/wallet_address.dart';
export 'src/ui/address_view_navigation.dart';
export 'src/ui/address_viewer.dart' show AddressViewer;

/// Wallet address reads and presentation.
abstract interface class AddressView {
  factory AddressView.open({
    required Labels labels,
    required WalletInventory inventory,
    required WalletNativeLifecycle native,
    required Future<Result<Wallet, SyncFailure>> Function(WalletKey) loadWallet,
  }) => _AddressView(
    ResolveAddressWalletUsecase(inventory),
    SyncAddressRepository(
      labels: labels,
      loadWallet: loadWallet,
      receive: native.receive,
      issuedIndex: native.issuedReceiveIndex,
    ),
  );

  /// Reads an external address without issuing it or requesting a sync.
  @useResult
  Future<Result<WalletAddress, AddressViewFailure>> at({
    required String walletId,
    required int index,
  });

  /// Reads or advances the wallet's durable receive index through Sync.
  @useResult
  Future<Result<WalletAddress, AddressViewFailure>> receiveAddress({
    required String walletId,
    bool advance = false,
  });

  /// Reads cached address history without issuing an address or syncing.
  @useResult
  Future<Result<List<WalletAddress>, AddressViewFailure>> list({
    required String walletId,
    bool change = false,
    int? limit,
    int? fromIndex,
  });

  @useResult
  Future<Result<bool, AddressViewFailure>> isLiquid(String walletId);

  /// Replaces the labels, leaving the address usable if label storage fails.
  Future<WalletAddress> attachLabels(WalletAddress address);
}

final class _AddressView implements AddressView {
  final ResolveAddressWalletUsecase _resolveWallet;
  final WalletAddressRepository _addresses;

  _AddressView(this._resolveWallet, this._addresses);

  @override
  Future<Result<WalletAddress, AddressViewFailure>> at({
    required String walletId,
    required int index,
  }) async {
    if (index < 0) return const Err(AddressViewAddressesUnavailableFailure());
    return switch (await _resolveWallet.execute(walletId)) {
      Ok(:final value) => _addresses.at(value, index),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<WalletAddress, AddressViewFailure>> receiveAddress({
    required String walletId,
    bool advance = false,
  }) async {
    return switch (await _resolveWallet.execute(walletId)) {
      Ok(:final value) => _addresses.receive(value, advance: advance),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<List<WalletAddress>, AddressViewFailure>> list({
    required String walletId,
    bool change = false,
    int? limit,
    int? fromIndex,
  }) async {
    return switch (await _resolveWallet.execute(walletId)) {
      Ok(:final value) => _addresses.list(
        value,
        change: change,
        limit: limit,
        fromIndex: fromIndex,
      ),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<bool, AddressViewFailure>> isLiquid(String walletId) async =>
      (await _resolveWallet.execute(walletId))
          .map((key) => key.network is LiquidNetwork);

  @override
  Future<WalletAddress> attachLabels(WalletAddress address) =>
      _addresses.attachLabels(address);
}
