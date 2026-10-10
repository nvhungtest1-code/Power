import 'package:flutter/material.dart';

import '../person.dart';

class PersonDetailScreen extends StatelessWidget {
  const PersonDetailScreen({
    super.key,
    required this.person,
    required this.people,
    required this.onOpenPerson,
    required this.onEditPerson,
    required this.onDeletePerson,
    required this.onAddChild,
    required this.onAddSpouse,
  });

  final Person person;
  final List<Person> people;
  final void Function(Person person) onOpenPerson;
  final Future<void> Function(Person person) onEditPerson;
  final Future<bool> Function(Person person) onDeletePerson;
  final Future<void> Function(Person person, {required String gender}) onAddChild;
  final Future<void> Function(Person person) onAddSpouse;

  Person? _personById(int? id) {
    if (id == null) return null;
    for (final member in people) {
      if (member.id == id) return member;
    }
    return null;
  }

  Person? _father() => _personById(person.fatherId);
  Person? _mother() => _personById(person.motherId);

  List<Person> _spouses() => person.spouseIds
      .map(_personById)
      .whereType<Person>()
      .toList();

  List<Person> _children() => people
      .where((p) => p.fatherId == person.id || p.motherId == person.id)
      .toList();

  bool get _isMale => person.gender == 'Nam' || person.gender == 'male';

  Future<void> _handleMenuAction(BuildContext context, String value) async {
    if (value == 'edit') {
      await onEditPerson(person);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (value == 'delete') {
      final deleted = await onDeletePerson(person);
      if (deleted && context.mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (value == 'add-son') {
      await onAddChild(person, gender: 'Nam');
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (value == 'add-daughter') {
      await onAddChild(person, gender: 'Nữ');
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (value == 'add-spouse') {
      await onAddSpouse(person);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final father = _father();
    final mother = _mother();
    final spouses = _spouses();
    final children = _children();

    return Scaffold(
      appBar: AppBar(
        title: Text(person.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Thao tác',
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Sửa thông tin')),
              const PopupMenuItem(value: 'delete', child: Text('Xóa thành viên')),
              const PopupMenuItem(value: 'add-son', child: Text('Thêm con trai')),
              const PopupMenuItem(value: 'add-daughter', child: Text('Thêm con gái')),
              const PopupMenuItem(value: 'add-spouse', child: Text('Thêm vợ/chồng')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileHeader(
                person: person,
                isMale: _isMale,
              ),
              const SizedBox(height: 20),
              const Text(
                'Thông tin cá nhân',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _InfoRow(label: 'Giới tính', value: person.gender),
              _InfoRow(
                label: 'Ngày sinh',
                value: person.birthDate == null
                    ? 'Chưa có'
                    : '${person.birthDate!.day.toString().padLeft(2, '0')}/${person.birthDate!.month.toString().padLeft(2, '0')}/${person.birthDate!.year}',
              ),
              _InfoRow(
                label: 'Ngày mất',
                value: person.deathDate == null
                    ? 'Chưa có'
                    : '${person.deathDate!.day.toString().padLeft(2, '0')}/${person.deathDate!.month.toString().padLeft(2, '0')}/${person.deathDate!.year}',
              ),
              const SizedBox(height: 20),
              const Text(
                'Thông tin bố mẹ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _PersonRelationTile(
                label: 'Cha',
                person: father,
                onOpenPerson: onOpenPerson,
              ),
              _PersonRelationTile(
                label: 'Mẹ',
                person: mother,
                onOpenPerson: onOpenPerson,
              ),
              const SizedBox(height: 20),
              const Text(
                'Vợ / chồng',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (spouses.isEmpty)
                const Text('Chưa có thông tin vợ/chồng.')
              else
                ...spouses.map(
                  (member) => _PersonRelationTile(
                    label: 'Vợ/Chồng',
                    person: member,
                    onOpenPerson: onOpenPerson,
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'Con cái',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (children.isEmpty)
                const Text('Chưa có thông tin con cái.')
              else
                ...children.map(
                  (member) => _PersonRelationTile(
                    label: member.gender == 'Nam' || member.gender == 'male'
                        ? 'Con trai'
                        : 'Con gái',
                    person: member,
                    onOpenPerson: onOpenPerson,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.person,
    required this.isMale,
  });

  final Person person;
  final bool isMale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMale ? Colors.blue : Colors.pink,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: isMale ? Colors.blue.shade100 : Colors.pink.shade100,
            child: Icon(
              isMale ? Icons.man : Icons.woman,
              size: 32,
              color: isMale ? Colors.blue : Colors.pink,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  person.gender,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PersonRelationTile extends StatelessWidget {
  const _PersonRelationTile({
    required this.label,
    required this.person,
    required this.onOpenPerson,
  });

  final String label;
  final Person? person;
  final void Function(Person person) onOpenPerson;

  @override
  Widget build(BuildContext context) {
    if (person == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('$label: Chưa xác định'),
      );
    }

    return InkWell(
      onTap: () => onOpenPerson(person!),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  person!.gender == 'Nam' || person!.gender == 'male'
                      ? Colors.blue.shade100
                      : Colors.pink.shade100,
              child: Icon(
                person!.gender == 'Nam' || person!.gender == 'male'
                    ? Icons.man
                    : Icons.woman,
                color: person!.gender == 'Nam' || person!.gender == 'male'
                    ? Colors.blue
                    : Colors.pink,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 2),
                  Text(
                    person!.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
