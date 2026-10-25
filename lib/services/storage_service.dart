import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _storageKey = 'easyrent_master_db_v3';

  static String _baseDirPath() {
    final String tmp = Directory.systemTemp.path;
    if (tmp.contains('/cache')) return tmp.split('/cache').first;
    if (tmp.contains('/code_cache')) return tmp.split('/code_cache').first;
    return Directory.systemTemp.parent.path;
  }

  static List<File> _getDataFiles() {
    final List<File> list = [];
    try {
      final base = _baseDirPath();
      final dir = Directory('$base/files');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      list.add(File('${dir.path}/easyrent_data_v3.json'));
      list.add(File('$base/easyrent_data_v3.json'));
    } catch (_) {}
    try {
      list.add(File('${Directory.systemTemp.path}/easyrent_data_v3.json'));
    } catch (_) {}
    return list;
  }

  static File _getSettingsFile() {
    final base = _baseDirPath();
    final dir = Directory('$base/files');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/easyrent_settings.json');
  }

  static Future<String?> loadRawData() async {
    for (final f in _getDataFiles()) {
      try {
        if (f.existsSync()) {
          final content = f.readAsStringSync();
          if (content.trim().isNotEmpty) return content;
        }
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) return raw;
    } catch (_) {}
    return null;
  }

  static Future<void> saveRawData(String jsonStr) async {
    for (final f in _getDataFiles()) {
      try {
        f.writeAsStringSync(jsonStr, flush: true);
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonStr);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    try {
      final f = _getSettingsFile();
      if (f.existsSync()) {
        final raw = f.readAsStringSync();
        if (raw.trim().isNotEmpty) {
          return Map<String, dynamic>.from(jsonDecode(raw) as Map);
        }
      }
    } catch (_) {}
    try {
      final p = await SharedPreferences.getInstance();
      return {
        'pin': p.getString('pin') ?? '1234',
        'lock': p.getBool('lock') ?? false,
        'dark': p.getBool('dark') ?? false,
        'hasPin': p.containsKey('pin'),
      };
    } catch (_) {
      return {'pin': '1234', 'lock': false, 'dark': false, 'hasPin': false};
    }
  }

  static Future<void> saveSettings({
    required String pin,
    required bool lock,
    required bool dark,
  }) async {
    final map = {'pin': pin, 'lock': lock, 'dark': dark, 'hasPin': true};
    try {
      _getSettingsFile().writeAsStringSync(jsonEncode(map), flush: true);
    } catch (_) {}
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('pin', pin);
      await p.setBool('lock', lock);
      await p.setBool('dark', dark);
    } catch (_) {}
  }

  static File writeTempFile(String fileName, String content) {
    final f = File('${Directory.systemTemp.path}/$fileName');
    f.writeAsStringSync(content, flush: true);
    return f;
  }
}
