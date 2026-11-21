import 'package:get_it/get_it.dart';

import 'locator.dart' as scope;
import 'ledger_flow/ledger_core_locator.dart' as core_ledger;
import 'ledger_flow/ledger_locator.dart' as flow_ledger;
import 'bitbox_flow/bitbox_core_locator.dart';
import 'bitbox_flow/bitbox_locator.dart';
import 'psbt_flow/psbt_flow_locator.dart';

void setupSigners(GetIt locator) {
  scope.locator = locator;
  core_ledger.LedgerLocator.registerDatasources(locator);
  core_ledger.LedgerLocator.registerRepositories(locator);
  core_ledger.LedgerLocator.registerUsecases(locator);
  BitBoxCoreLocator.registerDatasources(locator);
  BitBoxCoreLocator.registerRepositories(locator);
  BitBoxCoreLocator.registerUsecases(locator);
  flow_ledger.LedgerLocator.setup(locator);
  BitBoxLocator.setup(locator);
  PsbtFlowLocator.setup(locator);
}
