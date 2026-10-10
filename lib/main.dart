import 'dart:convert';

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

  Future<void> _showAddDialog() async {
    final nameController = TextEditingController();
    String gender = 'Nam';
    int? fatherId;
    int? motherId;
    DateTime? birthDate;
    DateTime? deathDate;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm thành viên'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: gender,
                    decoration: const InputDecoration(
                      labelText: 'Giới tính',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                      DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                      DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                      DropdownMenuItem(value: 'unknown', child: Text('Chưa rõ')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => gender = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: fatherId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cha',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Chưa chọn')),
                      ...people.map((p) => DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text(p.name, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (value) => setDialogState(() => fatherId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: motherId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Mẹ',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Chưa chọn')),
                      ...people.map((p) => DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text(p.name, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (value) => setDialogState(() => motherId = value),
                  ),
                  const SizedBox(height: 12),
                  _dateTile(
                    label: 'Ngày sinh',
                    value: birthDate,
                    onTap: () async {
                      final value = await _pickDate(context, birthDate);
                      if (value != null) setDialogState(() => birthDate = value);
                    },
                    onClear: () => setDialogState(() => birthDate = null),
                  ),
                  _dateTile(
                    label: 'Ngày mất',
                    value: deathDate,
                    onTap: () async {
                      final value = await _pickDate(context, deathDate);
                      if (value != null) setDialogState(() => deathDate = value);
                    },
                    onClear: () => setDialogState(() => deathDate = null),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập họ và tên.')),
                  );
                  return;
                }
                if (fatherId != null && fatherId == motherId) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cha và mẹ không thể là cùng một người.')),
                  );
                  return;
                }
                final person = Person(
                  id: _nextId++,
                  name: name,
                  gender: gender,
                  fatherId: fatherId,
                  motherId: motherId,
                  birthDate: _dateOnly(birthDate),
                  deathDate: _dateOnly(deathDate),
                );
                setState(() => people.add(person));
                await _savePeople();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
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
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _loading ? null : _showAddDialog,
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
          onPressed: _loading ? null : _showAddDialog,
          icon: const Icon(Icons.add),
          label: const Text('Thêm'),
        ),
      ),
    );
  }
}
