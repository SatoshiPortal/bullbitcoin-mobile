class BackupProviderEntity {
  final String name;
  final String iconPath;
  final String description;
  final String type;
  final bool isAvailable;

  const BackupProviderEntity({
    required this.name,
    required this.iconPath,
    required this.description,
    required this.type,
    this.isAvailable = true,
  });
}
