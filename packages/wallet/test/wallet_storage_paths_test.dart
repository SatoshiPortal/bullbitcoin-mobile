import 'package:test/test.dart';
import 'package:wallet/wallet.dart';

void main() {
  test('preserves the installed BDK, LWK and parent cache paths', () {
    final paths = WalletStoragePaths.inDocuments(
      documentsDirectory: '/installation/documents',
      walletId: 'wallet-01',
    );
    expect(
      paths.bdkDatabase,
      '/installation/documents/77616c6c65742d3031_bdk_dart',
    );
    expect(paths.lwkRoot, '/installation/documents/77616c6c65742d3031');
    expect(
      paths.bdkParentsDatabase,
      '/installation/documents/77616c6c65742d3031_bdk_dart.parents.sqlite',
    );
  });

  test('keeps the legacy code-unit encoding for non-ASCII wallet IDs', () {
    final paths = WalletStoragePaths.inDocuments(
      documentsDirectory: '/installation/documents/',
      walletId: 'é😀',
    );
    expect(paths.lwkRoot, '/installation/documents/e9d83dde00');
  });

  test(
    'rejects missing identity or root instead of opening another wallet',
    () {
      expect(
        () => WalletStoragePaths.inDocuments(
          documentsDirectory: '/installation/documents',
          walletId: '',
        ),
        throwsArgumentError,
      );
      expect(
        () => WalletStoragePaths.inDocuments(
          documentsDirectory: '',
          walletId: 'wallet-01',
        ),
        throwsArgumentError,
      );
    },
  );
}
