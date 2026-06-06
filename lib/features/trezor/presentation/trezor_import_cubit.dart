import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/public/import_watch_only_facade.dart';
import 'package:bb_mobile/features/trezor/application/usecases/get_trezor_accounts_usecase.dart';
import 'package:bb_mobile/features/trezor/application/usecases/prepare_trezor_import_usecase.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_base_cubit.dart';

class TrezorImportCubit
    extends TrezorOperationBaseCubit<WatchOnlyDescriptorEntity> {
  final GetTrezorAccountsUsecase _getAccounts;
  final PrepareTrezorImportUsecase _prepareImport;

  TrezorImportCubit({
    required GetTrezorAccountsUsecase getAccounts,
    required PrepareTrezorImportUsecase prepareImport,
  }) : _getAccounts = getAccounts,
       _prepareImport = prepareImport;

  Future<void> startImport({required ScriptType scriptType}) {
    return runOperation(() async {
      // Fetch account 0 for the selected derivation family. Master
      // fingerprint travels on the TrezorAccount itself (see review #2).
      final accounts = await _getAccounts.execute(
        startIndex: 0,
        count: 1,
        scriptType: scriptType,
      );
      if (accounts.isEmpty) {
        throw Exception('Trezor returned no accounts');
      }
      return _prepareImport.execute(account: accounts.first);
    });
  }
}
