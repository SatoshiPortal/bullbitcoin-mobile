import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/used_signing_key_account.dart';
import 'package:bb_mobile/features/settings/domain/usecases/export_signing_key_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/release_signing_key_account_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/signing_key_export_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExportSigningKeyUsecase extends Mock
    implements ExportSigningKeyUsecase {}

class _MockReleaseSigningKeyAccountUsecase extends Mock
    implements ReleaseSigningKeyAccountUsecase {}

({
  int account,
  String descriptorKey,
  bool isReserved,
  int? markedAccount,
  bool descriptionSaved,
  List<UsedSigningKeyAccount> usedAccounts,
})
_export(int account, {bool isReserved = false, int? markedAccount}) => (
  account: account,
  descriptorKey: 'signing-key-$account',
  isReserved: isReserved,
  markedAccount: markedAccount,
  descriptionSaved: true,
  usedAccounts: const <UsedSigningKeyAccount>[],
);

void main() {
  late _MockExportSigningKeyUsecase exportSigningKey;
  late _MockReleaseSigningKeyAccountUsecase releaseSigningKeyAccount;

  SigningKeyExportCubit buildCubit() => SigningKeyExportCubit(
    exportSigningKeyUsecase: exportSigningKey,
    releaseSigningKeyAccountUsecase: releaseSigningKeyAccount,
  );

  setUp(() {
    exportSigningKey = _MockExportSigningKeyUsecase();
    releaseSigningKeyAccount = _MockReleaseSigningKeyAccountUsecase();
    when(
      releaseSigningKeyAccount.execute,
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => exportSigningKey.execute(
        account: null,
        markUsed: false,
        description: null,
      ),
    ).thenAnswer((_) async => Ok(_export(0)));
  });

  blocTest<SigningKeyExportCubit, SigningKeyExportState>(
    'loads the signing key',
    build: buildCubit,
    act: (cubit) => cubit.load(),
    expect: () => [
      isA<SigningKeyExportState>().having((s) => s.isLoading, 'loading', true),
      isA<SigningKeyExportState>()
          .having((s) => s.isLoading, 'loading', false)
          .having((s) => s.account, 'account', 0)
          .having((s) => s.descriptorKey, 'key', 'signing-key-0')
          .having((s) => s.failure, 'failure', isNull),
    ],
  );

  for (final reserved in [false, true]) {
    blocTest<SigningKeyExportCubit, SigningKeyExportState>(
      'exports the selected account with reserved status $reserved',
      setUp: () {
        when(
          () => exportSigningKey.execute(
            account: 7,
            markUsed: false,
            description: null,
          ),
        ).thenAnswer((_) async => Ok(_export(7, isReserved: reserved)));
      },
      build: buildCubit,
      act: (cubit) => cubit.selectAccount(7),
      verify: (cubit) {
        expect(cubit.state.account, 7);
        expect(cubit.state.isReserved, reserved);
        expect(cubit.state.descriptorKey, 'signing-key-7');
      },
    );
  }

  blocTest<SigningKeyExportCubit, SigningKeyExportState>(
    'clears the previous key and prevents marking while a selection loads',
    build: buildCubit,
    act: (cubit) async {
      final pending = Completer<void>();
      when(
        () => exportSigningKey.execute(
          account: 1,
          markUsed: false,
          description: null,
        ),
      ).thenAnswer((_) async {
        await pending.future;
        return Ok(_export(1));
      });
      await cubit.load();
      final selection = cubit.selectAccount(1);
      try {
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
      } finally {
        pending.complete();
        await selection;
      }
    },
    verify: (cubit) => expect(cubit.state.descriptorKey, 'signing-key-1'),
  );

  blocTest<SigningKeyExportCubit, SigningKeyExportState>(
    'keeps the latest selection when returning to the displayed account',
    build: buildCubit,
    act: (cubit) async {
      final pending = Completer<void>();
      when(
        () => exportSigningKey.execute(
          account: 1,
          markUsed: false,
          description: null,
        ),
      ).thenAnswer((_) async {
        await pending.future;
        return Ok(_export(1));
      });
      when(
        () => exportSigningKey.execute(
          account: 0,
          markUsed: false,
          description: null,
        ),
      ).thenAnswer((_) async => Ok(_export(0)));
      final selectOne = cubit.selectAccount(1);
      try {
        await cubit.selectAccount(0);
      } finally {
        pending.complete();
        await selectOne;
      }
    },
    verify: (cubit) {
      expect(cubit.state.account, 0);
      expect(cubit.state.descriptorKey, 'signing-key-0');
    },
  );

  blocTest<SigningKeyExportCubit, SigningKeyExportState>(
    'marks the selected account and advances to the next suggestion',
    setUp: () {
      when(
        () => exportSigningKey.execute(
          account: 0,
          markUsed: true,
          description: 'Family vault',
        ),
      ).thenAnswer((_) async => Ok(_export(1, markedAccount: 0)));
    },
    build: buildCubit,
    act: (cubit) async {
      await cubit.load();
      await cubit.markAccountUsed('Family vault');
    },
    verify: (cubit) {
      expect(cubit.state.account, 1);
      expect(cubit.state.markedAccount, 0);
      expect(cubit.state.descriptorKey, 'signing-key-1');
    },
  );

  blocTest<SigningKeyExportCubit, SigningKeyExportState>(
    'account edits and a second mark cannot replace an in-flight mark',
    build: buildCubit,
    act: (cubit) async {
      final pending = Completer<void>();
      when(
        () => exportSigningKey.execute(
          account: 0,
          markUsed: true,
          description: 'Family vault',
        ),
      ).thenAnswer((_) async {
        await pending.future;
        return Ok(_export(1, markedAccount: 0));
      });
      await cubit.load();
      final marking = cubit.markAccountUsed('Family vault');
      try {
        await cubit.selectAccount(7);
        await cubit.markAccountUsed('Another vault');
      } finally {
        pending.complete();
        await marking;
      }
    },
    verify: (cubit) {
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
      verifyNever(
        () => exportSigningKey.execute(
          account: any(named: 'account'),
          markUsed: true,
          description: 'Another vault',
        ),
      );
    },
  );

  blocTest<SigningKeyExportCubit, SigningKeyExportState>(
    'holds a typed failure when export fails',
    setUp: () {
      when(
        () => exportSigningKey.execute(
          account: null,
          markUsed: false,
          description: null,
        ),
      ).thenAnswer((_) async => const Err(SettingsSigningKeyExportFailure()));
    },
    build: buildCubit,
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.descriptorKey, isEmpty);
      expect(cubit.state.failure, isA<SettingsSigningKeyExportFailure>());
    },
  );

  blocTest<SigningKeyExportCubit, SigningKeyExportState>(
    'releases the displayed account when closed',
    build: buildCubit,
    verify: (_) => verify(releaseSigningKeyAccount.execute).called(1),
  );
}
