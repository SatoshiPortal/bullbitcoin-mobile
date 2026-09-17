import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/network_x.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok;
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';

class LiquidWalletRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final Secrets _secrets;
  final LwkWalletDatasource _lwkWallet;

  LiquidWalletRepository({
    required this._walletMetadataDatasource,
    required this._secrets,
    required LwkWalletDatasource lwkWalletDatasource,
  }) : _lwkWallet = lwkWalletDatasource;

  Future<String> buildPset({
    required String walletId,
    required String address,
    int? amountSat,
    required RelativeFee feeRate,
    bool? drain,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }

    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.id,
    );
    final pset = await _lwkWallet.buildPset(
      wallet: wallet,
      address: address,
      amountSat: amountSat,
      feeRate: feeRate,
      drain: drain ?? false,
    );

    return pset;
  }

  Future<(int, int)> getPsetSizeAndAbsoluteFees({required String pset}) async {
    final (size, fees) = await _lwkWallet.decodeAbsoluteFeesFromPset(pset);
    return (size, fees);
  }

  Future<int> getLbtcUtxoCount({required String walletId}) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }
    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.id,
    );
    return _lwkWallet.getLbtcUtxoCount(wallet: wallet);
  }

  Future<List<String>> consolidate({
    required String walletId,
    required RelativeFee feeRate,
    required int highUtxoThreshold,
    required int maximumInputs,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }
    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.id,
    );
    return _lwkWallet.consolidate(
      wallet: wallet,
      feeRate: feeRate,
      highUtxoThreshold: highUtxoThreshold,
      maximumInputs: maximumInputs,
    );
  }

  Future<String> signPset({
    required String pset,
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }

    // The mnemonic stays inside `secrets`: it builds the lwk wallet in a
    // scratch directory it removes afterwards, signs, and returns only
    // the signed PSET.
    final secret = switch (await _secrets.fetch(
      Fingerprint(metadata.masterFingerprint),
    )) {
      Ok(:final value) => value,
      Err(:final failure) => throw Exception('No secret for wallet: $failure'),
    };

    return switch (await secret.sign.pset(
      pset,
      network: metadata.network.liquid,
    )) {
      Ok(:final value) => value,
      Err(:final failure) => throw Exception('Failed to sign PSET: $failure'),
    };
  }

  Future<int> getAmountSentToAddress({
    required String pset,
    required String address,
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }
    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.id,
    );
    return await _lwkWallet.getAmountSentToAddress(
      pset,
      address,
      wallet: wallet,
    );
  }
}
