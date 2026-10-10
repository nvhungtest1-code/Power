import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../person.dart';
import '../services/genealogy_file_service.dart';
import 'add_edit_person_screen.dart';
import 'person_detail_screen.dart';

class GenealogyHomeScreen extends StatefulWidget {
  const GenealogyHomeScreen({
    super.key,
    required this.navigatorKey,
    required this.messengerKey,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  @override
  State<GenealogyHomeScreen> createState() => _GenealogyHomeScreenState();
}

class _GenealogyHomeScreenState extends State<GenealogyHomeScreen> {
  static const _storageKey = 'power_genealogy_members_v1';
  final _fileService = GenealogyFileService();
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
          ? 2
          : people.map((person) => person.id).reduce((a, b) => a > b ? a : b) + 1;
    } catch (_) {
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

  Future<void> _addPerson({
    String? initialGender,
    int? defaultFatherId,
    int? defaultMotherId,
    Set<int>? defaultSpouseIds,
  }) async {
    final person = await widget.navigatorKey.currentState?.push<Person>(
      MaterialPageRoute(
        builder: (_) => AddPersonScreen(
          people: List<Person>.unmodifiable(people),
          nextId: _nextId,
          initialGender: initialGender,
          defaultFatherId: defaultFatherId,
          defaultMotherId: defaultMotherId,
          initialSpouseIds: defaultSpouseIds,
        ),
      ),
    );
    if (person == null || !mounted) return;

    setState(() {
      people.add(person);
      for (final spouseId in person.spouseIds) {
        final spouse = _personById(spouseId);
        if (spouse != null && !spouse.spouseIds.contains(person.id)) {
          spouse.spouseIds.add(person.id);
        }
      }
      _nextId = person.id + 1;
    });

    await _savePeople();
    if (mounted) {
      widget.messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Đã thêm thành viên.')),
      );
    }
  }

  Future<void> _addChildPerson(Person parent, {required String gender}) async {
    Person? spouse;
    for (final spouseId in parent.spouseIds) {
      final candidate = _personById(spouseId);
      if (candidate != null) {
        spouse = candidate;
        break;
      }
    }

    final defaultFatherId = parent.gender == 'Nữ' || parent.gender == 'female'
        ? spouse?.id
        : parent.id;
    final defaultMotherId = parent.gender == 'Nữ' || parent.gender == 'female'
        ? parent.id
        : spouse?.id;

    await _addPerson(
      initialGender: gender,
      defaultFatherId: defaultFatherId,
      defaultMotherId: defaultMotherId,
    );
  }

  Future<void> _addSpousePerson(Person currentPerson) async {
    final currentGender = currentPerson.gender;
    await _addPerson(
      initialGender: currentGender == 'Nam' || currentGender == 'male' ? 'Nữ' : 'Nam',
      defaultSpouseIds: {currentPerson.id},
    );
  }

  Future<void> _openDetailScreen(Person person) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonDetailScreen(
          person: person,
          people: List<Person>.unmodifiable(people),
          onOpenPerson: _openDetailScreen,
          onEditPerson: _editPerson,
          onDeletePerson: _deletePerson,
          onAddChild: _addChildPerson,
          onAddSpouse: _addSpousePerson,
        ),
      ),
    );
  }

  Future<void> _exportJson() async {
    try {
      await _fileService.exportPeople(people);
      if (mounted) {
        widget.messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Đã xuất dữ liệu gia phả thành file JSON.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        widget.messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Không thể xuất JSON: $e')),
        );
      }
    }
  }

  Future<void> _importJson() async {
    try {
      final imported = await _fileService.importPeople(
        navigatorKey: widget.navigatorKey,
        currentPeople: people,
      );
      if (imported == null || !mounted) return;

      setState(() {
        people
          ..clear()
          ..addAll(imported);
        _nextId = people.isEmpty
            ? 1
            : people.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;
      });

      await _savePeople();
      if (mounted) {
        widget.messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Đã nhập ${people.length} thành viên.')),
        );
      }
    } catch (e) {
      if (mounted) {
        widget.messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Không thể nhập JSON: $e')),
        );
      }
    }
  }

  Person? _personById(int? id) {
    if (id == null) return null;
    for (final person in people) {
      if (person.id == id) return person;
    }
    return null;
  }

  int? _treeParentId(Person person) => person.fatherId ?? person.motherId;

  List<Person> _childrenOf(int parentId) =>
      people.where((p) => _treeParentId(p) == parentId).toList();

  Future<bool> _deletePerson(Person person) async {
    final hasChildren = people.any(
      (p) => p.fatherId == person.id || p.motherId == person.id,
    );
    if (hasChildren) {
      widget.messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể xóa: thành viên này đang được liên kết làm cha hoặc mẹ.',
          ),
        ),
      );
      return false;
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
    return true;
  }

  Future<void> _editPerson(Person person) async {
    final updated = await widget.navigatorKey.currentState?.push<Person>(
      MaterialPageRoute(
        builder: (_) => AddPersonScreen(
          people: List<Person>.unmodifiable(people),
          nextId: _nextId,
          existingPerson: person,
          onDelete: _deletePerson,
        ),
      ),
    );
    if (updated == null || !mounted) return;

    setState(() {
      final index = people.indexWhere((p) => p.id == person.id);
      if (index < 0) return;

      for (final other in people) {
        if (other.id != person.id) other.spouseIds.remove(person.id);
      }
      for (final spouseId in updated.spouseIds) {
        final spouse = _personById(spouseId);
        if (spouse != null && !spouse.spouseIds.contains(person.id)) {
          spouse.spouseIds.add(person.id);
        }
      }
      people[index] = updated;
    });

    await _savePeople();
    if (mounted) {
      widget.messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Đã cập nhật thành viên.')),
      );
    }
  }

  Widget _personCard(Person person) {
    final children = _childrenOf(person.id);
    final isMale = person.gender == 'Nam' || person.gender == 'male';

    return Column(
      children: [
        InkWell(
          onTap: () => _openDetailScreen(person),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 190,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMale ? Colors.blue : Colors.pink,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 6,
                  color: Color(0x22000000),
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor:
                      isMale ? Colors.blue.shade100 : Colors.pink.shade100,
                  child: Icon(
                    isMale ? Icons.man : Icons.woman,
                    color: isMale ? Colors.blue : Colors.pink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  person.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(person.gender, style: TextStyle(color: Colors.grey.shade600)),
                if (person.birthDate != null || person.deathDate != null)
                  Text(
                    '${person.birthDate?.year ?? '?'} – ${person.deathDate?.year ?? (person.birthDate == null ? '?' : 'nay')}',
                  ),
              ],
            ),
          ),
        ),
        if (children.isNotEmpty) ...[
          Container(width: 2, height: 28, color: Colors.grey),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _personCard(child),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTree() {
    final roots = people.where((p) => _treeParentId(p) == null).toList();
    if (roots.isEmpty) {
      return const Center(
        child: Text('Chưa có dữ liệu gia phả. Nhấn “Thêm thành viên” để bắt đầu.'),
      );
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
          children: roots
              .map(
                (p) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _personCard(p),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🌳 Gia Phả Gia Đình',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            enabled: !_loading,
            tooltip: 'Sao lưu dữ liệu',
            onSelected: (value) {
              if (value == 'export') _exportJson();
              if (value == 'import') _importJson();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Xuất JSON'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text('Nhập JSON'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
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
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        'Tổng số thành viên: ${people.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 20),
                      const Expanded(
                        child: Text('Bấm vào thành viên để sửa thông tin'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Container(
                    color: Colors.grey.shade100,
                    child: _buildTree(),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addPerson,
        icon: const Icon(Icons.add),
        label: const Text('Thêm'),
      ),
    );
  }
}
