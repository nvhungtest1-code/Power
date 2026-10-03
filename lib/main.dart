import 'package:flutter/material.dart';

void main() {
  runApp(const GenealogyApp());
}

class Person {
  final int id;
  String name;
  String gender;
  int? parentId;

  Person({
    required this.id,
    required this.name,
    required this.gender,
    this.parentId,
  });
}

class GenealogyApp extends StatefulWidget {
  const GenealogyApp({super.key});

  @override
  State<GenealogyApp> createState() => _GenealogyAppState();
}

class _GenealogyAppState extends State<GenealogyApp> {
  int _nextId = 4;

  final List<Person> people = [
    Person(id: 1, name: 'Nguyễn Văn A', gender: 'Nam'),
    Person(id: 2, name: 'Nguyễn Văn B', gender: 'Nam', parentId: 1),
    Person(id: 3, name: 'Nguyễn Văn C', gender: 'Nữ', parentId: 1),
  ];

  void _showAddDialog() {
    final nameController = TextEditingController();
    String gender = 'Nam';
    int? parentId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm thành viên'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Họ và tên',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: gender,
                      decoration: const InputDecoration(
                        labelText: 'Giới tính',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Nam',
                          child: Text('Nam'),
                        ),
                        DropdownMenuItem(
                          value: 'Nữ',
                          child: Text('Nữ'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            gender = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<int?>(
                      value: parentId,
                      decoration: const InputDecoration(
                        labelText: 'Cha / mẹ',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Không chọn'),
                        ),
                        ...people.map(
                          (person) => DropdownMenuItem<int?>(
                            value: person.id,
                            child: Text(person.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          parentId = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();

                    if (name.isEmpty) {
                      return;
                    }

                    setState(() {
                      people.add(
                        Person(
                          id: _nextId++,
                          name: name,
                          gender: gender,
                          parentId: parentId,
                        ),
                      );
                    });

                    Navigator.pop(context);
                  },
                  child: const Text('Thêm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deletePerson(Person person) {
    final hasChildren =
        people.any((element) => element.parentId == person.id);

    if (hasChildren) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể xóa vì thành viên này đang có con.',
          ),
        ),
      );
      return;
    }

    setState(() {
      people.removeWhere((element) => element.id == person.id);
    });
  }

  List<Person> childrenOf(int parentId) {
    return people.where((person) => person.parentId == parentId).toList();
  }

  void _showPerson(Person person) {
    showDialog(
      context: context,
      builder: (context) {
        final parent = person.parentId == null
            ? null
            : people.where((p) => p.id == person.parentId).firstOrNull;

        return AlertDialog(
          title: Text(person.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Giới tính: ${person.gender}'),
              const SizedBox(height: 8),
              Text(
                'Cha/mẹ: ${parent?.name ?? "Không có"}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deletePerson(person);
              },
              child: const Text(
                'Xóa',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _personCard(Person person) {
    final children = childrenOf(person.id);

    return Column(
      children: [
        InkWell(
          onTap: () => _showPerson(person),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 190,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: person.gender == 'Nam'
                    ? Colors.blue
                    : Colors.pink,
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
                  radius: 25,
                  backgroundColor: person.gender == 'Nam'
                      ? Colors.blue.shade100
                      : Colors.pink.shade100,
                  child: Icon(
                    person.gender == 'Nam'
                        ? Icons.man
                        : Icons.woman,
                    color: person.gender == 'Nam'
                        ? Colors.blue
                        : Colors.pink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  person.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  person.gender,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (children.isNotEmpty) ...[
          Container(
            width: 2,
            height: 30,
            color: Colors.grey,
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children.map((child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    _personCard(child),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTree() {
    final roots =
        people.where((person) => person.parentId == null).toList();

    if (roots.isEmpty) {
      return const Center(
        child: Text('Chưa có dữ liệu gia phả'),
      );
    }

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.3,
      maxScale: 2.5,
      child: Padding(
        padding: const EdgeInsets.all(50),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: roots.map((person) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: _personCard(person),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gia Phả',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            '🌳 Gia Phả Gia Đình',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Thêm thành viên'),
              ),
            ),
          ],
        ),

        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Text(
                    'Tổng số thành viên: ${people.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Text(
                    '• Bấm vào thành viên để xem thông tin',
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
          onPressed: _showAddDialog,
          icon: const Icon(Icons.add),
          label: const Text('Thêm'),
        ),
      ),
    );
  }
}
