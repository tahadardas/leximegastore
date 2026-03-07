import 'dart:io';

final RegExp _designSystemImport = RegExp(
  r'''import\s+['"].*design_system/lexi_(tokens|typography|theme|motion|icons)\.dart['"];''',
);
final RegExp _legacyDesignImport = RegExp(
  r'''import\s+['"].*ui/lexi_design/lexi_.*\.dart['"];''',
);
final RegExp _hardColor = RegExp(r'Color\(\s*0x[0-9a-fA-F]+\s*\)');
final RegExp _hardSpacing = RegExp(
  r'''(SizedBox|EdgeInsets\.(all|only|symmetric|fromLTRB))\([^)]*\b([1-9]\d?)\b[^)]*\)''',
);

void main() {
  final root = Directory('lib');
  if (!root.existsSync()) {
    stderr.writeln('lib directory not found.');
    exitCode = 1;
    return;
  }

  final dartFiles = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  final targetRoots = <String>[
    r'lib\features\home\',
    r'lib\features\product\',
    r'lib\features\cart\',
    r'lib\features\checkout\',
    r'lib\features\orders\',
    r'lib\features\profile\',
    r'lib\app\router\',
    r'lib\app\shell\',
    r'lib\shared\widgets\product_card.dart',
  ];

  final mixedImportViolations = <String>[];
  final hardcodedHints = <String>[];

  for (final file in dartFiles) {
    final normalizedPath = file.path.replaceAll('/', r'\');
    final inScope = targetRoots.any(
      (rootPath) => normalizedPath.contains(rootPath),
    );
    if (!inScope) {
      continue;
    }

    final content = file.readAsStringSync();
    final hasDesignSystem = _designSystemImport.hasMatch(content);
    final hasLegacyDesign = _legacyDesignImport.hasMatch(content);

    if (hasDesignSystem && hasLegacyDesign) {
      mixedImportViolations.add(file.path);
    }

    if (!file.path.contains(r'\design_system\') &&
        !file.path.contains(r'\ui\lexi_design\')) {
      if (_hardColor.hasMatch(content)) {
        hardcodedHints.add('${file.path} -> hard-coded Color found');
      }
      if (_hardSpacing.hasMatch(content)) {
        hardcodedHints.add('${file.path} -> hard-coded spacing candidate');
      }
    }
  }

  if (mixedImportViolations.isNotEmpty) {
    stderr.writeln('Design token lint failed: mixed token sources in a file.');
    for (final path in mixedImportViolations) {
      stderr.writeln(' - $path');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Design token lint passed: no mixed token imports found.');
  if (hardcodedHints.isNotEmpty) {
    stdout.writeln(
      'Hints: consider replacing hard-coded values with tokens where possible:',
    );
    for (final hint in hardcodedHints.take(50)) {
      stdout.writeln(' - $hint');
    }
    if (hardcodedHints.length > 50) {
      stdout.writeln(' - ... ${hardcodedHints.length - 50} more');
    }
  }
}
