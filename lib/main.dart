import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EasyRentApp());
}

class EasyRentApp extends StatelessWidget {
  const EasyRentApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EasyRent Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2563EB),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      ),
      home: const PropertyHome(),
    );
  }
}

class RoomModel {
  String id, name, floor;
  int totalBeds, defaultRent;
  RoomModel({
    required this.id,
    required this.name,
    required this.floor,
    required this.totalBeds,
    required this.defaultRent,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'floor': floor,
        'totalBeds': totalBeds,
        'defaultRent': defaultRent,
      };

  factory RoomModel.fromJson(Map<String, dynamic> j) => RoomModel(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        floor: '${j['floor'] ?? 'Ground Floor'}',
        totalBeds: int.tryParse('${j['totalBeds']}') ?? 4,
        defaultRent: int.tryParse('${j['defaultRent']}') ?? 4000,
      );
}

class Tenant {
  String id, roomId, name, phone;
  int bedIndex, monthlyRent, dueDay, depositAmount, depositPaid;
  Tenant({
    required this.id,
    required this.roomId,
    required this.bedIndex,
    required this.name,
    required this.phone,
    required this.monthlyRent,
    required this.dueDay,
    required this.depositAmount,
    required this.depositPaid,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'bedIndex': bedIndex,
        'name': name,
        'phone': phone,
        'monthlyRent': monthlyRent,
        'dueDay': dueDay,
        'depositAmount': depositAmount,
        'depositPaid': depositPaid,
      };

  factory Tenant.fromJson(Map<String, dynamic> j) => Tenant(
        id: '${j['id'] ?? ''}',
        roomId: '${j['roomId'] ?? ''}',
        bedIndex: int.tryParse('${j['bedIndex']}') ?? 0,
        name: '${j['name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        monthlyRent: int.tryParse('${j['monthlyRent']}') ?? 4000,
        dueDay: int.tryParse('${j['dueDay']}') ?? 5,
        depositAmount: int.tryParse('${j['depositAmount']}') ?? 0,
        depositPaid: int.tryParse('${j['depositPaid']}') ?? 0,
      );
}

class ExpenseItem {
  String id, title, category, date, monthKey;
  int amount;
  ExpenseItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.monthKey,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'date': date,
        'monthKey': monthKey,
      };

  factory ExpenseItem.fromJson(Map<String, dynamic> j) => ExpenseItem(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        category: '${j['category'] ?? 'Other'}',
        amount: int.tryParse('${j['amount']}') ?? 0,
        date: '${j['date'] ?? ''}',
        monthKey: '${j['monthKey'] ?? ''}',
      );
}

class LogEntry {
  String id, title, subtitle, type, time, tenantId;
  LogEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.time,
    this.tenantId = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'type': type,
        'time': time,
        'tenantId': tenantId,
      };

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        subtitle: '${j['subtitle'] ?? ''}',
        type: '${j['type'] ?? 'info'}',
        time: '${j['time'] ?? ''}',
        tenantId: '${j['tenantId'] ?? ''}',
      );
}

class PropertyHome extends StatefulWidget {
  const PropertyHome({super.key});
  @override
  State<PropertyHome> createState() => _PropertyHomeState();
}

class _PropertyHomeState extends State<PropertyHome> {
  static const _storageKey = 'easyrent_master_db_v2';
  List<RoomModel> _rooms = [];
  List<Tenant> _tenants = [];
  List<ExpenseItem> _expenses = [];
  List<LogEntry> _logs = [];
  Map<String, Map<String, dynamic>> _payments = {};
  String _lastBackupTime = 'Never';
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _tab = 'rooms'; // 'floors', 'rooms', 'expenses', 'history'
  String? _selectedFloor;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _mKey => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
  String get _mName =>
      '${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][_month.month - 1]} ${_month.year}';

  int _paid(String tId) => int.tryParse('${_payments[_mKey]?[tId]?['paid'] ?? 0}') ?? 0;

  String _nowStamp() {
    final n = DateTime.now();
    final hr = n.hour > 12 ? n.hour - 12 : (n.hour == 0 ? 12 : n.hour);
    final ampm = n.hour >= 12 ? 'PM' : 'AM';
    return '${n.day}/${n.month}/${n.year} $hr:${n.minute.toString().padLeft(2, '0')} $ampm';
  }

  void _addLog(String title, String subtitle, String type, {String tenantId = ''}) {
    _logs.insert(
      0,
      LogEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        subtitle: subtitle,
        type: type,
        time: _nowStamp(),
        tenantId: tenantId,
      ),
    );
  }

  bool _isOverdue(Tenant t) {
    final paid = _paid(t.id);
    if (paid >= t.monthlyRent) return false;
    final now = DateTime.now();
    final curMonth = DateTime(now.year, now.month);
    if (_month.isBefore(curMonth)) return true;
    if (_month.isAfter(curMonth)) return false;
    return now.day >= t.dueDay;
  }

  List<File> _getStorageFiles() {
    final List<File> list = [];
    try {
      final String tmp = Directory.systemTemp.path;
      String base = tmp;
      if (tmp.contains('/cache')) {
        base = tmp.split('/cache').first;
      } else if (tmp.contains('/code_cache')) {
        base = tmp.split('/code_cache').first;
      } else {
        base = Directory.systemTemp.parent.path;
      }
      final dir = Directory('$base/files');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      list.add(File('${dir.path}/easyrent_data_v2.json'));
      list.add(File('$base/easyrent_data_v2.json'));
    } catch (_) {}
    try {
      list.add(File('${Directory.systemTemp.path}/easyrent_data_v2.json'));
    } catch (_) {}
    return list;
  }

  Future<void> _loadData() async {
    for (final f in _getStorageFiles()) {
      try {
        if (f.existsSync()) {
          final content = f.readAsStringSync();
          if (content.trim().isNotEmpty && _importJson(content, silent: true, saveAfter: false)) {
            if (mounted) setState(() {});
            return;
          }
        }
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty && _importJson(raw, silent: true, saveAfter: false)) {
        _saveData();
        return;
      }
    } catch (_) {}

    _rooms = [
      RoomModel(id: 'r1', name: 'Room F1', floor: 'First Floor', totalBeds: 4, defaultRent: 4000),
      RoomModel(id: 'r2', name: 'Room F2', floor: 'First Floor', totalBeds: 6, defaultRent: 4000),
      RoomModel(id: 'r3', name: 'Room G1', floor: 'Ground Floor', totalBeds: 6, defaultRent: 4000),
    ];
    _tenants = [
      Tenant(id: 't1', roomId: 'r1', bedIndex: 0, name: 'Uvais', phone: '', monthlyRent: 4000, dueDay: 5, depositAmount: 5000, depositPaid: 5000),
      Tenant(id: 't2', roomId: 'r1', bedIndex: 1, name: 'Rasal', phone: '', monthlyRent: 4000, dueDay: 5, depositAmount: 5000, depositPaid: 5000),
      Tenant(id: 't3', roomId: 'r1', bedIndex: 2, name: 'Nishan', phone: '', monthlyRent: 2000, dueDay: 10, depositAmount: 5000, depositPaid: 5000),
      Tenant(id: 't4', roomId: 'r1', bedIndex: 3, name: 'Munavir', phone: '', monthlyRent: 2000, dueDay: 25, depositAmount: 5000, depositPaid: 5000),
    ];
    _saveData();
  }

  Map<String, dynamic> _buildBackupMap() => {
        'app': 'EasyRent_Tracker',
        'version': 2,
        'lastBackupTime': _lastBackupTime,
        'rooms': _rooms.map((r) => r.toJson()).toList(),
        'tenants': _tenants.map((t) => t.toJson()).toList(),
        'expenses': _expenses.map((e) => e.toJson()).toList(),
        'logs': _logs.map((l) => l.toJson()).toList(),
        'payments': _payments,
      };

  void _saveData() {
    final jsonStr = jsonEncode(_buildBackupMap());

    for (final f in _getStorageFiles()) {
      try {
        f.writeAsStringSync(jsonStr, flush: true);
      } catch (_) {}
    }

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_storageKey, jsonStr);
    }).catchError((_) {});

    if (mounted) setState(() {});
  }

  bool _importJson(String raw, {bool silent = false, bool saveAfter = true}) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final Map<String, dynamic> d = Map<String, dynamic>.from(decoded);

      final List<RoomModel> loadedRooms = [];
      for (final item in (d['rooms'] as List? ?? [])) {
        if (item is Map) loadedRooms.add(RoomModel.fromJson(Map<String, dynamic>.from(item)));
      }

      final List<Tenant> loadedTenants = [];
      for (final item in (d['tenants'] as List? ?? [])) {
        if (item is Map) loadedTenants.add(Tenant.fromJson(Map<String, dynamic>.from(item)));
      }

      final List<ExpenseItem> loadedExpenses = [];
      for (final item in (d['expenses'] as List? ?? [])) {
        if (item is Map) loadedExpenses.add(ExpenseItem.fromJson(Map<String, dynamic>.from(item)));
      }

      final List<LogEntry> loadedLogs = [];
      for (final item in (d['logs'] as List? ?? [])) {
        if (item is Map) loadedLogs.add(LogEntry.fromJson(Map<String, dynamic>.from(item)));
      }

      final Map<String, Map<String, dynamic>> loadedPayments = {};
      final rawPayments = d['payments'];
      if (rawPayments is Map) {
        rawPayments.forEach((mKey, mVal) {
          if (mVal is Map) {
            final Map<String, dynamic> inner = {};
            mVal.forEach((tId, tVal) {
              if (tVal is Map) inner[tId.toString()] = Map<String, dynamic>.from(tVal);
            });
            loadedPayments[mKey.toString()] = inner;
          }
        });
      }

      _rooms = loadedRooms;
      _tenants = loadedTenants;
      _expenses = loadedExpenses;
      _logs = loadedLogs;
      _payments = loadedPayments;
      if (d['lastBackupTime'] != null) {
        _lastBackupTime = '${d['lastBackupTime']}';
      }

      if (saveAfter) {
        _addLog('Backup Restored', '${_rooms.length} Rooms, ${_tenants.length} Tenants restored', 'info');
        _saveData();
      }
      if (!silent) _msg('Backup Restored Successfully!');
      return true;
    } catch (_) {
      if (!silent) _msg('Invalid Backup Code! Please check and try again.');
      return false;
    }
  }

  void _msg(String txt) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));

  void _showExpenseDialog({ExpenseItem? exp}) {
    final isEdit = exp != null;
    final now = DateTime.now();
    final titleC = TextEditingController(text: exp?.title ?? '');
    final amtC = TextEditingController(text: exp != null ? '${exp.amount}' : '');
    final dateC = TextEditingController(text: exp?.date ?? '${now.day}/${now.month}/${now.year}');
    String cat = exp?.category ?? 'Electricity';
    const categories = ['Electricity', 'Water', 'Maintenance', 'Wifi', 'Cleaning', 'Salary', 'Other'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text(isEdit ? 'Edit Expense' : 'Add Expense ($_mName)'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: categories.contains(cat) ? cat : 'Other',
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setSt(() => cat = v ?? 'Other'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: titleC,
                decoration: const InputDecoration(labelText: 'Description / Note (e.g. KSEB Bill)', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amtC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹ ', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dateC,
                decoration: InputDecoration(
                  labelText: 'Expense Date (DD/MM/YYYY)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setSt(() => dateC.text = '${picked.day}/${picked.month}/${picked.year}');
                      }
                    },
                  ),
                ),
              ),
            ]),
          ),
          actions: [
            if (isEdit)
              TextButton(
                onPressed: () {
                  _addLog('Expense Deleted: ${exp.title}', '₹${exp.amount} (${exp.category})', 'info');
                  _expenses.removeWhere((x) => x.id == exp.id);
                  _saveData();
                  Navigator.pop(context);
                  _msg('Expense deleted!');
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final amt = int.tryParse(amtC.text.trim()) ?? 0;
                if (amt <= 0) return;
                final title = titleC.text.trim().isEmpty ? cat : titleC.text.trim();
                final dateStr = dateC.text.trim().isEmpty ? '${now.day}/${now.month}/${now.year}' : dateC.text.trim();
                final item = ExpenseItem(
                  id: isEdit ? exp.id : now.millisecondsSinceEpoch.toString(),
                  title: title,
                  category: cat,
                  amount: amt,
                  date: dateStr,
                  monthKey: isEdit ? exp.monthKey : _mKey,
                );
                if (isEdit) {
                  final idx = _expenses.indexWhere((x) => x.id == exp.id);
                  if (idx != -1) _expenses[idx] = item;
                  _addLog('Expense Edited: $title', 'Updated to ₹$amt (was ₹${exp.amount}) • $cat', 'expense');
                  _msg('Expense updated!');
                } else {
                  _expenses.add(item);
                  _addLog('Expense Added: $title', 'Amount: -₹$amt ($cat • $_mName)', 'expense');
                }
                _saveData();
                Navigator.pop(context);
              },
              child: Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomDialog({RoomModel? room}) {
    final isEdit = room != null;
    final nameC = TextEditingController(text: room?.name ?? '');
    final floorC = TextEditingController(text: room?.floor ?? (_selectedFloor ?? 'First Floor'));
    final bedsC = TextEditingController(text: '${room?.totalBeds ?? 4}');
    final rentC = TextEditingController(text: '${room?.defaultRent ?? 4000}');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Room' : 'Add Room'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Room Name (e.g. Room F1)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: floorC, decoration: const InputDecoration(labelText: 'Floor (e.g. First Floor)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: bedsC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Beds (e.g. 4 or 6)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: rentC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rent Per Bed (₹)', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          if (isEdit)
            TextButton(
              onPressed: () {
                _addLog('Room Deleted: ${room.name}', 'Floor: ${room.floor}', 'info');
                _tenants.removeWhere((t) => t.roomId == room.id);
                _rooms.removeWhere((r) => r.id == room.id);
                _saveData();
                Navigator.pop(context);
              },
              child: const Text('Delete Room', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameC.text.trim().isEmpty) return;
              final newR = RoomModel(
                id: isEdit ? room.id : DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameC.text.trim(),
                floor: floorC.text.trim().isEmpty ? 'Ground Floor' : floorC.text.trim(),
                totalBeds: (int.tryParse(bedsC.text) ?? 4).clamp(1, 20),
                defaultRent: int.tryParse(rentC.text) ?? 4000,
              );
              if (isEdit) {
                _rooms[_rooms.indexWhere((x) => x.id == room.id)] = newR;
                _addLog('Room Updated: ${newR.name}', '${newR.totalBeds} beds • ₹${newR.defaultRent}/bed', 'info');
              } else {
                _rooms.add(newR);
                _addLog('New Room Created: ${newR.name}', '${newR.floor} • ${newR.totalBeds} beds', 'info');
              }
              _saveData();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBedSheet(RoomModel room, int bedIdx, Tenant? t) {
    if (t == null) {
      _showTenantForm(room, bedIdx, null);
      return;
    }
    final paid = _paid(t.id), bal = (t.monthlyRent - paid).clamp(0, t.monthlyRent);
    final depBal = (t.depositAmount - t.depositPaid).clamp(0, t.depositAmount);
    final isOverdue = _isOverdue(t);
    final rentCtrl = TextEditingController();
    final depCtrl = TextEditingController();
