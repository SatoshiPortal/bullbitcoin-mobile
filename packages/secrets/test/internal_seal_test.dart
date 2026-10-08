import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:flutter_test/flutter_test.dart';

/// What is not exported is strictly internal — checked on the resolved element model, not on text.
///
/// A name left out of the `show` lists cannot be *written* by a consumer, but it can still be *reached*: a dot shorthand (`.new()`, Dart 3.10+) builds a value of the context type without naming it, and an exported signature is all the context it needs. `implementation_imports` sees only import directives, so it never fires. This test closes both halves: nothing exported hands a consumer a context of an unexported type, and nothing unexported can be constructed from outside even if it did.
void main() {
  late final LibraryElement secrets;
  late final LibraryElement testing;
  late final List<LibraryElement> internals;

  setUpAll(() async {
    final root = Directory.current.path;
    final collection = AnalysisContextCollection(
      includedPaths: [root],
      sdkPath: _dartSdkPath(root),
    );
    final session = collection.contextFor(root).currentSession;
    Future<LibraryElement> library(String uri) async {
      final result = await session.getLibraryByUri(uri);
      if (result is! LibraryElementResult) throw StateError('$uri: $result');
      return result.element;
    }

    secrets = await library('package:secrets/secrets.dart');
    testing = await library('package:secrets/testing.dart');
    internals = [
      for (final file in Directory('$root/lib/src').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          await library(
            'package:secrets/${file.path.substring('$root/lib/'.length)}',
          ),
    ];
  });

  Set<Element> exported() => {
    ...secrets.exportNamespace.definedNames2.values,
    ...testing.exportNamespace.definedNames2.values,
  };

  bool ours(Element e) =>
      e.library?.uri.toString().startsWith('package:secrets/') ?? false;

  test('no unexported type can be constructed from outside the package', () {
    final surface = exported();
    final offenders = <String>[];
    for (final lib in internals) {
      for (final type in lib.classes) {
        if (type.isPrivate || surface.contains(type)) continue;
        if (type.isAbstract || type.isSealed) continue;
        for (final c in type.constructors) {
          if (c.isPrivate) continue;
          if (!c.isOriginDeclaration) {
            offenders.add('${type.displayName}: implicit public constructor');
          } else if (!c.metadata.hasInternal) {
            final name = c.name == 'new' || c.name == null ? '' : '.${c.name}';
            offenders.add('${type.displayName}$name is not @internal');
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'annotate each with @internal (make implicit constructors explicit first)',
    );
  });

  test('no exported signature hands a consumer an unexported type', () {
    final surface = exported();
    final offenders = <String>[];

    void check(String where, DartType type) {
      final seen = <DartType>{};
      void walk(DartType t) {
        if (!seen.add(t)) return;
        if (t is InterfaceType) {
          if (ours(t.element) && !surface.contains(t.element)) {
            offenders.add('$where mentions ${t.element.displayName}');
          }
          t.typeArguments.forEach(walk);
        } else if (t is FunctionType) {
          walk(t.returnType);
          for (final p in t.formalParameters) {
            walk(p.type);
          }
        } else if (t is RecordType) {
          for (final f in [...t.positionalFields, ...t.namedFields]) {
            walk(f.type);
          }
        }
      }

      walk(type);
    }

    for (final element in surface) {
      if (element is! InterfaceElement || !ours(element)) continue;
      final name = element.displayName;
      for (final c in element.constructors) {
        if (c.isPrivate || c.metadata.hasInternal) continue;
        check('$name(${c.name})', c.type);
      }
      for (final m in element.methods) {
        if (m.isPrivate || m.metadata.hasInternal) continue;
        check('$name.${m.displayName}', m.type);
      }
      for (final g in element.getters) {
        if (g.isPrivate || g.metadata.hasInternal) continue;
        check('$name.${g.displayName}', g.returnType);
      }
    }
    expect(offenders, isEmpty);
  });
}

/// The Dart SDK bundled with the Flutter SDK this workspace resolves against.
String _dartSdkPath(String start) {
  var dir = Directory(start);
  while (true) {
    final config = File('${dir.path}/.dart_tool/package_config.json');
    if (config.existsSync()) {
      final packages =
          (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
      final flutter = packages.cast<Map>().firstWhere(
        (p) => p['name'] == 'flutter',
      );
      final root = Uri.parse(flutter['rootUri'] as String).toFilePath();
      return '${Directory(root).parent.parent.path}/bin/cache/dart-sdk';
    }
    if (dir.parent.path == dir.path) throw StateError('no package_config');
    dir = dir.parent;
  }
}
