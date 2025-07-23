import 'package:hex/hex.dart';

class DriveFile {
  final String id;
  final String name;
  final DateTime createdTime;

  DriveFile({required this.id, required this.name, required this.createdTime});
  String get backupId {
    try {
      final parts = name.split('_');
      if (parts.length < 2) {
        return name.replaceAll('.json', '');
      }

      final lastPart = parts.last;
      final cleaned = lastPart
          .replaceAll('.json', '')
          // Removes all occurrences of '[', ']', and whitespace characters since backupId is a List of integers in string format
          .replaceAll(RegExp(r'[\[\]\s]'), '');

      // Checks if the cleaned string contains only digits and commas
      if (!RegExp(r'^[\d,]+$').hasMatch(cleaned)) {
        return name.replaceAll('.json', '');
      }

      final intList =
          cleaned.split(',').where((e) => e.isNotEmpty).map(int.parse).toList();
      return HEX.encode(intList);
    } catch (e) {
      return name.replaceAll('.json', '');
    }
  }
}
