import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart'
    show WalletPreferencesRecoveryApplyResult;
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_setup_banner_cubit.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/recover_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/data/wallet_metadata_backup_section_provider.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/apply_pending_wizard_choices_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../wallet_backup/metadata/support/portable_settings_fixture.dart';
import '../wallet_backup/support/wallet_backup_behavior_harness.dart';

class _CreateDefaults extends Mock implements CreateDefaultWalletsUsecase {}

class _Wallet extends Mock implements Wallet {}

class _VerifyPhysical extends Mock
    implements CompletePhysicalBackupVerificationUsecase {}

class _CreateOnboarding extends Mock implements CreateOnboardingWalletUsecase {}

class _Labels extends Mock implements LabelsFacade {}

class _Wizard extends Mock implements WizardRepository {}

class _Settings extends Mock implements SettingsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (conflict, editDuringFetch, editBeforeFetch) in [
    (false, false, false),
    (true, false, false),
    (false, true, false),
    (false, false, true),
  ]) {
    test(
      'physical recovery preserves preferences (conflict: $conflict, in-flight edit: $editDuringFetch, earlier edit: $editBeforeFetch)',
      () async {
        final remote = FakeWalletBackupRemote();
        final source = await WalletBackupBehaviorHarness.create(remote: remote);
        addTearDown(source.dispose);
        source.metadata.snapshot = WalletMetadataSnapshot(
          labels: const [],
          frozenOutpoints: const [],
          walletPreferences: [
            WalletPreferences(
              walletRef: 'fresh',
              label: 'Recovered savings',
              hideOnHome: true,
            ),
            WalletPreferences(
              walletRef: 'existing',
              label: conflict ? 'Other device label' : 'Keep local label',
            ),
          ],
          settings: portableSettingsFixture(),
        );
        expect(await source.facade.setEnabled(true), isA<Ok>());
        final published = remote.storedCiphertext;

        final preferences = {
          'fresh': WalletPreferences(
            walletRef: 'fresh',
            label: 'Secure Bitcoin',
          ),
          'existing': WalletPreferences(
            walletRef: 'existing',
            label: 'Keep local label',
          ),
        };
        final labels = _Labels();
        when(labels.fetchAllStrict).thenAnswer((_) async => const Ok([]));
        final metadata = WalletMetadataBackupImpl(
          labels: labels,
          getFrozenOutpoints: () async => const [],
          restoreFrozenOutpoints: (_) async {},
          getPreferences: () async => Ok(preferences.values.toList()),
          applyPreferences: (updates) async {
            for (final update in updates) {
              expect(
                preferences[update.expected.walletRef]!.hasSameValues(
                  update.expected,
                ),
                isTrue,
              );
              preferences[update.recovered.walletRef] = update.recovered;
            }
            return Ok(
              WalletPreferencesRecoveryApplyResult(
                appliedWalletRefs: {
                  for (final update in updates) update.recovered.walletRef,
                },
                conflictedWalletRefs: const {},
              ),
            );
          },
          readPortableSettings: () async => portableSettingsFixture(),
          restorePortableSettings: (_) async {},
          changeStreams: const [],
        );
        addTearDown(metadata.dispose);
        final target = await WalletBackupBehaviorHarness.create(
          remote: remote,
          metadataSection: metadata,
        );
        addTearDown(target.dispose);

        // Seed creation is a controlled boundary here; core tests separately
        // verify that pre-existing/adopted wallet IDs are excluded from this result.
        final defaults = _CreateDefaults();
        final freshWallet = _Wallet();
        when(() => freshWallet.id).thenReturn('fresh');
        when(() => freshWallet.label).thenReturn('Secure Bitcoin');
        when(
          () => defaults.execute(mnemonicWords: any(named: 'mnemonicWords')),
        ).thenAnswer(
          (_) async =>
              (wallets: <Wallet>[freshWallet], createdWalletIds: {'fresh'}),
        );
        final verification = _VerifyPhysical();
        when(() => verification.execute()).thenAnswer((_) async {});
        final onboarding = OnboardingBloc(
          createOnboardingWalletUsecase: _CreateOnboarding(),
          recoverOnboardingWalletUsecase: RecoverOnboardingWalletUsecase(
            createDefaultWalletsUsecase: defaults,
            completePhysicalBackupVerificationUsecase: verification,
          ),
        );
        addTearDown(onboarding.close);
        final fetchesBeforeSeed = remote.fetchCount;
        onboarding.add(
          OnboardingRecoverWalletClicked(
            mnemonic: (
              words: defaultSeedMnemonic.split(' '),
              language: bip39.Language.english,
              label: '',
              passphrase: '',
            ),
          ),
        );
        final completed = await onboarding.stream.firstWhere(
          (state) => state.isSuccess,
        );
        expect(
          remote.fetchCount,
          fetchesBeforeSeed,
          reason: 'Home navigation must not wait for remote recovery',
        );
        final navigation = WalletHomeRecoveryContext(
          completed.defaultCreatedWalletPreferences,
        );

        var pending = true;
        final wizard = _Wizard();
        when(wizard.readPending).thenAnswer(
          (_) async => pending
              ? const WizardChoices(
                  metadataBackupEnabled: true,
                  touched: {WizardField.metadataBackupEnabled},
                )
              : null,
        );
        when(wizard.clearPending).thenAnswer((_) async {
          pending = false;
        });
        when(wizard.markComplete).thenAnswer((_) async {});
        final applyChoices = ApplyPendingWizardChoicesUsecase(
          wizardRepository: wizard,
          settingsRepository: _Settings(),
          walletBackup: target.facade,
        );
        final banner = DataBackupSetupBannerCubit(
          hasPendingChoices: () async => pending,
          applyPendingChoices: applyChoices.execute,
          watchState: target.facade.watchState,
        );
        addTearDown(() => banner.close().timeout(const Duration(seconds: 5)));
        void editPreferences() {
          preferences['fresh'] = WalletPreferences(
            walletRef: 'fresh',
            label: 'Edited while recovering',
            hideOnHome: false,
            autoSweepEnabled: true,
          );
        }

        if (editBeforeFetch) editPreferences();
        if (editDuringFetch) {
          remote.beforeFetch = () async {
            remote.beforeFetch = null;
            editPreferences();
          };
        }
        await banner.start(
          defaultCreatedWalletPreferences: navigation
              .takeCreatedWalletPreferences(),
        );

        expect(
          preferences['fresh']!.label,
          editDuringFetch || editBeforeFetch
              ? 'Edited while recovering'
              : 'Recovered savings',
        );
        expect(
          preferences['fresh']!.hideOnHome,
          !(editDuringFetch || editBeforeFetch),
        );
        expect(
          preferences['fresh']!.autoSweepEnabled,
          editDuringFetch || editBeforeFetch ? isTrue : isNull,
        );
        expect(preferences['existing']!.label, 'Keep local label');
        final hasConflict = conflict || editDuringFetch || editBeforeFetch;
        expect((await target.readState()).enabled, !hasConflict);
        expect(pending, hasConflict);
        expect(navigation.takeCreatedWalletPreferences(), isEmpty);
        if (hasConflict) {
          expect(banner.state, isA<DataBackupSetupFailed>());
          expect(
            remote.storedCiphertext,
            published,
            reason: 'An unresolved conflict cannot replace the remote backup',
          );
        } else {
          expect(banner.state, isA<DataBackupSetupHidden>());
          expect(
            (await target.readState()).recoveryState,
            WalletBackupRecoveryState.idle,
          );
        }
      },
    );
  }
}
