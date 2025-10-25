import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Spark {
  // Spark uses the wallet's main mnemonic (no arbitrary derivation needed like with Ark)
  static const network = Network.mainnet;
  static String get apiKey => dotenv.env['BREEZ_SPARK_API_KEY'] ?? '';
  static const storageDir = 'spark_data';
}

/// Extension to add copyWith method to Config
extension ConfigCopyWith on Config {
  Config copyWith({
    String? apiKey,
    Network? network,
    int? syncIntervalSecs,
    Fee? maxDepositClaimFee,
    bool? preferSparkOverLightning,
    bool? useDefaultExternalInputParsers,
  }) {
    return Config(
      apiKey: apiKey ?? this.apiKey,
      network: network ?? this.network,
      syncIntervalSecs: syncIntervalSecs ?? this.syncIntervalSecs,
      maxDepositClaimFee: maxDepositClaimFee ?? this.maxDepositClaimFee,
      preferSparkOverLightning:
          preferSparkOverLightning ?? this.preferSparkOverLightning,
      useDefaultExternalInputParsers:
          useDefaultExternalInputParsers ?? this.useDefaultExternalInputParsers,
    );
  }
}
