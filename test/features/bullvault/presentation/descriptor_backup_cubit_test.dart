import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/descriptor_backup_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/fetch_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/descriptor_backup_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements DescriptorBackupRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('wss://relay.example'));
    registerFallbackValue(DescriptorBackupSession());
  });

  test(
    'changing input cancels old lookup and suppresses its late result',
    () async {
      final repo = _Repository();
      final pending =
          <Completer<Result<DescriptorBackupFetch, BullVaultFailure>>>[];
      final sessions = <DescriptorBackupSession>[];
      when(() => repo.fetch(any(), any(), any())).thenAnswer((call) {
        final completer =
            Completer<Result<DescriptorBackupFetch, BullVaultFailure>>();
        pending.add(completer);
        sessions.add(call.positionalArguments[2] as DescriptorBackupSession);
        return completer.future;
      });
      final cubit = DescriptorBackupCubit(FetchDescriptorBackupUsecase(repo));
      final first = cubit.fetch('first', 'wss://relay.example');
      final second = cubit.fetch('second', 'wss://relay.example');
      expect(sessions.first.isCancelled, isTrue);
      final current = DescriptorBackupFetch(
        [],
        incomplete: false,
        rejectedEvents: 0,
      );
      pending[1].complete(Ok(current));
      await second;
      expect(cubit.state.result, same(current));
      pending[0].complete(const Err(BullVaultBackupStatusFailure()));
      await first;
      expect(cubit.state.result, same(current));
      expect(cubit.state.failure, isNull);
      await cubit.close();
    },
  );

  test(
    'closing the screen cancels the lookup and ignores completion',
    () async {
      final repo = _Repository();
      final pending =
          Completer<Result<DescriptorBackupFetch, BullVaultFailure>>();
      late DescriptorBackupSession session;
      when(() => repo.fetch(any(), any(), any())).thenAnswer((call) {
        session = call.positionalArguments[2] as DescriptorBackupSession;
        return pending.future;
      });
      final cubit = DescriptorBackupCubit(FetchDescriptorBackupUsecase(repo));
      final operation = cubit.fetch('account', 'wss://relay.example');
      await cubit.close();
      expect(session.isCancelled, isTrue);
      pending.complete(const Err(BullVaultBackupStatusFailure()));
      await operation;
      expect(cubit.isClosed, isTrue);
    },
  );
}
