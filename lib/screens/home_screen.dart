import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/room.dart';
import '../models/tenant.dart';
import '../models/expense.dart';
import '../models/log_entry.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/room_card.dart';
import '../widgets/expense_card.dart';
import '../widgets/summary_chips.dart';
import 'lock_screen.dart';

const _blue = Color(0xFF2563EB);
const _green = Color(0xFF15803D);
const _red = Color(0xFFDC2626);
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

int _i(dynamic v, int d) => int.tryParse('$v') ?? d;
String _s(dynamic v, [String d = '']) => v == null ? d : '$v';
String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
String _iso(DateTime d) => '${_key(d)}-${d.day.toString().padLeft(2, '0')}';
String _fmt(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
}
String _csv(String s) => '"${s.replaceAll('"', '""')}"';

class PropertyHome extends StatefulWidget {
  final void Function(bool isDark)? onThemeChanged;
  const PropertyHome({super.key, this.onThemeChanged});
  @override
  State<PropertyHome> createState() => _PropertyHomeState();
}

class _PropertyHomeState extends State<PropertyHome>
    with WidgetsBindingObserver {
  final _authService = AuthService();

  List<RoomModel> _rooms = [];
  List<Tenant> _tenants = [];
  List<ExpenseItem> _expenses = [];
  List<LogEntry> _logs = [];
  Map<String, Map<String, dynamic>> _payments = {};
  String _lastBackup = 'Never', _appPin = '1234', _tab = 'rooms';
  bool _lockEnabled = false, _isLocked = false, _darkMode = false;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedFloor;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive) &&
        _lockEnabled &&
        !_isLocked) {
      setState(() => _isLocked = true);
    }
  }

  String get _mKey => _key(_month);
  String get _mName => '${_months[_month.month - 1]} ${_month.year}';
  String _id() => '${DateTime.now().microsecondsSinceEpoch}${_seq++}';
  void _msg(String t) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
    }
  }

  String _nowStamp() {
    final n = DateTime.now(), h = n.hour % 12 == 0 ? 12 : n.hour % 12;
    return '${n.day}/${n.month}/${n.year} $h:${n.minute.toString().padLeft(2, '0')} ${n.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _addLog(String title, String sub, String type, {String tenantId = ''}) {
    _logs.insert(
      0,
      LogEntry(
        id: _id(),
        title: title,
        subtitle: sub,
        type: type,
        time: _nowStamp(),
        monthKey: _mKey,
        tenantId: tenantId,
      ),
    );
    if (_logs.length > 500) _logs.removeRange(500, _logs.length);
  }

  int _paid(Tenant t, [String? k]) =>
      _i(_payments[k ?? _mKey]?[t.id]?['paid'], 0);
  int _rent(Tenant t, [String? k]) =>
      _i(_payments[k ?? _mKey]?[t.id]?['rent'], t.monthlyRent);

  void _setPaid(Tenant t, int paid) =>
      _payments.putIfAbsent(_mKey, () => {})[t.id] = {
        'paid': paid,
        'rent': _rent(t)
      };

  DateTime _due(Tenant t, String k) {
    final y = int.parse(k.substring(0, 4)),
        m = int.parse(k.substring(5)),
        last = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, t.dueDay > last ? last : t.dueDay);
  }

  bool _overdue(Tenant t, String k) =>
      _paid(t, k) < _rent(t, k) && !DateTime.now().isBefore(_due(t, k));

  String _lateText(Tenant t) {
    final d = DateTime.now().difference(_due(t, _mKey)).inDays;
    return d <= 0 ? 'Due today' : '$d days late';
  }

  String _roomName(String id) =>
      _rooms.where((r) => r.id == id).map((r) => r.name).join();

  MonthSummary _summary([String? k]) {
    final key = k ?? _mKey, s = MonthSummary();
    for (final t in _tenants.where((t) => t.activeIn(key))) {
      final r = _rent(t, key), p = _paid(t, key), bal = (r - p).clamp(0, r);
      s.expected += r;
      s.collected += p;
      s.depHeld += t.depositPaid;
      s.depPending += (t.depositAmount - t.depositPaid).clamp(0, t.depositAmount);
      if (_overdue(t, key)) {
        s.overdue += bal;
        s.overdueList.add(t);
      } else {
        s.upcoming += bal;
      }
    }
    s.expenses = _expenses
        .where((e) => e.monthKey == key)
        .fold(0, (a, e) => a + e.amount);
    return s;
  }

  Future<void> _biometricUnlock() async {
    final ok = await _authService.authenticate();
    if (ok && mounted) setState(() => _isLocked = false);
  }

  Future<void> _saveLock() async {
    await StorageService.saveSettings(
      pin: _appPin,
      lock: _lockEnabled,
      dark: _darkMode,
    );
  }

  Map<String, dynamic> _backupMap() => {
        'app': 'EasyRent_Tracker',
        'version': 4,
        'lastBackupTime': _lastBackup,
        'rooms': _rooms.map((r) => r.toJson()).toList(),
        'tenants': _tenants.map((t) => t.toJson()).toList(),
        'expenses': _expenses.map((e) => e.toJson()).toList(),
        'logs': _logs.map((l) => l.toJson()).toList(),
        'payments': _payments,
      };

  Future<void> _saveData() async {
    if (mounted) setState(() {});
    try {
      await StorageService.saveRawData(jsonEncode(_backupMap()));
    } catch (e) {
      _msg('Could not save data: $e');
    }
  }

  Future<void> _loadData() async {
    final settings = await StorageService.loadSettings();
    _appPin = _s(settings['pin'], '1234');
    _lockEnabled = settings['lock'] == true;
    _darkMode = settings['dark'] == true;
    final legacy = settings['hasPin'] != true;

    final raw = await StorageService.loadRawData();
    if (raw != null) {
      _importJson(raw, silent: true, save: false, legacyLock: legacy);
    }
    if (legacy) await _saveLock();
    if (!mounted) return;
    setState(() => _isLocked = _lockEnabled);
    if (_lockEnabled) _biometricUnlock();
  }

  bool _importJson(String raw,
      {bool silent = false, bool save = true, bool legacyLock = false}) {
    try {
      final d = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
          (d[k] as List? ?? [])
              .whereType<Map>()
              .map((e) => f(Map<String, dynamic>.from(e)))
              .toList();
      final rooms = list('rooms', RoomModel.fromJson),
          tenants = list('tenants', Tenant.fromJson);
      final expenses = list('expenses', ExpenseItem.fromJson),
          logs = list('logs', LogEntry.fromJson);
      final pay = <String, Map<String, dynamic>>{};
      (d['payments'] as Map? ?? {}).forEach((m, v) {
        if (v is Map) {
          pay['$m'] = {
            for (final e in v.entries)
              if (e.value is Map)
                '${e.key}': Map<String, dynamic>.from(e.value as Map)
          };
        }
      });
      for (final t in tenants.where((t) => t.joined.isEmpty)) {
        final ks = pay.entries
            .where((e) => e.value.containsKey(t.id))
            .map((e) => e.key)
            .toList()
          ..sort();
        t.joined = ks.isEmpty ? _key(DateTime.now()) : ks.first;
      }
      _rooms = rooms;
      _tenants = tenants;
      _expenses = expenses;
      _logs = logs;
      _payments = pay;
      if (d['lastBackupTime'] != null) _lastBackup = '${d['lastBackupTime']}';
      if (legacyLock) {
        _lockEnabled = d['lockEnabled'] == true;
        _appPin = _s(d['appPin'], '1234');
      }
      if (save) {
        _addLog('Backup Restored', '${_rooms.length} rooms restored', 'info');
        _saveData();
      }
      if (!silent) _msg('Backup restored successfully!');
      return true;
    } catch (_) {
      if (!silent) _msg('Invalid backup code!');
      return false;
    }
  }

  Widget _tf(TextEditingController c, String label,
          {bool digits = false, String? prefix}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          keyboardType: digits ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            prefixText: prefix,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Widget _card(Widget child, {double r = 14, double mb = 10}) => Card(
        elevation: 0,
        margin: EdgeInsets.only(bottom: mb),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: child,
      );

  Widget _iconBox(IconData i, Color fg, Color bg,
          {double pad = 10, double size = 24}) =>
      Container(
        padding: EdgeInsets.all(pad),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Icon(i, color: fg, size: size),
      );

  Widget _list<T>(List<T> items, Widget Function(T) item, String empty) =>
      items.isEmpty
          ? Center(
              child: Text(empty, style: TextStyle(color: Colors.grey.shade600)))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              itemCount: items.length,
              itemBuilder: (_, i) => item(items[i]),
            );

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Yes')),
          ],
        ),
      ) ??
      false;

  void _showLockDialog() {
    final pinC = TextEditingController(text: _appPin);
    var on = _lockEnabled;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.fingerprint, color: _blue),
            SizedBox(width: 8),
            Text('App Lock Settings')
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: on,
              onChanged: (v) => setSt(() => on = v),
              title: const Text('Enable Fingerprint & PIN Lock',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pinC,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Backup PIN (4-6 digits)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ]),
          actions: [
            if (_lockEnabled)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _isLocked = true);
                },
                child: const Text('Lock Now'),
              ),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (pinC.text.trim().length < 4) {
                  _msg('PIN must be at least 4 digits!');
                  return;
                }
                setState(() {
                  _lockEnabled = on;
                  _appPin = pinC.text.trim();
                });
                _saveLock();
                Navigator.pop(ctx);
                _msg(on ? 'App Lock Enabled!' : 'App Lock Disabled.');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExpense(ExpenseItem e) async {
    if (!await _confirm('Delete expense?', '${e.title} • ₹${e.amount}')) return;
    _expenses.removeWhere((x) => x.id == e.id);
    _addLog('Expense Deleted: ${e.title}', '₹${e.amount} (${e.category})', 'info');
    _saveData();
  }

  void _showExpenseDialog({ExpenseItem? exp}) {
    const cats = [
      'Rent', 'Electricity', 'Water', 'Maintenance',
      'Wifi', 'Cleaning', 'Salary', 'Other'
    ];
    final titleC = TextEditingController(text: exp?.title ?? ''),
        amtC = TextEditingController(text: exp == null ? '' : '${exp.amount}');
    final today = DateTime.now();
    var date = exp != null
        ? (DateTime.tryParse(exp.date) ?? today)
        : (_key(today) == _mKey ? today : DateTime(_month.year, _month.month));
    var cat = exp == null
        ? 'Electricity'
        : (cats.contains(exp.category) ? exp.category : 'Other');

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(exp == null ? 'Add Expense' : 'Edit Expense'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: cat,
                decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    isDense: true),
                items: [
                  for (final c in cats)
                    DropdownMenuItem(value: c, child: Text(c))
                ],
                onChanged: (v) => setSt(() => cat = v ?? 'Other'),
              ),
              const SizedBox(height: 10),
              _tf(titleC, 'Description / Note'),
              _tf(amtC, 'Amount (₹)', digits: true, prefix: '₹ '),
              InkWell(
                onTap: () async {
                  final p = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035));
                  if (p != null) setSt(() => date = p);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  child: Text(_fmt(_iso(date))),
                ),
              ),
            ]),
          ),
          actions: [
            if (exp != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteExpense(exp);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final amt = _i(amtC.text.trim(), 0);
                if (amt <= 0) {
                  _msg('Enter a valid amount');
                  return;
                }
                final title =
                    titleC.text.trim().isEmpty ? cat : titleC.text.trim();
                final e = exp ??
                    ExpenseItem(
                        id: _id(),
                        title: '',
                        category: '',
                        amount: 0,
                        date: '',
                        monthKey: '');
                e.title = title;
                e.category = cat;
                e.amount = amt;
                e.date = _iso(date);
                e.monthKey = _key(date);
                if (exp == null) _expenses.add(e);
                _addLog(
                  exp == null
                      ? 'Expense Added: $title'
                      : 'Expense Edited: $title',
                  '₹$amt • $cat • ${_key(date)}',
                  'expense',
                );
                _saveData();
                Navigator.pop(ctx);
              },
              child: Text(exp == null ? 'Save' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomDialog({RoomModel? room}) {
    final nameC = TextEditingController(text: room?.name ?? ''),
        floorC = TextEditingController(
            text: room?.floor ?? _selectedFloor ?? 'First Floor'),
        bedsC = TextEditingController(text: '${room?.totalBeds ?? 4}'),
        rentC = TextEditingController(text: '${room?.defaultRent ?? 4000}');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(room == null ? 'Add Room' : 'Edit Room'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _tf(nameC, 'Room Name (e.g. Room F1)'),
            _tf(floorC, 'Floor (e.g. First Floor)'),
            _tf(bedsC, 'Total Beds', digits: true),
            _tf(rentC, 'Rent Per Bed (₹)', digits: true),
          ]),
        ),
        actions: [
          if (room != null)
            TextButton(
              onPressed: () async {
                if (!await _confirm('Delete ${room.name}?',
                    'Its tenants and their payment history will be removed too.')) {
                  return;
                }
                final ids = _tenants
                    .where((t) => t.roomId == room.id)
                    .map((t) => t.id)
                    .toSet();
                _tenants.removeWhere((t) => ids.contains(t.id));
                for (final m in _payments.values) {
                  m.removeWhere((k, _) => ids.contains(k));
                }
                _rooms.removeWhere((r) => r.id == room.id);
                _addLog('Room Deleted: ${room.name}', room.floor, 'info');
                _saveData();
                if (mounted) Navigator.pop(context);
              },
              child:
                  const Text('Delete Room', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameC.text.trim(),
                  beds = _i(bedsC.text, 4).clamp(1, 20);
              if (name.isEmpty) {
                _msg('Enter room name');
                return;
              }
              if (room != null &&
                  _tenants.any((t) =>
                      t.roomId == room.id &&
                      t.lastMonth.isEmpty &&
                      t.bedIndex >= beds)) {
                _msg('Vacate tenants in beds above $beds first');
                return;
              }
              final r = room ??
                  RoomModel(
                      id: _id(),
                      name: '',
                      floor: '',
                      totalBeds: 4,
                      defaultRent: 4000);
              r.name = name;
              r.floor = floorC.text.trim().isEmpty
                  ? 'Ground Floor'
                  : floorC.text.trim();
              r.totalBeds = beds;
              r.defaultRent = _i(rentC.text, 4000);
              if (room == null) _rooms.add(r);
              _addLog(
                room == null
                    ? 'New Room Created: $name'
                    : 'Room Updated: $name',
                '${r.floor} • $beds beds',
                'info',
              );
              _saveData();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTenantForm(RoomModel room, int bed, Tenant? t) {
    final nameC = TextEditingController(text: t?.name ?? ''),
        phoneC = TextEditingController(text: t?.phone ?? ''),
        rentC =
            TextEditingController(text: '${t?.monthlyRent ?? room.defaultRent}'),
        dueC = TextEditingController(text: '${t?.dueDay ?? 5}'),
        depTC = TextEditingController(text: '${t?.depositAmount ?? 5000}'),
        depPC = TextEditingController(text: '${t?.depositPaid ?? 5000}');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            t == null ? 'Assign Bed ${bed + 1} (${room.name})' : 'Edit Tenant'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _tf(nameC, 'Tenant Name'),
            _tf(phoneC, 'Phone Number', digits: true),
            _tf(rentC, 'Monthly Rent (₹)', digits: true),
            _tf(dueC, 'Rent Due Day (1-31)', digits: true),
            _tf(depTC, 'Total Deposit Agreed (₹)', digits: true),
            _tf(depPC, 'Deposit Paid (₹)', digits: true),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameC.text.trim().isEmpty) {
                _msg('Enter tenant name');
                return;
              }
              final n = t ??
                  Tenant(
                    id: _id(),
                    roomId: room.id,
                    bedIndex: bed,
                    name: '',
                    phone: '',
                    monthlyRent: 0,
                    dueDay: 5,
                    depositAmount: 0,
                    depositPaid: 0,
                    joined: _mKey,
                  );
              n.name = nameC.text.trim();
              n.phone = phoneC.text.trim();
              n.monthlyRent = _i(rentC.text, room.defaultRent);
              n.dueDay = _i(dueC.text, 5).clamp(1, 31);
              n.depositAmount = _i(depTC.text, 0);
              n.depositPaid = _i(depPC.text, 0);
              final snap = _payments[_mKey]?[n.id];
              if (t != null && snap is Map) snap['rent'] = n.monthlyRent;
              if (t == null) _tenants.add(n);
              _addLog(
                t == null
                    ? 'New Tenant Joined: ${n.name}'
                    : 'Tenant Edited: ${n.name}',
                t == null ? '${room.name} (Bed ${bed + 1})' : room.name,
                t == null ? 'deposit' : 'info',
                tenantId: n.id,
              );
              _saveData();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBedSheet(RoomModel room, int bed, Tenant? t) {
    if (t == null) {
      _showTenantForm(room, bed, null);
      return;
    }
    final paid = _paid(t),
        rent = _rent(t),
        bal = (rent - paid).clamp(0, rent),
        depBal = (t.depositAmount - t.depositPaid).clamp(0, t.depositAmount);
    final rentC = TextEditingController(), depC = TextEditingController();
    final logs = _logs.where((l) => l.tenantId == t.id).take(8).toList();
    void close() => Navigator.pop(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Expanded(
              child: Text('${t.name} (${room.name})',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold))),
          IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () {
                close();
                _showTenantForm(room, bed, t);
              }),
          IconButton(
            icon: const Icon(Icons.person_remove_outlined,
                color: Colors.red, size: 20),
            onPressed: () async {
              if (!await _confirm('Vacate ${t.name}?',
                  'Stays in $_mName and earlier months, removed from next month. Records are kept.')) {
                return;
              }
              if (t.joined == _mKey &&
                  !_payments.values.any((m) => m.containsKey(t.id))) {
                _tenants.remove(t);
              } else {
                t.lastMonth = _mKey;
              }
              _addLog('Tenant Vacated: ${t.name}',
                  '${room.name} (Bed ${bed + 1})', 'info',
                  tenantId: t.id);
              _saveData();
              if (mounted) close();
            },
          ),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.WithOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monthly Rent: ₹$rent • Due Day: ${t.dueDay}'),
                      Text(
                        'Paid ($_mName): ₹$paid • Balance: ₹$bal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: bal == 0
                              ? _green
                              : (_overdue(t, _mKey) ? _red : _blue),
                        ),
                      ),
                      const Divider(),
                      Text(
                        'Deposit Held: ₹${t.depositPaid} / ₹${t.depositAmount} ${depBal > 0 ? "(Due: ₹$depBal)" : "✓"}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, color: Colors.teal),
                      ),
                    ],
                  ),
                ),
                if (t.phone.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.call, size: 18),
                        label: const Text('Call'),
                        onPressed: () => launchUrl(Uri.parse('tel:${t.phone}')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.chat, size: 18),
                        label: const Text('WhatsApp'),
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366)),
                        onPressed: () {
                          final phone =
                              t.phone.replaceAll(RegExp(r'[^0-9]'), '');
                          final msg = Uri.encodeComponent(
                              'Hello ${t.name}, regarding your rent for $_mName.');
                          launchUrl(
                            Uri.parse('https://wa.me/91$phone?text=$msg'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _tf(rentC, 'Add Rent (₹)', digits: true)),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: () {
                      final add = _i(rentC.text, 0);
                      if (add > 0) {
                        _setPaid(t, (paid + add).clamp(0, rent * 2));
                        _addLog('Rent Received: +₹$add',
                            '${t.name} (${room.name}) • $_mName', 'rent',
                            tenantId: t.id);
                        _saveData();
                      }
                      close();
                    },
                    child: const Text('Add'),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: () {
                      _setPaid(t, rent);
                      _addLog('Full Rent Paid: ₹$rent',
                          '${t.name} (${room.name}) • $_mName', 'rent',
                          tenantId: t.id);
                      _saveData();
                      close();
                    },
                    child: const Text('Full'),
                  ),
                ]),
                Row(children: [
                  Expanded(child: _tf(depC, 'Add Deposit (₹)', digits: true)),
                  const SizedBox(width: 6),
                  FilledButton.tonal(
                    onPressed: () {
                      final add = _i(depC.text, 0);
                      if (add > 0) {
                        t.depositPaid =
                            (t.depositPaid + add).clamp(0, 999999);
                        _addLog('Deposit Received: +₹$add',
                            '${t.name} (${room.name})', 'deposit',
                            tenantId: t.id);
                        _saveData();
                      }
                      close();
                    },
                    child: const Text('Add Dep'),
                  ),
                ]),
                if (logs.isNotEmpty) ...[
                  const Divider(height: 22),
                  const Text('Recent Activity / Payment History:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  for (final l in logs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Icon(
                          l.type == 'rent'
                              ? Icons.check_circle_outline
                              : Icons.history,
                          size: 14,
                          color: _green,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('${l.title} • ${l.time}',
                              style: const TextStyle(fontSize: 11)),
                        ),
                      ]),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (paid > 0)
            TextButton(
              onPressed: () async {
                if (!await _confirm('Reset rent?',
                    'Paid amount for $_mName will become ₹0.')) {
                  return;
                }
                _setPaid(t, 0);
                _addLog('Rent Reset to ₹0',
                    '${t.name} (${room.name}) • $_mName', 'info',
                    tenantId: t.id);
                _saveData();
                if (mounted) close();
              },
              child:
                  const Text('Reset Rent', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: close, child: const Text('Close')),
        ],
      ),
    );
  }

  void _remind(Tenant t) => Share.share(
      'Hi ${t.name}, your rent of ₹${_rent(t) - _paid(t)} for $_mName was due on ${_fmt(_iso(_due(t, _mKey)))}. Please pay at the earliest. Thank you.');

  String _reportText() {
    final s = _summary(),
        act = _tenants.where((t) => t.activeIn(_mKey)).toList();
    final beds = _rooms.fold(0, (a, r) => a + r.totalBeds),
        maxRent = _rooms.fold(0, (a, r) => a + r.totalBeds * r.defaultRent);
    final b = StringBuffer()
      ..writeln('=== EASYRENT REPORT ($_mName) ===')
      ..writeln(
          'Occupancy: ${act.length}/$beds beds (${(beds - act.length).clamp(0, beds)} vacant)')
      ..writeln('Expected: ₹${s.expected} | Max potential: ₹$maxRent')
      ..writeln('Collected: ₹${s.collected}')
      ..writeln(
          'Pending: ₹${s.overdue + s.upcoming} (Overdue ₹${s.overdue} | Not yet due ₹${s.upcoming})')
      ..writeln('Expenses: ₹${s.expenses} | Net Profit: ₹${s.net}')
      ..writeln(
          'Deposits held: ₹${s.depHeld} | Deposit pending: ₹${s.depPending}');

    if (s.overdueList.isNotEmpty) {
      b.writeln('\n=== OVERDUE ===');
      for (final t in s.overdueList) {
        b.writeln(
            ' ! ${t.name} (${_roomName(t.roomId)}): ₹${_rent(t) - _paid(t)} • ${_lateText(t)}');
      }
    }

    b.writeln('\n=== BY ROOM ===');
    for (final r in _rooms) {
      b.writeln('[${r.name} - ${r.floor}]');
      final rt = act.where((t) => t.roomId == r.id).toList();
      if (rt.isEmpty) b.writeln(' All beds vacant');
      for (final t in rt) {
        b.writeln(
            ' • ${t.name}: Rent ₹${_rent(t)} | Paid ₹${_paid(t)} | Dep ₹${t.depositPaid}/₹${t.depositAmount}');
      }
    }

    b.writeln('\n=== EXPENSES BY CATEGORY ===');
    final cat = <String, int>{};
    for (final e in _expenses.where((e) => e.monthKey == _mKey)) {
      cat[e.category] = (cat[e.category] ?? 0) + e.amount;
    }
    if (cat.isEmpty) b.writeln(' No expenses recorded.');
    cat.forEach((k, v) => b.writeln(' • $k: ₹$v'));

    b.writeln('\n=== ${_month.year} (Collected - Expenses = Net) ===');
    var yc = 0, ye = 0;
    for (var m = 1; m <= 12; m++) {
      final y = _summary('${_month.year}-${m.toString().padLeft(2, '0')}');
      yc += y.collected;
      ye += y.expenses;
      if (y.collected + y.expenses > 0) {
        b.writeln(
            ' ${_months[m - 1]}: ₹${y.collected} - ₹${y.expenses} = ₹${y.net}');
      }
    }
    b.writeln(' Total: ₹$yc - ₹$ye = ₹${yc - ye}');
    return b.toString();
  }

  Future<void> _shareCsv() async {
    final rows = ['Room,Bed,Tenant,Phone,Rent,Paid,Balance,Status'];
    for (final t in _tenants.where((t) => t.activeIn(_mKey))) {
      final r = _rent(t),
          p = _paid(t),
          status = p >= r ? 'Paid' : (_overdue(t, _mKey) ? 'Overdue' : 'Pending');
      rows.add(
          '${_csv(_roomName(t.roomId))},${t.bedIndex + 1},${_csv(t.name)},${_csv(t.phone)},$r,$p,${(r - p).clamp(0, r)},$status');
    }
    try {
      final f = StorageService.writeTempFile(
          'EasyRent_$_mKey.csv', rows.join('\n'));
      await Share.shareXFiles([XFile(f.path)], text: 'EasyRent $_mName');
    } catch (e) {
      _msg('Export failed: $e');
    }
  }

  void _showReportDialog() {
    final text = _reportText(), od = _summary().overdueList;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Report - $_mName'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(text,
                    style:
                        const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                if (od.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text('Send rent reminder',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  for (final t in od)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${t.name} • ₹${_rent(t) - _paid(t)}'),
                      subtitle: Text(_lateText(t)),
                      trailing: IconButton(
                          icon: const Icon(Icons.send, color: _green),
                          onPressed: () => _remind(t)),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                _msg('Copied!');
              },
              child: const Text('Copy')),
          TextButton(onPressed: _shareCsv, child: const Text('CSV')),
          FilledButton(
              onPressed: () => Share.share(text), child: const Text('Share')),
        ],
      ),
    );
  }

  void _showBackupDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.cloud_sync_outlined, color: _blue),
            SizedBox(width: 8),
            Text('Backup & Restore')
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      'Rooms: ${_rooms.length} | Tenants: ${_tenants.length} | Expenses: ${_expenses.length}\nLast Backup: $_lastBackup',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () async {
                      _lastBackup = _nowStamp();
                      _saveData();
                      setSt(() {});
                      final json = jsonEncode(_backupMap());
                      try {
                        final f = StorageService.writeTempFile(
                            'EasyRent_Backup.json', json);
                        await Share.shareXFiles([XFile(f.path)],
                            text: 'EasyRent Backup ($_lastBackup)');
                      } catch (_) {
                        Share.share(json);
                      }
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Export Backup File (.json)'),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () {
                      _lastBackup = _nowStamp();
                      _saveData();
                      setSt(() {});
                      Clipboard.setData(
                          ClipboardData(text: jsonEncode(_backupMap())));
                      _msg('Backup code copied!');
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Backup Code'),
                  ),
                  const Divider(height: 24),
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Paste backup JSON here...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      if (ctrl.text.trim().isEmpty ||
                          !await _confirm('Restore backup?',
                              'This replaces ALL current data.')) {
                        return;
                      }
                      if (_importJson(ctrl.text.trim()) && mounted) {
                        Navigator.pop(ctx);
                      }
                    },
                    icon: const Icon(Icons.settings_backup_restore),
                    label: const Text('Restore Data Now'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'))
          ],
        ),
      ),
    );
  }

  Widget _floorCard(String fl) {
    final fr = _rooms.where((r) => r.floor == fl).toList(),
        ids = fr.map((r) => r.id).toSet();
    final occ = _tenants
            .where((t) => t.activeIn(_mKey) && ids.contains(t.roomId))
            .length,
        beds = fr.fold(0, (a, r) => a + r.totalBeds);
    return _card(
      ListTile(
        leading: _iconBox(
            Icons.apartment, Colors.blue.shade700, Colors.blue.shade50),
        title: Text(fl, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${fr.length} Rooms • $occ/$beds beds occupied'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => setState(() {
          _selectedFloor = fl;
          _tab = 'rooms';
        }),
      ),
      r: 16,
      mb: 12,
    );
  }

  Widget _logCard(LogEntry l) {
    final MaterialColor c = {
          'rent': Colors.green,
          'deposit': Colors.teal,
          'expense': Colors.red
        }[l.type] ??
        Colors.blue;
    final ic = {
          'rent': Icons.payments_outlined,
          'deposit': Icons.shield_outlined,
          'expense': Icons.money_off_csred_outlined
        }[l.type] ??
        Icons.history;
    return _card(
      ListTile(
        dense: true,
        isThreeLine: true,
        leading: _iconBox(ic, c.shade700, c.shade50, pad: 8, size: 20),
        title: Text(l.title,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: c.shade700)),
        subtitle: Text('${l.subtitle}\n${l.time}',
            style: const TextStyle(fontSize: 11, height: 1.3)),
      ),
      mb: 8,
    );
  }

  Widget _tabBar() {
    const tabs = {
      'floors': 'Floors',
      'rooms': 'Rooms',
      'expenses': 'Expenses',
      'history': 'History'
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Row(
            children: [
              for (final e in tabs.entries) ...[
                if (e.key != 'floors')
                  Container(width: 1, color: Colors.grey.shade400),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _tab = e.key;
                      if (e.key == 'rooms') _selectedFloor = null;
                    }),
                    child: Container(
                      color: _tab == e.key
                          ? const Color(0xFFDCE2F9)
                          : Colors.transparent,
                      alignment: Alignment.center,
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: _tab == e.key ? const Color(0xFF1E3A8A) : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return LockScreen(
        expectedPin: _appPin,
        onUnlocked: () => setState(() => _isLocked = false),
        onBiometricTap: _biometricUnlock,
        onMessage: _msg,
      );
    }

    final s = _summary();
    final floors = _rooms.map((r) => r.floor).toSet().toList();
    final rooms = _selectedFloor == null
        ? _rooms
        : _rooms.where((r) => r.floor == _selectedFloor).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Management',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: _darkMode ? 'Light mode' : 'Dark mode',
            onPressed: () {
              setState(() => _darkMode = !_darkMode);
              _saveLock();
              widget.onThemeChanged?.call(_darkMode);
            },
            icon: Icon(_darkMode ? Icons.light_mode : Icons.dark_mode_outlined),
          ),
          IconButton(
            onPressed: _showLockDialog,
            icon: Icon(
              _lockEnabled ? Icons.lock_outline : Icons.lock_open_outlined,
              color: _lockEnabled ? Colors.blue.shade800 : null,
            ),
          ),
          IconButton(
              onPressed: _showReportDialog,
              icon: const Icon(Icons.assessment_outlined),
              tooltip: 'Report'),
          IconButton(
              onPressed: _showBackupDialog,
              icon: const Icon(Icons.cloud_sync_outlined),
              tooltip: 'Backup'),
          IconButton(
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1)),
              icon: const Icon(Icons.chevron_left)),
          Center(
              child: Text(_mName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 11))),
          IconButton(
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1)),
              icon: const Icon(Icons.chevron_right)),
        ],
      ),
      body: Column(children: [
        SummaryChips(summary: s),
        _tabBar(),
        Expanded(
          child: _tab == 'floors'
              ? _list(floors, _floorCard, 'No rooms yet.')
              : _tab == 'expenses'
                  ? _list(
                      _expenses.where((e) => e.monthKey == _mKey).toList(),
                      (e) => ExpenseCard(
                        expense: e,
                        formattedDate: _fmt(e.date),
                        onEdit: () => _showExpenseDialog(exp: e),
                        onDelete: () => _deleteExpense(e),
                      ),
                      'No expenses recorded for $_mName.',
                    )
                  : _tab == 'history'
                      ? _list(
                          _logs.where((l) => l.monthKey == _mKey).toList(),
                          _logCard,
                          'No history logs for $_mName.',
                        )
                      : _list(
                          rooms,
                          (room) => RoomCard(
                            room: room,
                            activeRoomTenants: _tenants
                                .where(
                                    (t) => t.roomId == room.id && t.activeIn(_mKey))
                                .toList(),
                            getRent: _rent,
                            getPaid: _paid,
                            isOverdue: (t) => _overdue(t, _mKey),
                            onEditRoom: () => _showRoomDialog(room: room),
                            onTapBed: (bed, t) => _showBedSheet(room, bed, t),
                          ),
                          'No rooms yet. Tap "Add room".',
                        ),
        ),
      ]),
      floatingActionButton: _tab == 'history'
          ? null
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFFDCE2F9),
              foregroundColor: const Color(0xFF1E3A8A),
              elevation: 2,
              onPressed: () =>
                  _tab == 'expenses' ? _showExpenseDialog() : _showRoomDialog(),
              icon: const Icon(Icons.add),
              label: Text(
                _tab == 'expenses' ? 'Add expense' : 'Add room',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
    );
  }
}
