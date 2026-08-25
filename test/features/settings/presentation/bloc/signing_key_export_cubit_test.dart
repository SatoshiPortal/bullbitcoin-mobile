import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/export_signing_key_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/signing_key_export_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExportSigningKeyUsecase extends Mock
    implements ExportSigningKeyUsecase {}

void main() {
  late _MockExportSigningKeyUsecase exportSigningKey;
  late SigningKeyExportCubit cubit;

  setUp(() {
    exportSigningKey = _MockExportSigningKeyUsecase();
    cubit = SigningKeyExportCubit(exportSigningKeyUsecase: exportSigningKey);
  });

  tearDown(() => cubit.close());

  test('loads the signing key', () async {
    when(
      () => exportSigningKey.execute(account: 0),
    ).thenAnswer((_) async => const Ok('signing-key'));

    await cubit.load();

    expect(cubit.state.descriptorKey, 'signing-key');
    expect(cubit.state.failure, isNull);
  });

  test('selecting an account replaces the displayed key', () async {
    when(
      () => exportSigningKey.execute(account: 7),
    ).thenAnswer((_) async => const Ok('account-7-key'));

    await cubit.selectAccount(7);

    expect(cubit.state.account, 7);
    expect(cubit.state.descriptorKey, 'account-7-key');
  });

  test('holds a typed failure when export fails', () async {
    when(
      () => exportSigningKey.execute(account: any(named: 'account')),
    ).thenAnswer((_) async => const Err(SettingsSigningKeyExportFailure()));

    await cubit.load();

    expect(cubit.state.descriptorKey, isEmpty);
    expect(cubit.state.failure, isA<SettingsSigningKeyExportFailure>());
  });
}
