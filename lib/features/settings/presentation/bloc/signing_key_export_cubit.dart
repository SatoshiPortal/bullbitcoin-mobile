import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/export_signing_key_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SigningKeyExportState {
  final int account;
  final String descriptorKey;
  final SettingsFailure? failure;

  const SigningKeyExportState({
    this.account = 0,
    this.descriptorKey = '',
    this.failure,
  });

  SigningKeyExportState copyWith({
    int? account,
    String? descriptorKey,
    SettingsFailure? failure,
    bool clearFailure = false,
  }) => SigningKeyExportState(
    account: account ?? this.account,
    descriptorKey: descriptorKey ?? this.descriptorKey,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

class SigningKeyExportCubit extends Cubit<SigningKeyExportState> {
  final ExportSigningKeyUsecase _exportSigningKeyUsecase;
  int _requestId = 0;

  SigningKeyExportCubit({required this._exportSigningKeyUsecase})
    : super(const SigningKeyExportState());

  Future<void> load() => _export(state.account);

  Future<void> selectAccount(int account) async {
    if (state.account == account) return;
    emit(state.copyWith(account: account));
    await _export(account);
  }

  Future<void> _export(int account) async {
    final requestId = ++_requestId;
    emit(state.copyWith(descriptorKey: '', clearFailure: true));

    final result = await _exportSigningKeyUsecase.execute(account: account);
    if (isClosed || requestId != _requestId) return;

    result.fold(
      (descriptorKey) => emit(
        state.copyWith(descriptorKey: descriptorKey, clearFailure: true),
      ),
      (failure) => emit(state.copyWith(failure: failure)),
    );
  }
}
