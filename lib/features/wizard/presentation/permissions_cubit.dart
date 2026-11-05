import 'package:bb_mobile/features/wizard/domain/usecase/answer_permissions_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// State: whether an answer is being handled, so a second tap while the OS
/// prompt is open does nothing.
class PermissionsCubit extends Cubit<bool> {
  PermissionsCubit({required this._answer}) : super(false);

  final AnswerPermissionsUsecase _answer;

  /// Returns once the answer is handled, false when one was already running.
  Future<bool> answer({required bool allowNotifications}) async {
    if (state) return false;
    emit(true);
    try {
      await _answer.execute(allowNotifications: allowNotifications);
    } finally {
      if (!isClosed) emit(false);
    }
    return true;
  }
}
