import 'package:bb_mobile/_core/domain/usecases/get_default_wallet_use_case.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_wallet_event.dart';
part 'backup_wallet_state.dart';
part 'backup_wallet_bloc.freezed.dart';

class BackupWalletBloc extends Bloc<BackupWalletEvent, BackupWalletState> {
  final CreateEncryptedVaultUsecase createEncryptedVaultUseCase;
  final GetDefaultWalletUseCase getDefaultWalletUseCase;
  BackupWalletBloc({
    required this.createEncryptedVaultUseCase,
    required this.getDefaultWalletUseCase,
  }) : super(const BackupWalletState()) {
    on<BackupWalletEvent>((event, emit) {});
  }
}
