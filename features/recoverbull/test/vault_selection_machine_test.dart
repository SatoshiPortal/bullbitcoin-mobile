import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/domain/entities/drive_file_metadata.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import 'package:bull_recoverbull/src/presentation/vault_selection_machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final older = DriveFileMetadata(
    id: 'old',
    name: 'old',
    createdTime: DateTime.utc(2025),
  );
  final latest = DriveFileMetadata(
    id: 'new',
    name: 'new',
    createdTime: DateTime.utc(2026),
  );
  final vault = EncryptedVault(
    id: '11' * 32,
    salt: '22' * 16,
    ciphertext: List.filled(64, 0),
    createdAt: DateTime.utc(2026),
  );
  test('Drive reads the newest file and accepts only its attempt', () {
    final opening = transitionVaultSelection(
      const VaultSelectionIdle(),
      const VaultSelectionStarted(7, VaultProvider.googleDrive),
    );
    expect(
      transitionVaultSelection(opening, VaultSelectionListed(6, [latest])),
      same(opening),
    );
    final reading = transitionVaultSelection(
      opening,
      VaultSelectionListed(7, [older, latest]),
    );
    expect((reading as VaultSelectionReading).file, same(latest));
    expect(
      transitionVaultSelection(reading, VaultSelectionOpened(6, vault)),
      same(reading),
    );
    final selected = transitionVaultSelection(
      reading,
      VaultSelectionOpened(7, vault),
    ) as VaultSelectionSelected;
    expect(selected.vault, same(vault));
    expect(selected.provider, VaultProvider.googleDrive);
  });
  test('leaving invalidates a late result even after a new attempt', () {
    final first = transitionVaultSelection(
      const VaultSelectionIdle(),
      const VaultSelectionStarted(1, VaultProvider.googleDrive),
    );
    final left = transitionVaultSelection(first, const VaultSelectionLeft());
    final second = transitionVaultSelection(
      left,
      const VaultSelectionStarted(2, VaultProvider.customLocation),
    );
    expect(
      transitionVaultSelection(second, VaultSelectionListed(1, [latest])),
      same(second),
    );
    expect(
      transitionVaultSelection(second, VaultSelectionOpened(1, vault)),
      same(second),
    );
    expect(
      transitionVaultSelection(second, VaultSelectionOpened(2, vault)),
      isA<VaultSelectionSelected>(),
    );
  });
  test('empty, cancellation and failure are distinct', () {
    const opening = VaultSelectionOpening(1, VaultProvider.googleDrive);
    expect(
      transitionVaultSelection(opening, const VaultSelectionListed(1, [])),
      isA<VaultSelectionEmpty>(),
    );
    expect(
      transitionVaultSelection(
        opening,
        const VaultSelectionError(1, VaultCancelledFailure()),
      ),
      isA<VaultSelectionCancelled>(),
    );
    expect(
      transitionVaultSelection(
        opening,
        const VaultSelectionError(1, VaultInvalidFailure()),
      ),
      isA<VaultSelectionFailed>(),
    );
  });
}
