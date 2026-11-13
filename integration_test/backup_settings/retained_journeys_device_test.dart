import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/features/bullvault/ui/bullvault_menu_screen_test.dart'
    as suite0;
import '../../test/features/bullvault/ui/bullvault_settings_screen_test.dart'
    as suite1;
import '../../test/features/bullvault/ui/bullvault_policy_panel_test.dart'
    as suite2;
import '../../test/features/bullvault/ui/widgets/bullvault_completion_steps_test.dart'
    as suite3;
import '../../test/features/bullvault/ui/bullvault_renewal_screen_test.dart'
    as suite4;
import '../../test/features/bullvault/ui/bullvault_cosigner_screen_test.dart'
    as suite5;
import '../../test/features/bullvault/ui/bullvault_recovery_notice_test.dart'
    as suite6;
import '../../test/features/backup_settings/ui/vault_backup_screen_test.dart'
    as suite7;
import '../../test/features/backup_settings/ui/vault_recovery_screen_test.dart'
    as suite8;
import '../../test/features/backup_settings/ui/vault_words_recovery_screen_test.dart'
    as suite9;
import '../../test/features/backup_settings/ui/data_backup_words_recovery_screen_test.dart'
    as suite10;
import '../../test/features/backup_settings/ui/data_backup_settings_screen_test.dart'
    as suite11;
import '../../test/features/backup_settings/ui/data_backup_contents_test.dart'
    as suite12;
import '../../test/features/backup_settings/ui/data_backup_recovery_screen_test.dart'
    as suite13;
import '../../test/features/backup_settings/ui/data_recovery_words_screen_test.dart'
    as suite14;
import '../../test/features/backup_settings/ui/backup_recovery_routes_test.dart'
    as suite15;
import '../../test/features/wizard/ui/data_backup_wizard_test.dart' as suite16;
import '../../test/features/onboarding/ui/physical_prompt_test.dart' as suite17;
import '../../test/features/onboarding/ui/physical_recovery_completion_test.dart'
    as suite18;
import '../../test/features/settings/ui/backup_settings_groups_test.dart'
    as suite19;
import '../../test/features/settings/ui/widgets/wallet_inspection_views_test.dart'
    as suite20;

import '../../test/features/wallet_backup/domain/vault_discovery_test.dart'
    as recovery_fence;

// These fixtures exercise production widgets on Android; owner and full-app integration evidence is recorded separately.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Vault recovery restart persistence', recovery_fence.main);
  group('BullVault menu and practice', suite0.main);
  group('Selected vault actions', suite1.main);
  group('Policy facts', suite2.main);
  group('Vault setup verification', suite3.main);
  group('Vault renewal', suite4.main);
  group('Vault cosigner', suite5.main);
  group('Recovered vault notice', suite6.main);
  group('Vault backup and future destinations', suite7.main);
  group('Vault recovery landing', suite8.main);
  group('Vault words recovery', suite9.main);
  group('Vault-only words result', suite10.main);
  group('Data Backup controls', suite11.main);
  group('Data Backup Contents', suite12.main);
  group('Data Backup recovery confirmation', suite13.main);
  group('Data Recovery Words reveal', suite14.main);
  group('Backup routes', suite15.main);
  group('Wizard consent', suite16.main);
  group('Physical restore prompt', suite17.main);
  group('Physical restore readiness', suite18.main);
  group('Five Settings groups', suite19.main);
  group('Selected Policy and Keys', suite20.main);
}
