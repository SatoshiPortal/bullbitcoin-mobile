import 'dart:async';

import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/services/payjoin_service.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';

class PayjoinServiceImpl implements PayjoinService {
  final PayjoinRepository _payjoin;
  final ElectrumServerRepository _electrumServer;
  final SettingsRepository _settings;
  final WalletManagerService _walletManager;
  late StreamController<Payjoin> _payjoinStreamController;

  PayjoinServiceImpl({
    required PayjoinRepository payjoinRepository,
    required ElectrumServerRepository electrumServerRepository,
    required SettingsRepository settingsRepository,
    required WalletManagerService walletManagerService,
  })  : _payjoin = payjoinRepository,
        _electrumServer = electrumServerRepository,
        _settings = settingsRepository,
        _walletManager = walletManagerService {
    // Setup a stream controller to broadcast payjoin events
    _payjoinStreamController = StreamController<Payjoin>.broadcast();
    // Listen to payjoin events from the repository and process them
    _payjoin.requestsForReceivers.listen(
      (payjoin) => _processPayjoinRequest(
        payjoin,
      ),
    );
    _payjoin.proposalsForSenders
        .listen((payjoin) => _processPayjoinProposal(payjoin));
  }

  @override
  Stream<Payjoin> get payjoins =>
      _payjoinStreamController.stream.asBroadcastStream();

  @override
  Future<Payjoin> createPayjoinReceiver({
    required String walletId,
    required String address,
    required bool isTestnet,
    required BigInt maxFeeRateSatPerVb,
    int? expireAfterSec,
  }) async {
    final payjoin = await _payjoin.createPayjoinReceiver(
      walletId: walletId,
      address: address,
      isTestnet: isTestnet,
      maxFeeRateSatPerVb: maxFeeRateSatPerVb,
      expireAfterSec: expireAfterSec,
    );

    _payjoinStreamController.add(payjoin);

    return payjoin;
  }

  @override
  Future<Payjoin> createPayjoinSender({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
  }) async {
    final payjoin = await _payjoin.createPayjoinSender(
      walletId: walletId,
      bip21: bip21,
      originalPsbt: originalPsbt,
      networkFeesSatPerVb: networkFeesSatPerVb,
    );

    _payjoinStreamController.add(payjoin);

    return payjoin;
  }

  Future<void> _processPayjoinRequest(PayjoinReceiver payjoin) async {
    final walletId = payjoin.walletId;
    final unspentUtxos =
        await _walletManager.getUnspentUtxos(walletId: walletId);

    final processedPayjoin = await _payjoin.processRequest(
      id: payjoin.id,
      hasOwnedInputs: (inputScript) => _walletManager.isOwnedByWallet(
        walletId: walletId,
        scriptBytes: inputScript,
      ),
      hasReceiverOutput: (outputScript) => _walletManager.isOwnedByWallet(
        walletId: walletId,
        scriptBytes: outputScript,
      ),
      unspentUtxos: unspentUtxos,
      processPsbt: (psbt) =>
          _walletManager.signPsbt(walletId: walletId, psbt: psbt),
    );

    _payjoinStreamController.add(processedPayjoin);
  }

  Future<void> _processPayjoinProposal(PayjoinSender payjoin) async {
    final walletId = payjoin.walletId;
    final proposalPsbt = payjoin.proposalPsbt;
    final environment = await _settings.getEnvironment();
    final network = Network.fromEnvironment(
        isTestnet: environment.isTestnet, isLiquid: false);
    final electrumServer =
        await _electrumServer.getElectrumServer(network: network);

    if (proposalPsbt == null) {
      return;
    }

    final finalizedPsbt = await _walletManager.signPsbt(
      walletId: walletId,
      psbt: proposalPsbt,
    );

    final processedPayjoin = await _payjoin.broadcastPsbt(
      payjoinId: payjoin.id,
      finalizedPsbt: finalizedPsbt,
      electrumServer: electrumServer,
    );

    _payjoinStreamController.add(processedPayjoin);
  }
}
