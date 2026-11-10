import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Milestone 1 — Vault Module Permanent Deletion Static Verification',
      () {
    test('VaultController file does not exist in lib/controllers/', () {
      final file = File('lib/controllers/vault_controller.dart');
      expect(file.existsSync(), isFalse,
          reason:
              'lib/controllers/vault_controller.dart must be permanently deleted.');
    });

    test('VaultView file does not exist in lib/ui/views/', () {
      final file = File('lib/ui/views/vault_view.dart');
      expect(file.existsSync(), isFalse,
          reason: 'lib/ui/views/vault_view.dart must be permanently deleted.');
    });

    test('Zero Vault imports exist across all Dart files in lib/', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final bannedImportPatterns = [
        RegExp(r'''import\s+['"][^'"]*vault_controller\.dart['"]'''),
        RegExp(r'''import\s+['"][^'"]*(?<!welcome_)vault_view\.dart['"]'''),
      ];

      final violations = <String>[];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final pattern in bannedImportPatterns) {
          if (pattern.hasMatch(content)) {
            violations.add(
                '${file.path}: matches banned import "${pattern.pattern}"');
          }
        }
      }

      expect(violations, isEmpty,
          reason:
              'Banned Vault imports detected in lib/:\n${violations.join('\n')}');
    });

    test('Zero VaultController or VaultCredential class references in lib/',
        () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final bannedSymbols = [
        RegExp(r'\bVaultController\b'),
        RegExp(r'\bVaultCredential\b'),
      ];

      final violations = <String>[];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final regex in bannedSymbols) {
          if (regex.hasMatch(content)) {
            violations.add(
                '${file.path}: references banned symbol "${regex.pattern}"');
          }
        }
      }

      expect(violations, isEmpty,
          reason:
              'Banned Vault symbols detected in lib/:\n${violations.join('\n')}');
    });

    test('Zero VaultView standalone class references in lib/', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      // Matches standalone VaultView, but intentionally allows WelcomeVaultView
      final regex = RegExp(r'(?<!Welcome)\bVaultView\b');

      final violations = <String>[];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        if (regex.hasMatch(content)) {
          violations.add('${file.path}: references banned symbol "VaultView"');
        }
      }

      expect(violations, isEmpty,
          reason:
              'Banned VaultView symbols detected in lib/:\n${violations.join('\n')}');
    });

    test('lib/main.dart does not register VaultController provider', () {
      final mainFile = File('lib/main.dart');
      expect(mainFile.existsSync(), isTrue);
      final content = mainFile.readAsStringSync();
      expect(content.contains('VaultController'), isFalse,
          reason: 'lib/main.dart must not contain VaultController provider.');
      expect(content.contains('lockVault()'), isFalse,
          reason: 'lib/main.dart must not call lockVault().');
    });

    test(
        'lib/ui/sheets/payly_sheets.dart does not contain Vault methods or modals',
        () {
      final sheetsFile = File('lib/ui/sheets/payly_sheets.dart');
      expect(sheetsFile.existsSync(), isTrue);
      final content = sheetsFile.readAsStringSync();
      expect(content.contains('VaultController'), isFalse,
          reason:
              'lib/ui/sheets/payly_sheets.dart must not reference VaultController.');
      expect(content.contains('VaultCredential'), isFalse,
          reason:
              'lib/ui/sheets/payly_sheets.dart must not reference VaultCredential.');
      expect(content.contains('Unlock Credential Vault'), isFalse,
          reason: 'Credential vault unlock modal must be scrubbed.');
    });

    test(
        'lib/ui/views/home_view.dart has no Vault Lock quick action or controller watch',
        () {
      final homeFile = File('lib/ui/views/home_view.dart');
      expect(homeFile.existsSync(), isTrue);
      final content = homeFile.readAsStringSync();
      expect(content.contains('VaultController'), isFalse,
          reason:
              'lib/ui/views/home_view.dart must not watch VaultController.');
      expect(content.contains("'Vault Lock'"), isFalse,
          reason: 'Quick action Vault Lock must be removed.');
    });
  });
}
