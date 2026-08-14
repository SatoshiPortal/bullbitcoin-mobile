import 'package:path/path.dart' as p;

/// The support-chat backend supplies attachment display names; they are
/// server-controlled input, not safe path material. Reduce the name to its
/// last path segment so a crafted value (`../../databases/app.db`, absolute
/// paths) can never make a download write outside the intended directory,
/// and fall back to the opaque attachment id when nothing usable remains.
String sanitizeAttachmentFileName(
  String fileName, {
  required String attachmentId,
}) {
  // Normalize Windows separators first: on POSIX a backslash is a valid
  // filename character, but treating it as a separator too costs nothing
  // and keeps the same input harmless on every platform.
  final baseName = p.basename(fileName.replaceAll('\\', '/'));
  final isUsable =
      baseName.isNotEmpty &&
      baseName != '.' &&
      baseName != '..' &&
      !baseName.contains('/');
  return isUsable ? baseName : 'attachment_$attachmentId';
}
