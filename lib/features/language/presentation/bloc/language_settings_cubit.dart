import 'package:bb_mobile/features/language/domain/entities/language.dart';
import 'package:bb_mobile/features/language/domain/usecases/get_language_usecase.dart';
import 'package:bb_mobile/features/language/domain/usecases/set_language_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LanguageSettingsCubit extends Cubit<Language?> {
  final SetLanguageUseCase _setLanguageUseCase;
  final GetLanguageUsecase _getLanguageUsecase;

  LanguageSettingsCubit({
    required SetLanguageUseCase setLanguageUseCase,
    required GetLanguageUsecase getLanguageUsecase,
  })  : _setLanguageUseCase = setLanguageUseCase,
        _getLanguageUsecase = getLanguageUsecase,
        super(null);

  Future<void> getFromSettings() async {
    final language = await _getLanguageUsecase.execute();
    emit(language);
  }

  Future<void> changeLanguage(Language language) async {
    await _setLanguageUseCase.execute(language);
    emit(language);
  }
}
