import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';

class Gdrive {
  static final google = GoogleSignIn(scopes: [DriveApi.driveFileScope]);

  final DriveApi api;
  final GoogleSignInAccount account;

  Gdrive._(this.api, this.account);

  static Future<Gdrive?> connect() async {
    final account = await google.signIn();
    if (account == null) {
      print("User not signed in");
      return null;
    }

    final client = await google.authenticatedClient();
    if (client == null) {
      print("Client is null");
      return null;
    }

    final api = DriveApi(client);
    return Gdrive._(api, account);
  }

  static Future<void> disconnect() async => google.disconnect();

  Future<bool> write({required String filename, required Map content}) async {
    try {
      // Create an empty file in the appDataFolder
      final file = File()..name = filename;
      final createdFile = await api.files.create(file);

      if (createdFile.id == null) {
        print("Failed to create file.");
        return false;
      }

      // Update the file with content
      final media = Media(
        Stream.value(utf8.encode(jsonEncode(content))),
        utf8.encode(jsonEncode(content)).length,
      );
      await api.files.update(file, createdFile.id!, uploadMedia: media);

      print("File created");
      return true;
    } catch (e) {
      print("Error: $e");
      return false;
    }
  }
}
