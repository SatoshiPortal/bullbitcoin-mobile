import 'dart:typed_data';

import 'package:bb_mobile/wallet_signing_adapters.dart';
import 'package:secrets/secrets.dart';
import 'package:wallet/wallet.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart'
    show WalletSourceKey, WalletSourceOperationCoordinator;

final class PayjoinWalletAdapter implements PayjoinWalletPort {
  final Secrets _secrets;
  final BdkWalletDatasource _wallet;
  final WalletCatalogPort _metadata;
  final WalletSourceOperationCoordinator _coordinator;

  const PayjoinWalletAdapter(
    this._secrets,
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
      return _signPsbt(psbt, metadata, network);
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
      // Checked before the proposal is built: a wallet without a local mnemonic fails here, as it did when the session held a private wallet.
      await _loadMnemonicSecret(metadata);
      final session = _PayjoinWalletSession(
        spendable,
        ownsOutpoint,
        ownsOutput,
        (psbt) => _signPsbt(psbt, metadata, network),
      );
      try {
        return await operation(session);
      } finally {
        session.close();
      }
    });
  }

  /// Signs [psbt] inside `secrets`; the caller already holds the wallet source session.
  Future<String> _signPsbt(
    String psbt,
    WalletMetadata metadata,
    BitcoinNetwork network,
  ) async {
    final secret = await _loadMnemonicSecret(metadata);
    // The receiver's own input in a payjoin proposal carries no derivation path, and the package signs only what it can derive: the watch-only view adds the paths first.
    final annotated = await _wallet.addOwnDerivations(
      psbt: psbt,
      wallet: WalletModel.fromMetadata(metadata),
    );
    return _unwrap(
      await secret.sign.psbt(
        annotated,
        network: network,
        scriptType: secretScriptTypeOf(metadata.scriptType),
      ),
    );
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

  Future<WalletMetadata> _loadMetadata(
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

  Future<Secret> _loadMnemonicSecret(WalletMetadata metadata) async {
    final fingerprint = seedFingerprintOf(metadata);
    if (fingerprint == null) {
      throw Exception('No secret for wallet: not a seed-derived wallet');
    }
    final secret = _unwrap(await _secrets.fetch(fingerprint));
    if (!secret.info.isMnemonic) {
      throw StateError('Payjoin requires a local mnemonic wallet');
    }
    return secret;
  }

  /// This adapter already reports every problem by throwing — the port has no failure type — so a package failure becomes a `StateError` naming its kind, never its message.
  static T _unwrap<T>(Result<T, SecretFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError('secrets: ${failure.runtimeType}'),
  };
}

final class _PayjoinWalletSession implements PayjoinWalletSession {
  List<PayjoinUtxo>? _utxos;
  bool Function(Outpoint)? _ownsOutpoint;
  bool Function(Uint8List)? _hasReceiverOutput;
  Future<String> Function(String)? _signPsbt;

  _PayjoinWalletSession(
    this._utxos,
    this._ownsOutpoint,
    this._hasReceiverOutput,
    this._signPsbt,
  );

  /// The session's capability, or a [StateError] once [close] has run.
  T _open<T extends Object>(T? capability) {
    if (capability == null) {
      throw StateError('Payjoin wallet session is closed');
    }
    return capability;
  }

  @override
  List<PayjoinUtxo> get spendableUtxos => _open(_utxos);

  @override
  bool ownsOutpoint(Outpoint outpoint) => _open(_ownsOutpoint)(outpoint);

  @override
  bool hasReceiverOutput(Uint8List script) => _open(_hasReceiverOutput)(script);

  @override
  Future<String> signPsbt(String psbt) => _open(_signPsbt)(psbt);

  void close() {
    _utxos = null;
    _ownsOutpoint = null;
    _hasReceiverOutput = null;
    _signPsbt = null;
  }
}
