"""Independent verification of the synthetic fixture, not a general BIP138 reader.

Usage: python3 tools/verify_bip138_fixture.py build/bip138-prototype [live.json]
Requires Python cryptography; uses its RFC8439 implementation, not the Dart codec.
"""

import hashlib
import json
import pathlib
import sys

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305


def tagged(tag, payload):
    digest = hashlib.sha256(tag.encode()).digest()
    return hashlib.sha256(digest + digest + payload).digest()


def decode_xpub(value):
    alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
    integer = 0
    for char in value:
        integer = integer * 58 + alphabet.index(char)
    raw = integer.to_bytes((integer.bit_length() + 7) // 8, 'big')
    assert len(raw) == 82
    assert hashlib.sha256(hashlib.sha256(raw[:-4]).digest()).digest()[:4] == raw[-4:]
    return raw[46:78]  # 78-byte BIP32 payload: public key is bytes 45..77.


class Reader:
    def __init__(self, data):
        self.data = data
        self.offset = 0

    def take(self, count):
        end = self.offset + count
        assert end <= len(self.data)
        result = self.data[self.offset:end]
        self.offset = end
        return result

    def compact(self):
        first = self.take(1)[0]
        if first < 253:
            return first
        return int.from_bytes(self.take({253: 2, 254: 4, 255: 8}[first]), 'little')


def main():
    directory = pathlib.Path(sys.argv[1])
    evidence_name = sys.argv[2] if len(sys.argv) > 2 else 'live.json'
    evidence = json.loads((directory / evidence_name).read_text())
    reader = Reader((directory / 'fixture.bip138').read_bytes())
    assert reader.take(8) == b'BIP138\x01\x00'  # v1, no optional path hints.
    masks = [reader.take(32) for _ in range(reader.take(1)[0])]
    assert len(masks) == 5
    assert reader.take(1) == b'\x01'
    nonce = reader.take(12)
    ciphertext = reader.take(reader.compact())
    for index, xpub in enumerate(evidence['xpubs']):
        individual = tagged('BIP138_INDIVIDUAL_SECRET', decode_xpub(xpub))
        for mask in masks:
            secret = bytes(a ^ b for a, b in zip(individual, mask))
            try:
                plaintext = ChaCha20Poly1305(secret).decrypt(nonce, ciphertext, None)
            except InvalidTag:
                continue
            content = Reader(plaintext)
            assert content.take(3) == b'\x01\x01\x7c'  # BIP380 content.
            descriptor = content.take(content.compact()).decode()
            assert descriptor == evidence['descriptor']
            print(f'INDEPENDENT_BIP138_PASS recipient={index} bytes={len(ciphertext)}')
            break
        else:
            raise AssertionError(f'No valid recipient mask: {index}')


if __name__ == '__main__':
    main()
