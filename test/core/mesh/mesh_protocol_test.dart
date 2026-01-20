import 'package:flutter_test/flutter_test.dart';
import 'package:bb_mobile/core/mesh/mesh_protocol.dart';
import 'dart:typed_data';

void main() {
  group('MeshProtocol Tests', () {
    // Helper to generate a dummy payload
    Uint8List generatePayload(int size) {
      final list = List<int>.generate(size, (i) => i % 256);
      return Uint8List.fromList(list);
    }

    test('Fragmentation splits large payload correctly', () {
      // 1200 bytes should be 3 chunks (500 + 500 + 200)
      final payload = generatePayload(1200);
      final chunks = MeshProtocol.fragment(payload);

      expect(chunks.length, 3);
      
      // Verify headers
      // Chunk 0
      expect(chunks[0][0], 3); // Total
      expect(chunks[0][1], 0); // Index
      expect(chunks[0].length, 502); // 2 header + 500 payload

      // Chunk 1
      expect(chunks[1][0], 3);
      expect(chunks[1][1], 1);
      expect(chunks[1].length, 502);

      // Chunk 2 (Remainder)
      expect(chunks[2][0], 3);
      expect(chunks[2][1], 2);
      expect(chunks[2].length, 202); // 2 header + 200 payload
    });

    test('Reassembly reconstructs original payload', () {
      final payload = generatePayload(1200);
      final chunks = MeshProtocol.fragment(payload);
      
      // Convert list to map as expected by reassemble
      final chunkMap = {
        0: chunks[0],
        1: chunks[1],
        2: chunks[2],
      };

      final reconstructed = MeshProtocol.reassemble(chunkMap);
      
      expect(reconstructed, isNotNull);
      expect(reconstructed!.length, payload.length);
      expect(reconstructed, equals(payload));
    });

    test('Reassembly handles out-of-order chunks', () {
      final payload = generatePayload(1200);
      final chunks = MeshProtocol.fragment(payload);
      
      // Insert in random order
      final chunkMap = {
        2: chunks[2],
        0: chunks[0],
        1: chunks[1],
      };

      final reconstructed = MeshProtocol.reassemble(chunkMap);
      
      expect(reconstructed, equals(payload));
    });

    test('Reassembly fails if chunks are missing', () {
      final payload = generatePayload(1200);
      final chunks = MeshProtocol.fragment(payload);
      
      // Missing chunk 1
      final chunkMap = {
        0: chunks[0],
        2: chunks[2],
      };

      final reconstructed = MeshProtocol.reassemble(chunkMap);
      
      expect(reconstructed, isNull);
    });
    
    test('Header parsing is accurate', () {
       final payload = Uint8List.fromList([5, 2, 0xAA, 0xBB]); // Total 5, Index 2, Data AA BB
       final header = MeshProtocol.parseHeader(payload);
       
       expect(header.totalChunks, 5);
       expect(header.index, 2);
       expect(header.payload.length, 2);
       expect(header.payload[0], 0xAA);
    });
  });
}
