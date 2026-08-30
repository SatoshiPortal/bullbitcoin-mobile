import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart'
    show WalletSourceKey, WalletSourceOperationCoordinator;

final class PayjoinWalletAdapter implements PayjoinWalletPort {
  final SeedDatasource _seed;
  final BdkWalletDatasource _wallet;
  final WalletMetadataDatasource _metadata;
  final WalletSourceOperationCoordinator _coordinator;

  const PayjoinWalletAdapter(
    this._seed,
    this._wallet,
    this._metadata,
    this._coordinator,
  );

  @override
  Future<String> signPsbt({
    required String walletId,
    required BitcoinNetwork network,
    required String psbt,
  }) async {
    await _loadMetadata(walletId, network);
    return _coordinator.runExclusive(_sourceKey(walletId, network), (_) async {
      final metadata = await _loadMetadata(walletId, network);
      final wallet = await _loadPrivateWalletFromMetadata(metadata, walletId);
      return _wallet.signPsbt(psbt, wallet: wallet);
    });
  }

  @override
  Future<T> withReceiverWallet<T>({
    required String walletId,
    required BitcoinNetwork network,
    required Future<T> Function(PayjoinWalletSession session) operation,
  }) async {
    await _loadMetadata(walletId, network);
    return _coordinator.runExclusive(_sourceKey(walletId, network), (_) async {
      final metadata = await _loadMetadata(walletId, network);
      final publicWallet = WalletModel.fromMetadata(metadata);
      final utxos = await _wallet.getUtxos(wallet: publicWallet);
      final spendable = List<PayjoinUtxo>.unmodifiable(
        utxos.whereType<BitcoinWalletUtxoModel>().map(_toPayjoinUtxo),
      );
      final ownsOutput = await _wallet.createIsMineChecker(
        wallet: publicWallet,
      );
      final ownsOutpoint = await _wallet.createOutpointIsMineChecker(
        wallet: publicWallet,
      );
      final privateWallet = await _loadPrivateWalletFromMetadata(
        metadata,
        walletId,
      );
      return _wallet.withPsbtSigner(
        wallet: privateWallet,
        operation: (processPsbt) async {
          final session = _PayjoinWalletSession(
            spendable,
            ownsOutpoint,
            ownsOutput,
            processPsbt,
          );
          try {
            return await operation(session);
          } finally {
            session.close();
          }
        },
      );
    });
  }

  WalletSourceKey _sourceKey(String walletId, BitcoinNetwork network) =>
      WalletSourceKey(
        walletId,
        'bitcoin',
        network.isMainnet ? 'mainnet' : 'testnet',
      );

  PayjoinUtxo _toPayjoinUtxo(BitcoinWalletUtxoModel utxo) => PayjoinUtxo(
    outpoint: (txId: utxo.txId, vout: utxo.vout),
    value: Sats(utxo.amountSat),
    scriptPubkey: Uint8List.fromList(utxo.scriptPubkey),
    confirmed: utxo.confirmations > 0,
  );

  Future<WalletMetadataModel> _loadMetadata(
    String walletId,
    BitcoinNetwork network,
  ) async {
    final metadata = await _metadata.fetch(walletId);
    if (metadata == null || !metadata.isBitcoin) {
      throw StateError('Bitcoin wallet metadata not found');
    }
    if (metadata.isTestnet == network.isMainnet) {
      throw StateError('Wallet network does not match Payjoin network');
    }
    return metadata;
  }

  Future<PrivateBdkWalletModel> _loadPrivateWalletFromMetadata(
    WalletMetadataModel metadata,
    String walletId,
  ) async {
    final seed = await _seed.get(metadata.masterFingerprint);
    if (seed is! MnemonicSeedModel) {
      throw StateError('Payjoin requires a local mnemonic wallet');
    }
    return WalletModel.privateBdk(
          id: walletId,
          scriptType: metadata.scriptType,
          mnemonic: seed.mnemonicWords.join(' '),
          passphrase: seed.passphrase,
          isTestnet: metadata.isTestnet,
        )
        as PrivateBdkWalletModel;
  }
}

final class _PayjoinWalletSession implements PayjoinWalletSession {
  List<PayjoinUtxo>? _utxos;
  bool Function(Outpoint)? _ownsOutpoint;
  bool Function(Uint8List)? _hasReceiverOutput;
  String Function(String)? _processPsbt;

  _PayjoinWalletSession(
    this._utxos,
    this._ownsOutpoint,
    this._hasReceiverOutput,
    this._processPsbt,
  );

  void _ensureOpen() {
    if (_utxos == null) throw StateError('Payjoin wallet session is closed');
  }

  @override
  List<PayjoinUtxo> get spendableUtxos {
    _ensureOpen();
    return _utxos!;
  }

  @override
  bool ownsOutpoint(Outpoint outpoint) {
    _ensureOpen();
    return _ownsOutpoint!(outpoint);
  }

  @override
  bool hasReceiverOutput(Uint8List script) {
    _ensureOpen();
    return _hasReceiverOutput!(script);
  }

  @override
  String processPsbt(String psbt) {
    _ensureOpen();
    return _processPsbt!(psbt);
  }

  void close() {
    _utxos = null;
    _ownsOutpoint = null;
    _hasReceiverOutput = null;
    _processPsbt = null;
  }
}
