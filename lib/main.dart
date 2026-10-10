import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const GenealogyApp());

class Person {
  final int id;
  String name;
  String gender;
  int? fatherId;
  int? motherId;
  List<int> spouseIds;
  DateTime? birthDate;
  DateTime? deathDate;

  // Compatibility with the previous version of the app.
  int? get parentId => fatherId ?? motherId;
  set parentId(int? value) => fatherId = value;

  Person({
    required this.id,
    required this.name,
    required this.gender,
    int? parentId,
    this.fatherId,
    this.motherId,
    List<int>? spouseIds,
    this.birthDate,
    this.deathDate,
  }) : spouseIds = spouseIds ?? [] {
    fatherId ??= parentId;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gender': gender,
        'fatherId': fatherId,
        'motherId': motherId,
        'spouseIds': spouseIds,
        'birthDate': birthDate?.toIso8601String(),
        'deathDate': deathDate?.toIso8601String(),
      };

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? json['fullName'] as String? ?? '',
        gender: json['gender'] as String? ?? 'unknown',
        fatherId: (json['fatherId'] ?? json['parentId']) is num
            ? ((json['fatherId'] ?? json['parentId']) as num).toInt()
            : null,
        motherId: json['motherId'] is num
            ? (json['motherId'] as num).toInt()
            : null,
        spouseIds: (json['spouseIds'] as List<dynamic>? ?? [])
            .whereType<num>()
            .map((id) => id.toInt())
            .toList(),
        birthDate: _parseDate(json['birthDate']),
        deathDate: _parseDate(json['deathDate']),
      );

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class GenealogyApp extends StatefulWidget {
  const GenealogyApp({super.key});

  @override
  State<GenealogyApp> createState() => _GenealogyAppState();
}

class _GenealogyAppState extends State<GenealogyApp> {
  static const _storageKey = 'power_genealogy_members_v1';
  final List<Person> people = [];
  bool _loading = true;
  int _nextId = 1;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        people
          ..clear()
          ..addAll(decoded.map((item) =>
              Person.fromJson(Map<String, dynamic>.from(item as Map))));
      }
      _nextId = people.isEmpty
          ? 1
          : people.map((person) => person.id).reduce((a, b) => a > b ? a : b) + 1;
    } catch (_) {
      // If cached data is invalid, start empty rather than crash.
      people.clear();
      _nextId = 1;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _savePeople() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(people.map((person) => person.toJson()).toList()),
    );
  }

  DateTime? _dateOnly(DateTime? value) =>
      value == null ? null : DateTime(value.year, value.month, value.day);

  Future<void> _addPerson() async {
    final person = await Navigator.of(context).push<Person>(
      MaterialPageRoute(
        builder: (_) => AddPersonScreen(people: List<Person>.unmodifiable(people), nextId: _nextId),
      ),
    );
    if (person == null || !mounted) return;
    setState(() {
      people.add(person);
      for (final spouseId in person.spouseIds) {
        final spouse = people.where((p) => p.id == spouseId).firstOrNull;
        if (spouse != null && !spouse.spouseIds.contains(person.id)) {
          spouse.spouseIds.add(person.id);
        }
      }
      _nextId = person.id + 1;
    });
    await _savePeople();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm thành viên.')),
      );
    }
  }

  Future<void> _exportJson() async {
    try {
      final data = <String, dynamic>{
        'format': 'power-genealogy',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'people': people.map((person) => person.toJson()).toList(),
      };
      final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
      await FileSaver.instance.saveFile(
        name: 'gia_pha_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}',
        bytes: bytes,
        fileExtension: 'json',
        mimeType: MimeType.custom,
        customMimeType: 'application/json',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xuất dữ liệu gia phả thành file JSON.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xuất JSON: $e')),
        );
      }
    }
  }

  Future<void> _importJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) throw const FormatException('Không đọc được nội dung file.');
      final decoded = jsonDecode(utf8.decode(bytes));
      final dynamic rawPeople = decoded is List ? decoded : (decoded is Map ? decoded['people'] : null);
      if (rawPeople is! List) {
        throw const FormatException('JSON phải là một danh sách người hoặc object có trường "people".');
      }
      final imported = rawPeople.map<Person>((item) {
        if (item is! Map) throw const FormatException('Một bản ghi người không hợp lệ.');
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
          throw FormatException('Liên kết cha/mẹ/vợ/chồng của "${person.name}" trỏ tới mã không tồn tại.');
        }
        if (person.fatherId == person.id || person.motherId == person.id) {
          throw FormatException('"${person.name}" không thể là cha/mẹ của chính mình.');
        }
      }
      if (!mounted) return;
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nhập dữ liệu JSON?'),
          content: Text('File có ${imported.length} thành viên. Dữ liệu hiện tại (${people.length} thành viên) sẽ bị thay thế hoàn toàn.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Thay thế dữ liệu')),
          ],
        ),
      );
      if (replace != true || !mounted) return;
      setState(() {
        people
          ..clear()
          ..addAll(imported);
        _nextId = people.isEmpty ? 1 : people.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;
      });
      await _savePeople();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã nhập ${people.length} thành viên.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể nhập JSON: $e')),
        );
      }
    }
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(1500),
      lastDate: DateTime(now.year + 1),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final text = value == null
        ? 'Chưa chọn'
        : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.calendar_month),
            label: Text('$label: $text', overflow: TextOverflow.ellipsis),
          ),
        ),
        IconButton(onPressed: value == null ? null : onClear, icon: const Icon(Icons.clear)),
      ]),
    );
  }

  int? _treeParentId(Person person) => person.fatherId ?? person.motherId;

  List<Person> _childrenOf(int parentId) =>
      people.where((p) => _treeParentId(p) == parentId).toList();

  Future<void> _deletePerson(Person person) async {
    final hasChildren = people.any((p) =>
        p.fatherId == person.id || p.motherId == person.id);
    if (hasChildren) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xóa: thành viên này đang được liên kết làm cha hoặc mẹ.')),
      );
      return;
    }
    setState(() {
      people.removeWhere((p) => p.id == person.id);
      for (final p in people) {
        p.spouseIds.remove(person.id);
        if (p.fatherId == person.id) p.fatherId = null;
        if (p.motherId == person.id) p.motherId = null;
      }
    });
    await _savePeople();
  }

  void _showPerson(Person person) {
    final father = people.where((p) => p.id == person.fatherId).firstOrNull;
    final mother = people.where((p) => p.id == person.motherId).firstOrNull;
    final spouses = people.where((p) => person.spouseIds.contains(p.id)).toList();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(person.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Giới tính: ${person.gender}'),
            Text('Ngày sinh: ${_formatDate(person.birthDate)}'),
            Text('Ngày mất: ${_formatDate(person.deathDate)}'),
            Text('Cha: ${father?.name ?? 'Chưa rõ'}'),
            Text('Mẹ: ${mother?.name ?? 'Chưa rõ'}'),
            Text('Vợ/chồng: ${spouses.isEmpty ? 'Chưa có dữ liệu' : spouses.map((p) => p.name).join(', ')}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Đóng')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Xóa thành viên?'),
                  content: Text('Bạn có chắc muốn xóa ${person.name}?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
                  ],
                ),
              );
              if (confirmed == true) await _deletePerson(person);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) => date == null
      ? 'Chưa có'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Widget _personCard(Person person) {
    final children = _childrenOf(person.id);
    final isMale = person.gender == 'Nam' || person.gender == 'male';
    return Column(
      children: [
        InkWell(
          onTap: () => _showPerson(person),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 190,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isMale ? Colors.blue : Colors.pink, width: 2),
              boxShadow: const [BoxShadow(blurRadius: 6, color: Color(0x22000000), offset: Offset(0, 3))],
            ),
            child: Column(children: [
              CircleAvatar(
                backgroundColor: isMale ? Colors.blue.shade100 : Colors.pink.shade100,
                child: Icon(isMale ? Icons.man : Icons.woman, color: isMale ? Colors.blue : Colors.pink),
              ),
              const SizedBox(height: 10),
              Text(person.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(person.gender, style: TextStyle(color: Colors.grey.shade600)),
              if (person.birthDate != null || person.deathDate != null)
                Text('${person.birthDate?.year ?? '?'} – ${person.deathDate?.year ?? (person.birthDate == null ? '?' : 'nay')}'),
            ]),
          ),
        ),
        if (children.isNotEmpty) ...[
          Container(width: 2, height: 28, color: Colors.grey),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: children.map((child) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _personCard(child),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTree() {
    final roots = people.where((p) => _treeParentId(p) == null).toList();
    if (roots.isEmpty) {
      return const Center(child: Text('Chưa có dữ liệu gia phả. Nhấn “Thêm thành viên” để bắt đầu.'));
    }
    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.25,
      maxScale: 2.5,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: roots.map((p) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _personCard(p),
          )).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gia Phả',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo), useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('🌳 Gia Phả Gia Đình', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            PopupMenuButton<String>(
              enabled: !_loading,
              tooltip: 'Sao lưu dữ liệu',
              onSelected: (value) {
                if (value == 'export') _exportJson();
                if (value == 'import') _importJson();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.download), title: Text('Xuất JSON'), contentPadding: EdgeInsets.zero)),
                PopupMenuItem(value: 'import', child: ListTile(leading: Icon(Icons.upload_file), title: Text('Nhập JSON'), contentPadding: EdgeInsets.zero)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _loading ? null : _addPerson,
                icon: const Icon(Icons.person_add),
                label: const Text('Thêm thành viên'),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(children: [
                    Text('Tổng số thành viên: ${people.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 20),
                    const Expanded(child: Text('Bấm vào thành viên để xem thông tin')),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(child: Container(color: Colors.grey.shade100, child: _buildTree())),
              ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed:_addPerson,
          icon: const Icon(Icons.add),
          label: const Text('Thêm'),
        ),
      ),
    );
  }
}


class AddPersonScreen extends StatefulWidget {
  final List<Person> people;
  final int nextId;

  const AddPersonScreen({super.key, required this.people, required this.nextId});

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _gender = 'Nam';
  int? _fatherId;
  int? _motherId;
  final Set<int> _spouseIds = {};
  DateTime? _birthDate;
  DateTime? _deathDate;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<DateTime?> _chooseDate(DateTime? current) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(1500),
      lastDate: DateTime(now.year + 1),
    );
  }

  String _dateText(DateTime? date) => date == null
      ? 'Chưa chọn'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_fatherId != null && _fatherId == _motherId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cha và mẹ không thể là cùng một người.')),
      );
      return;
    }
    setState(() => _saving = true);
    Navigator.of(context).pop(Person(
      id: widget.nextId,
      name: _nameController.text.trim(),
      gender: _gender,
      fatherId: _fatherId,
      motherId: _motherId,
      spouseIds: _spouseIds.toList(),
      birthDate: _birthDate == null ? null : DateTime(_birthDate!.year, _birthDate!.month, _birthDate!.day),
      deathDate: _deathDate == null ? null : DateTime(_deathDate!.year, _deathDate!.month, _deathDate!.day),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sortedPeople = [...widget.people]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm thành viên'),
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Thông tin cơ bản', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Họ và tên *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập họ và tên.' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(labelText: 'Giới tính', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                      DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                      DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                      DropdownMenuItem(value: 'unknown', child: Text('Chưa rõ')),
                    ],
                    onChanged: (value) { if (value != null) setState(() => _gender = value); },
                  ),
                  const SizedBox(height: 24),
                  const Text('Ngày tháng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _dateButton('Ngày sinh', _birthDate, () async { final date = await _chooseDate(_birthDate); if (date != null) setState(() => _birthDate = date); }, () => setState(() => _birthDate = null)),
                  _dateButton('Ngày mất', _deathDate, () async { final date = await _chooseDate(_deathDate); if (date != null) setState(() => _deathDate = date); }, () => setState(() => _deathDate = null)),
                  const SizedBox(height: 24),
                  const Text('Quan hệ gia đình', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _fatherId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Cha', border: OutlineInputBorder()),
                    items: [const DropdownMenuItem<int?>(value: null, child: Text('Chưa xác định')), ...sortedPeople.map((p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)))],
                    onChanged: (value) => setState(() => _fatherId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _motherId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Mẹ', border: OutlineInputBorder()),
                    items: [const DropdownMenuItem<int?>(value: null, child: Text('Chưa xác định')), ...sortedPeople.map((p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)))],
                    onChanged: (value) => setState(() => _motherId = value),
                  ),
                  const SizedBox(height: 16),
                  const Text('Vợ/chồng (có thể chọn nhiều người)'),
                  const SizedBox(height: 4),
                  if (sortedPeople.isEmpty)
                    const Text('Chưa có thành viên khác để liên kết.', style: TextStyle(color: Colors.grey))
                  else
                    ...sortedPeople.map((p) => CheckboxListTile(
                      value: _spouseIds.contains(p.id),
                      title: Text(p.name),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (checked) => setState(() { if (checked == true) { _spouseIds.add(p.id); } else { _spouseIds.remove(p.id); } }),
                    )),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Lưu thành viên')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateButton(String label, DateTime? date, VoidCallback onTap, VoidCallback onClear) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: onTap, icon: const Icon(Icons.calendar_month), label: Text('$label: ${_dateText(date)}', overflow: TextOverflow.ellipsis))),
        IconButton(onPressed: date == null ? null : onClear, tooltip: 'Xóa ngày', icon: const Icon(Icons.clear)),
      ]),
    );
  }
}
