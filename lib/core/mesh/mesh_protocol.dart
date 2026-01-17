import 'dart:typed_data';
import 'dart:math';

/// Implements the "Whale Protocol" for fragmenting large data packets
/// over BLE limits.
///
/// Header Structure (2 Bytes):
/// [TotalChunks (1 Byte) | CurrentIndex (1 Byte)]
class MeshProtocol {
  // Standard BLE MTU is often 512, but safe payload size is smaller.
  // We'll use 500 bytes for payload + 2 bytes header = 502 bytes, well within 512.
  static const int MAX_CHUNK_PAYLOAD_SIZE = 500;

  /// Splits a large payload into smaller chunks with headers.
  static List<Uint8List> fragment(Uint8List data) {
    if (data.isEmpty) return [];

    int totalSize = data.length;
    int totalChunks = (totalSize / MAX_CHUNK_PAYLOAD_SIZE).ceil();
    
    if (totalChunks > 255) {
      throw Exception("Payload too large: Max 255 chunks supported");
    }

    List<Uint8List> chunks = [];

    for (int i = 0; i < totalChunks; i++) {
      int start = i * MAX_CHUNK_PAYLOAD_SIZE;
      int end = min(start + MAX_CHUNK_PAYLOAD_SIZE, totalSize);
      
      Uint8List payload = data.sublist(start, end);
      
      // Construct Header: [TotalChunks, CurrentIndex]
      // Index is 0-based
      BytesBuilder builder = BytesBuilder();
      builder.addByte(totalChunks);
      builder.addByte(i); 
      builder.add(payload);
      
      chunks.add(builder.toBytes());
    }

    return chunks;
  }

  /// Attempts to reassemble a complete payload from a set of chunks.
  /// Returns null if chunks are missing.
  static Uint8List? reassemble(Map<int, Uint8List> chunks) {
    if (chunks.isEmpty) return null;

    // Get metadata from the first distinct chunk we have
    // (We assume all chunks belong to the same transmission for now in this simple protocol)
    final firstChunk = chunks.values.first;
    if (firstChunk.length < 2) return null; // Invalid chunk
    
    int totalChunks = firstChunk[0];
    
    // Do we have all chunks?
    if (chunks.length != totalChunks) {
      return null;
    }

    // sort by index to be safe
    var sortedKeys = chunks.keys.toList()..sort();
    
    BytesBuilder fullPayload = BytesBuilder();
    
    for (int i = 0; i < totalChunks; i++) {
      if (!chunks.containsKey(i)) return null; // Should be covered by length check, but safety first
      
      Uint8List chunk = chunks[i]!;
      // Strip header (first 2 bytes)
      fullPayload.add(chunk.sublist(2));
    }

    return fullPayload.toBytes();
  }
  
  /// Parses a raw chunk to extract its metadata
  static MeshChunkHeader parseHeader(Uint8List chunk) {
    if (chunk.length < 2) throw Exception("Invalid chunk size");
    return MeshChunkHeader(
      totalChunks: chunk[0],
      index: chunk[1],
      payload: chunk.sublist(2)
    );
  }
}

class MeshChunkHeader {
  final int totalChunks;
  final int index;
  final Uint8List payload;

  MeshChunkHeader({required this.totalChunks, required this.index, required this.payload});
}
