import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:primitives/primitives.dart' show Err;
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'dart:math';
import 'package:bull_logger/bull_logger.dart';
import 'package:sync/read.dart';
import 'package:sync/sync.dart';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';

import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet/data/bdk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/lwk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_address_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_address_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';

class WalletAddressRepository {
  final WalletNativeLifecycle? _native;
  final WalletMetadataDatasource _walletMetadataDatasource;
  final BdkWalletDatasource _bdkWallet;
  final LwkWalletDatasource _lwkWallet;
  final LabelsFacade _labelsFacade;

  WalletAddressRepository({
    this._native,
    required this._walletMetadataDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
    required this._labelsFacade,
  }) : _bdkWallet = bdkWalletDatasource,
       _lwkWallet = lwkWalletDatasource;

  Future<WalletAddress> getLastRevealedReceiveAddress({
    required String walletId,
  }) => _receive(walletId, advance: false);

  Future<WalletAddress> generateNewReceiveAddress({required String walletId}) =>
      _receive(walletId, advance: true);

  Future<WalletAddress> _receive(
    String walletId, {
    required bool advance,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) throw WalletError.notFound(walletId);
    final native = _native;
    if (native == null) throw StateError('Native writer is not configured');
    // Retry only native admission, never label lookup after an issued address.
    // Busy may follow a reconciled write: an advance can skip an index, but
    // the writer's durable high-water mark prevents address reuse.
    late ({String address, int index}) issued;
    for (var attempt = 0; ; attempt++) {
      try {
        issued = await native.receive(metadata, advance: advance);
        if (attempt > 0) {
          log.fine('Receive writer recovered retries=$attempt');
        }
        break;
      } on WalletSnapshotException catch (error) {
        if (error.failure is! TransactionSyncBusyFailure) rethrow;
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
    final labels = await _labelsFacade.fetchByReference(issued.address);
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

  Future<List<WalletAddress>> getGeneratedReceiveAddresses(
    String walletId, {
    int? limit,
    int? fromIndex,
  }) async {
    // Fetch wallet metadata and history in parallel
    final walletMetadata = await _walletMetadataDatasource.fetch(walletId);

    if (walletMetadata == null) throw WalletError.notFound(walletId);

    final walletModel = WalletModel.fromMetadata(walletMetadata);
    final isBdkWallet = walletModel is PublicBdkWalletModel;

    final issued = await _native?.issuedReceiveIndex(walletMetadata);
    final from =
        fromIndex ??
        max(
          issued ?? -1,
          isBdkWallet
              ? await _bdkWallet.getLastRevealedAddressIndex(
                  wallet: walletModel,
                )
              : await _lwkWallet.getLastUnusedAddressIndex(wallet: walletModel),
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
          walletModel: walletModel,
          walletId: walletId,
          isBdkWallet: isBdkWallet,
          isChange: false,
        );
      }),
    );

    // Enrich addresses with balance and transaction data in parallel
    return await _enrichAddresses(
      addresses: addresses,
      walletModel: walletModel,
      isBdkWallet: isBdkWallet,
    );
  }

  Future<WalletAddressModel> _generateAddressModel({
    required int index,
    required WalletModel walletModel,
    required String walletId,
    required bool isBdkWallet,
    required bool isChange,
  }) async {
    final address = isBdkWallet
        ? await _bdkWallet.getAddressByIndex(
            index,
            wallet: walletModel,
            isChange: isChange,
          )
        : (await _lwkWallet.getAddressByIndex(
            index,
            wallet: walletModel,
          )).confidential;

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
    required WalletModel walletModel,
    required bool isBdkWallet,
  }) async {
    final allTransactions = isBdkWallet
        ? await _bdkWallet.getTransactions(wallet: walletModel)
        : await _lwkWallet.getTransactions(wallet: walletModel);
    final addressBalances = isBdkWallet
        ? await _bdkWallet.getAddressBalancesSat(wallet: walletModel)
        : await _lwkWallet.getAddressBalancesSat(wallet: walletModel);

    final enrichedAddresses = await Future.wait(
      addresses.map((addressModel) async {
        // Fetch balance and transactions in parallel
        final balanceSat = addressBalances[addressModel.address] ?? BigInt.zero;

        final transactions = allTransactions
            .where(
              (tx) => tx.outputs.any(
                (element) => element.address == addressModel.address,
              ),
            )
            .toList();

        return addressModel.copyWith(
          balanceSat: balanceSat.toInt(),
          nrOfTransactions: transactions.length,
          updatedAt: DateTime.now(),
        );
      }),
    );

    final result = <WalletAddress>[];
    for (var model in enrichedAddresses) {
      final labels = await _labelsFacade.fetchByReference(model.address);
      final entity = WalletAddressMapper.toEntity(model, labels: labels);
      result.add(entity);
    }

    return result;
  }

  Future<List<WalletAddress>> getUsedChangeAddresses(
    String walletId, {
    int? limit,
    int? fromIndex,
    required bool descending,
  }) async {
    // Fetch wallet metadata and history in parallel
    final walletMetadata = await _walletMetadataDatasource.fetch(walletId);

    if (walletMetadata == null) throw WalletError.notFound(walletId);

    final walletModel = WalletModel.fromMetadata(walletMetadata);
    final isBdkWallet = walletModel is PublicBdkWalletModel;

    if (!isBdkWallet) {
      // LWK currently doesn't support fetching
      // change addresses separately, so we return an empty list here.
      return [];
    }

    final from =
        fromIndex ??
        await _bdkWallet.getLastRevealedAddressIndex(
          wallet: walletModel,
          isChange: true,
        );
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
          walletModel: walletModel,
          walletId: walletId,
          isBdkWallet: isBdkWallet,
          isChange: true,
        );
      }),
    );

    // Enrich addresses with balance and transaction data in parallel
    return await _enrichAddresses(
      addresses: addresses,
      walletModel: walletModel,
      isBdkWallet: isBdkWallet,
    );
  }

  Future<WalletAddress> getAddressAtIndex({
    required String walletId,
    required int index,
    required bool isChange,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw WalletError.notFound(walletId);
    }

    final walletModel = WalletModel.fromMetadata(metadata);
    String address;

    if (walletModel is PublicBdkWalletModel) {
      address = await _bdkWallet.getAddressByIndex(
        index,
        wallet: walletModel,
        isChange: isChange,
      );
    } else {
      final addressInfo = await _lwkWallet.getAddressByIndex(
        index,
        wallet: walletModel,
      );
      address = addressInfo.confidential;
    }

    final walletAddressModel = WalletAddressModel(
      walletId: walletId,
      index: index,
      address: address,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final labels = await _labelsFacade.fetchByReference(address);
    return WalletAddressMapper.toEntity(walletAddressModel, labels: labels);
  }
}
