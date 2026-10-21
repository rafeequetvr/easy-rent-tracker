import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const EasyRentApp());

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
    id: j['id'] ?? '', name: j['name'] ?? '', floor: j['floor'] ?? 'Ground Floor',
    totalBeds: j['totalBeds'] ?? 4, defaultRent: j['defaultRent'] ?? 4000,
  );
}

class Tenant {
  String id, roomId, name, phone;
  int bedIndex, monthlyRent, dueDay, depositAmount, depositPaid;
  Tenant({
    required this.id, required this.roomId, required this.bedIndex, required this.name,
    required this.phone, required this.monthlyRent, required this.dueDay,
    required this.depositAmount, required this.depositPaid,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'roomId': roomId, 'bedIndex': bedIndex, 'name': name, 'phone': phone,
    'monthlyRent': monthlyRent, 'dueDay': dueDay, 'depositAmount': depositAmount, 'depositPaid': depositPaid,
  };
  factory Tenant.fromJson(Map<String, dynamic> j) => Tenant(
    id: j['id'] ?? '', roomId: j['roomId'] ?? '', bedIndex: j['bedIndex'] ?? 0,
    name: j['name'] ?? '', phone: j['phone'] ?? '', monthlyRent: j['monthlyRent'] ?? 4000,
    dueDay: j['dueDay'] ?? 5, depositAmount: j['depositAmount'] ?? 0, depositPaid: j['depositPaid'] ?? 0,
  );
}

class ExpenseItem {
  String id, title, category, date, monthKey;
  int amount;
  ExpenseItem({required this.id, required this.title, required this.category, required this.amount, required this.date, required this.monthKey});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'category': category, 'amount': amount, 'date': date, 'monthKey': monthKey};
  factory ExpenseItem.fromJson(Map<String, dynamic> j) => ExpenseItem(
    id: j['id'] ?? '', title: j['title'] ?? '', category: j['category'] ?? 'Other',
    amount: j['amount'] ?? 0, date: j['date'] ?? '', monthKey: j['monthKey'] ?? '',
  );
}

class PropertyHome extends StatefulWidget {
  const PropertyHome({super.key});
  @override
  State<PropertyHome> createState() => _PropertyHomeState();
}

class _PropertyHomeState extends State<PropertyHome> {
  static const _storageKey = 'easyrent_master_db_v1';
  List<RoomModel> _rooms = [];
  List<Tenant> _tenants = [];
  List<ExpenseItem> _expenses = [];
  Map<String, Map<String, dynamic>> _payments = {};
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _tab = 'rooms'; // 'floors', 'rooms', 'expenses'
  String? _selectedFloor;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _mKey => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
  String get _mName => '${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][_month.month - 1]} ${_month.year}';

  int _paid(String tId) => _payments[_mKey]?[tId]?['paid'] ?? 0;

  bool _isOverdue(Tenant t) {
    final paid = _paid(t.id);
    if (paid >= t.monthlyRent) return false;
    final now = DateTime.now();
    final curMonth = DateTime(now.year, now.month);
    if (_month.isBefore(curMonth)) return true;
    if (_month.isAfter(curMonth)) return false;
    return now.day >= t.dueDay;
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      _importJson(raw, silent: true);
    } else {
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
        Tenant(id: 't5', roomId: 'r2', bedIndex: 0, name: 'Javad', phone: '', monthlyRent: 4000, dueDay: 5, depositAmount: 5000, depositPaid: 5000),
        Tenant(id: 't6', roomId: 'r2', bedIndex: 1, name: 'Ajsal', phone: '', monthlyRent: 4000, dueDay: 5, depositAmount: 5000, depositPaid: 5000),
        Tenant(id: 't7', roomId: 'r2', bedIndex: 2, name: 'Ashik', phone: '', monthlyRent: 4000, dueDay: 5, depositAmount: 5000, depositPaid: 5000),
      ];
      await _saveData();
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'rooms': _rooms.map((r) => r.toJson()).toList(),
      'tenants': _tenants.map((t) => t.toJson()).toList(),
      'expenses': _expenses.map((e) => e.toJson()).toList(),
      'payments': _payments,
    };
    await prefs.setString(_storageKey, jsonEncode(data));
    if (mounted) setState(() {});
  }

  void _importJson(String raw, {bool silent = false}) {
    try {
      final d = jsonDecode(raw);
      _rooms = (d['rooms'] as List? ?? []).map((e) => RoomModel.fromJson(e)).toList();
      _tenants = (d['tenants'] as List? ?? []).map((e) => Tenant.fromJson(e)).toList();
      _expenses = (d['expenses'] as List? ?? []).map((e) => ExpenseItem.fromJson(e)).toList();
      _payments = (d['payments'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v)));
      _saveData();
      if (!silent) _msg('Backup Restored Successfully!');
    } catch (_) {
      if (!silent) _msg('Invalid Backup Data!');
    }
  }

  void _msg(String txt) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));

  void _showExpenseDialog({ExpenseItem? exp}) {
    final isEdit = exp != null;
    final titleC = TextEditingController(text: exp?.title ?? '');
    final amtC = TextEditingController(text: exp != null ? '${exp.amount}' : '');
    String cat = exp?.category ?? 'Electricity';
    const categories = ['Electricity', 'Water', 'Maintenance', 'Wifi', 'Cleaning', 'Salary', 'Other'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text(isEdit ? 'Edit Expense' : 'Add Expense ($_mName)'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: categories.contains(cat) ? cat : 'Other',
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setSt(() => cat = v ?? 'Other'),
            ),
            const SizedBox(height: 10),
            TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Description / Note (e.g. KSEB Bill)', border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            TextField(controller: amtC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder(), isDense: true)),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final amt = int.tryParse(amtC.text.trim()) ?? 0;
                if (amt <= 0) return;
                final now = DateTime.now();
                final item = ExpenseItem(
                  id: isEdit ? exp.id : now.millisecondsSinceEpoch.toString(),
                  title: titleC.text.trim().isEmpty ? cat : titleC.text.trim(),
                  category: cat,
                  amount: amt,
                  date: isEdit ? exp.date : '${now.day}/${now.month}/${now.year}',
                  monthKey: isEdit ? exp.monthKey : _mKey,
                );
                if (isEdit) {
                  _expenses[_expenses.indexWhere((x) => x.id == exp.id)] = item;
                } else {
                  _expenses.add(item);
                }
                _saveData();
                Navigator.pop(context);
              },
              child: const Text('Save'),
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
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Room Name (e.g. Room F1)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: floorC, decoration: const InputDecoration(labelText: 'Floor (e.g. First Floor)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: bedsC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Beds (e.g. 4 or 6)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: rentC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rent Per Bed (₹)', border: OutlineInputBorder())),
        ])),
        actions: [
          if (isEdit)
            TextButton(
              onPressed: () {
                _tenants.removeWhere((t) => t.roomId == room.id);
                _rooms.removeWhere((r) => r.id == room.id);
                _saveData(); Navigator.pop(context);
              },
              child: const Text('Delete Room', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameC.text.trim().isEmpty) return;
              final newR = RoomModel(
                id: isEdit ? room.id : DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameC.text.trim(), floor: floorC.text.trim(),
                totalBeds: (int.tryParse(bedsC.text) ?? 4).clamp(1, 20),
                defaultRent: int.tryParse(rentC.text) ?? 4000,
              );
              if (isEdit) {
                _rooms[_rooms.indexWhere((x) => x.id == room.id)] = newR;
              } else {
                _rooms.add(newR);
              }
              _saveData(); Navigator.pop(context);
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

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text('${t.name} (${room.name})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () { Navigator.pop(context); _showTenantForm(room, bedIdx, t); }),
          IconButton(icon: const Icon(Icons.person_remove_outlined, color: Colors.red, size: 20), onPressed: () {
            _tenants.removeWhere((x) => x.id == t.id);
            _saveData(); Navigator.pop(context);
          }),
        ]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            FilledButton(onPressed: () {
              final add = int.tryParse(rentCtrl.text) ?? 0;
              _payments.putIfAbsent(_mKey, () => {})[t.id] = {'paid': (paid + add).clamp(0, t.monthlyRent * 2)};
              _saveData(); Navigator.pop(context);
            }, child: const Text('Add')),
            const SizedBox(width: 4),
            OutlinedButton(onPressed: () {
              _payments.putIfAbsent(_mKey, () => {})[t.id] = {'paid': t.monthlyRent};
              _saveData(); Navigator.pop(context);
            }, child: const Text('Full')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: depCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Add Deposit (₹)', isDense: true, border: OutlineInputBorder()))),
            const SizedBox(width: 6),
            FilledButton.tonal(onPressed: () {
              t.depositPaid = (t.depositPaid + (int.tryParse(depCtrl.text) ?? 0)).clamp(0, 999999);
              _saveData(); Navigator.pop(context);
            }, child: const Text('Add Dep')),
          ]),
        ])),
        actions: [
          if (paid > 0)
            TextButton(onPressed: () { _payments.putIfAbsent(_mKey, () => {})[t.id] = {'paid': 0}; _saveData(); Navigator.pop(context); }, child: const Text('Reset Rent', style: TextStyle(color: Colors.red))),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'Hello ${t.name} (${room.name}), your $_mName rent balance is ₹$bal (Due: ${t.dueDay}th).'));
              _msg('WhatsApp Reminder Copied!');
            },
            icon: const Icon(Icons.copy, size: 16), label: const Text('Reminder'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
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
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          tf(nameC, 'Tenant Name'), tf(phoneC, 'Phone Number', true),
          tf(rentC, 'Monthly Rent (₹)', true), tf(dueC, 'Rent Due Day (1-31)', true),
          tf(depTC, 'Total Deposit Agreed (₹)', true), tf(depPC, 'Deposit Paid (₹)', true),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
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
            } else {
              _tenants.add(newT);
            }
            _saveData(); Navigator.pop(context);
          }, child: const Text('Save')),
        ],
      ),
    );
  }

  void _showReportDialog() {
    int col = 0, due = 0, upcoming = 0;
    final sb = StringBuffer('=== PROPERTY REPORT ($_mName) ===\n');
    for (final r in _rooms) {
      sb.writeln('\n[${r.name} - ${r.floor}]');
      final rTenants = _tenants.where((t) => t.roomId == r.id).toList();
      if (rTenants.isEmpty) sb.writeln('  All Beds Vacant');
      for (final t in rTenants) {
        final p = _paid(t.id), b = (t.monthlyRent - p).clamp(0, t.monthlyRent);
        final od = _isOverdue(t);
        col += p;
        if (od) due += b; else upcoming += b;
        final status = b == 0 ? 'PAID' : (od ? 'OVERDUE (₹$b)' : 'UPCOMING (₹$b, Due ${t.dueDay}th)');
        sb.writeln('  • ${t.name}: Paid ₹$p | $status | Dep: ₹${t.depositPaid}/₹${t.depositAmount}');
      }
    }

    final mExpenses = _expenses.where((e) => e.monthKey == _mKey).toList();
    final totalExp = mExpenses.fold(0, (s, e) => s + e.amount);
    sb.writeln('\n=== EXPENSES ($_mName) ===');
    if (mExpenses.isEmpty) {
      sb.writeln('  No expenses recorded.');
    } else {
      for (final e in mExpenses) {
        sb.writeln('  • ${e.title} (${e.category}) - ₹${e.amount} [${e.date}]');
      }
    }

    final net = col - totalExp;
    final header = 'Rent Collected: ₹$col | Expenses: ₹$totalExp\nNet Profit/Balance: ₹$net\nOverdue Rent: ₹$due | Upcoming: ₹$upcoming\n-----------------------------------------';
    final text = '$header\n$sb';

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
    final jsonStr = jsonEncode({
      'rooms': _rooms.map((r) => r.toJson()).toList(),
      'tenants': _tenants.map((t) => t.toJson()).toList(),
      'expenses': _expenses.map((e) => e.toJson()).toList(),
      'payments': _payments,
    });
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Backup & Restore'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilledButton.icon(onPressed: () => Share.share(jsonStr), icon: const Icon(Icons.share), label: const Text('Share / Save Backup')),
          const SizedBox(height: 6),
          OutlinedButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: jsonStr)); _msg('Backup Copied!'); }, icon: const Icon(Icons.copy), label: const Text('Copy Backup Code')),
          const Divider(height: 24),
          TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Paste Backup Code to Restore', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: () { if (ctrl.text.trim().isNotEmpty) { _importJson(ctrl.text.trim()); Navigator.pop(context); } }, child: const Text('Restore Now')),
        ])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final floors = _rooms.map((r) => r.floor).toSet().toList();
    final visibleRooms = _selectedFloor == null ? _rooms : _rooms.where((r) => r.floor == _selectedFloor).toList();
    final mExpenses = _expenses.where((e) => e.monthKey == _mKey).toList();

    int totalCol = 0;
    for (final t in _tenants) {
      totalCol += _paid(t.id);
    }
    final int totalExp = mExpenses.fold(0, (s, e) => s + e.amount);
    final int netProfit = totalCol - totalExp;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Management', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(onPressed: _showReportDialog, icon: const Icon(Icons.assessment_outlined), tooltip: 'Report'),
          IconButton(onPressed: _showBackupDialog, icon: const Icon(Icons.cloud_sync_outlined), tooltip: 'Backup'),
          IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left)),
          Center(child: Text(_mName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right)),
        ],
      ),
      body: Column(children: [
        // Compact Monthly Summary Strip (Collected | Expenses | Net)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Collected: ₹$totalCol', style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 12)),
                Text('Expenses: ₹$totalExp', style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12)),
                Text('Net: ₹$netProfit', style: TextStyle(color: netProfit >= 0 ? const Color(0xFF1E3A8A) : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ),

        // Top Segmented Pill Bar (Floors | Rooms | Expenses)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = 'floors'),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _tab == 'floors' ? const Color(0xFFDCE2F9) : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Floors', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ),
              Container(width: 1, color: Colors.grey.shade400),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() { _tab = 'rooms'; _selectedFloor = null; }),
                  child: Container(
                    color: _tab == 'rooms' ? const Color(0xFFDCE2F9) : Colors.transparent,
                    alignment: Alignment.center,
                    child: const Text('Rooms', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ),
              Container(width: 1, color: Colors.grey.shade400),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = 'expenses'),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _tab == 'expenses' ? const Color(0xFFDCE2F9) : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Expenses', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ),
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
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.apartment, color: Colors.blue.shade700),
                        ),
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
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                                  child: Icon(Icons.receipt_long_outlined, color: Colors.red.shade700),
                                ),
                                title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${e.category} • ${e.date}', style: const TextStyle(fontSize: 12)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('₹${e.amount}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red.shade700)),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      onPressed: () => _showExpenseDialog(exp: e),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                      onPressed: () {
                                        _expenses.removeWhere((x) => x.id == e.id);
                                        _saveData();
                                      },
                                    ),
                                  ],
                                ),
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
      floatingActionButton: FloatingActionButton.extended(
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
    final isFull = occ >= room.totalBeds;
    final isVacant = occ == 0;

    final Color statusBg = isFull ? const Color(0xFFE6F6EC) : (isVacant ? const Color(0xFFE8F0FE) : const Color(0xFFFEF3E2));
    final Color statusTxt = isFull ? const Color(0xFF15803D) : (isVacant ? const Color(0xFF1D4ED8) : const Color(0xFFB45309));
    final String statusLabel = isFull ? 'Fully occupied' : (isVacant ? 'Vacant' : 'Partially occupied');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => _showRoomDialog(room: room),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.door_front_door_outlined, color: statusTxt),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 2),
                Text('$occ/${room.totalBeds} beds full • Rent: ₹${room.defaultRent}\nPer bed',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.2)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
              child: Text(statusLabel, style: TextStyle(color: statusTxt, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.grey.shade600, size: 20),
          ]),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: room.totalBeds,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.6,
          ),
          itemBuilder: (_, bedIdx) {
            final matches = rTenants.where((x) => x.bedIndex == bedIdx).toList();
            final t = matches.isEmpty ? null : matches.first;
            if (t == null) {
              return InkWell(
                onTap: () => _showBedSheet(room, bedIdx, null),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.bed_outlined, size: 16, color: Color(0xFF15803D)),
                    SizedBox(width: 6),
                    Expanded(child: Text('Vacant', style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w500, fontSize: 13))),
                    Icon(Icons.add, size: 16, color: Color(0xFF15803D)),
                  ]),
                ),
              );
            }

            final paid = _paid(t.id);
            final bal = (t.monthlyRent - paid).clamp(0, t.monthlyRent);
            final isPaid = bal == 0;
            final overdue = _isOverdue(t);

            final amtColor = isPaid
                ? const Color(0xFF15803D)
                : (overdue ? const Color(0xFFDC2626) : const Color(0xFF2563EB));

            return InkWell(
              onTap: () => _showBedSheet(room, bedIdx, t),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(t.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  ),
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
