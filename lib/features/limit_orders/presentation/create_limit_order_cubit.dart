import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_creation_context.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/create_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/get_limit_order_rate_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/load_limit_order_creation_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/resolve_wallet_address_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/validate_lightning_address_usecase.dart';
import 'package:bb_mobile/features/limit_orders/presentation/create_limit_order_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class CreateLimitOrderCubit extends Cubit<CreateLimitOrderState> {
  final LoadLimitOrderCreationUsecase _loadCreation;
  final GetLimitOrderRateUsecase _getRate;
  final CreateLimitOrderUsecase _create;
  final ResolveWalletAddressUsecase _resolveAddress;
  final ValidateLightningAddressUsecase _validateLnAddress;

  int _destinationRequestId = 0;

  CreateLimitOrderCubit(
    this._loadCreation,
    this._getRate,
    this._create,
    this._resolveAddress,
    this._validateLnAddress,
  ) : super(const CreateLimitOrderState());

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));
    final result = await _loadCreation.execute();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            isLoading: false,
            balances: value.balances,
            currency: value.selectedCurrency,
            rate: value.rate,
            wallets: value.wallets,
            appWallets: value.appWallets,
            discount: 1,
            limitPrice: value.rate.priceForDiscount(1),
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  void continueFromIntro() {
    emit(state.copyWith(step: CreateLimitOrderStep.target, clearFailure: true));
  }

  void setDiscount(double discount) {
    final rate = state.rate;
    if (rate == null) return;
    final clamped = discount.clamp(1, 99).toDouble();
    emit(
      state.copyWith(
        discount: clamped,
        limitPrice: rate.priceForDiscount(clamped),
        clearFailure: true,
      ),
    );
  }

  void setLimitPrice(double price) {
    final rate = state.rate;
    if (rate == null) return;
    final clamped = price.clamp(rate.indexPrice * 0.01, rate.indexPrice * 0.99);
    emit(
      state.copyWith(
        limitPrice: clamped,
        discount: rate.discountForPrice(clamped),
        clearFailure: true,
      ),
    );
  }

  Future<void> selectCurrency(FiatCurrency currency) async {
    emit(
      state.copyWith(currency: currency, isLoading: true, clearFailure: true),
    );
    final result = await _getRate.execute(currency.code);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            rate: value,
            isLoading: false,
            discount: 1,
            limitPrice: value.priceForDiscount(1),
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  void continueFromTarget() {
    emit(state.copyWith(step: CreateLimitOrderStep.amount, clearFailure: true));
  }

  void setAmount(double amount) {
    emit(state.copyWith(fiatAmount: amount, clearFailure: true));
  }

  void continueFromAmount() {
    emit(state.copyWith(step: CreateLimitOrderStep.wallet, clearFailure: true));
  }

  void selectWallet(LimitOrderWallet wallet) {
    _destinationRequestId++;
    emit(
      state.copyWith(
        wallet: wallet,
        clearSelectedAppWallet: true,
        isResolvingAddress: false,
        lightningAddressInvalid: false,
        clearFailure: true,
      ),
    );
  }

  Future<void> selectAppWallet(Wallet appWallet) async {
    final requestId = ++_destinationRequestId;
    emit(
      state.copyWith(
        isResolvingAddress: true,
        clearWallet: true,
        selectedAppWalletId: appWallet.id,
        lightningAddressInvalid: false,
        clearFailure: true,
      ),
    );
    final result = await _resolveAddress.execute(appWallet.id);
    if (isClosed || requestId != _destinationRequestId) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            isResolvingAddress: false,
            wallet: LimitOrderWallet(
              type: appWallet.network.isLiquid
                  ? LimitOrderWalletType.liquid
                  : LimitOrderWalletType.bitcoin,
              address: value,
            ),
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            isResolvingAddress: false,
            clearSelectedAppWallet: true,
            failure: failure,
          ),
        );
    }
  }

  Future<void> setLightningAddress(String input) async {
    final requestId = ++_destinationRequestId;
    emit(
      state.copyWith(
        lightningAddressInput: input,
        isResolvingAddress: true,
        clearWallet: true,
        clearSelectedAppWallet: true,
        lightningAddressInvalid: false,
        clearFailure: true,
      ),
    );
    final address = await _validateLnAddress.execute(input);
    if (isClosed || requestId != _destinationRequestId) return;
    if (address == null) {
      emit(
        state.copyWith(
          isResolvingAddress: false,
          lightningAddressInvalid: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        isResolvingAddress: false,
        lightningAddressInvalid: false,
        wallet: LimitOrderWallet(
          type: LimitOrderWalletType.lightning,
          address: address,
        ),
      ),
    );
  }

  void continueFromWallet() {
    if (state.wallet == null || state.amountLimitViolation != null) return;
    emit(
      state.copyWith(
        step: CreateLimitOrderStep.confirmation,
        clearFailure: true,
      ),
    );
  }

  void goBack() {
    final step = switch (state.step) {
      CreateLimitOrderStep.intro => CreateLimitOrderStep.intro,
      CreateLimitOrderStep.target => CreateLimitOrderStep.intro,
      CreateLimitOrderStep.amount => CreateLimitOrderStep.target,
      CreateLimitOrderStep.wallet => CreateLimitOrderStep.amount,
      CreateLimitOrderStep.confirmation => CreateLimitOrderStep.wallet,
      CreateLimitOrderStep.done => CreateLimitOrderStep.confirmation,
    };
    emit(state.copyWith(step: step, clearFailure: true));
  }

  Future<void> submit() async {
    final currency = state.currency;
    final wallet = state.wallet;
    if (currency == null ||
        wallet == null ||
        state.isSubmitting ||
        state.amountLimitViolation != null) {
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearFailure: true));
    final result = await _create.execute(
      limitPrice: state.limitPrice,
      fiatAmount: state.fiatAmount,
      currency: currency,
      address: wallet.address,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            createdOrder: value,
            isSubmitting: false,
            step: CreateLimitOrderStep.done,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isSubmitting: false, failure: failure));
    }
  }
}
