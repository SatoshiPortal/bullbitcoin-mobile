import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/acknowledge_backup_health_reminder_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/evaluate_backup_health_reminder_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/start_backup_health_action_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_health_reminder_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockEvaluateUsecase extends Mock
    implements EvaluateBackupHealthReminderUsecase {}

class _MockAcknowledgeUsecase extends Mock
    implements AcknowledgeBackupHealthReminderUsecase {}

class _MockStartActionUsecase extends Mock
    implements StartBackupHealthActionUsecase {}

void main() {
  const decision = BackupHealthDecision(
    masterFingerprint: 'f00dbabe',
    posture: BackupHealthPosture.recoverbullOnly,
    trigger: BackupHealthTrigger.scheduled,
    currentBalanceTier: BackupBalanceTier.none,
  );
  final wallet = Wallet(
    origin: 'default',
    network: Network.bitcoinMainnet,
    isDefault: true,
    masterFingerprint: decision.masterFingerprint,
    xpubFingerprint: 'xpub-default',
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: 'wpkh(xpub/0/*)',
    internalPublicDescriptor: 'wpkh(xpub/1/*)',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
    isEncryptedVaultTested: true,
  );
  late _MockEvaluateUsecase evaluate;
  late _MockAcknowledgeUsecase acknowledge;
  late _MockStartActionUsecase startAction;
  late BackupHealthReminderCubit cubit;

  setUpAll(() => registerFallbackValue(<Wallet>[]));

  setUp(() {
    evaluate = _MockEvaluateUsecase();
    acknowledge = _MockAcknowledgeUsecase();
    startAction = _MockStartActionUsecase();
    cubit = BackupHealthReminderCubit(evaluate, acknowledge, startAction);
  });

  tearDown(() => cubit.close());

  test(
    'shows the evaluator decision and hides it after acknowledgement',
    () async {
      when(
        () =>
            evaluate.execute(wallets: any(named: 'wallets'), arkBalanceSat: 0),
      ).thenAnswer((_) async => const Ok(decision));
      when(
        () => acknowledge.execute(decision),
      ).thenAnswer((_) async => const Ok(null));

      await cubit.evaluate(wallets: [wallet], arkBalanceSat: 0);
      expect(
        cubit.state,
        isA<BackupHealthReminderVisible>().having(
          (state) => state.decision,
          'decision',
          same(decision),
        ),
      );

      await cubit.acknowledge();

      expect(cubit.state, isA<BackupHealthReminderHidden>());
      verify(() => acknowledge.execute(decision)).called(1);
    },
  );

  test(
    'keeps the reminder visible if acknowledgement cannot be saved',
    () async {
      when(
        () =>
            evaluate.execute(wallets: any(named: 'wallets'), arkBalanceSat: 0),
      ).thenAnswer((_) async => const Ok(decision));
      when(
        () => acknowledge.execute(decision),
      ).thenAnswer((_) async => const Err(BackupSettingsPersistenceFailure()));

      await cubit.evaluate(wallets: [wallet], arkBalanceSat: 0);
      await cubit.acknowledge();

      expect(
        cubit.state,
        isA<BackupHealthReminderVisible>()
            .having((state) => state.isSaving, 'isSaving', isFalse)
            .having(
              (state) => state.failure,
              'failure',
              isA<BackupSettingsPersistenceFailure>(),
            ),
      );
    },
  );

  test(
    'a persisted primary action suppresses reevaluation for the session',
    () async {
      when(
        () =>
            evaluate.execute(wallets: any(named: 'wallets'), arkBalanceSat: 0),
      ).thenAnswer((_) async => const Ok(decision));
      when(
        () => startAction.execute(decision),
      ).thenAnswer((_) async => const Ok(null));

      await cubit.evaluate(wallets: [wallet], arkBalanceSat: 0);
      final started = await cubit.startRecommendedAction();
      await cubit.reevaluate();

      expect(started, isTrue);
      expect(cubit.state, isA<BackupHealthReminderHidden>());
      verify(
        () =>
            evaluate.execute(wallets: any(named: 'wallets'), arkBalanceSat: 0),
      ).called(1);
    },
  );

  test('does not navigate when primary-action persistence fails', () async {
    when(
      () => evaluate.execute(wallets: any(named: 'wallets'), arkBalanceSat: 0),
    ).thenAnswer((_) async => const Ok(decision));
    when(
      () => startAction.execute(decision),
    ).thenAnswer((_) async => const Err(BackupSettingsPersistenceFailure()));

    await cubit.evaluate(wallets: [wallet], arkBalanceSat: 0);
    final started = await cubit.startRecommendedAction();

    expect(started, isFalse);
    expect(
      cubit.state,
      isA<BackupHealthReminderVisible>().having(
        (state) => state.failure,
        'failure',
        isA<BackupSettingsPersistenceFailure>(),
      ),
    );
  });
}
