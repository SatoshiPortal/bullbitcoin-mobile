import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'backups_copy.dart';
import 'ui/backup_options_screen.dart';

const _routeName = 'backupOptions';

enum _BackupIntent { start, verify }

final class BackupsFeature {
  final GoRoute route;

  const BackupsFeature._(this.route);

  static BackupsFeature mount({
    required BackupsCopy Function(BuildContext) copyOf,
    required Widget encryptedIcon,
    required Widget physicalIcon,
    required void Function(BuildContext) onStartPhysical,
    required void Function(BuildContext) onVerifyPhysical,
  }) => BackupsFeature._(
    GoRoute(
      name: _routeName,
      path: 'backup-options',
      builder: (context, state) {
        final verify = state.extra == _BackupIntent.verify;
        return BackupOptionsScreen(
          copy: copyOf(context),
          verify: verify,
          encryptedIcon: encryptedIcon,
          physicalIcon: physicalIcon,
          onOpenPhysical: verify ? onVerifyPhysical : onStartPhysical,
        );
      },
    ),
  );
}

abstract final class BackupsNavigation {
  static Future<void> start(BuildContext context) =>
      context.pushNamed<void>(_routeName, extra: _BackupIntent.start);

  static Future<void> verify(BuildContext context) =>
      context.pushNamed<void>(_routeName, extra: _BackupIntent.verify);
}
