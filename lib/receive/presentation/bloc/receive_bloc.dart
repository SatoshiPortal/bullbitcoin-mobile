import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/receive/domain/usecases/get_receive_address_use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'receive_bloc.freezed.dart';
part 'receive_event.dart';
part 'receive_state.dart';

class ReceiveBloc extends Bloc<ReceiveEvent, ReceiveState> {
  ReceiveBloc({
    required GetReceiveAddressUseCase getReceiveAddressUseCase,
    required CreateReceiveSwapUseCase createReceiveSwapUseCase,
  })  : _getReceiveAddressUseCase = getReceiveAddressUseCase,
        _createReceiveSwapUseCase = createReceiveSwapUseCase,
        super(const ReceiveState.initial()) {
    on<ReceiveBitcoinStarted>(_onBitcoinStarted);
    on<ReceiveLightningStarted>(_onLightningStarted);
    on<ReceiveLiquidStarted>(_onLiquidStarted);
  }

  final GetReceiveAddressUseCase _getReceiveAddressUseCase;
  final CreateReceiveSwapUseCase _createReceiveSwapUseCase;

  void _onBitcoinStarted(
    ReceiveBitcoinStarted event,
    Emitter<ReceiveState> emit,
  ) {
    // TODO: get the wallet, fiat currency, exchange rate, and bitcoin unit
    // TODO: check where to get the wallet id from (from the event or from the default wallet use case if not present in the event?)
    emit(
      ReceiveState.bitcoin(
        wallet: Wallet(
          id: '1',
          name: 'My Wallet',
          network: Network.bitcoinMainnet,
          balanceSat: BigInt.from(100000000),
          isDefault: true,
        ),
        fiatCurrencyCode: '',
        exchangeRate: 0.0,
        bitcoinUnit: BitcoinUnit.sats,
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
      ReceiveState.lightning(
        wallet: Wallet(
          id: '1',
          name: 'My Wallet',
          network: Network.bitcoinMainnet,
          balanceSat: BigInt.from(100000000),
          isDefault: true,
        ),
        fiatCurrencyCode: '',
        exchangeRate: 0.0,
        bitcoinUnit: BitcoinUnit.sats,
      ),
    );
  }

  void _onLiquidStarted(
    ReceiveLiquidStarted event,
    Emitter<ReceiveState> emit,
  ) {
    // TODO: get the wallet, fiat currency, exchange rate, and bitcoin unit
    // TODO: check where to get the wallet id from (from the event or from the default wallet use case if not present in the event?)
    emit(
      ReceiveState.liquid(
        wallet: Wallet(
          id: '1',
          name: 'My Wallet',
          network: Network.bitcoinMainnet,
          balanceSat: BigInt.from(100000000),
          isDefault: true,
        ),
        fiatCurrencyCode: '',
        exchangeRate: 0.0,
        bitcoinUnit: BitcoinUnit.sats,
      ),
    );
  }
}
