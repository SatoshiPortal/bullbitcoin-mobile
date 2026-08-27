import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _archiveUrl =
    'https://pub.dev/api/archives/payjoin-0.2.1%2Bpayjoin-1.0.0-rc.8.tar.gz';
const _archiveSha256 =
    '52696fe34ef3c05f9827f5dd08a984e8ea86642677ba934f65a7f3a722755985';
const _bindingSha256 =
    'aee74c23bf5076c5db8dda79c9ac1866446d3c4e237dbafeddd52c3efe499500';

Future<void> main() async {
  Directory? temporaryDirectory;
  File? temporaryBinding;

  try {
    final packageRoot = _findPayjoinRoot();
    final binding = File('${packageRoot.path}/lib/payjoin.dart');

    if (binding.existsSync()) {
      final actualHash = await _sha256(binding);
      if (actualHash != _bindingSha256) {
        throw StateError(
          'Existing payjoin binding has SHA-256 $actualHash, expected '
          '$_bindingSha256.',
        );
      }
      stdout.writeln('Validated existing payjoin binding: ${binding.path}');
      return;
    }

    stdout.writeln('Payjoin binding is missing; hydrating ${binding.path}');
    temporaryDirectory = await Directory.systemTemp.createTemp('payjoin-');
    final archive = File('${temporaryDirectory.path}/payjoin.tar.gz');
    await _downloadArchive(archive);
    final archiveHash = await _sha256(archive);
    if (archiveHash != _archiveSha256) {
      throw StateError(
        'Downloaded payjoin archive has SHA-256 $archiveHash, expected '
        '$_archiveSha256.',
      );
    }

    final extractionDirectory = await Directory(
      '${temporaryDirectory.path}/extract',
    ).create();
    final tarResult = await Process.run('tar', [
      '-xzf',
      archive.path,
      '-C',
      extractionDirectory.path,
      '--strip-components=1',
      'lib/payjoin.dart',
    ]);
    if (tarResult.exitCode != 0) {
      throw StateError(
        'Could not extract lib/payjoin.dart from the verified payjoin archive: '
                '${tarResult.stderr}'
            .trim(),
      );
    }

    final extractedBinding = File('${extractionDirectory.path}/payjoin.dart');
    if (!extractedBinding.existsSync()) {
      throw StateError(
        'Verified payjoin archive did not contain lib/payjoin.dart.',
      );
    }
    final bindingHash = await _sha256(extractedBinding);
    if (bindingHash != _bindingSha256) {
      throw StateError(
        'Extracted payjoin binding has SHA-256 $bindingHash, expected '
        '$_bindingSha256.',
      );
    }

    temporaryBinding = File('${binding.path}.tmp');
    if (temporaryBinding.existsSync()) {
      throw StateError(
        'Refusing to use an existing temporary binding: ${temporaryBinding.path}',
      );
    }
    await extractedBinding.copy(temporaryBinding.path);
    await temporaryBinding.rename(binding.path);
    temporaryBinding = null;
    stdout.writeln('Installed verified payjoin binding: ${binding.path}');
  } catch (error) {
    stderr.writeln('Failed to prepare payjoin dependency: $error');
    exitCode = 1;
  } finally {
    if (temporaryBinding != null && temporaryBinding.existsSync()) {
      temporaryBinding.deleteSync();
    }
    temporaryDirectory?.deleteSync(recursive: true);
  }
}

Directory _findPayjoinRoot() {
  final configFile = File('.dart_tool/package_config.json');
  if (!configFile.existsSync()) {
    throw StateError(
      'Missing .dart_tool/package_config.json; run pub get first.',
    );
  }

  final config = jsonDecode(configFile.readAsStringSync());
  final packages = config is Map<String, dynamic> ? config['packages'] : null;
  if (packages is! List) {
    throw StateError(
      'Invalid .dart_tool/package_config.json: packages is missing.',
    );
  }

  for (final package in packages) {
    if (package is! Map<String, dynamic> || package['name'] != 'payjoin') {
      continue;
    }
    final rootUri = package['rootUri'];
    if (rootUri is! String) {
      throw StateError(
        'Invalid payjoin package configuration: rootUri is missing.',
      );
    }
    final configUri = configFile.absolute.uri;
    final root = Uri.parse(rootUri).isAbsolute
        ? Uri.parse(rootUri)
        : configUri.resolve(rootUri);
    return Directory.fromUri(root);
  }

  throw StateError('Package "payjoin" was not found in package_config.json.');
}

Future<void> _downloadArchive(File destination) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(_archiveUrl));
    request.followRedirects = true;
    request.maxRedirects = 5;
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(
        'pub.dev returned HTTP ${response.statusCode} for the payjoin archive.',
      );
    }
    await response.pipe(destination.openWrite());
  } finally {
    client.close(force: true);
  }
}

Future<String> _sha256(File file) async =>
    sha256.convert(await file.readAsBytes()).toString();
