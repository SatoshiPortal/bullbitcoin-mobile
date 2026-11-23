import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Exact legacy feature imports at 982b98e90 (2026-11-06). Remove entries as their
// consumers migrate; never extend this list to permit a new shell dependency.
const _legacyImports = {
  'lib/features/send/ui/send_router.dart -> locator.dart',
