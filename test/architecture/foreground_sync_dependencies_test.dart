import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Source-edge baseline generated once from 4c3385e6c (2026-11-07).
// These edges include legacy violations, not architectural permission.
// Networks owner moves and captured-network consumers: see the per-edge review
// in FEATURES.md (2026-11-07); do not regenerate this baseline blindly.
// Remove retired edges; review any addition instead of regenerating this list.
// Silent receives a fingerprint reader through composition, not a wallet import.
// Ark integration reviewed on 2026-11-19: send and swap use its public facade;
// settings and wallet use its published UI and foreground setup capabilities.
// These four edges are documented in FEATURES.md.
// QR and NFC consumers use the scanning feature's public capabilities; its
// implementation has no dependencies on those consumers (see FEATURES.md).
// Label Editor publishes the existing note, label and import/export UI. Its
// consumers use that surface while data-only consumers depend on the package.
// Wallet reader ownership (2026-11-22): see FEATURES.md for the address,
// coin, receive and history edges that replace the legacy wallet placements.
// Exchange workspace UI consumers use the published routes (see FEATURES.md).
const _allowedTargets = <String, String>{
  'address_view': 'label_editor scanning silent',
  'all_seed_view': 'access',
  'backups': 'access label_editor physical_backup_verification recoverbull',
