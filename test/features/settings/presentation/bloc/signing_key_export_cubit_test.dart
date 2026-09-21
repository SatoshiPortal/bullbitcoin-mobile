import 'package:bb_mobile/features/settings/domain/used_signing_key_account.dart';
import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/export_signing_key_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/release_signing_key_account_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/signing_key_export_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExportSigningKeyUsecase extends Mock
    implements ExportSigningKeyUsecase {}

class _MockReleaseSigningKeyAccountUsecase extends Mock
    implements ReleaseSigningKeyAccountUsecase {}

void main() {
  late _MockExportSigningKeyUsecase exportSigningKey;
  late _MockReleaseSigningKeyAccountUsecase releaseSigningKeyAccount;
  late SigningKeyExportCubit cubit;

  setUp(() {
    exportSigningKey = _MockExportSigningKeyUsecase();
    releaseSigningKeyAccount = _MockReleaseSigningKeyAccountUsecase();
    when(
      releaseSigningKeyAccount.execute,
    ).thenAnswer((_) async => const Ok(null));
    cubit = SigningKeyExportCubit(
      exportSigningKeyUsecase: exportSigningKey,
      releaseSigningKeyAccountUsecase: releaseSigningKeyAccount,
    );
  });

  tearDown(() => cubit.close());

  test(
    'account edits and a second mark cannot replace an in-flight mark',
    () async {
      when(
        () => exportSigningKey.execute(
          account: null,
          markUsed: false,
          description: null,
        ),
      ).thenAnswer(
        (_) async => const Ok((
          account: 0,
          descriptorKey: 'key-0',
          isReserved: false,
          markedAccount: null,
          descriptionSaved: true,
          usedAccounts: <UsedSigningKeyAccount>[],
          usedAccountsIncomplete: false,
        )),
      );
      final pending = Completer<void>();
      when(
        () => exportSigningKey.execute(
          account: 0,
          markUsed: true,
          description: 'Family vault',
        ),
      ).thenAnswer((_) async {
        await pending.future;
        return const Ok((
          account: 1,
          descriptorKey: 'key-1',
          isReserved: false,
          markedAccount: 0,
          descriptionSaved: true,
          usedAccounts: <UsedSigningKeyAccount>[],
          usedAccountsIncomplete: false,
        ));
      });
      await cubit.load();
      final marking = cubit.markAccountUsed('Family vault');
      await cubit.selectAccount(7);
      await cubit.markAccountUsed('Another vault');
      pending.complete();
      await marking;
      expect(cubit.state.account, 1);
      expect(cubit.state.markedAccount, 0);
      verify(
        () => exportSigningKey.execute(
          account: 0,
          markUsed: true,
          description: 'Family vault',
        ),
      ).called(1);
      verifyNever(
        () => exportSigningKey.execute(
          account: 7,
          markUsed: false,
          description: null,
        ),
      );
    },
  );

  test('loads the signing key', () async {
    when(
      () => exportSigningKey.execute(
        account: null,
        markUsed: false,
        description: null,
      ),
    ).thenAnswer(
      (_) async => const Ok((
        account: 0,
        descriptorKey: 'signing-key',
        isReserved: false,
        markedAccount: null,
        descriptionSaved: true,
        usedAccounts: <UsedSigningKeyAccount>[],
        usedAccountsIncomplete: false,
      )),
    );

    await cubit.load();

    expect(cubit.state.descriptorKey, 'signing-key');
    expect(cubit.state.account, 0);
    expect(cubit.state.failure, isNull);
  });

  test('exports an explicitly selected account', () async {
    when(
      () => exportSigningKey.execute(
        account: 7,
        markUsed: false,
        description: null,
      ),
    ).thenAnswer(
      (_) async => const Ok((
        account: 7,
        descriptorKey: 'signing-key-7',
        isReserved: false,
        markedAccount: null,
        descriptionSaved: true,
        usedAccounts: <UsedSigningKeyAccount>[],
        usedAccountsIncomplete: false,
      )),
    );

    await cubit.selectAccount(7);

    expect(cubit.state.account, 7);
    expect(cubit.state.descriptorKey, 'signing-key-7');
  });

  test('clears the previous key while a different account loads', () async {
    final delayed = Completer<void>();
    when(
      () => exportSigningKey.execute(
        account: null,
        markUsed: false,
        description: null,
      ),
    ).thenAnswer(
      (_) async => const Ok((
        account: 0,
        descriptorKey: 'signing-key-0',
        isReserved: false,
        markedAccount: null,
        descriptionSaved: true,
        usedAccounts: <UsedSigningKeyAccount>[],
        usedAccountsIncomplete: false,
      )),
    );
    when(
      () => exportSigningKey.execute(
        account: 1,
        markUsed: false,
        description: null,
      ),
    ).thenAnswer((_) async {
      await delayed.future;
      return const Ok((
        account: 1,
        descriptorKey: 'signing-key-1',
        isReserved: false,
        markedAccount: null,
        descriptionSaved: true,
        usedAccounts: <UsedSigningKeyAccount>[],
        usedAccountsIncomplete: false,
      ));
    });

    await cubit.load();
    final selection = cubit.selectAccount(1);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.account, 1);
    expect(cubit.state.isLoading, isTrue);
    expect(cubit.state.descriptorKey, isEmpty);

    await cubit.markAccountUsed('Family vault');
    verifyNever(
      () => exportSigningKey.execute(
        account: 1,
        markUsed: true,
        description: 'Family vault',
      ),
    );

    delayed.complete();
    await selection;
    expect(cubit.state.descriptorKey, 'signing-key-1');
  });

  test(
    'keeps the latest selection when returning to the displayed account',
    () async {
      final accountOne = Completer<void>();
      when(
        () => exportSigningKey.execute(
          account: 1,
          markUsed: false,
          description: null,
        ),
      ).thenAnswer((_) async {
        await accountOne.future;
        return const Ok((
          account: 1,
          descriptorKey: 'signing-key-1',
          isReserved: false,
          markedAccount: null,
          descriptionSaved: true,
          usedAccounts: <UsedSigningKeyAccount>[],
          usedAccountsIncomplete: false,
        ));
      });
      when(
        () => exportSigningKey.execute(
          account: 0,
          markUsed: false,
          description: null,
        ),
      ).thenAnswer(
        (_) async => const Ok((
          account: 0,
          descriptorKey: 'signing-key-0',
          isReserved: false,
          markedAccount: null,
          descriptionSaved: true,
          usedAccounts: <UsedSigningKeyAccount>[],
          usedAccountsIncomplete: false,
        )),
      );

      final selectOne = cubit.selectAccount(1);
      await Future<void>.delayed(Duration.zero);
      await cubit.selectAccount(0);
      accountOne.complete();
      await selectOne;

      expect(cubit.state.account, 0);
      expect(cubit.state.descriptorKey, 'signing-key-0');
    },
  );

  test(
    'marks the selected account and advances to the next suggestion',
    () async {
      when(
        () => exportSigningKey.execute(
          account: null,
          markUsed: false,
          description: null,
        ),
      ).thenAnswer(
        (_) async => const Ok((
          account: 0,
          descriptorKey: 'signing-key-0',
          isReserved: false,
          markedAccount: null,
          descriptionSaved: true,
          usedAccounts: <UsedSigningKeyAccount>[],
          usedAccountsIncomplete: false,
        )),
      );
      when(
        () => exportSigningKey.execute(
          account: 0,
          markUsed: true,
          description: 'Family vault',
        ),
      ).thenAnswer(
        (_) async => const Ok((
          account: 1,
          descriptorKey: 'signing-key-1',
          isReserved: false,
          markedAccount: 0,
          descriptionSaved: true,
          usedAccounts: <UsedSigningKeyAccount>[],
          usedAccountsIncomplete: false,
        )),
      );

      await cubit.load();
      await cubit.markAccountUsed('Family vault');

      expect(cubit.state.account, 1);
      expect(cubit.state.markedAccount, 0);
      expect(cubit.state.descriptorKey, 'signing-key-1');
    },
  );

  test('exports a reserved selection with its warning state', () async {
    when(
      () => exportSigningKey.execute(
        account: 7,
        markUsed: false,
        description: null,
      ),
    ).thenAnswer(
      (_) async => const Ok((
        account: 7,
        descriptorKey: 'signing-key-7',
        isReserved: true,
        markedAccount: null,
        descriptionSaved: true,
        usedAccounts: <UsedSigningKeyAccount>[],
        usedAccountsIncomplete: false,
      )),
    );

    await cubit.selectAccount(7);

    expect(cubit.state.account, 7);
    expect(cubit.state.isReserved, isTrue);
    expect(cubit.state.descriptorKey, 'signing-key-7');
  });

  test('holds a typed failure when export fails', () async {
    when(
      () => exportSigningKey.execute(
        account: null,
        markUsed: false,
        description: null,
      ),
    ).thenAnswer((_) async => const Err(SettingsSigningKeyExportFailure()));

    await cubit.load();

    expect(cubit.state.descriptorKey, isEmpty);
    expect(cubit.state.failure, isA<SettingsSigningKeyExportFailure>());
  });

  test('releases the displayed account when closed', () async {
    await cubit.close();

    verify(releaseSigningKeyAccount.execute).called(1);
  });
}
