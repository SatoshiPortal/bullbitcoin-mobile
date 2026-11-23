typedef BackupOptionCopy = ({String title, String description, String tag});

typedef BackupsCopy = ({
  String backupTitle,
  String testTitle,
  String importanceWarning,
  BackupOptionCopy encrypted,
  BackupOptionCopy physical,
  String helpLabel,
  String helpTitle,
  String closeLabel,
  String losePhysical,
  String encryptedVault,
  String physicalRecommendation,
  String physicalRecommendationText,
  String encryptedRecommendation,
  String encryptedRecommendationText,
  String moreInfo,
});
