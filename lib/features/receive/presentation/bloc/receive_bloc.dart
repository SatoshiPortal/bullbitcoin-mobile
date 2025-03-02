import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:bb_mobile/core/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_address_use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'receive_bloc.freezed.dart';
part 'receive_event.dart';
part 'receive_state.dart';

class ReceiveBloc extends Bloc<ReceiveEvent, ReceiveState> {
  ReceiveBloc({
    required GetWalletsUseCase getWalletsUseCase,
    required GetReceiveAddressUseCase getReceiveAddressUseCase,
    required CreateReceiveSwapUseCase createReceiveSwapUseCase,
    String?
        selectedWalletId, // TODO: analyze other ways to pass a preselected wallet (like in the ...Started events)
    // TODO: analyze as well if the list of wallets that can be used to select a wallet should be passed to the bloc or if it should be fetched by the bloc itself
  })  : _getWalletsUseCase = getWalletsUseCase,
        _getReceiveAddressUseCase = getReceiveAddressUseCase,
        _createReceiveSwapUseCase = createReceiveSwapUseCase,
        super(ReceiveState(selectedWalletId: selectedWalletId)) {
    on<ReceiveBitcoinStarted>(_onBitcoinStarted);
    on<ReceiveLightningStarted>(_onLightningStarted);
    on<ReceiveLiquidStarted>(_onLiquidStarted);
  }

  final GetWalletsUseCase _getWalletsUseCase;
  final GetReceiveAddressUseCase _getReceiveAddressUseCase;
  final CreateReceiveSwapUseCase _createReceiveSwapUseCase;

  void _onBitcoinStarted(
    ReceiveBitcoinStarted event,
    Emitter<ReceiveState> emit,
  ) {
    // TODO: get the wallet, fiat currency, exchange rate, and bitcoin unit
    // TODO: check where to get the selected wallet id from if none was passed through the constructor (from the event or from the default wallet use case if not present in the event?)
    // TODO: also get the first unused address for the selected wallet
    emit(
      state.copyWith(
        status: ReceiveStatus.inProgress,
        paymentNetwork: ReceivePaymentNetwork.bitcoin,
      ),
    );
  }

  void _onLightningStarted(
    ReceiveLightningStarted event,
    Emitter<ReceiveState> emit,
  ) {
    // TODO: get the wallet, fiat currency, exchange rate, and bitcoin unit
    // TODO: check where to get the wallet id from (from the event or from the default wallet use case if not present in the event?)
    emit(
      state.copyWith(
        status: ReceiveStatus.inProgress,
        paymentNetwork: ReceivePaymentNetwork.lightning,
      ),
    );
  }

  void _onLiquidStarted(
    ReceiveLiquidStarted event,
    Emitter<ReceiveState> emit,
  ) {
    // TODO: get the wallet, fiat currency, exchange rate, and bitcoin unit
    // TODO: check where to get the wallet id from (from the event or from the default wallet use case if not present in the event?)
    // TODO: also get the first unused address for the selected wallet
    emit(
      state.copyWith(
        status: ReceiveStatus.inProgress,
        paymentNetwork: ReceivePaymentNetwork.liquid,
      ),
    );
  }
}
