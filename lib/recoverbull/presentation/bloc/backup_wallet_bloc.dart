import 'dart:async';

import 'package:bb_mobile/_core/domain/usecases/get_default_wallet_use_case.dart';
import 'package:bb_mobile/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_wallet_bloc.freezed.dart';
part 'backup_wallet_event.dart';
part 'backup_wallet_state.dart';

class BackupWalletBloc extends Bloc<BackupWalletEvent, BackupWalletState> {
  final CreateEncryptedVaultUsecase createEncryptedVaultUsecase;
  final GetDefaultWalletUsecase getDefaultWalletUsecase;
  BackupWalletBloc({
    required this.createEncryptedVaultUsecase,
    required this.getDefaultWalletUsecase,
  }) : super(BackupWalletState()) {
    on<BackupWalletEvent>((event, emit) {});
  }
}
