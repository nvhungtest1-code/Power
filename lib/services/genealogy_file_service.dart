import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../person.dart';

class GenealogyFileService {
  Future<void> exportPeople(List<Person> people) async {
    final data = <String, dynamic>{
      'format': 'power-genealogy',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'people': people.map((person) => person.toJson()).toList(),
    };

    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );

    await FileSaver.instance.saveFile(
      name:
          'gia_pha_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}',
      bytes: bytes,
      fileExtension: 'json',
      mimeType: MimeType.custom,
      customMimeType: 'application/json',
    );
  }

  Future<List<Person>?> importPeople({
    required GlobalKey<NavigatorState> navigatorKey,
    required List<Person> currentPeople,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw const FormatException('Không đọc được nội dung file.');
    }

    final decoded = jsonDecode(utf8.decode(bytes));
    final dynamic rawPeople =
        decoded is List ? decoded : (decoded is Map ? decoded['people'] : null);
    if (rawPeople is! List) {
      throw const FormatException(
        'JSON phải là một danh sách người hoặc object có trường "people".',
      );
    }

    final imported = rawPeople.map<Person>((item) {
      if (item is! Map) {
        throw const FormatException('Một bản ghi người không hợp lệ.');
      }
      return Person.fromJson(Map<String, dynamic>.from(item));
    }).toList();

    final ids = imported.map((p) => p.id).toList();
    if (ids.toSet().length != ids.length) {
      throw const FormatException('File có mã thành viên bị trùng.');
    }
    if (imported.any((p) => p.id <= 0 || p.name.trim().isEmpty)) {
      throw const FormatException('Mỗi người phải có mã dương và họ tên.');
    }

    final importedIds = ids.toSet();
    for (final person in imported) {
      if ((person.fatherId != null && !importedIds.contains(person.fatherId)) ||
          (person.motherId != null && !importedIds.contains(person.motherId)) ||
          person.spouseIds.any((id) => !importedIds.contains(id))) {
        throw FormatException(
            'Liên kết cha/mẹ/vợ/chồng của "${person.name}" trỏ tới mã không tồn tại.');
      }
      if (person.fatherId == person.id || person.motherId == person.id) {
        throw FormatException('"${person.name}" không thể là cha/mẹ của chính mình.');
      }
    }

    final replace = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập dữ liệu JSON?'),
        content: Text(
          'File có ${imported.length} thành viên. Dữ liệu hiện tại (${currentPeople.length} thành viên) sẽ bị thay thế hoàn toàn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thay thế dữ liệu'),
          ),
        ],
      ),
    );

    if (replace != true) return null;
    return imported;
  }
}
