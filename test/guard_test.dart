import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Liquid Glass Guard Test - Ensure color and fontSize counts only go DOWN against baseline', () {
    final baselineFile = File('docs/guard_baseline.json');
    expect(baselineFile.existsSync(), true, reason: 'docs/guard_baseline.json must exist');

    final baselineJson = jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>;

    final libDir = Directory('lib');
    final violations = <String>[];

    final colorRegex = RegExp(r'Color\(0x[0-9a-fA-F]+\)|Colors\.(?!transparent)[a-zA-Z0-9_\.]+|Color\.fromRGBO\([^)]+\)|Color\.fromARGB\([^)]+\)');
    final fontSizeRegex = RegExp(r'fontSize:\s*[0-9\.]+');

    for (final file in libDir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final relativePath = file.path.replaceAll('\\', '/');

      if (relativePath.contains('core/theme') || relativePath.contains('core/widgets')) continue;

      final content = file.readAsStringSync();
      final currentColors = colorRegex.allMatches(content).length;
      final currentFontSizes = fontSizeRegex.allMatches(content).length;

      final baselineData = baselineJson[relativePath] as Map<String, dynamic>?;

      if (baselineData == null) {
        if (currentColors > 0 || currentFontSizes > 0) {
          violations.add('NEW FILE WITH VIOLATIONS: $relativePath (Colors: $currentColors, FontSizes: $currentFontSizes)');
        }
      } else {
        final baselineColors = baselineData['colors'] as int;
        final baselineFontSizes = baselineData['fontSizes'] as int;

        if (currentColors > baselineColors) {
          violations.add('$relativePath: Colors increased from $baselineColors to $currentColors');
        }
        if (currentFontSizes > baselineFontSizes) {
          violations.add('$relativePath: FontSizes increased from $baselineFontSizes to $currentFontSizes');
        }
      }
    }

    if (violations.isNotEmpty) {
      fail('Guard Test Failed - Violations found against baseline:\n${violations.join('\n')}');
    }
  });
}
