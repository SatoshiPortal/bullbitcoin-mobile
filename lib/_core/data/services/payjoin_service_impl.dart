import 'dart:async';

import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/_core/domain/services/payjoin_service.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';

class PayjoinServiceImpl implements PayjoinService {
  final PayjoinRepository _payjoin;
  final WalletManagerService _walletManager;
  late StreamController<Payjoin> _payjoinStreamController;

  PayjoinServiceImpl({
    required PayjoinRepository payjoinRepository,
    required WalletManagerService walletManagerService,
  })  : _payjoin = payjoinRepository,
        _walletManager = walletManagerService {
    // Setup a stream controller to broadcast payjoin events
    _payjoinStreamController = StreamController<Payjoin>.broadcast();
    // Listen to payjoin events from the repository and process them
    _payjoin.requestedPayjoins.listen(
      (payjoin) => _processPayjoinRequest(
        payjoin,
      ),
    );
    _payjoin.sentProposals
        .listen((payjoin) => _processPayjoinProposal(payjoin));
  }

  @override
  // TODO: implement payjoins
  Stream<Payjoin> get payjoins =>
      _payjoinStreamController.stream.asBroadcastStream();

  @override
  Future<Payjoin> createPayjoinReceive() {
    // TODO: implement createPayjoinReceive
    throw UnimplementedError();
  }

  @override
  Future<Payjoin> createPayjoinSend() {
    // TODO: implement createPayjoinSend
    throw UnimplementedError();
  }

  Future<void> _processPayjoinRequest(ReceivePayjoin payjoin) async {}
  Future<void> _processPayjoinProposal(SendPayjoin payjoin) async {}
}
