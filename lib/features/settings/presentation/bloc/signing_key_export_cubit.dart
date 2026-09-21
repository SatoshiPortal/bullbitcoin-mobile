import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/used_signing_key_account.dart';
import 'package:bb_mobile/features/settings/domain/usecases/export_signing_key_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/release_signing_key_account_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SigningKeyExportState {
  final int account;
  final String descriptorKey;
  final bool isReserved;
  final bool isLoading;
  final int? markedAccount;
  final bool descriptionSaved;
  final List<UsedSigningKeyAccount> usedAccounts;
  final SettingsFailure? failure;

  const SigningKeyExportState({
    this.account = 0,
    this.descriptorKey = '',
    this.isReserved = false,
    this.isLoading = false,
    this.markedAccount,
    this.descriptionSaved = true,
    this.usedAccounts = const [],
    this.failure,
  });

  SigningKeyExportState copyWith({
    int? account,
    String? descriptorKey,
    bool? isReserved,
    bool? isLoading,
    int? markedAccount,
    bool? descriptionSaved,
    List<UsedSigningKeyAccount>? usedAccounts,
    bool clearMarkedAccount = false,
    SettingsFailure? failure,
    bool clearFailure = false,
  }) => SigningKeyExportState(
    account: account ?? this.account,
    descriptorKey: descriptorKey ?? this.descriptorKey,
    isReserved: isReserved ?? this.isReserved,
    isLoading: isLoading ?? this.isLoading,
    markedAccount: clearMarkedAccount
        ? null
        : markedAccount ?? this.markedAccount,
    descriptionSaved: descriptionSaved ?? this.descriptionSaved,
    usedAccounts: usedAccounts ?? this.usedAccounts,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

class SigningKeyExportCubit extends Cubit<SigningKeyExportState> {
  final ExportSigningKeyUsecase _exportSigningKeyUsecase;
  final ReleaseSigningKeyAccountUsecase _releaseSigningKeyAccountUsecase;
  int _requestId = 0;
  int? _requestedAccount;
  bool _markUsed = false;
  String? _description;

  SigningKeyExportCubit({
    required this._exportSigningKeyUsecase,
    required this._releaseSigningKeyAccountUsecase,
  }) : super(const SigningKeyExportState());

  Future<void> load() async {
    await _export(account: _requestedAccount, markUsed: _markUsed);
  }

  Future<void> selectAccount(int account) async {
    if (_markUsed && state.isLoading) return;
    if ((!state.isLoading && state.account == account) ||
        (state.isLoading && _requestedAccount == account)) {
      return;
    }
    _requestedAccount = account;
    _markUsed = false;
    await _export(account: account);
  }

  Future<void> markAccountUsed(String description) async {
    if (state.isLoading || state.isReserved || state.descriptorKey.isEmpty) {
      return;
    }
    _requestedAccount = state.account;
    _markUsed = true;
    _description = description;
    await _export(account: state.account, markUsed: true);
  }

  @override
  Future<void> close() async {
    switch (await _releaseSigningKeyAccountUsecase.execute()) {
      case Ok():
      case Err():
        break;
    }
    return super.close();
  }

  Future<void> _export({int? account, bool markUsed = false}) async {
    final requestId = ++_requestId;
    emit(
      state.copyWith(
        account: account,
        descriptorKey: '',
        isReserved: false,
        isLoading: true,
        clearFailure: true,
        clearMarkedAccount: !markUsed,
      ),
    );

    final result = await _exportSigningKeyUsecase.execute(
      account: account,
      markUsed: markUsed,
      description: markUsed ? _description : null,
    );
    if (isClosed || requestId != _requestId) return;

    result.fold(
      (export) {
        if (markUsed) {
          _requestedAccount = null;
          _markUsed = false;
          _description = null;
        }
        emit(
          state.copyWith(
            account: export.account,
            descriptorKey: export.descriptorKey,
            isReserved: export.isReserved,
            isLoading: false,
            markedAccount: export.markedAccount,
            descriptionSaved: export.descriptionSaved,
            usedAccounts: export.usedAccounts,
            clearFailure: true,
          ),
        );
      },
      (failure) => emit(
        state.copyWith(
          isLoading: false,
          usedAccounts: const [],
          failure: failure,
        ),
      ),
    );
  }
}
