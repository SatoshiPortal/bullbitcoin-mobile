/// Test support for consumers of `package:sync`.
///
/// `Wallet` is `final`: a test cannot implement it. These builders return a real `Wallet` whose values were published from data the test supplies, or mapped from a native wallet the test built, through the same projection and mapping code as production.
///
/// Import this in `test/` only. It is not exported by `package:sync/sync.dart`.
library;

export 'src/testing/test_wallets.dart'
    show MemoryFreezeStore, testWallet, testWalletFromNative;

export 'src/testing/freezes_only_sync.dart';

export 'src/data/write/spend/spend_writer.dart' show WalletSpender;

export 'src/data/secrets_wallet_catalog.dart' show catalogForTesting;
