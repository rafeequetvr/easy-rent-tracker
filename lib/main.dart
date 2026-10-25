import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
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
  RoomModel({required this.id, required this.name, required this.floor, required this.totalBeds, required this.defaultRent});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'floor': floor, 'totalBeds': totalBeds, 'defaultRent': defaultRent};
  factory RoomModel.fromJson(Map<String, dynamic> j) => RoomModel(
        id: '${j['id'] ?? ''}', name: '${j['name'] ?? ''}', floor: '${j['floor'] ?? 'Ground Floor'}',
        totalBeds: int.tryParse('${j['totalBeds']}') ?? 4, defaultRent: int.tryParse('${j['defaultRent']}') ?? 4000,
      );
}

class Tenant {
  String id, roomId, name, phone;
  int bedIndex, monthlyRent, dueDay, depositAmount, depositPaid;
  Tenant({
    required this.id, required this.roomId, required this.bedIndex, required this.name,
    required this.phone, required this.monthlyRent, required this.dueDay, required this.depositAmount, required this.depositPaid,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'roomId': roomId, 'bedIndex': bedIndex, 'name': name, 'phone': phone,
        'monthlyRent': monthlyRent, 'dueDay': dueDay, 'depositAmount': depositAmount, 'depositPaid': depositPaid,
      };
  factory Tenant.fromJson(Map<String, dynamic> j) => Tenant(
        id: '${j['id'] ?? ''}', roomId: '${j['roomId'] ?? ''}', bedIndex: int.tryParse('${j['bedIndex']}') ?? 0,
        name: '${j['name'] ?? ''}', phone: '${j['phone'] ?? ''}', monthlyRent: int.tryParse('${j['monthlyRent']}') ?? 4000,
        dueDay: int.tryParse('${j['dueDay']}') ?? 5, depositAmount: int.tryParse('${j['depositAmount']}') ?? 0,
        depositPaid: int.tryParse('${j['depositPaid']}') ?? 0,
      );
}

class ExpenseItem {
  String id, title, category, date, monthKey;
  int amount;
  ExpenseItem({required this.id, required this.title, required this.category, required this.amount, required this.date, required this.monthKey});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'category': category, 'amount': amount, 'date': date, 'monthKey': monthKey};
  factory ExpenseItem.fromJson(Map<String, dynamic> j) => ExpenseItem(
        id: '${j['id'] ?? ''}', title: '${j['title'] ?? ''}', category: '${j['category'] ?? 'Other'}',
        amount: int.tryParse('${j['amount']}') ?? 0, date: '${j['date'] ?? ''}', monthKey: '${j['monthKey'] ?? ''}',
      );
}

class LogEntry {
  String id, title, subtitle, type, time, tenantId;
  LogEntry({required this.id, required this.title, required this.subtitle, required this.type, required this.time, this.tenantId = ''});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'subtitle': subtitle, 'type': type, 'time': time, 'tenantId': tenantId};
  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        id: '${j['id'] ?? ''}', title: '${j['title'] ?? ''}', subtitle: '${j['subtitle'] ?? ''}',
        type: '${j['type'] ?? 'info'}', time: '${j['time'] ?? ''}', tenantId: '${j['tenantId'] ?? ''}',
      );
}

class PropertyHome extends StatefulWidget {
  const PropertyHome({super.key});
  @override
  State<PropertyHome> createState() => _PropertyHomeState();
}

class _PropertyHomeState extends State<PropertyHome> {
  static const _storageKey = 'easyrent_master_db_v2';
  final LocalAuthentication _auth = LocalAuthentication();

  List<RoomModel> _rooms = [];
  List<Tenant> _tenants = [];
  List<ExpenseItem> _expenses = [];
  List<LogEntry> _logs = [];
  Map<String, Map<String, dynamic>> _payments = {};
  String _lastBackupTime = 'Never';
  bool _lockEnabled = false;
  String _appPin = '1234';
  bool _isLocked = false;
  final TextEditingController _unlockPinCtrl = TextEditingController();

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _tab = 'rooms';
  String? _selectedFloor;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _mKey => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
  String get _mName => '${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][_month.month - 1]} ${_month.year}';

  int _paid(String tId) => int.tryParse('${_payments[_mKey]?[tId]?['paid'] ?? 0}') ?? 0;

  String _nowStamp() {
    final n = DateTime.now();
    final hr = n.hour > 12 ? n.hour - 12 : (n.hour == 0 ? 12 : n.hour);
    final ampm = n.hour >= 12 ? 'PM' : 'AM';
    return '${n.day}/${n.month}/${n.year} $hr:${n.minute.toString().padLeft(2, '0')} $ampm';
  }

  void _addLog(String title, String subtitle, String type, {String tenantId = ''}) {
    _logs.insert(0, LogEntry(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title, subtitle: subtitle, type: type, time: _nowStamp(), tenantId: tenantId));
  }

  bool _isOverdue(Tenant t) {
    if (_paid(t.id) >= t.monthlyRent) return false;
    final now = DateTime.now();
    final curMonth = DateTime(now.year, now.month);
    if (_month.isBefore(curMonth)) return true;
    if (_month.isAfter(curMonth)) return false;
    return now.day >= t.dueDay;
  }

  Future<void> _triggerBiometricUnlock() async {
    try {
      final canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) return;
      final didAuth = await _auth.authenticate(localizedReason: 'Scan fingerprint to unlock EasyRent Tracker');
      if (didAuth && mounted) {
        setState(() => _isLocked = false);
      }
    } catch (_) {}
  }

  List<File> _getStorageFiles() {
    final List<File> list = [];
    try {
      final String tmp = Directory.systemTemp.path;
      String base = tmp.contains('/cache') ? tmp.split('/cache').first : (tmp.contains('/code_cache') ? tmp.split('/code_cache').first : Directory.systemTemp.parent.path);
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
    bool loaded = false;
    for (final f in _getStorageFiles()) {
      try {
        if (f.existsSync()) {
          final content = f.readAsStringSync();
          if (content.trim().isNotEmpty && _importJson(content, silent: true, saveAfter: false)) {
            loaded = true;
            break;
          }
        }
      } catch (_) {}
    }

    if (!loaded) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_storageKey);
        if (raw != null && raw.isNotEmpty && _importJson(raw, silent: true, saveAfter: false)) {
          loaded = true;
          _saveData();
        }
      } catch (_) {}
    }

    if (!loaded) {
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

    if (_lockEnabled) {
      setState(() => _isLocked = true);
      _triggerBiometricUnlock();
    } else if (mounted) {
      setState(() {});
    }
  }

  Map<String, dynamic> _buildBackupMap() => {
        'app': 'EasyRent_Tracker',
        'version': 2,
        'lastBackupTime': _lastBackupTime,
        'lockEnabled': _lockEnabled,
        'appPin': _appPin,
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
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_storageKey, jsonStr)).catchError((_) {});
    if (mounted) setState(() {});
  }

  bool _importJson(String raw, {bool silent = false, bool saveAfter = true}) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final Map<String, dynamic> d = Map<String, dynamic>.from(decoded);

      _rooms = (d['rooms'] as List? ?? []).whereType<Map>().map((e) => RoomModel.fromJson(Map<String, dynamic>.from(e))).toList();
      _tenants = (d['tenants'] as List? ?? []).whereType<Map>().map((e) => Tenant.fromJson(Map<String, dynamic>.from(e))).toList();
      _expenses = (d['expenses'] as List? ?? []).whereType<Map>().map((e) => ExpenseItem.fromJson(Map<String, dynamic>.from(e))).toList();
      _logs = (d['logs'] as List? ?? []).whereType<Map>().map((e) => LogEntry.fromJson(Map<String, dynamic>.from(e))).toList();

      final Map<String, Map<String, dynamic>> loadedPayments = {};
      if (d['payments'] is Map) {
        (d['payments'] as Map).forEach((mKey, mVal) {
          if (mVal is Map) {
            final Map<String, dynamic> inner = {};
            mVal.forEach((tId, tVal) {
              if (tVal is Map) inner[tId.toString()] = Map<String, dynamic>.from(tVal);
            });
            loadedPayments[mKey.toString()] = inner;
          }
        });
      }
      _payments = loadedPayments;
      if (d['lastBackupTime'] != null) _lastBackupTime = '${d['lastBackupTime']}';
      if (d['lockEnabled'] != null) _lockEnabled = d['lockEnabled'] == true;
      if (d['appPin'] != null && '${d['appPin']}'.isNotEmpty) _appPin = '${d['appPin']}';

      if (saveAfter) {
        _addLog('Backup Restored', '${_rooms.length} Rooms, ${_tenants.length} Tenants restored', 'info');
        _saveData();
      }
      if (!silent) _msg('Backup Restored Successfully!');
      return true;
    } catch (_) {
      if (!silent) _msg('Invalid Backup Code!');
      return false;
    }
  }

  void _msg(String txt) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));

  void _showLockSettingsDialog() {
    final pinC = TextEditingController(text: _appPin);
    bool enabled = _lockEnabled;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Row(children: [Icon(Icons.fingerprint, color: Color(0xFF2563EB)), SizedBox(width: 8), Text('App Lock Settings')]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Fingerprint & PIN Lock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Require authentication when opening app', style: TextStyle(fontSize: 12)),
              value: enabled,
              onChanged: (v) => setSt(() => enabled = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pinC,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Backup PIN (4-6 digits)', border: OutlineInputBorder(), isDense: true),
            ),
          ]),
          actions: [
            if (_lockEnabled)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _isLocked = true);
                },
                child: const Text('Lock Now'),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (pinC.text.trim().length < 4) {
                  _msg('PIN must be at least 4 digits!');
                  return;
                }
                _lockEnabled = enabled;
                _appPin = pinC.text.trim();
                _saveData();
                Navigator.pop(context);
                _msg(_lockEnabled ? 'App Lock Enabled!' : 'App Lock Disabled.');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTenantForm(RoomModel room, int bedIdx, Tenant? t) {
    final isEdit = t != null;
    final nameC = TextEditingController(text: t?.name ?? '');
    final phoneC = TextEditingController(text: t?.phone ?? '');
    final rentC = TextEditingController(text: '${t?.monthlyRent ?? room.defaultRent}');
    final dueC = TextEditingController(text: '${t?.dueDay ?? 5}');
    final depTC = TextEditingController(text: '${t?.depositAmount ?? 5000}');
    final depPC = TextEditingController(text: '${t?.depositPaid ?? 5000}');

    Widget tf(TextEditingController c, String l, [bool num = false]) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(controller: c, keyboardType: num ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: l, isDense: true, border: const OutlineInputBorder())),
        );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Tenant' : 'Assign Bed ${bedIdx + 1} (${room.name})'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            tf(nameC, 'Tenant Name'), tf(phoneC, 'Phone Number', true),
            tf(rentC, 'Monthly Rent (₹)', true), tf(dueC, 'Rent Due Day (1-31)', true),
            tf(depTC, 'Total Deposit Agreed (₹)', true), tf(depPC, 'Deposit Paid (₹)', true),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameC.text.trim().isEmpty) return;
              final newT = Tenant(
                id: isEdit ? t.id : DateTime.now().millisecondsSinceEpoch.toString(),
                roomId: room.id, bedIndex: bedIdx, name: nameC.text.trim(), phone: phoneC.text.trim(),
                monthlyRent: int.tryParse(rentC.text) ?? room.defaultRent,
                dueDay: (int.tryParse(dueC.text) ?? 5).clamp(1, 31),
                depositAmount: int.tryParse(depTC.text) ?? 0, depositPaid: int.tryParse(depPC.text) ?? 0,
              );
              if (isEdit) {
                _tenants[_tenants.indexWhere((x) => x.id == t.id)] = newT;
                _addLog('Tenant Edited: ${newT.name}', '${room.name} (Bed ${bedIdx + 1}) • Rent: ₹${newT.monthlyRent}', 'info', tenantId: newT.id);
              } else {
                _tenants.add(newT);
                _addLog('New Tenant Joined: ${newT.name}', '${room.name} (Bed ${bedIdx + 1}) • Dep Paid: ₹${newT.depositPaid}', 'deposit', tenantId: newT.id);
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
              TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Description / Note', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: amtC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹ ', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              TextField(
                controller: dateC,
                decoration: InputDecoration(
                  labelText: 'Expense Date (DD/MM/YYYY)', border: const OutlineInputBorder(), isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    onPressed: () async {
                      final picked = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(2020), lastDate: DateTime(2035));
                      if (picked != null) setSt(() => dateC.text = '${picked.day}/${picked.month}/${picked.year}');
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
                final item = ExpenseItem(id: isEdit ? exp.id : now.millisecondsSinceEpoch.toString(), title: title, category: cat, amount: amt, date: dateStr, monthKey: isEdit ? exp.monthKey : _mKey);
                if (isEdit) {
                  final idx = _expenses.indexWhere((x) => x.id == exp.id);
                  if (idx != -1) _expenses[idx] = item;
                  _addLog('Expense Edited: $title', 'Updated to ₹$amt (was ₹${exp.amount}) • $cat', 'expense');
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
                name: nameC.text.trim(), floor: floorC.text.trim().isEmpty ? 'Ground Floor' : floorC.text.trim(),
                totalBeds: (int.tryParse(bedsC.text) ?? 4).clamp(1, 20), defaultRent: int.tryParse(rentC.text) ?? 4000,
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
    final tenantLogs = _logs.where((l) => l.tenantId == t.id).take(8).toList();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text('${t.name} (${room.name})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () { Navigator.pop(context); _showTenantForm(room, bedIdx, t); }),
          IconButton(icon: const Icon(Icons.person_remove_outlined, color: Colors.red, size: 20), onPressed: () {
            _addLog('Tenant Vacated: ${t.name}', '${room.name} (Bed ${bedIdx + 1})', 'info', tenantId: t.id);
            _tenants.removeWhere((x) => x.id == t.id);
            _saveData();
            Navigator.pop(context);
          }),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Monthly Rent: ₹${t.monthlyRent} • Due Day: ${t.dueDay}th'),
                  Text('Paid ($_mName): ₹$paid • Balance: ₹$bal', style: TextStyle(fontWeight: FontWeight.bold, color: bal == 0 ? Colors.green : (isOverdue ? Colors.red : Colors.blue))),
                  if (!isOverdue && bal > 0) Text('Status: Upcoming (Due on ${t.dueDay}th)', style: const TextStyle(fontSize: 12, color: Colors.blue)),
                  const Divider(),
                  Text('Deposit Held: ₹${t.depositPaid} / ₹${t.depositAmount} ${depBal > 0 ? "(Due: ₹$depBal)" : "✓"}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.teal)),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: rentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Add Rent (₹)', isDense: true, border: OutlineInputBorder()))),
                const SizedBox(width: 6),
                FilledButton(
                    onPressed: () {
                      final add = int.tryParse(rentCtrl.text) ?? 0;
                      if (add > 0) {
                        final newPaid = (paid + add).clamp(0, t.monthlyRent * 2);
                        _payments.putIfAbsent(_mKey, () => {})[t.id] = {'paid': newPaid};
                        _addLog('Rent Received: +₹$add', '${t.name} (${room.name}) • $_mName (Total Paid: ₹$newPaid)', 'rent', tenantId: t.id);
                        _saveData();
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Add')),
                const SizedBox(width: 4),
                OutlinedButton(
                    onPressed: () {
                      _payments.putIfAbsent(_mKey, () => {})[t.id] = {'paid': t.monthlyRent};
                      _addLog('Full Rent Paid: +₹${t.monthlyRent}', '${t.name} (${room.name}) • $_mName', 'rent', tenantId: t.id);
                      _saveData();
                      Navigator.pop(context);
                    },
                    child: const Text('Full')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: depCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Add Deposit (₹)', isDense: true, border: OutlineInputBorder()))),
                const SizedBox(width: 6),
                FilledButton.tonal(
                    onPressed: () {
                      final add = int.tryParse(depCtrl.text) ?? 0;
                      if (add > 0) {
                        t.depositPaid = (t.depositPaid + add).clamp(0, 999999);
                        _addLog('Deposit Received: +₹$add', '${t.name} (${room.name}) • Total Dep: ₹${t.depositPaid}', 'deposit', tenantId: t.id);
                        _saveData();
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Add Dep')),
              ]),
              if (tenantLogs.isNotEmpty) ...[
                const Divider(height: 22),
                const Text('Recent Activity / Payment History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                const SizedBox(height: 6),
                ...tenantLogs.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(l.type == 'rent' ? Icons.check_circle_outline : Icons.history, size: 14, color: l.type == 'rent' ? Colors.green : Colors.teal),
                        const SizedBox(width: 6),
                        Expanded(child: Text('${l.title} (${l.subtitle}) • ${l.time}', style: const TextStyle(fontSize: 11))),
                      ]),
                    )),
              ],
            ]),
          ),
        ),
        actions: [
          if (paid > 0)
            TextButton(
                onPressed: () {
                  _payments.putIfAbsent(_mKey, () => {})[t.id] = {'paid': 0};
                  _addLog('Rent Reset to ₹0', '${t.name} (${room.name}) • $_mName', 'info', tenantId: t.id);
                  _saveData();
                  Navigator.pop(context);
                },
                child: const Text('Reset Rent', style: TextStyle(color: Colors.red))),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'Hello ${t.name} (${room.name}), your $_mName rent balance is ₹$bal (Due: ${t.dueDay}th).'));
              _msg('WhatsApp Reminder Copied!');
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Reminder'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showReportDialog() {
    int expectedRent = 0, col = 0, due = 0, upcoming = 0, depHeld = 0, depPending = 0;
    final int totalBeds = _rooms.fold(0, (s, r) => s + r.totalBeds);
    final int maxPotentialRent = _rooms.fold(0, (s, r) => s + (r.totalBeds * r.defaultRent));
    final int occBeds = _tenants.length;
    final int vacBeds = (totalBeds - occBeds).clamp(0, totalBeds);
    final List<String> overdueList = [];
    final sb = StringBuffer();

    for (final r in _rooms) {
      sb.writeln('\n[${r.name} - ${r.floor}]');
      final rTenants = _tenants.where((t) => t.roomId == r.id).toList();
      if (rTenants.isEmpty) sb.writeln('  All Beds Vacant');
      for (final t in rTenants) {
        final p = _paid(t.id), b = (t.monthlyRent - p).clamp(0, t.monthlyRent);
        final od = _isOverdue(t);
        expectedRent += t.monthlyRent;
        col += p;
        depHeld += t.depositPaid;
        depPending += (t.depositAmount - t.depositPaid).clamp(0, t.depositAmount);
        if (od) {
          due += b;
          overdueList.add('  ! ${t.name} (${r.name}) - Overdue: ₹$b (Due ${t.dueDay}th)');
        } else {
          upcoming += b;
        }
        final status = b == 0 ? 'PAID' : (od ? 'OVERDUE (₹$b)' : 'UPCOMING (₹$b, Due ${t.dueDay}th)');
        sb.writeln('  • ${t.name}: Rent ₹${t.monthlyRent} | Paid ₹$p | $status | Dep: ₹${t.depositPaid}/₹${t.depositAmount}');
      }
    }

    final mExpenses = _expenses.where((e) => e.monthKey == _mKey).toList();
    final totalExp = mExpenses.fold(0, (s, e) => s + e.amount);
    final Map<String, int> catTotals = {};
    for (final e in mExpenses) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }

    final net = col - totalExp;
    final out = StringBuffer();
    out.writeln('=== EASYRENT REPORT ($_mName) ===');
    out.writeln('Occupancy: $occBeds/$totalBeds Beds Occupied ($vacBeds Vacant)');
    out.writeln('Total Expected Income (Active Tenants): ₹$expectedRent');
    out.writeln('Max Potential Income (If 100% Full): ₹$maxPotentialRent');
    out.writeln('Rent Collected: ₹$col | Expenses: ₹$totalExp');
    out.writeln('Net Profit / Balance: ₹$net');
    out.writeln('Overdue Rent: ₹$due | Upcoming: ₹$upcoming');
    out.writeln('Deposit Held: ₹$depHeld | Deposit Pending: ₹$depPending');
    out.writeln('-----------------------------------------');
    if (overdueList.isNotEmpty) {
      out.writeln('\n=== OVERDUE DEFAULTERS (${overdueList.length}) ===');
      for (final line in overdueList) {
        out.writeln(line);
      }
    }
    out.writeln('\n=== ROOM-WISE BREAKDOWN ===$sb');
    out.writeln('\n=== EXPENSES BY CATEGORY ($_mName) ===');
    if (mExpenses.isEmpty) {
      out.writeln('  No expenses recorded.');
    } else {
      catTotals.forEach((k, v) => out.writeln('  • $k: ₹$v'));
      for (final e in mExpenses) {
        out.writeln('  - ${e.title} (${e.category}): ₹${e.amount} [${e.date}]');
      }
    }
    final text = out.toString();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Report - $_mName'),
        content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: SelectableText(text, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')))),
        actions: [
          TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: text)); _msg('Copied!'); }, child: const Text('Copy')),
          FilledButton.icon(onPressed: () => Share.share(text), icon: const Icon(Icons.download, size: 16), label: const Text('Download / Share')),
        ],
      ),
    );
  }

  void _showBackupDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Row(children: [Icon(Icons.cloud_sync_outlined, color: Color(0xFF2563EB)), SizedBox(width: 8), Text('Backup & Restore', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text('Rooms: ${_rooms.length} | Tenants: ${_tenants.length} | Expenses: ${_expenses.length}\nLast Backup: $_lastBackupTime', style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () async {
                    _lastBackupTime = _nowStamp();
                    _saveData();
                    setSt(() {});
                    final jsonStr = jsonEncode(_buildBackupMap());
                    try {
                      final f = File('${Directory.systemTemp.path}/EasyRent_Backup.json');
                      f.writeAsStringSync(jsonStr, flush: true);
                      await Share.shareXFiles([XFile(f.path)], text: 'EasyRent Backup ($_lastBackupTime)');
                    } catch (_) {
                      Share.share(jsonStr);
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Export Backup File (.json)'),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () {
                    _lastBackupTime = _nowStamp();
                    _saveData();
                    setSt(() {});
                    Clipboard.setData(ClipboardData(text: jsonEncode(_buildBackupMap())));
                    _msg('Backup code copied!');
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy Backup Code'),
                ),
                const Divider(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Restore Backup:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  TextButton.icon(
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) setSt(() => ctrl.text = data!.text!.trim());
                    },
                    icon: const Icon(Icons.content_paste, size: 16),
                    label: const Text('Paste'),
                  ),
                ]),
                TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Paste backup JSON here...', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () {
                    if (ctrl.text.trim().isNotEmpty && _importJson(ctrl.text.trim())) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.settings_backup_restore),
                  label: const Text('Restore Data Now'),
                ),
              ]),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      ),
    );
  }

  Widget _segTab(String key, String label, {bool isFirst = false, bool isLast = false}) {
    final sel = _tab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _tab = key;
          if (key == 'rooms') _selectedFloor = null;
        }),
        child: Container(
          decoration: BoxDecoration(
            color: sel ? const Color(0xFFDCE2F9) : Colors.transparent,
            borderRadius: BorderRadius.horizontal(left: isFirst ? const Radius.circular(24) : Radius.zero, right: isLast ? const Radius.circular(24) : Radius.zero),
          ),
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) => Expanded(
        child: Column(children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.fingerprint, size: 68, color: Color(0xFF2563EB)),
              ),
              const SizedBox(height: 16),
              const Text('EasyRent Tracker Locked', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Use Fingerprint or enter your PIN to unlock', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _unlockPinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(hintText: 'Enter PIN', border: OutlineInputBorder(), isDense: true),
                  onSubmitted: (v) {
                    if (v.trim() == _appPin) {
                      _unlockPinCtrl.clear();
                      setState(() => _isLocked = false);
                    } else {
                      _msg('Incorrect PIN!');
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                FilledButton.icon(
                  onPressed: () {
                    if (_unlockPinCtrl.text.trim() == _appPin) {
                      _unlockPinCtrl.clear();
                      setState(() => _isLocked = false);
                    } else {
                      _msg('Incorrect PIN!');
                    }
                  },
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: const Text('Unlock with PIN'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _triggerBiometricUnlock,
                  icon: const Icon(Icons.fingerprint, size: 20),
                  label: const Text('Fingerprint'),
                ),
              ]),
            ]),
          ),
        ),
      );
    }

    final floors = _rooms.map((r) => r.floor).toSet().toList();
    final visibleRooms = _selectedFloor == null ? _rooms : _rooms.where((r) => r.floor == _selectedFloor).toList();
    final mExpenses = _expenses.where((e) => e.monthKey == _mKey).toList();

    int totalExpected = 0, totalCol = 0;
    for (final t in _tenants) {
      totalExpected += t.monthlyRent;
      totalCol += _paid(t.id);
    }
    final int totalExp = mExpenses.fold(0, (s, e) => s + e.amount);
    final int netProfit = totalCol - totalExp;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Management', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showLockSettingsDialog,
            icon: Icon(_lockEnabled ? Icons.lock_outline : Icons.lock_open_outlined, color: _lockEnabled ? Colors.blue.shade800 : null),
            tooltip: 'App Lock',
          ),
          IconButton(onPressed: _showReportDialog, icon: const Icon(Icons.assessment_outlined), tooltip: 'Report'),
          IconButton(onPressed: _showBackupDialog, icon: const Icon(Icons.cloud_sync_outlined), tooltip: 'Backup'),
          IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left)),
          Center(child: Text(_mName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right)),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Row(children: [
              _summaryChip('Expected', '₹$totalExpected', const Color(0xFF2563EB)),
              Container(width: 1, height: 24, color: Colors.grey.shade200),
              _summaryChip('Collected', '₹$totalCol', const Color(0xFF15803D)),
              Container(width: 1, height: 24, color: Colors.grey.shade200),
              _summaryChip('Expenses', '₹$totalExp', const Color(0xFFDC2626)),
              Container(width: 1, height: 24, color: Colors.grey.shade200),
              _summaryChip('Net Profit', '₹$netProfit', netProfit >= 0 ? const Color(0xFF1E3A8A) : Colors.red),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Container(
            height: 42,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade400)),
            child: Row(children: [
              _segTab('floors', 'Floors', isFirst: true),
              Container(width: 1, color: Colors.grey.shade400),
              _segTab('rooms', 'Rooms'),
              Container(width: 1, color: Colors.grey.shade400),
              _segTab('expenses', 'Expenses'),
              Container(width: 1, color: Colors.grey.shade400),
              _segTab('history', 'History', isLast: true),
            ]),
          ),
        ),
        Expanded(
          child: _tab == 'floors'
              ? ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: floors.length,
                  itemBuilder: (_, i) {
                    final fl = floors[i];
                    final fRooms = _rooms.where((r) => r.floor == fl).toList();
                    final totalBeds = fRooms.fold(0, (s, r) => s + r.totalBeds);
                    final occBeds = _tenants.where((t) => fRooms.any((r) => r.id == t.roomId)).length;
                    return Card(
                      color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.apartment, color: Colors.blue.shade700)),
                        title: Text(fl, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${fRooms.length} Rooms • $occBeds/$totalBeds beds occupied'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => setState(() { _selectedFloor = fl; _tab = 'rooms'; }),
                      ),
                    );
                  },
                )
              : _tab == 'expenses'
                  ? (mExpenses.isEmpty
                      ? Center(child: Text('No expenses recorded for $_mName.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: mExpenses.length,
                          itemBuilder: (_, i) {
                            final e = mExpenses[i];
                            return Card(
                              color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
                              child: ListTile(
                                onTap: () => _showExpenseDialog(exp: e),
                                leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.receipt_long_outlined, color: Colors.red.shade700)),
                                title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${e.category} • ${e.date} (Tap to edit)', style: const TextStyle(fontSize: 12)),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text('₹${e.amount}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red.shade700)),
                                  IconButton(icon: const Icon(Icons.edit_outlined, size: 19, color: Colors.blue), onPressed: () => _showExpenseDialog(exp: e)),
                                  IconButton(icon: const Icon(Icons.delete_outline, size: 19, color: Colors.grey), onPressed: () {
                                    _addLog('Expense Deleted: ${e.title}', '₹${e.amount}', 'info');
                                    _expenses.removeWhere((x) => x.id == e.id);
                                    _saveData();
                                  }),
                                ]),
                              ),
                            );
                          },
                        ))
                  : _tab == 'history'
                      ? (_logs.isEmpty
                          ? const Center(child: Text('No activity or payment history yet.'))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                              itemCount: _logs.length,
                              itemBuilder: (_, i) {
                                final l = _logs[i];
                                final isRent = l.type == 'rent', isDep = l.type == 'deposit', isExp = l.type == 'expense';
                                final Color c = isRent ? Colors.green.shade700 : (isDep ? Colors.teal.shade700 : (isExp ? Colors.red.shade700 : Colors.blue.shade700));
                                final Color bg = isRent ? Colors.green.shade50 : (isDep ? Colors.teal.shade50 : (isExp ? Colors.red.shade50 : Colors.blue.shade50));
                                final IconData ic = isRent ? Icons.payments_outlined : (isDep ? Icons.shield_outlined : (isExp ? Icons.money_off_csred_outlined : Icons.history));
                                return Card(
                                  color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
                                  child: ListTile(
                                    dense: true,
                                    leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Icon(ic, color: c, size: 20)),
                                    title: Text(l.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: c)),
                                    subtitle: Text('${l.subtitle}\n${l.time}', style: const TextStyle(fontSize: 11, height: 1.3)),
                                    isThreeLine: true,
                                  ),
                                );
                              },
                            ))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: visibleRooms.length,
                          itemBuilder: (_, i) => _buildRoomCard(visibleRooms[i]),
                        ),
        ),
      ]),
      floatingActionButton: _tab == 'history'
          ? null
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFFDCE2F9),
              foregroundColor: const Color(0xFF1E3A8A),
              elevation: 2,
              onPressed: () => _tab == 'expenses' ? _showExpenseDialog() : _showRoomDialog(),
              icon: const Icon(Icons.add),
              label: Text(_tab == 'expenses' ? 'Add expense' : 'Add room', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
    );
  }

  Widget _buildRoomCard(RoomModel room) {
    final rTenants = _tenants.where((t) => t.roomId == room.id).toList();
    final occ = rTenants.length;
    final isFull = occ >= room.totalBeds, isVacant = occ == 0;
    final Color statusBg = isFull ? const Color(0xFFE6F6EC) : (isVacant ? const Color(0xFFE8F0FE) : const Color(0xFFFEF3E2));
    final Color statusTxt = isFull ? const Color(0xFF15803D) : (isVacant ? const Color(0xFF1D4ED8) : const Color(0xFFB45309));
    final String statusLabel = isFull ? 'Fully occupied' : (isVacant ? 'Vacant' : 'Partially occupied');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => _showRoomDialog(room: room),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.door_front_door_outlined, color: statusTxt)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 2),
                Text('$occ/${room.totalBeds} beds full • Rent: ₹${room.defaultRent}\nPer bed', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.2)),
              ]),
            ),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)), child: Text(statusLabel, style: TextStyle(color: statusTxt, fontWeight: FontWeight.w600, fontSize: 12))),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.grey.shade600, size: 20),
          ]),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: room.totalBeds,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 3.6),
          itemBuilder: (_, bedIdx) {
            final matches = rTenants.where((x) => x.bedIndex == bedIdx).toList();
            final t = matches.isEmpty ? null : matches.first;
            if (t == null) {
              return InkWell(
                onTap: () => _showBedSheet(room, bedIdx, null),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBBF7D0))),
                  child: const Row(children: [
                    Icon(Icons.bed_outlined, size: 16, color: Color(0xFF15803D)),
                    SizedBox(width: 6),
                    Expanded(child: Text('Vacant', style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w500, fontSize: 13))),
                    Icon(Icons.add, size: 16, color: Color(0xFF15803D)),
                  ]),
                ),
              );
            }
            final paid = _paid(t.id), bal = (t.monthlyRent - paid).clamp(0, t.monthlyRent);
            final isPaid = bal == 0, overdue = _isOverdue(t);
            final amtColor = isPaid ? const Color(0xFF15803D) : (overdue ? const Color(0xFFDC2626) : const Color(0xFF2563EB));

            return InkWell(
              onTap: () => _showBedSheet(room, bedIdx, t),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                child: Row(children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 4),
                  Expanded(child: Text(t.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  Text('₹${isPaid ? t.monthlyRent : bal}', style: TextStyle(color: amtColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade500),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }
}
