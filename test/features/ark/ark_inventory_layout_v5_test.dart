import 'package:bb_mobile/core/themes/app_theme.dart';

import '../../../features/ark/test/support/ark_inventory_layout_contract.dart'
    as inventory;

void main() {
  inventory.register({
    for (final theme in AppThemeType.values)
      theme.name: AppTheme.themeData(theme),
  });
}
