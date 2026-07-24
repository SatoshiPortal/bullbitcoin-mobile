import 'package:bb_mobile/core/wallet/data/datasources/cbf_wallet_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deliberately does NOT call `TestWidgetsFlutterBinding.ensureInitialized()`
/// anywhere in this file — unlike `cbf_wallet_datasource_test.dart`, which
/// needs a live binding for its `startSync`/lifecycle-attachment tests. The
/// whole point here is to prove [CbfWalletDatasource] can be constructed (as
/// `WalletLocator`'s lazy singleton would do if resolved from a background
/// context, e.g. the background-task isolate handler resolving a sibling
/// datasource through the same locator) with no `WidgetsBinding` in play at
/// all, and that doing so never throws.
///
/// If [CbfWalletDatasource] ever again attached its
/// [WidgetsBindingCbfLifecycleSource] eagerly from the constructor, this
/// file would fail with a `WidgetsBinding.instance` "was accessed before
/// the binding was initialized" error — see the constructor's doc on
/// `_disposeLifecycleListener` for why attachment is deferred to the first
/// real `startSync` call instead.
void main() {
  test('constructing with every default (including the real, WidgetsBinding-'
      'backed lifecycle source) never throws with no live binding', () {
    expect(CbfWalletDatasource.new, returnsNormally);
  });

  test('dispose() on a freshly constructed, never-synced instance is a safe '
      'no-op with no live binding', () {
    final datasource = CbfWalletDatasource();

    expect(datasource.dispose, returnsNormally);
  });
}
