import 'package:bull_recoverbull/src/domain/entities/recoverbull_network.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/allow_permission_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_permission_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_recoverbull_url_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/store_recoverbull_url_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/mark_recoverbull_backup_stored_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/mark_recoverbull_backup_verified_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Repository extends Mock implements RecoverBullRepository {}

void main() {
  test(
    'thin settings usecases preserve failures including backup metadata writes',
    () async {
      final repository = _Repository();
      const failure = RecoverBullUnexpectedFailure('Storage unavailable');
      final url = Uri.parse('http://test.onion');
      when(
        () => repository.fetchPermission(),
      ).thenAnswer((_) async => const Err(failure));
      when(
        () => repository.fetchUrl(),
      ).thenAnswer((_) async => const Err(failure));
      when(
        () => repository.allowPermission(true),
      ).thenAnswer((_) async => const Err(failure));
      when(
        () => repository.storeUrl(url),
      ).thenAnswer((_) async => const Err(failure));
      when(
        () => repository.markBackupStored(RecoverBullNetwork.mainnet),
      ).thenAnswer((_) async => const Err(failure));
      when(
        () => repository.markBackupVerified(RecoverBullNetwork.mainnet),
      ).thenAnswer((_) async => const Err(failure));
      expect(
        (await FetchPermissionUsecase(
                  recoverBullRepository: repository,
                ).execute()
                as Err<bool, RecoverBullFailure>)
            .failure,
        same(failure),
      );
      expect(
        (await FetchRecoverbullUrlUsecase(
                  recoverBullRepository: repository,
                ).execute()
                as Err<Uri, RecoverBullFailure>)
            .failure,
        same(failure),
      );
      for (final result in [
        await AllowPermissionUsecase(
          recoverBullRepository: repository,
        ).execute(true),
        await StoreRecoverbullUrlUsecase(
          recoverBullRepository: repository,
        ).execute(url),
        await MarkRecoverBullBackupStoredUsecase(
          repository,
        ).execute(RecoverBullNetwork.mainnet),
        await MarkRecoverBullBackupVerifiedUsecase(
          repository,
        ).execute(RecoverBullNetwork.mainnet),
      ]) {
        expect(
          (result as Err<Null, RecoverBullFailure>).failure,
          same(failure),
        );
      }
    },
  );
}
