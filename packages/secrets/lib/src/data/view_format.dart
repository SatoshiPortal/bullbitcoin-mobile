import 'package:primitives/primitives.dart';

import '../domain/domain.dart';
import 'inventory_import.dart' show defaultViewId;
import 'secrets_database.dart';

/// Whether this binary may open an inventory holding more than the initial
/// view. Release and reproducible builds leave it undefined, so they refuse any
/// other layout. It is one compile-time constant shared by every isolate of
/// the binary, so the foreground and the background workers agree.
const multiViewSupported = bool.fromEnvironment('BULL_MULTI_VIEW');

bool? _testOverride;

/// Whether this process supports more than the initial view. The compile-time
/// [multiViewSupported], unless a test replaced it through `testing.dart`.
/// Nothing in production can set the override.
bool get multiViewEnabled => _testOverride ?? multiViewSupported;

/// Replaces the gate for tests; `null` restores the build's own value.
void overrideMultiViewForTests(bool? value) => _testOverride = value;

/// Checks the layout invariants of the supported format, in every opener.
///
/// A build without multiple views supports exactly one view, `'all'`, whose
/// credential is absent or an existing row, and a single access state. A build
/// with them only requires every view to reference an existing credential and
/// the access state to exist. Anything else is [DatabaseViewsUnsupported], which
/// is not a damaged file and never starts a recovery.
Future<Result<void, DatabaseOpenFailure>> checkSupportedViewFormat(
  SecretsDatabase database,
) async {
  final multiView = multiViewEnabled;
  final views = await database.customSelect('''
      SELECT v.id AS id,
             v.credential_id AS credential_id,
             EXISTS (SELECT 1 FROM credentials c WHERE c.id = v.credential_id)
               AS credential_exists
      FROM views v
      ''').get();
  final states = await database
      .customSelect('SELECT COUNT(*) AS n FROM access_state')
      .getSingle();
  if (states.read<int>('n') != 1 || views.isEmpty) {
    return const Err(DatabaseViewsUnsupported());
  }
  for (final view in views) {
    final credential = view.read<String?>('credential_id');
    if (credential != null && view.read<int>('credential_exists') != 1) {
      return const Err(DatabaseViewsUnsupported());
    }
  }
  if (!multiView &&
      (views.length != 1 || views.single.read<String>('id') != defaultViewId)) {
    return const Err(DatabaseViewsUnsupported());
  }
  return const Ok(null);
}
