import 'package:bb_mobile/features/exchange_support_chat/domain/attachment_filename_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeAttachmentFileName', () {
    test('keeps a plain filename untouched', () {
      expect(
        sanitizeAttachmentFileName('receipt.pdf', attachmentId: 'a1'),
        'receipt.pdf',
      );
    });

    test('reduces a traversal payload to its last segment', () {
      // The audit payload: a server-supplied name that would otherwise make
      // File('${tempDir.path}/$fileName') escape the temp directory.
      expect(
        sanitizeAttachmentFileName(
          '../../../databases/bull_bitcoin.db',
          attachmentId: 'a1',
        ),
        'bull_bitcoin.db',
      );
    });

    test('reduces an absolute path to its last segment', () {
      expect(
        sanitizeAttachmentFileName('/etc/passwd', attachmentId: 'a1'),
        'passwd',
      );
    });

    test('treats Windows separators as separators too', () {
      expect(
        sanitizeAttachmentFileName(r'..\..\evil.txt', attachmentId: 'a1'),
        'evil.txt',
      );
      expect(
        sanitizeAttachmentFileName(r'C:\temp\evil.txt', attachmentId: 'a1'),
        'evil.txt',
      );
    });

    test('falls back to the attachment id for a bare traversal segment', () {
      expect(
        sanitizeAttachmentFileName('..', attachmentId: 'a1'),
        'attachment_a1',
      );
      expect(
        sanitizeAttachmentFileName('.', attachmentId: 'a1'),
        'attachment_a1',
      );
      expect(
        sanitizeAttachmentFileName('', attachmentId: 'a1'),
        'attachment_a1',
      );
      expect(
        sanitizeAttachmentFileName('/', attachmentId: 'a1'),
        'attachment_a1',
      );
    });
  });
}
