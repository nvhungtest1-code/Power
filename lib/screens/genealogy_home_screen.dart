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

  Future<void> _addParentPerson(Person child, {required String parentType}) async {
    final targetGender = parentType == 'father' ? 'Nam' : 'Nữ';
    final defaultFatherId = parentType == 'father' ? null : child.fatherId;
    final defaultMotherId = parentType == 'mother' ? null : child.motherId;

    await _addPerson(
      initialGender: targetGender,
      defaultFatherId: defaultFatherId,
      defaultMotherId: defaultMotherId,
    );

    if (!mounted) return;

    final latestPerson = people.isEmpty ? null : people.last;
    if (latestPerson == null) return;

    setState(() {
      if (parentType == 'father') {
        final childPerson = people.firstWhere((p) => p.id == child.id, orElse: () => child);
        childPerson.fatherId = latestPerson.id;
      } else {
        final childPerson = people.firstWhere((p) => p.id == child.id, orElse: () => child);
        childPerson.motherId = latestPerson.id;
      }
    });

    await _savePeople();
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
          onAddParent: _addParentPerson,
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

  int _generationOf(Person person, Map<int, int> cache) {
    if (cache.containsKey(person.id)) return cache[person.id]!;

    final parents = [person.fatherId, person.motherId]
        .whereType<int>()
        .map((parentId) => _personById(parentId))
        .whereType<Person>()
        .toList();

    if (parents.isEmpty) {
      cache[person.id] = 0;
      return 0;
    }

    final parentGeneration = parents
        .map((parent) => _generationOf(parent, cache))
        .reduce((a, b) => a > b ? a : b);
    cache[person.id] = parentGeneration + 1;
    return cache[person.id]!;
  }

  List<List<Person>> _generationRows() {
    final map = <int, List<Person>>{};
    final cache = <int, int>{};

    for (final person in people) {
      final generation = _generationOf(person, cache);
      map.putIfAbsent(generation, () => []).add(person);
    }

    final rows = map.keys.toList()..sort();
    return rows.map((generation) {
      final row = List<Person>.from(map[generation]!);
      row.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return row;
    }).toList();
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
    final isMale = person.gender == 'Nam' || person.gender == 'male';

    return InkWell(
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
              backgroundColor: isMale ? Colors.blue.shade100 : Colors.pink.shade100,
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
            if (person.description.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                person.description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ],
            if (person.birthDate != null || person.deathDate != null)
              Text(
                '${person.birthDate?.year ?? '?'} – ${person.deathDate?.year ?? (person.birthDate == null ? '?' : 'nay')}',
              ),
          ],
        ),
      ),
    );
  }

  List<Offset> _rowCenters(List<Person> row, double availableWidth) {
    if (row.isEmpty) return const <Offset>[];

    const cardWidth = 190.0;
    const gap = 24.0;
    final totalWidth = row.length * cardWidth + (row.length - 1) * gap;
    final startX = (availableWidth - totalWidth) / 2;

    return List.generate(row.length, (index) {
      final x = startX + index * (cardWidth + gap) + (cardWidth / 2);
      return Offset(x, 100);
    });
  }

  Widget _buildTree() {
    final rows = _generationRows();
    if (rows.isEmpty) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final row = rows[rowIndex];
                    final currentCenters = _rowCenters(row, constraints.maxWidth);
                    final previousRow = rowIndex == 0 ? <Person>[] : rows[rowIndex - 1];
                    final previousCenters = rowIndex == 0
                        ? const []
                        : _rowCenters(previousRow, constraints.maxWidth);

                    return SizedBox(
                      height: 170,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _FamilyConnectionPainter(
                                row: row,
                                previousRow: previousRow,
                                currentCenters: currentCenters,
                                previousCenters: previousCenters,
                              ),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: row
                                .map(
                                  (person) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: _personCard(person),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  class _FamilyConnectionPainter extends CustomPainter {
    const _FamilyConnectionPainter({
      required this.row,
      required this.previousRow,
      required this.currentCenters,
      required this.previousCenters,
    });

    final List<Person> row;
    final List<Person> previousRow;
    final List<Offset> currentCenters;
    final List<Offset> previousCenters;

    @override
    void paint(Canvas canvas, Size size) {
      if (previousRow.isEmpty) return;

      final paint = Paint()
        ..color = Colors.indigo.withOpacity(0.55)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      for (var i = 0; i < row.length; i++) {
        final person = row[i];
        final parentId = person.fatherId ?? person.motherId;
        if (parentId == null) continue;

        final parentIndex = previousRow.indexWhere((p) => p.id == parentId);
        if (parentIndex < 0) continue;

        final parentCenter = previousCenters[parentIndex];
        final childCenter = currentCenters[i];
        final midY = 82.0;

        final parentAnchor = Offset(parentCenter.dx, size.height - 10);
        final childAnchor = Offset(childCenter.dx, 10);

        canvas.drawLine(parentAnchor, Offset(parentCenter.dx, midY), paint);
        canvas.drawLine(Offset(parentCenter.dx, midY), Offset(childCenter.dx, midY), paint);
        canvas.drawLine(Offset(childCenter.dx, midY), childAnchor, paint);
      }
    }

    @override
    bool shouldRepaint(covariant _FamilyConnectionPainter oldDelegate) =>
        oldDelegate.row != row ||
        oldDelegate.previousRow != previousRow ||
        oldDelegate.currentCenters != currentCenters ||
        oldDelegate.previousCenters != previousCenters;
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
