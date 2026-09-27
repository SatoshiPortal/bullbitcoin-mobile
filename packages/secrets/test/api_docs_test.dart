import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/api_docs.dart';
import '../tool/key_material_gate.dart' show dartSdkPath;

void main() {
  late Directory fixture;
  late String sdkPath;
  late String packagePath;

  setUp(() {
    var repository = Directory.current;
    while (!File(
      '${repository.path}/packages/secrets/pubspec.yaml',
    ).existsSync()) {
      if (repository.parent.path == repository.path) {
        throw StateError('No repository');
      }
      repository = repository.parent;
    }
    sdkPath = dartSdkPath(repository.path);
    packagePath = '${repository.path}/packages/secrets';
    fixture = Directory.systemTemp.createTempSync('secrets_api_docs_');
    final source = File('${repository.path}/.dart_tool/package_config.json');
    final config = jsonDecode(source.readAsStringSync()) as Map;
    for (final package in config['packages'] as List) {
      package['rootUri'] = source.uri
          .resolve(package['rootUri'] as String)
          .toString();
    }
    File('${fixture.path}/.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(config));
    File('${fixture.path}/api.dart').writeAsStringSync('''
export 'implementation.dart' show Secrets, Secret, SecretExtension, Operations, Navigation, Signing, ModuleKeys, Description, Imported;
''');
    File('${fixture.path}/implementation.dart').writeAsStringSync('''
import 'package:meta/meta.dart';

class Result<T, F> {}
class SecretFailure {}
typedef Imported = ({Secret secret, int count});

final class Secrets {
  static const implementationFlag = true;
  Future<Result<Secret, SecretFailure>> generate({int count = 12}) async => throw UnimplementedError();
  Future<Result<Imported, SecretFailure>> restore() async => throw UnimplementedError();
  ModuleKeys keys({required String module}) => ModuleKeys._();
}

final class Secret {
  String get id => 'id';
  Description get info => Description();
  @internal
  String get material => 'hidden';
  @internal
  Future<Result<String, SecretFailure>> signFlat() async => throw UnimplementedError();
  void _private() {}
  @override
  String toString() => 'Secret';
}

extension SecretExtension on Secret {
  Operations get derive => Operations._(this);
  Signing get sign => Signing._(this);
  Navigation get navigation => Navigation._(this);
}

extension UnexportedExtension on Secret {
  String unrelated() => 'not in the canonical import';
}

extension type Operations._(Secret _secret) {
  Future<Result<List<String>, SecretFailure>> child({required int index, String? language}) async => throw UnimplementedError();
  Signing get signing => Signing._(_secret);
}

extension type Signing._(Secret _secret) {
  Future<Result<String, SecretFailure>> transaction(String payload, {required String network, int account = 0}) async => throw UnimplementedError();
}

extension type Navigation._(Secret _secret) {
  Operations get operations => Operations._(_secret);
}

final class ModuleKeys {
  ModuleKeys._();
  Future<Result<String, SecretFailure>> get({required String name}) async => throw UnimplementedError();
  void reset([bool force = false]) {}
}

final class Description {
  String format() => 'data object, not a capability group';
}
''');
  });

  tearDown(() => fixture.deleteSync(recursive: true));

  Future<String> generate() => generateApiTrees(
    libraryPath: '${fixture.path}/api.dart',
    sdkPath: sdkPath,
  );

  test(
    'follows exported extensions and factories without exposing internals',
    () async {
      final trees = await generate();
      expect(trees, contains('Secrets\n'));
      expect(trees, contains('Secret\n'));
      expect(trees, contains('generate([count: 12]) -> Secret'));
      expect(trees, contains('restore() -> Imported'));
      expect(trees, contains('keys(module:)\n'));
      expect(trees, contains('get(name:) -> String'));
      expect(trees, contains('reset([force = false]) -> void'));
      expect(trees, contains('derive\n'));
      expect(trees, contains('child(index:, [language:]) -> List<String>'));
      expect(trees, contains('signing\n'));
      expect(trees, contains('navigation\n'));
      expect(trees, contains('operations\n'));
      expect(
        trees,
        contains('transaction(payload, network:, [account: 0]) -> String'),
      );
      expect(trees, contains('info -> Description'));
      for (final hidden in [
        'material ->',
        'signFlat(',
        '_private(',
        'unrelated(',
        'implementationFlag',
        'toString(',
        'format(',
      ]) {
        expect(trees, isNot(contains(hidden)), reason: hidden);
      }
      expect(
        await generate(),
        trees,
        reason: 'Generation must be deterministic',
      );
    },
  );

  test(
    'a changed public signature changes the diagram without a method list',
    () async {
      final before = await generate();
      final source = File('${fixture.path}/implementation.dart');
      source.writeAsStringSync(
        source.readAsStringSync().replaceAll(
          'child({required int index, String? language})',
          'descendant({required int position, String? language, int count = 24})',
        ),
      );
      final after = await generate();
      expect(after, isNot(before));
      expect(
        after,
        contains(
          'descendant(position:, [language:], [count: 24]) -> List<String>',
        ),
      );
      expect(after, isNot(contains('child(')));
    },
  );

  test('a missing root and unresolved exported source fail generation', () async {
    await expectLater(
      generateApiTrees(
        libraryPath: '${fixture.path}/api.dart',
        sdkPath: sdkPath,
        roots: ['Missing'],
      ),
      throwsStateError,
    );
    final source = File('${fixture.path}/implementation.dart');
    source.writeAsStringSync(
      '${source.readAsStringSync()}\nMissingType broken() => throw UnimplementedError();\n',
    );
    await expectLater(generate(), throwsStateError);
  });

  test(
    'the getting-started example resolves with its documented imports',
    () async {
      final readme = File('$packagePath/README.md').readAsStringSync();
      final example = RegExp(
        r'<!-- secrets-example:start -->\s*```dart\n([\s\S]*?)\n```\s*<!-- secrets-example:end -->',
      ).firstMatch(readme);
      expect(
        example,
        isNotNull,
        reason: 'Keep one complete documented example',
      );
      final file = File('${fixture.path}/example.dart')
        ..writeAsStringSync(example!.group(1)!);
      final path = file.resolveSymbolicLinksSync();
      final collection = AnalysisContextCollection(
        includedPaths: [fixture.resolveSymbolicLinksSync()],
        sdkPath: sdkPath,
      );
      try {
        final result = await collection
            .contextFor(path)
            .currentSession
            .getResolvedUnit(path);
        expect(result, isA<ResolvedUnitResult>());
        final resolved = result as ResolvedUnitResult;
        expect(
          resolved.diagnostics.where(
            (diagnostic) => diagnostic.diagnosticCode.severity.name == 'ERROR',
          ),
          isEmpty,
          reason:
              'The README must not rely on undefined helpers or missing imports',
        );
      } finally {
        await collection.dispose();
      }
    },
  );

  test(
    'check reports drift without writing and regeneration preserves prose',
    () {
      final readme = File('${fixture.path}/README.md')
        ..writeAsStringSync('Before\n$apiDocsStart\nold\n$apiDocsEnd\nAfter\n');
      final before = readme.readAsStringSync();
      expect(updateApiReadme(readme, 'new tree', check: true), isFalse);
      expect(readme.readAsStringSync(), before);
      expect(updateApiReadme(readme, 'new tree', check: false), isFalse);
      expect(
        readme.readAsStringSync(),
        'Before\n$apiDocsStart\n\nnew tree\n\n$apiDocsEnd\nAfter\n',
      );
      expect(updateApiReadme(readme, 'new tree', check: true), isTrue);
    },
  );

  test('missing, duplicate and reversed markers are refused', () {
    for (final markdown in [
      'No markers',
      '$apiDocsEnd\n$apiDocsStart',
      '$apiDocsStart\n$apiDocsStart\n$apiDocsEnd',
      '$apiDocsStart\n$apiDocsEnd\n$apiDocsEnd',
    ]) {
      expect(() => replaceApiTrees(markdown, 'tree'), throwsStateError);
    }
  });
}
