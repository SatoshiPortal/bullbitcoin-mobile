import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/public/import_watch_only_facade.dart';
import 'package:bb_mobile/features/trezor/domain/usecases/get_default_trezor_account_usecase.dart';
import 'package:bb_mobile/features/trezor/domain/usecases/prepare_trezor_import_usecase.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_base_cubit.dart';

class TrezorImportCubit
    extends TrezorOperationBaseCubit<WatchOnlyDescriptorEntity> {
  final GetDefaultTrezorAccountUsecase _getDefaultAccount;
  final PrepareTrezorImportUsecase _prepareImport;

  TrezorImportCubit({
    required this._getDefaultAccount,
    required this._prepareImport,
  });

  Future<void> startImport({
    required ScriptType scriptType,
    required bool isTestnet,
  }) async {
    return runOperation(() async {
      final account = await _getDefaultAccount.execute(
        scriptType: scriptType,
        isTestnet: isTestnet,
      );
      return _prepareImport.execute(account: account);
    });
  }
}
