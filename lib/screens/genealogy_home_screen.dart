import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../person.dart';
import '../services/genealogy_file_service.dart';
import 'add_edit_person_screen.dart';
import 'person_detail_screen.dart';

class _FamilyConnectionPainter extends CustomPainter {
  const _FamilyConnectionPainter({
    required this.rows,
    required this.rowCenters,
    required this.rowTopOffsets,
  });

  final List<List<Person>> rows;
  final List<List<Offset>> rowCenters;
  final List<double> rowTopOffsets;

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.length < 2) return;

    final paint = Paint()
      ..color = Colors.indigo.withOpacity(0.55)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final currentRow = rows[rowIndex];
      final previousRow = rows[rowIndex - 1];
      final currentCenters = rowCenters[rowIndex];
      final previousCenters = rowCenters[rowIndex - 1];
      final currentTop = rowTopOffsets[rowIndex];
      final previousTop = rowTopOffsets[rowIndex - 1];

      for (var i = 0; i < currentRow.length; i++) {
        final child = currentRow[i];
        final parentId = child.fatherId ?? child.motherId;
        if (parentId == null) continue;

        final parentIndex = previousRow.indexWhere((p) => p.id == parentId);
        if (parentIndex < 0) continue;

        final parentCenter = previousCenters[parentIndex];
        final childCenter = currentCenters[i];
        final parentAnchor = Offset(parentCenter.dx, previousTop + 150);
        final childAnchor = Offset(childCenter.dx, currentTop + 10);
        final midY = (parentAnchor.dy + childAnchor.dy) / 2;

        canvas.drawLine(parentAnchor, Offset(parentCenter.dx, midY), paint);
        canvas.drawLine(Offset(parentCenter.dx, midY), Offset(childCenter.dx, midY), paint);
        canvas.drawLine(Offset(childCenter.dx, midY), childAnchor, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FamilyConnectionPainter oldDelegate) =>
      oldDelegate.rows != rows ||
      oldDelegate.rowCenters != rowCenters ||
      oldDelegate.rowTopOffsets != rowTopOffsets;
}

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

  Future<void> _addSiblingPerson(Person currentPerson) async {
    await _addPerson(
      defaultFatherId: currentPerson.fatherId,
      defaultMotherId: currentPerson.motherId,
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
          onAddSibling: _addSiblingPerson,
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

  List<Person> _orderRowByFamily(List<Person> row) {
    final ordered = List<Person>.from(row);
    ordered.sort((a, b) {
      final aParentId = a.fatherId ?? a.motherId ?? a.id;
      final bParentId = b.fatherId ?? b.motherId ?? b.id;

      final parentCompare = aParentId.compareTo(bParentId);
      if (parentCompare != 0) return parentCompare;

      final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (nameCompare != 0) return nameCompare;

      return a.id.compareTo(b.id);
    });
    return ordered;
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
      final row = _orderRowByFamily(List<Person>.from(map[generation]!));
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

  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              offset: const Offset(0, 6),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personCard(Person person) {
    final isMale = person.gender == 'Nam' || person.gender == 'male';
    final accentColor = isMale ? Colors.blue : Colors.pink;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetailScreen(person),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 180,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                (isMale ? Colors.blue : Colors.pink).withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withOpacity(0.38),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 14,
                color: accentColor.withOpacity(0.12),
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: accentColor.withOpacity(0.12),
                child: Icon(
                  isMale ? Icons.man_rounded : Icons.woman_rounded,
                  color: accentColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                person.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  person.gender,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (person.description.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  person.description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    height: 1.3,
                  ),
                ),
              ],
              if (person.birthDate != null || person.deathDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${person.birthDate?.year ?? '?'} – ${person.deathDate?.year ?? (person.birthDate == null ? '?' : 'nay')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Offset> _rowCenters(List<Person> row, double availableWidth) {
    if (row.isEmpty) return const <Offset>[];

    final safeWidth = availableWidth.isFinite ? availableWidth : 1200.0;
    const cardWidth = 190.0;
    const gap = 24.0;
    final totalWidth = row.length * cardWidth + (row.length - 1) * gap;
    final startX = (safeWidth - totalWidth) / 2;

    return List.generate(row.length, (index) {
      final x = startX + index * (cardWidth + gap) + (cardWidth / 2);
      return Offset(x, 0);
    });
  }

  double _treeCanvasWidth(List<List<Person>> rows, double viewportWidth) {
    if (rows.isEmpty) return viewportWidth.isFinite ? viewportWidth : 1200.0;

    const cardWidth = 190.0;
    const gap = 24.0;
    const padding = 80.0;
    final widestRowWidth = rows
        .map((row) => row.length * cardWidth + (row.length - 1) * gap)
        .reduce((a, b) => a > b ? a : b);
    final desiredWidth = widestRowWidth + padding;
    final safeViewport = viewportWidth.isFinite ? viewportWidth : 1200.0;
    return desiredWidth > safeViewport ? desiredWidth : safeViewport;
  }

  Widget _buildTree() {
    final rows = _generationRows();
    if (rows.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.family_restroom_rounded, size: 48, color: Colors.indigo.shade300),
              const SizedBox(height: 12),
              const Text(
                'Chưa có dữ liệu gia phả',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nhấn “Thêm thành viên” để bắt đầu xây dựng cây gia đình của bạn.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(120),
        minScale: 0.25,
        maxScale: 2.0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final canvasWidth = _treeCanvasWidth(rows, viewportWidth);

            const rowHeight = 210.0;
            final rowCenters = <List<Offset>>[];
            final rowTopOffsets = <double>[];
            double currentTop = 24;

            for (final row in rows) {
              rowCenters.add(_rowCenters(row, canvasWidth));
              rowTopOffsets.add(currentTop);
              currentTop += rowHeight;
            }

            final totalHeight = currentTop + 24;

            return SizedBox(
              width: canvasWidth,
              height: totalHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FamilyConnectionPainter(
                        rows: rows,
                        rowCenters: rowCenters,
                        rowTopOffsets: rowTopOffsets,
                      ),
                    ),
                  ),
                  ...List.generate(rows.length, (rowIndex) {
                    final row = rows[rowIndex];
                    return Positioned(
                      top: rowTopOffsets[rowIndex],
                      left: 0,
                      right: 0,
                      child: Row(
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
                    );
                  }),
                ],
              ),
            );
          },
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
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.indigo.shade50,
                    Colors.white,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            label: 'Thành viên',
                            value: '${people.length}',
                            icon: Icons.groups_rounded,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            label: 'Thế hệ',
                            value: '${_generationRows().length}',
                            icon: Icons.account_tree_rounded,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Bấm vào mỗi thành viên để xem và chỉnh sửa chi tiết.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _buildTree(),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addPerson,
        icon: const Icon(Icons.add),
        label: const Text('Thêm'),
      ),
    );
  }
}
