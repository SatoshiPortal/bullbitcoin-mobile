// import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
// import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
// import 'package:test/test.dart';

// class SeedTestCase {
//   final List<String> mnemonicWords;
//   final String passphrase;
//   final String expectedMasterFingerprint;
//   final String expectedSeedHex;
//   final Exception? expectedException;

//   const SeedTestCase({
//     required this.mnemonicWords,
//     required this.passphrase,
//     required this.expectedMasterFingerprint,
//     required this.expectedSeedHex,
//     this.expectedException,
//   });
// }

// void main() {
//   // TODO: add more test cases
//   final List<SeedTestCase> seedTests = [
//     const SeedTestCase(
//       mnemonicWords: [
//         'abandon',
//         'abandon',
//         'abandon',
//         'abandon',
//         'abandon',
//         'abandon',
//         'abandon',
//         'abandon',
//         'abandon',
//         'abandon',
//         'abandon',
//         'about',
//       ],
//       passphrase: '',
//       expectedMasterFingerprint: '73c5da0a',
//       expectedSeedHex:
//           '5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4',
//     ),
//   ];

//   test('Seed - Entities Tests', () {
//     for (final test in seedTests) {
//       try {
//         final seed = Seed.mnemonic(
//           mnemonicWords: test.mnemonicWords,
//           passphrase: test.passphrase,
//         );

//         expect(seed.masterFingerprint, test.expectedMasterFingerprint);
//         expect(seed.hex, test.expectedSeedHex);
//       } catch (e) {
//         expect(e, test.expectedException);
//       }
//     }
//   });
// }

// Temporary main function to prevent compilation errors
// TODO: Remove this when tests are ready to be implemented
void main() {
  // Tests are commented out and will be implemented later
}
