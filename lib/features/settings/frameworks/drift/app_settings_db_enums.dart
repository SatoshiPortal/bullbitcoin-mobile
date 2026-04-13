/// Database-specific enums for app settings persistence.
///
/// These enums are decoupled from domain enums to maintain stable database
/// schema even if domain enums change. This follows the principle of keeping
/// the persistence layer independent from domain changes and viceversa.

/// Bitcoin unit representation in the database
enum BitcoinUnitDb { btc, sats }

/// Theme mode representation in the database
enum ThemeModeDb { system, light, dark }

/// Environment mode representation in the database
enum EnvironmentModeDb { production, test }

/// Feature level representation in the database
enum FeatureLevelDb { stable, alpha }
