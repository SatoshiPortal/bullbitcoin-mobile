import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/sp_failure_mapping.dart';
import 'package:bb_mobile/features/send/domain/sp_send_wallet.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_sp_network_for_send_usecase.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';

class RefreshSpWalletForSendUsecase {
  final SpFacade _spFacade;
  final GetSpNetworkForSendUsecase _getSpNetworkForSendUsecase;

  RefreshSpWalletForSendUsecase(
    this._spFacade,
    this._getSpNetworkForSendUsecase,
  );

  /// The SP balance and network the send flow spends from, or null when SP is
  /// not set up.
  Future<Result<SpSendWallet?, SendFailure>> execute() async {
    final refreshed = (await _spFacade.refresh()).mapErr(
      (failure) =>
          failure.toSendFailure() ?? SendUnexpectedFailure(failure.logMessage),
    );
    switch (refreshed) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final spWallet):
        if (spWallet == null) return const Ok(null);
        // Never guessed: an unreadable network is forwarded, so the send flow
        // fails closed instead of describing a test wallet as a mainnet one.
        // A session is live by here (the refresh above established it), so this
        // is a genuine read failure rather than a cold-start unknown.
        final Network network;
        switch (_getSpNetworkForSendUsecase.execute()) {
          case Ok(:final value):
            network = value;
          case Err(:final failure):
            return Err(failure);
        }
        return Ok(
          SpSendWallet(
            balanceSat: spWallet.balance.totalUnifiedSat.value,
            network: network,
          ),
        );
    }
  }
}
