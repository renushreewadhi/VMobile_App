import 'dart:io';

void main() {
  final libDir = Directory('lib');
  final colorCounts = <String, int>{};
  final fontSizeCounts = <String, int>{};
  final widgetCounts = <String, int>{};

  final colorRegex = RegExp(r'Color\(0x[0-9a-fA-F]+\)|Colors\.[a-zA-Z0-9_\.]+|Color\.fromRGBO\([^)]+\)|Color\.fromARGB\([^)]+\)');
  final fontSizeRegex = RegExp(r'fontSize:\s*([0-9\.]+)');
  final widgetRegex = RegExp(r'ElevatedButton|OutlinedButton|TextButton|FilledButton|AppBar|BottomNavigationBar|NavigationBar|AlertDialog');

  for (final file in libDir.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final content = file.readAsStringSync();

    for (final m in colorRegex.allMatches(content)) {
      final val = m.group(0)!;
      if (val == 'Colors.transparent') continue;
      colorCounts[val] = (colorCounts[val] ?? 0) + 1;
    }

    if (!file.path.contains('core/theme') && !file.path.contains('core\\theme')) {
      for (final m in fontSizeRegex.allMatches(content)) {
        final val = m.group(0)!;
        fontSizeCounts[val] = (fontSizeCounts[val] ?? 0) + 1;
      }
    }

    for (final m in widgetRegex.allMatches(content)) {
      final val = m.group(0)!;
      widgetCounts[val] = (widgetCounts[val] ?? 0) + 1;
    }
  }

  print('=== DISTINCT COLORS (${colorCounts.length}) ===');
  final sortedColors = colorCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (final e in sortedColors) {
    print('${e.value.toString().padLeft(5)} : ${e.key}');
  }

  print('\n=== DISTINCT FONT SIZES (${fontSizeCounts.length}) ===');
  final sortedFontSizes = fontSizeCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (final e in sortedFontSizes) {
    print('${e.value.toString().padLeft(5)} : ${e.key}');
  }

  print('\n=== LEGACY WIDGETS (${widgetCounts.length}) ===');
  final sortedWidgets = widgetCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (final e in sortedWidgets) {
    print('${e.value.toString().padLeft(5)} : ${e.key}');
  }
}
