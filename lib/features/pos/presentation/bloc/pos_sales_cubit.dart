import 'dart:async';

import 'package:bb_mobile/features/pos/application/usecases/watch_sales_usecase.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_ref.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_sale.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PosSalesState {
  const PosSalesState({
    this.isLoading = false,
    this.sales = const [],
    this.error,
  });

  final bool isLoading;
  final List<PosSale> sales;
  final String? error;

  PosSalesState copyWith({
    bool? isLoading,
    List<PosSale>? sales,
    String? error,
    bool clearError = false,
  }) {
    return PosSalesState(
      isLoading: isLoading ?? this.isLoading,
      sales: sales ?? this.sales,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class PosSalesCubit extends Cubit<PosSalesState> {
  PosSalesCubit({required WatchSalesUsecase watchSalesUsecase})
    : _watchSalesUsecase = watchSalesUsecase,
      super(const PosSalesState());

  final WatchSalesUsecase _watchSalesUsecase;
  Timer? _timer;

  Future<void> start(PosRef ref) async {
    await refresh(ref);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => refresh(ref));
  }

  Future<void> refresh(PosRef ref) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final sales = await _watchSalesUsecase.execute(ref: ref);
      emit(state.copyWith(isLoading: false, sales: sales));
    } catch (error) {
      emit(state.copyWith(isLoading: false, error: '$error'));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
