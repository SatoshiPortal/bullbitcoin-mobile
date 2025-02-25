import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'receive_bloc.freezed.dart';
part 'receive_event.dart';
part 'receive_state.dart';

class ReceiveBloc extends Bloc<ReceiveEvent, ReceiveState> {
  ReceiveBloc() : super(const ReceiveState.initial()) {
    on<ReceiveBitcoinStarted>(_onBitcoinStarted);
    on<ReceiveLightningStarted>(_onLightningStarted);
    on<ReceiveLiquidStarted>(_onLiquidStarted);
  }

  void _onBitcoinStarted(
    ReceiveBitcoinStarted event,
    Emitter<ReceiveState> emit,
  ) {
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
