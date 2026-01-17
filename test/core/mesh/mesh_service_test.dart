import 'package:bb_mobile/core/mesh/mesh_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MeshService Security Checks', () {
    test('isValidTxHex accepts valid bitcoin transaction hex', () {
      // Example of a minimal valid hex string (simulated)
      const validTx = '02000000000101586737526372637474747474747474256'; // Truncated but hex
      // Make it > 20 chars and valid hex
      const validHex = '02000000000101586737526372637474747474747474256abcdef1234567890';
      
      expect(MeshService.isValidTxHex(validHex), true);
    });

    test('isValidTxHex rejects non-hex characters (Malicious Injection)', () {
      const maliciousPayload = '02000000<script>alert(1)</script>';
      expect(MeshService.isValidTxHex(maliciousPayload), false);
    });

    test('isValidTxHex rejects short garbage strings', () {
      const shortGarbage = 'deadbeef';
      expect(MeshService.isValidTxHex(shortGarbage), false, reason: 'Should reject strings <= 20 chars');
    });

    test('isValidTxHex rejects valid hex logic but weird data (Not strictly enforced yet, but checking basic constraints)', () {
       // Currently we only check strictly for Hex chars and length.
       // This test ensures our "Sanitization" works against text messages.
       const textMessage = 'Hello World this is a chat message';
       expect(MeshService.isValidTxHex(textMessage), false);
    });
  });
}
