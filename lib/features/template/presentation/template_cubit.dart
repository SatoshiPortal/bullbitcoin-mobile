import 'package:bb_mobile/features/template/domain/usecases/collect_and_cache_ip_usecase.dart';
import 'package:bb_mobile/features/template/domain/usecases/get_cached_ip_usecase.dart';
import 'package:bb_mobile/features/template/presentation/template_state.dart';
import 'package:bb_mobile/features/template/template_errors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TemplateCubit extends Cubit<TemplateState> {
  final CollectAndCacheIpUsecase _collectAndCacheIpUsecase;
  final GetCachedIpUsecase _getCachedIpUsecase;

  TemplateCubit({
    required CollectAndCacheIpUsecase collectAndCacheIpUsecase,
    required GetCachedIpUsecase getCachedIpUsecase,
  }) : _collectAndCacheIpUsecase = collectAndCacheIpUsecase,
       _getCachedIpUsecase = getCachedIpUsecase,
       super(const TemplateState());

  void clearError() => emit(state.copyWith(error: null));

  void reset() => emit(const TemplateState());

  Future<void> collectIp() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final ip = await _collectAndCacheIpUsecase.call();
      if (ip == null) {
        emit(state.copyWith(isLoading: false, error: NoIpAddressError()));
        return;
      }
      emit(
        state.copyWith(
          isLoading: false,
          ipAddress: ip,
          redirection: Redirection.toSomewhereElse,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: Exception(e.toString())));
      rethrow;
    }
  }

  Future<void> getCachedIp() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final ip = await _getCachedIpUsecase.call();
      if (ip == null) {
        emit(state.copyWith(isLoading: false, error: NoCachedIpError()));
        return;
      }

      emit(
        state.copyWith(
          isLoading: false,
          ipAddress: ip,
          redirection: Redirection.toSomewhereElse,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: Exception(e.toString())));
    }
  }
}
