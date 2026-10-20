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
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
      ),
      home: const RentTrackerHome(),
    );
  }
}

class Tenant {
  String id, name, floor, room, bed, phone;
  int monthlyRent, dueDay, depositAmount, depositPaid;

  Tenant({
    required this.id, required this.name, required this.floor,
    required this.room, required this.bed, required this.phone,
    required this.monthlyRent, required this.dueDay,
    required this.depositAmount, required this.depositPaid,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'floor': floor, 'room': room, 'bed': bed,
    'phone': phone, 'monthlyRent': monthlyRent, 'dueDay': dueDay,
    'depositAmount': depositAmount, 'depositPaid': depositPaid,
  };

  factory Tenant.fromJson(Map<String, dynamic> j) => Tenant(
    id: j['id'] ?? '', name: j['name'] ?? '',
    floor: j['floor'] ?? 'Ground Floor', room: j['room'] ?? '',
    bed: j['bed'] ?? 'Bed 1', phone: j['phone'] ?? '',
    monthlyRent: j['monthlyRent'] ?? 0, dueDay: j['dueDay'] ?? 5,
    depositAmount: j['depositAmount'] ?? 0, depositPaid: j['depositPaid'] ?? 0,
  );
}

class RentTrackerHome extends StatefulWidget {
  const RentTrackerHome({super.key});
  @override
  State<RentTrackerHome> createState() => _RentTrackerHomeState();
}

class _RentTrackerHomeState extends State<RentTrackerHome> {
  static const _storageKey = 'easyrent_flutter_v5';
  List<Tenant> _tenants = [];
  Map<String, Map<String, dynamic>> _payments = {};
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _filter = 'all', _search = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _mKey => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
  String get _mName => '${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][_month.month - 1]} ${_month.year}';

  int _paid(String id) => _payments[_mKey]?[id]?['paidAmount'] ?? 0;
  String _updated(String id) => _payments[_mKey]?[id]?['lastUpdated'] ?? '';

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      _importJson(raw, showMsg: false);
    } else {
      _tenants = [
        Tenant(id: '1', name: 'Rahul Nair', floor: '1st Floor', room: '101', bed: 'Bed A', phone: '9876543210', monthlyRent: 8000, dueDay: 5, depositAmount: 15000, depositPaid: 15000),
      ];
      _saveData();
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {'tenants': _tenants.map((t) => t.toJson()).toList(), 'payments': _payments};
    await prefs.setString(_storageKey, jsonEncode(data));
    setState(() {});
  }

  void _importJson(String raw, {bool showMsg = true}) {
    try {
      final decoded = jsonDecode(raw);
      setState(() {
        _tenants = (decoded['tenants'] as List? ?? []).map((e) => Tenant.fromJson(e)).toList();
        _payments = (decoded['payments'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v)));
      });
      _saveData();
      if (showMsg) _msg('Backup restored successfully!');
    } catch (e) {
      if (showMsg) _msg('Invalid backup data!');
    }
  }

  void _msg(String txt) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));

  void _setRent(Tenant t, int amt) {
    final now = DateTime.now();
    _payments.putIfAbsent(_mKey, () => {})[t.id] = {
      'paidAmount': amt.clamp(0, t.monthlyRent * 2),
      'lastUpdated': amt > 0 ? '${now.day}/${now.month}/${now.year}' : ''
    };
    _saveData();
  }

  void _showRentDialog(Tenant t) {
    final paid = _paid(t.id), bal = (t.monthlyRent - paid).clamp(0, t.monthlyRent);
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${t.name} (${t.room}) - Rent'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Monthly Rent: ₹${t.monthlyRent}\nPaid: ₹$paid | Balance: ₹$bal', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Add Rent Received (₹)', border: OutlineInputBorder())),
        ]),
        actions: [
          if (paid > 0) TextButton(onPressed: () { _setRent(t, 0); Navigator.pop(context); }, child: const Text('Reset', style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () { _setRent(t, t.monthlyRent); Navigator.pop(context); }, child: const Text('Full Paid')),
          FilledButton(onPressed: () {
            final add = int.tryParse(ctrl.text) ?? 0;
            if (add > 0) _setRent(t, paid + add);
            Navigator.pop(context);
          }, child: const Text('Save')),
        ],
      ),
    );
  }

  void _showDepositDialog(Tenant t) {
    final totalCtrl = TextEditingController(text: '${t.depositAmount}'), addCtrl = TextEditingController();
    final bal = (t.depositAmount - t.depositPaid).clamp(0, t.depositAmount);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${t.name} - Deposit'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: totalCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Agreed Deposit (₹)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Text('Collected: ₹${t.depositPaid} | Pending: ₹$bal', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          const SizedBox(height: 12),
          TextField(controller: addCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Add Deposit Received (₹)', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () { t.depositPaid = 0; _saveData(); Navigator.pop(context); }, child: const Text('Reset', style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () {
            t.depositAmount = int.tryParse(totalCtrl.text) ?? t.depositAmount;
            t.depositPaid = t.depositAmount;
            _saveData(); Navigator.pop(context);
          }, child: const Text('Full Paid')),
          FilledButton(onPressed: () {
            t.depositAmount = int.tryParse(totalCtrl.text) ?? t.depositAmount;
            t.depositPaid = (t.depositPaid + (int.tryParse(addCtrl.text) ?? 0)).clamp(0, 9999999);
            _saveData(); Navigator.pop(context);
          }, child: const Text('Save')),
        ],
      ),
    );
  }

  void _showTenantDialog({Tenant? t}) {
    final isEdit = t != null;
    final nameC = TextEditingController(text: t?.name ?? ''), floorC = TextEditingController(text: t?.floor ?? 'Ground Floor'),
          roomC = TextEditingController(text: t?.room ?? ''), bedC = TextEditingController(text: t?.bed ?? 'Bed 1'),
          phoneC = TextEditingController(text: t?.phone ?? ''), rentC = TextEditingController(text: t?.monthlyRent.toString() ?? ''),
          depTC = TextEditingController(text: t?.depositAmount.toString() ?? '0'), depPC = TextEditingController(text: t?.depositPaid.toString() ?? '0'),
          dueC = TextEditingController(text: t?.dueDay.toString() ?? '5');

    Widget tf(TextEditingController c, String lbl, [bool num = false]) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(controller: c, keyboardType: num ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: lbl, isDense: true, border: const OutlineInputBorder())),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Tenant' : 'Add Tenant'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          tf(nameC, 'Tenant Name'), tf(floorC, 'Floor (e.g. 1st Floor)'), tf(roomC, 'Room No (e.g. 101)'),
          tf(bedC, 'Bed No (e.g. Bed A)'), tf(phoneC, 'Phone', true), tf(rentC, 'Monthly Rent (₹)', true),
          tf(depTC, 'Total Security Deposit (₹)', true), tf(depPC, 'Deposit Paid (₹)', true), tf(dueC, 'Due Day (1-31)', true),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final rent = int.tryParse(rentC.text) ?? 0;
            if (nameC.text.trim().isEmpty || roomC.text.trim().isEmpty || rent <= 0) return;
            final newT = Tenant(
              id: isEdit ? t.id : DateTime.now().millisecondsSinceEpoch.toString(),
              name: nameC.text.trim(), floor: floorC.text.trim(), room: roomC.text.trim(), bed: bedC.text.trim(),
              phone: phoneC.text.trim(), monthlyRent: rent, dueDay: (int.tryParse(dueC.text) ?? 5).clamp(1, 31),
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
    int col = 0, pen = 0, paidCnt = 0;
    final sb = StringBuffer('=== EASYRENT REPORT ($_mName) ===\n');
    for (var t in _tenants) {
      final p = _paid(t.id), b = (t.monthlyRent - p).clamp(0, t.monthlyRent);
      col += p; pen += b;
      if (p >= t.monthlyRent) paidCnt++;
      sb.writeln('• ${t.name} (${t.floor}, ${t.room}-${t.bed}) | Rent: ₹${t.monthlyRent} | Paid: ₹$p | Due: ₹$b | Dep: ₹${t.depositPaid}/₹${t.depositAmount}');
    }
    final summary = 'Total Tenants: ${_tenants.length} (Paid: $paidCnt, Pending: ${_tenants.length - paidCnt})\nCollected Rent: ₹$col | Pending Due: ₹$pen\n---------------------------------\n';
    final fullReport = '$summary$sb';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Report - $_mName'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: SelectableText(fullReport, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
        ),
        actions: [
          TextButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: fullReport)); _msg('Report copied!'); }, icon: const Icon(Icons.copy, size: 16), label: const Text('Copy')),
          FilledButton.icon(onPressed: () => Share.share(fullReport, subject: 'EasyRent Report $_mName'), icon: const Icon(Icons.download, size: 16), label: const Text('Download / Share')),
        ],
      ),
    );
  }

  void _showBackupDialog() {
    final jsonStr = jsonEncode({'tenants': _tenants.map((t) => t.toJson()).toList(), 'payments': _payments});
    final restoreCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Backup & Restore'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Save a backup of all tenants & payments to WhatsApp/Drive, or paste backup code below to restore.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => Share.share(jsonStr, subject: 'EasyRent_Backup.json'),
              icon: const Icon(Icons.cloud_upload), label: const Text('Export / Share Backup'),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () { Clipboard.setData(ClipboardData(text: jsonStr)); _msg('Backup data copied!'); },
              icon: const Icon(Icons.copy), label: const Text('Copy Backup Text'),
            ),
            const Divider(height: 24),
            TextField(controller: restoreCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Paste Backup Data Here', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () {
                if (restoreCtrl.text.trim().isNotEmpty) {
                  _importJson(restoreCtrl.text.trim());
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.settings_backup_restore), label: const Text('Restore Data'),
            ),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int col = 0, pen = 0, depCol = 0, depExp = 0;
    for (final t in _tenants) {
      final p = _paid(t.id);
      col += p; pen += (t.monthlyRent - p).clamp(0, t.monthlyRent);
      depExp += t.depositAmount; depCol += t.depositPaid;
    }

    final list = _tenants.where((t) {
      final p = _paid(t.id);
      if (_filter == 'paid' && p < t.monthlyRent) return false;
      if (_filter == 'partial' && (p == 0 || p >= t.monthlyRent)) return false;
      if (_filter == 'due' && p >= t.monthlyRent) return false;
      if (_filter == 'dep_due' && (t.depositAmount - t.depositPaid) <= 0) return false;
      final q = _search.toLowerCase();
      return '${t.name} ${t.floor} ${t.room} ${t.bed}'.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('EasyRent', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _showReportDialog, icon: const Icon(Icons.assessment_outlined), tooltip: 'Detailed Report'),
          IconButton(onPressed: _showBackupDialog, icon: const Icon(Icons.cloud_sync_outlined), tooltip: 'Backup & Restore'),
          IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left)),
          Center(child: Text(_mName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right)),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(children: [
            _statCard('Collected Rent', '₹$col', Colors.green.shade700),
            const SizedBox(width: 8),
            _statCard('Pending Due', '₹$pen', Colors.red.shade700),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Deposit Held: ₹$depCol / ₹$depExp', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.teal.shade900)),
              Text('Pending: ₹${(depExp - depCol).clamp(0, depExp)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepOrange.shade800)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search name, floor, room, bed...', prefixIcon: const Icon(Icons.search),
              filled: true, fillColor: Colors.white, isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            for (final f in [('all', 'All'), ('due', 'Rent Due'), ('partial', 'Partial'), ('paid', 'Paid'), ('dep_due', 'Deposit Due')])
              Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(f.$2), selected: _filter == f.$1, onSelected: (_) => setState(() => _filter = f.$1))),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No tenants found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12), itemCount: list.length,
                  itemBuilder: (_, i) {
                    final t = list[i];
                    final paid = _paid(t.id), bal = (t.monthlyRent - paid).clamp(0, t.monthlyRent), depBal = (t.depositAmount - t.depositPaid).clamp(0, t.depositAmount);
                    final isPaid = paid >= t.monthlyRent;
                    return Card(
                      color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Expanded(child: Text('${t.name} • ${t.floor} - ${t.room} (${t.bed})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                            IconButton(icon: const Icon(Icons.edit_outlined, size: 18), visualDensity: VisualDensity.compact, onPressed: () => _showTenantDialog(t: t)),
                            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey), visualDensity: VisualDensity.compact, onPressed: () { _tenants.removeWhere((x) => x.id == t.id); _saveData(); }),
                          ]),
                          Text('Rent: ₹${t.monthlyRent} | Paid: ₹$paid | Due Day: ${t.dueDay}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                          Text('Deposit: ₹${t.depositPaid}/₹${t.depositAmount} ${depBal > 0 ? "(Due: ₹$depBal)" : "✓"}', style: TextStyle(color: depBal > 0 ? Colors.deepOrange : Colors.teal, fontSize: 12, fontWeight: FontWeight.w600)),
                          if (_updated(t.id).isNotEmpty) Text('Updated: ${_updated(t.id)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(isPaid ? '✓ Rent Paid' : 'Rent Due: ₹$bal', style: TextStyle(color: isPaid ? Colors.green.shade800 : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                            Row(children: [
                              if (!isPaid || depBal > 0)
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18), visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: 'Hello ${t.name} (${t.room}-${t.bed}), $_mName rent due is ₹$bal. ${depBal > 0 ? "Pending Deposit: ₹$depBal." : ""} Please pay soon.'));
                                    _msg('Reminder copied!');
                                  },
                                ),
                              OutlinedButton(onPressed: () => _showDepositDialog(t), style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact), child: const Text('Deposit')),
                              const SizedBox(width: 6),
                              FilledButton.tonal(onPressed: () => _showRentDialog(t), style: FilledButton.styleFrom(visualDensity: VisualDensity.compact), child: const Text('Rent')),
                            ]),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showTenantDialog(), icon: const Icon(Icons.person_add), label: const Text('Add Tenant')),
    );
  }

  Widget _statCard(String lbl, String val, Color col) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(lbl, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: col)),
      ]),
    ),
  );
}
