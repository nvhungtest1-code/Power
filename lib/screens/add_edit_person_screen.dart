import 'package:flutter/material.dart';

import '../person.dart';

class AddPersonScreen extends StatefulWidget {
  final List<Person> people;
  final int nextId;
  final Person? existingPerson;
  final Future<bool> Function(Person person)? onDelete;
  final String? initialGender;
  final int? defaultFatherId;
  final int? defaultMotherId;
  final Set<int>? initialSpouseIds;

  const AddPersonScreen({
    super.key,
    required this.people,
    required this.nextId,
    this.existingPerson,
    this.onDelete,
    this.initialGender,
    this.defaultFatherId,
    this.defaultMotherId,
    this.initialSpouseIds,
  });

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _gender = 'Nam';
  int? _fatherId;
  int? _motherId;
  final Set<int> _spouseIds = {};
  DateTime? _birthDate;
  DateTime? _deathDate;
  bool _saving = false;

  bool get _isEditing => widget.existingPerson != null;

  @override
  void initState() {
    super.initState();
    final person = widget.existingPerson;
    if (person != null) {
      _nameController.text = person.name;
      _descriptionController.text = person.description;
      _gender = person.gender;
      _fatherId = person.fatherId ?? widget.defaultFatherId;
      _motherId = person.motherId ?? widget.defaultMotherId;
      _spouseIds.addAll(person.spouseIds);
      _birthDate = person.birthDate;
      _deathDate = person.deathDate;
    } else {
      _gender = widget.initialGender ?? 'Nam';
      _fatherId = widget.defaultFatherId;
      _motherId = widget.defaultMotherId;
      if (widget.initialSpouseIds != null) {
        _spouseIds.addAll(widget.initialSpouseIds!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
      id: widget.existingPerson?.id ?? widget.nextId,
      name: _nameController.text.trim(),
      gender: _gender,
      description: _descriptionController.text.trim(),
      fatherId: _fatherId,
      motherId: _motherId,
      spouseIds: _spouseIds.toList(),
      birthDate: _birthDate == null
          ? null
          : DateTime(_birthDate!.year, _birthDate!.month, _birthDate!.day),
      deathDate: _deathDate == null
          ? null
          : DateTime(_deathDate!.year, _deathDate!.month, _deathDate!.day),
    ));
  }

  Future<void> _confirmDelete() async {
    final person = widget.existingPerson;
    final deleteCallback = widget.onDelete;
    if (person == null || deleteCallback == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa thành viên?'),
        content: Text('Bạn có chắc muốn xóa ${person.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    final deleted = await deleteCallback(person);
    if (!mounted) return;

    if (deleted) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedPeople = widget.people
        .where((person) => person.id != widget.existingPerson?.id)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa thành viên' : 'Thêm thành viên'),
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
                  const Text(
                    'Thông tin cơ bản',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập họ và tên.'
                            : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả / Ghi chú',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _gender,
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
                      if (value != null) setState(() => _gender = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ngày tháng',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _dateButton(
                    'Ngày sinh',
                    _birthDate,
                    () async {
                      final date = await _chooseDate(_birthDate);
                      if (date != null) setState(() => _birthDate = date);
                    },
                    () => setState(() => _birthDate = null),
                  ),
                  _dateButton(
                    'Ngày mất',
                    _deathDate,
                    () async {
                      final date = await _chooseDate(_deathDate);
                      if (date != null) setState(() => _deathDate = date);
                    },
                    () => setState(() => _deathDate = null),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Quan hệ gia đình',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _fatherId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cha',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Chưa xác định')),
                      ...sortedPeople.map(
                        (p) => DropdownMenuItem<int?>(
                          value: p.id,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _fatherId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _motherId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Mẹ',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Chưa xác định')),
                      ...sortedPeople.map(
                        (p) => DropdownMenuItem<int?>(
                          value: p.id,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _motherId = value),
                  ),
                  const SizedBox(height: 16),
                  const Text('Vợ/chồng (có thể chọn nhiều người)'),
                  const SizedBox(height: 4),
                  if (sortedPeople.isEmpty)
                    const Text(
                      'Chưa có thành viên khác để liên kết.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ...sortedPeople.map(
                      (p) => CheckboxListTile(
                        value: _spouseIds.contains(p.id),
                        title: Text(p.name),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (checked) => setState(() {
                          if (checked == true) {
                            _spouseIds.add(p.id);
                          } else {
                            _spouseIds.remove(p.id);
                          }
                        }),
                      ),
                    ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_isEditing ? 'Lưu thay đổi' : 'Lưu thành viên'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                  if (_isEditing && widget.onDelete != null) ...[
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: _saving ? null : _confirmDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Xóa thành viên'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateButton(
    String label,
    DateTime? date,
    VoidCallback onTap,
    VoidCallback onClear,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                '$label: ${_dateText(date)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            onPressed: date == null ? null : onClear,
            tooltip: 'Xóa ngày',
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
    );
  }
}
