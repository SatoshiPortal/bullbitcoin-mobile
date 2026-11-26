import 'dart:math';

import 'package:bull_logger/bull_logger.dart';
import 'package:labels/labels.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

import '../domain/address_view_failure.dart';
import '../domain/wallet_address.dart';
import '../domain/wallet_address_repository.dart';

final class SyncAddressRepository implements WalletAddressRepository {
  final Labels _labels;
  final Future<Result<Wallet, SyncFailure>> Function(WalletKey) _loadWallet;
  final Future<Result<({String address, int index}), SyncFailure>> Function(
    WalletKey, {
    bool advance,
  })
  _receive;
  final Future<Result<int?, SyncFailure>> Function(WalletKey) _issuedIndex;

  const SyncAddressRepository({
    required this._labels,
    required this._loadWallet,
    required this._receive,
    required this._issuedIndex,
  });

  @override
  Future<Result<WalletAddress, AddressViewFailure>> at(
    WalletKey key,
    int index,
  ) async {
    switch (await _loadWallet(key)) {
      case Err(:final failure):
        return Err(_unavailable(failure));
      case Ok(:final value):
        return switch (await _derive(value, key, index, Keychain.external)) {
          Ok(:final value) => Ok(await attachLabels(value)),
          Err(:final failure) => Err(failure),
        };
    }
  }

  @override
  Future<Result<WalletAddress, AddressViewFailure>> receive(
    WalletKey key, {
    required bool advance,
  }) async {
    // A reconciled busy write can advance the durable high-water mark.
    // Retry native admission only, never validation or labels after issuance.
    for (var attempt = 0; ; attempt++) {
      switch (await _receive(key, advance: advance)) {
        case Ok(value: final issued):
          if (attempt > 0) {
            log.fine('Receive writer recovered retries=$attempt');
          }
          if (await validateAddress(issued.address, key.network) case Err()) {
            return const Err(AddressViewInvalidAddressFailure());
          }
          try {
            return Ok(
              await attachLabels(_address(key, issued.index, issued.address)),
            );
          } on Exception catch (error) {
            return Err(
              AddressViewAddressesUnavailableFailure(
                error.runtimeType.toString(),
              ),
            );
          }
        case Err(failure: SyncBusyFailure()):
          if (attempt == 4) {
            log.warning('Receive address failed reason=busy attempts=5');
            return const Err(AddressViewWriterBusyFailure());
          }
          if (attempt == 0) {
            log.warning('Receive writer busy retry scheduled');
          }
          await Future<void>.delayed(
            Duration(milliseconds: 250 * (attempt + 1)),
          );
        case Err(:final failure):
          return Err(_unavailable(failure));
      }
    }
  }

  @override
  Future<Result<List<WalletAddress>, AddressViewFailure>> list(
    WalletKey key, {
    required bool change,
    int? limit,
    int? fromIndex,
  }) async {
    int? issued;
    if (change) {
      // Liquid does not expose change history.
      if (key.network is! BitcoinNetwork) return const Ok([]);
    } else {
      switch (await _issuedIndex(key)) {
        case Ok(:final value):
          issued = value;
        case Err(:final failure):
          return Err(_unavailable(failure));
      }
    }
    if (fromIndex != null && fromIndex < 0) return const Ok([]);

    final Wallet wallet;
    switch (await _loadWallet(key)) {
      case Ok(:final value):
        wallet = value;
      case Err(:final failure):
        return Err(_unavailable(failure));
    }

    final int from;
    if (fromIndex != null) {
      from = fromIndex;
    } else {
      switch (wallet.addresses.book.now.latest) {
        case Ok(:final value):
          final index = change
              ? value.changeIndex
              : max(issued ?? -1, value.receiveIndex);
          if (index == null) {
            return Err(_unavailable(const SyncUnsupportedNetworkFailure()));
          }
          from = index;
        case Err(:final failure):
          return Err(_unavailable(failure));
      }
    }
    if (from < 0) return const Ok([]);
    final to = limit == null ? 0 : max(from - limit + 1, 0);
    final step = from <= to ? 1 : -1;
    final keychain = change ? Keychain.internal : Keychain.external;
    final projected = await Future.wait([
      for (var offset = 0; offset <= (to - from).abs(); offset++)
        _derive(wallet, key, from + offset * step, keychain),
    ]);

    final addresses = <WalletAddress>[];
    for (final result in projected) {
      switch (result) {
        case Ok(:final value):
          addresses.add(value);
        case Err(:final failure):
          return Err(failure);
      }
    }
    switch (wallet.addresses.usage()) {
      case Ok(:final value):
        final enriched = <WalletAddress>[];
        for (final address in addresses) {
          final usage = value[address.address];
          enriched.add(
            await attachLabels(
              address.copyWith(
                balanceSat: usage?.balanceSat.toInt() ?? 0,
                nrOfTransactions: usage?.transactionCount ?? 0,
                updatedAt: DateTime.now(),
              ),
            ),
          );
        }
        return Ok(enriched);
      case Err(:final failure):
        return Err(_unavailable(failure));
    }
  }

  @override
  Future<WalletAddress> attachLabels(WalletAddress address) async {
    final labels = (await _labels.fetch(reference: address.address))
        .fold((labels) => labels, (_) => const <Label>[]);
    return address.copyWith(labels: labels);
  }

  Future<Result<WalletAddress, AddressViewFailure>> _derive(
    Wallet wallet,
    WalletKey key,
    int index,
    Keychain keychain,
  ) async {
    final projected = await wallet.addresses
        .at(index, keychain: keychain)
        .watch()
        .firstWhere(
          (value) => value.status != ValueStatus.notLoaded,
          orElse: () => const WalletAddressAt.closed(),
        );
    return projected.latest
        .map((value) => _address(key, index, value.address))
        .mapErr(_unavailable);
  }

  WalletAddress _address(WalletKey key, int index, String address) {
    final now = DateTime.now();
    return WalletAddress(
      walletId: key.id,
      index: index,
      address: address,
      createdAt: now,
      updatedAt: now,
    );
  }

  static AddressViewAddressesUnavailableFailure _unavailable(
    SyncFailure failure,
  ) => AddressViewAddressesUnavailableFailure(failure.logCode);
}
