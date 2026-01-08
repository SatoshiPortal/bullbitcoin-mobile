import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';

abstract interface class SeedCryptoPort {
  Future<String> getFingerprintFromSeedSecret(SeedSecret seedSecret);
}
