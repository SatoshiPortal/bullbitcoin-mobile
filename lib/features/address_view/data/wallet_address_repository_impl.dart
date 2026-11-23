import '../domain/repositories/wallet_address_repository.dart';

import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:primitives/primitives.dart' show Err, Result;
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart'
    show InvalidWalletAddressException;

import 'dart:math';

import 'package:bull_logger/bull_logger.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;

import 'package:labels/labels.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/address_view/data/mappers/wallet_address_mapper.dart';
import 'package:bb_mobile/features/address_view/data/models/wallet_address_model.dart';
import 'package:bb_mobile/features/address_view/domain/wallet_address.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_error.dart';

class WalletAddressRepositoryImpl implements WalletAddressRepository {
  final WalletNativeLifecycle _native;
  final WalletRegistrations _walletRegistrations;
  final Future<Result<Wallet, SyncFailure>> Function(WalletKey) _loadWallet;
  final Labels _labelsFacade;

  WalletAddressRepositoryImpl({
    required this._native,
    required this._walletRegistrations,
    required this._loadWallet,
    required this._labelsFacade,
  });

  @override
  Future<WalletAddress> getLastRevealedReceiveAddress({
    required String walletId,
  }) => _receive(walletId, advance: false);

  @override
  Future<WalletAddress> generateNewReceiveAddress({required String walletId}) =>
      _receive(walletId, advance: true);

  Future<WalletAddress> _receive(
    String walletId, {
    required bool advance,
  }) async {
    final metadata = await _walletRegistrations.fetch(walletId);
    if (metadata == null) throw WalletNotFoundException(walletId);
    // Retry only native admission, never label lookup after an issued address.
    // Busy may follow a reconciled write: an advance can skip an index, but
    // the writer's durable high-water mark prevents address reuse.
    late ({String address, int index}) issued;
    for (var attempt = 0; ; attempt++) {
      try {
        issued = WalletSyncBinding.value(
          await _native.receive(
            WalletSyncBinding.keyFromMetadata(metadata),
            advance: advance,
          ),
        );
        if (attempt > 0) {
          log.fine('Receive writer recovered retries=$attempt');
        }
        break;
      } on WalletSnapshotException catch (error) {
        if (error.failure is! SyncBusyFailure) rethrow;
        if (attempt == 4) {
          log.warning('Receive address failed reason=busy attempts=5');
          rethrow;
        }
        if (attempt == 0) {
          log.warning('Receive writer busy retry scheduled');
        }
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }
    if (await validateAddress(issued.address, metadata.network.shared)
        case Err()) {
      throw const InvalidWalletAddressException();
    }
    final labels = (await _labelsFacade.fetch(reference: issued.address))
        .fold((labels) => labels, (_) => const <Label>[]);
    return WalletAddressMapper.toEntity(
      WalletAddressModel(
        walletId: walletId,
        index: issued.index,
        address: issued.address,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      labels: labels,
    );
  }

  @override
  Future<List<WalletAddress>> getGeneratedReceiveAddresses(
    String walletId, {
    int? limit,
    int? fromIndex,
  }) async {
    final walletMetadata = await _walletRegistrations.fetch(walletId);

    if (walletMetadata == null) throw WalletNotFoundException(walletId);

    final key = WalletKey(
      id: walletMetadata.id,
      network: walletMetadata.network.shared,
    );
    final issued = WalletSyncBinding.value(
      await _native.issuedReceiveIndex(
        WalletSyncBinding.keyFromMetadata(walletMetadata),
      ),
    );
    if (fromIndex != null && fromIndex < 0) return const [];
    final wallet = WalletSyncBinding.value(await _loadWallet(key));
    final from =
        fromIndex ??
        max(
          issued ?? -1,
          WalletSyncBinding.value(wallet.addresses.book.now.latest)
              .receiveIndex,
        );
    if (from < 0) return const [];
    final to = limit != null ? max(from - limit + 1, 0) : 0;

    // This is already in case we want to support both ascending and descending in the future
    final step = from <= to ? 1 : -1;
    final indexes = List.generate(
      (to - from).abs() + 1,
      (i) => from + i * step,
    );

    final addresses = await Future.wait(
      indexes.map((index) async {
        return await _generateAddressModel(
          index: index,
          wallet: wallet,
          walletId: walletId,
          isChange: false,
        );
      }),
    );

    return await _enrichAddresses(addresses: addresses, wallet: wallet);
  }

  Future<String> _addressAt(
    Wallet wallet,
    int index, {
    required bool isChange,
  }) async {
    final value = await wallet.addresses
        .at(index, keychain: isChange ? Keychain.internal : Keychain.external)
        .watch()
        .firstWhere((value) => value.status != ValueStatus.notLoaded);
    return WalletSyncBinding.value(value.latest).address;
  }

  Future<WalletAddressModel> _generateAddressModel({
    required int index,
    required Wallet wallet,
    required String walletId,
    required bool isChange,
  }) async {
    final address = await _addressAt(wallet, index, isChange: isChange);

    return WalletAddressModel(
      walletId: walletId,
      index: index,
      address: address,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<List<WalletAddress>> _enrichAddresses({
    required List<WalletAddressModel> addresses,
    required Wallet wallet,
  }) async {
    final usage = WalletSyncBinding.value(wallet.addresses.usage());
    final result = <WalletAddress>[];
    for (final address in addresses) {
      final stats = usage[address.address];
      final model = address.copyWith(
        balanceSat: stats?.balanceSat.toInt() ?? 0,
        nrOfTransactions: stats?.transactionCount ?? 0,
        updatedAt: DateTime.now(),
      );
      final labels = (await _labelsFacade.fetch(reference: model.address))
          .fold((labels) => labels, (_) => const <Label>[]);
      final entity = WalletAddressMapper.toEntity(model, labels: labels);
      result.add(entity);
    }

    return result;
  }

  @override
  Future<List<WalletAddress>> getUsedChangeAddresses(
    String walletId, {
    int? limit,
    int? fromIndex,
    required bool descending,
  }) async {
    final walletMetadata = await _walletRegistrations.fetch(walletId);

    if (walletMetadata == null) throw WalletNotFoundException(walletId);

    if (!walletMetadata.network.isBitcoin) {
      // LWK currently doesn't support fetching
      // change addresses separately, so we return an empty list here.
      return [];
    }

    if (fromIndex != null && fromIndex < 0) return const [];
    final key = WalletKey(
      id: walletMetadata.id,
      network: walletMetadata.network.shared,
    );
    final wallet = WalletSyncBinding.value(await _loadWallet(key));

    final from =
        fromIndex ??
        WalletSyncBinding.value(wallet.addresses.book.now.latest).changeIndex;
    if (from == null) {
      throw const WalletSnapshotException(SyncUnsupportedNetworkFailure());
    }
    if (from < 0) {
      // No change addresses have been revealed yet, so we return an empty list.
      return [];
    }
    final to = limit != null ? max(from - limit + 1, 0) : 0;

    // This is already in case we want to support both ascending and descending in the future
    final step = from <= to ? 1 : -1;
    final indexes = List.generate(
      (to - from).abs() + 1,
      (i) => from + i * step,
    );

    final addresses = await Future.wait(
      indexes.map((index) async {
        return await _generateAddressModel(
          index: index,
          wallet: wallet,
          walletId: walletId,
          isChange: true,
        );
      }),
    );

    return await _enrichAddresses(addresses: addresses, wallet: wallet);
  }

  @override
  Future<WalletAddress> getAddressAtIndex({
    required String walletId,
    required int index,
    required bool isChange,
  }) async {
    final metadata = await _walletRegistrations.fetch(walletId);

    if (metadata == null) {
      throw WalletNotFoundException(walletId);
    }

    final key = WalletKey(id: metadata.id, network: metadata.network.shared);
    final wallet = WalletSyncBinding.value(await _loadWallet(key));
    final address = await _addressAt(
      wallet,
      index,
      isChange: isChange && metadata.network.isBitcoin,
    );

    final walletAddressModel = WalletAddressModel(
      walletId: walletId,
      index: index,
      address: address,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final labels = (await _labelsFacade.fetch(reference: address))
        .fold((labels) => labels, (_) => const <Label>[]);
    return WalletAddressMapper.toEntity(walletAddressModel, labels: labels);
  }
}
