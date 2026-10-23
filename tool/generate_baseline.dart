import 'dart:convert';
import 'dart:io';

void main() {
  final libDir = Directory('lib');
  final baseline = <String, Map<String, int>>{};

  final colorRegex = RegExp(r'Color\(0x[0-9a-fA-F]+\)|Colors\.(?!transparent)[a-zA-Z0-9_\.]+|Color\.fromRGBO\([^)]+\)|Color\.fromARGB\([^)]+\)');
  final fontSizeRegex = RegExp(r'fontSize:\s*[0-9\.]+');

  for (final file in libDir.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final relativePath = file.path.replaceAll('\\', '/');

    if (relativePath.contains('core/theme')) continue;

    final content = file.readAsStringSync();
    final colorCount = colorRegex.allMatches(content).length;
    final fontSizeCount = fontSizeRegex.allMatches(content).length;

    if (colorCount > 0 || fontSizeCount > 0) {
      baseline[relativePath] = {
        'colors': colorCount,
        'fontSizes': fontSizeCount,
      };
    }
  }

  final jsonString = const JsonEncoder.withIndent('  ').convert(baseline);
  File('docs/guard_baseline.json').writeAsStringSync(jsonString);
  print('Generated docs/guard_baseline.json with ${baseline.length} files.');
}
