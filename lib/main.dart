import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

void main() {
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
      ),
      home: const RentTrackerHome(),
    );
  }
}

class Tenant {
  final String id;
  final String name;
  final String room;
  final String phone;
  final int monthlyRent;
  final int dueDay;
  final int securityDeposit;
  final int depositPaid;

  Tenant({
    required this.id,
    required this.name,
    required this.room,
    required this.phone,
    required this.monthlyRent,
    required this.dueDay,
    required this.securityDeposit,
    required this.depositPaid,
  });

  Tenant copyWith({
    String? name,
    String? room,
    String? phone,
    int? monthlyRent,
    int? dueDay,
    int? securityDeposit,
    int? depositPaid,
  }) {
    return Tenant(
      id: id,
      name: name ?? this.name,
      room: room ?? this.room,
      phone: phone ?? this.phone,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      dueDay: dueDay ?? this.dueDay,
      securityDeposit: securityDeposit ?? this.securityDeposit,
      depositPaid: depositPaid ?? this.depositPaid,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'room': room,
        'phone': phone,
        'monthlyRent': monthlyRent,
        'dueDay': dueDay,
        'securityDeposit': securityDeposit,
        'depositPaid': depositPaid,
      };

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
        id: json['id'].toString(),
        name: json['name'] ?? '',
        room: json['room'] ?? '',
        phone: json['phone'] ?? '',
        monthlyRent: (json['monthlyRent'] as num?)?.toInt() ?? 0,
        dueDay: (json['dueDay'] as num?)?.toInt() ?? 5,
        securityDeposit: (json['securityDeposit'] as num?)?.toInt() ?? 0,
        depositPaid: (json['depositPaid'] as num?)?.toInt() ?? 0,
      );
}

class PaymentRecord {
  final int paidAmount;
  final String lastUpdated;

  PaymentRecord({required this.paidAmount, required this.lastUpdated});

  Map<String, dynamic> toJson() => {
        'paidAmount': paidAmount,
        'lastUpdated': lastUpdated,
      };

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        paidAmount: (json['paidAmount'] as num?)?.toInt() ?? 0,
        lastUpdated: json['lastUpdated'] ?? '',
      );
}

class RentTrackerHome extends StatefulWidget {
  const RentTrackerHome({super.key});

  @override
  State<RentTrackerHome> createState() => _RentTrackerHomeState();
}

class _RentTrackerHomeState extends State<RentTrackerHome> {
  static const String _storageKey = 'easyrent_flutter_v2';

  List<Tenant> _tenants = [];
  Map<String, Map<String, PaymentRecord>> _payments = {};

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _filter = 'all'; // 'all', 'due', 'partial', 'paid', 'deposit_due'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _monthKey =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  String get _monthDisplay {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  String _encodeAllData() {
    final data = {
      'app': 'EasyRentTracker',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'tenants': _tenants.map((t) => t.toJson()).toList(),
      'payments': _payments.map((month, records) => MapEntry(
            month,
            records.map((tId, rec) => MapEntry(tId, rec.toJson())),
          )),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  bool _applyJsonData(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic> || !decoded.containsKey('tenants')) {
        return false;
      }

      final List<dynamic> tenantList = decoded['tenants'] ?? [];
      final Map<String, dynamic> paymentMap = decoded['payments'] ?? {};

      final loadedTenants = tenantList.map((e) => Tenant.fromJson(e)).toList();
      final loadedPayments = paymentMap.map((month, records) {
        final Map<String, dynamic> tenantRecords =
            Map<String, dynamic>.from(records);
        return MapEntry(
          month,
          tenantRecords.map(
            (tId, rec) => MapEntry(
              tId,
              PaymentRecord.fromJson(Map<String, dynamic>.from(rec)),
            ),
          ),
        );
      });

      setState(() {
        _tenants = loadedTenants;
        _payments = loadedPayments;
      });
      _saveData();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      _applyJsonData(raw);
    } else {
      _tenants = [
        Tenant(
          id: '1',
          name: 'Rahul Sharma',
          room: '101-A',
          phone: '9876543210',
          monthlyRent: 8000,
          dueDay: 5,
          securityDeposit: 16000,
          depositPaid: 16000,
        ),
        Tenant(
          id: '2',
          name: 'Ajay Krishnan',
          room: '102-B',
          phone: '9811223344',
          monthlyRent: 7500,
          dueDay: 5,
          securityDeposit: 15000,
          depositPaid: 10000,
        ),
      ];
      _saveData();
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _encodeAllData());
  }

  // Export Data as .json File
  Future<void> _exportBackupFile() async {
    try {
      final directory = await getTemporaryDirectory();
      final now = DateTime.now();
      final fileName =
          'easyrent_backup_${now.year}_${now.month}_${now.day}.json';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(_encodeAllData());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'EasyRent Tracker Backup ($fileName)',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating backup file: $e')),
      );
    }
  }

  // Import Data from .json File
  Future<void> _importBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final success = _applyJsonData(content);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '✅ Backup restored successfully!'
                  : '❌ Invalid backup file selected.',
            ),
            backgroundColor:
                success ? Colors.green.shade700 : Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import file: $e')),
      );
    }
  }

  void _showPasteBackupDialog() {
    final pasteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste Backup Code'),
        content: TextField(
          controller: pasteCtrl,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Paste your copied JSON backup data here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final success = _applyJsonData(pasteCtrl.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? '✅ Data restored successfully!'
                        : '❌ Invalid backup code.',
                  ),
                ),
              );
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showBackupMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Backup & Restore Data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Export your rent and deposit records so you never lose data when switching phones.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const Divider(height: 24),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(Icons.upload_file, color: Colors.blue.shade700),
                ),
                title: const Text('Export Backup File (.json)'),
                subtitle: const Text('Save to Google Drive, WhatsApp, or Phone'),
                onTap: () {
                  Navigator.pop(context);
                  _exportBackupFile();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: Icon(Icons.download_for_offline,
                      color: Colors.green.shade700),
                ),
                title: const Text('Import Backup File (.json)'),
                subtitle: const Text('Restore records from a saved backup file'),
                onTap: () {
                  Navigator.pop(context);
                  _importBackupFile();
                },
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _encodeAllData()));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Backup code copied to clipboard!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Text'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showPasteBackupDialog();
                      },
                      icon: const Icon(Icons.paste, size: 18),
                      label: const Text('Paste Text'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getPaidAmount(String tenantId) {
    return _payments[_monthKey]?[tenantId]?.paidAmount ?? 0;
  }

  String _getLastUpdated(String tenantId) {
    return _payments[_monthKey]?[tenantId]?.lastUpdated ?? '';
  }

  void _updatePayment(Tenant tenant, int newPaidAmount) {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    setState(() {
      _payments.putIfAbsent(_monthKey, () => {});
      _payments[_monthKey]![tenant.id] = PaymentRecord(
        paidAmount: newPaidAmount.clamp(0, tenant.monthlyRent * 2),
        lastUpdated: newPaidAmount > 0 ? dateStr : '',
      );
    });
    _saveData();
  }

  void _updateDeposit(Tenant tenant, int newDepositPaid, int newTotalDeposit) {
    final index = _tenants.indexWhere((t) => t.id == tenant.id);
    if (index == -1) return;

    setState(() {
      _tenants[index] = tenant.copyWith(
        securityDeposit: newTotalDeposit.clamp(0, 10000000),
        depositPaid: newDepositPaid.clamp(0, newTotalDeposit),
      );
    });
    _saveData();
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    });
  }

  // Monthly Rent Payment Dialog
  void _showRentPaymentDialog(Tenant tenant) {
    final currentPaid = _getPaidAmount(tenant.id);
    final balance =
        (tenant.monthlyRent - currentPaid).clamp(0, tenant.monthlyRent);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rent — ${tenant.name} (${tenant.room})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Month: $_monthDisplay'),
            const SizedBox(height: 6),
            Text('Monthly Rent: ₹${tenant.monthlyRent}'),
            Text(
              'Paid So Far: ₹$currentPaid',
              style: const TextStyle(
                  color: Colors.green, fontWeight: FontWeight.w600),
            ),
            Text(
              'Balance Due: ₹$balance',
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Add Rent Payment Received (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          if (currentPaid > 0)
            TextButton(
              onPressed: () {
                _updatePayment(tenant, 0);
                Navigator.pop(context);
              },
              child: const Text('Reset (₹0)',
                  style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () {
              _updatePayment(tenant, tenant.monthlyRent);
              Navigator.pop(context);
            },
            child: const Text('Mark Full Paid'),
          ),
          FilledButton(
            onPressed: () {
              final added = int.tryParse(controller.text.trim()) ?? 0;
              if (added > 0) {
                _updatePayment(tenant, currentPaid + added);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Security Deposit Collection Dialog
  void _showDepositDialog(Tenant tenant) {
    final depositBalance =
        (tenant.securityDeposit - tenant.depositPaid).clamp(0, tenant.securityDeposit);
    final addDepositCtrl = TextEditingController();
    final totalDepositCtrl =
        TextEditingController(text: tenant.securityDeposit.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Security Deposit — ${tenant.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Collected: ₹${tenant.depositPaid} / ₹${tenant.securityDeposit}',
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.w600),
              ),
              Text(
                'Pending Deposit: ₹$depositBalance',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addDepositCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Add Deposit Received Now (₹)',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: totalDepositCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total Agreed Deposit Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (tenant.depositPaid > 0)
            TextButton(
              onPressed: () {
                final newTotal = int.tryParse(totalDepositCtrl.text.trim()) ??
                    tenant.securityDeposit;
                _updateDeposit(tenant, 0, newTotal);
                Navigator.pop(context);
              },
              child: const Text('Reset Paid (₹0)',
                  style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () {
              final newTotal = int.tryParse(totalDepositCtrl.text.trim()) ??
                  tenant.securityDeposit;
              _updateDeposit(tenant, newTotal, newTotal);
              Navigator.pop(context);
            },
            child: const Text('Mark Full Paid'),
          ),
          FilledButton(
            onPressed: () {
              final newTotal = int.tryParse(totalDepositCtrl.text.trim()) ??
                  tenant.securityDeposit;
              final added = int.tryParse(addDepositCtrl.text.trim()) ?? 0;
              _updateDeposit(tenant, tenant.depositPaid + added, newTotal);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Add New Tenant Dialog
  void _showAddTenantDialog() {
    final nameCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final rentCtrl = TextEditingController();
    final depositTotalCtrl = TextEditingController();
    final depositPaidCtrl = TextEditingController();
    final dueCtrl = TextEditingController(text: '5');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Tenant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tenant Name *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: roomCtrl,
                decoration:
                    const InputDecoration(labelText: 'Room / Bed No. (e.g. 101-A) *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rentCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monthly Rent (₹) *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: depositTotalCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Security Deposit Amount (₹)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: depositPaidCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Deposit Paid So Far (₹)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dueCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Monthly Due Day (1-31)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final room = roomCtrl.text.trim();
              final rent = int.tryParse(rentCtrl.text.trim()) ?? 0;
              final totalDep = int.tryParse(depositTotalCtrl.text.trim()) ?? 0;
              final paidDep = int.tryParse(depositPaidCtrl.text.trim()) ?? 0;
              final due = int.tryParse(dueCtrl.text.trim()) ?? 5;

              if (name.isNotEmpty && room.isNotEmpty && rent > 0) {
                setState(() {
                  _tenants.add(Tenant(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    room: room,
                    phone: phoneCtrl.text.trim(),
                    monthlyRent: rent,
                    dueDay: due.clamp(1, 31),
                    securityDeposit: totalDep,
                    depositPaid: paidDep.clamp(0, totalDep),
                  ));
                });
                _saveData();
                Navigator.pop(context);
              }
            },
            child: const Text('Add Tenant'),
          ),
        ],
      ),
    );
  }

  void _copyReminder(Tenant tenant) {
    final paid = _getPaidAmount(tenant.id);
    final rentBalance = (tenant.monthlyRent - paid).clamp(0, tenant.monthlyRent);
    final depBalance =
        (tenant.securityDeposit - tenant.depositPaid).clamp(0, tenant.securityDeposit);

    String msg = 'Hi ${tenant.name} (Room ${tenant.room}), ';
    if (rentBalance > 0 && paid > 0) {
      msg +=
          'we received ₹$paid towards your $_monthDisplay rent of ₹${tenant.monthlyRent}. The remaining rent balance is ₹$rentBalance. ';
    } else if (rentBalance > 0) {
      msg +=
          'friendly reminder that your $_monthDisplay rent of ₹${tenant.monthlyRent} is due on the ${tenant.dueDay}th. ';
    }

    if (depBalance > 0) {
      msg += 'Your pending security deposit balance is ₹$depBalance. ';
    }

    msg += 'Please share the payment confirmation once completed.';

    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalExpectedRent = 0;
    int totalCollectedRent = 0;
    int totalDepositHeld = 0;
    int totalDepositPending = 0;

    for (final t in _tenants) {
      totalExpectedRent += t.monthlyRent;
      totalCollectedRent += _getPaidAmount(t.id);
      totalDepositHeld += t.depositPaid;
      totalDepositPending +=
          (t.securityDeposit - t.depositPaid).clamp(0, t.securityDeposit);
    }
    final int totalPendingRent =
        (totalExpectedRent - totalCollectedRent).clamp(0, totalExpectedRent);

    final filteredTenants = _tenants.where((t) {
      final paid = _getPaidAmount(t.id);
      final depDue = t.securityDeposit - t.depositPaid;

      if (_filter == 'paid' && paid < t.monthlyRent) return false;
      if (_filter == 'partial' && (paid == 0 || paid >= t.monthlyRent)) {
        return false;
      }
      if (_filter == 'due' && paid >= t.monthlyRent) return false;
      if (_filter == 'deposit_due' && depDue <= 0) return false;

      final q = _searchQuery.toLowerCase();
      return t.name.toLowerCase().contains(q) ||
          t.room.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EasyRent Tracker',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Center(
            child: Text(
              _monthDisplay,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          IconButton(
            onPressed: () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            onPressed: _showBackupMenu,
            tooltip: 'Backup & Restore',
            icon: const Icon(Icons.cloud_sync_outlined,
                color: Color(0xFF2563EB)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Monthly Rent Summary Cards
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                _buildStatCard(
                    'Expected Rent', '₹$totalExpectedRent', Colors.blue.shade800),
                const SizedBox(width: 8),
                _buildStatCard(
                    'Collected', '₹$totalCollectedRent', Colors.green.shade700),
                const SizedBox(width: 8),
                _buildStatCard(
                    'Pending Rent', '₹$totalPendingRent', Colors.red.shade700),
              ],
            ),
          ),

          // Security Deposit Summary Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 18, color: Colors.indigo.shade800),
                      const SizedBox(width: 6),
                      Text(
                        'Deposit Held: ₹$totalDepositHeld',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Deposit Pending: ₹$totalDepositPending',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: totalDepositPending > 0
                          ? Colors.red.shade700
                          : Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by tenant name or room...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildFilterChip('all', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('due', 'Rent Due'),
                const SizedBox(width: 8),
                _buildFilterChip('partial', 'Partial Rent'),
                const SizedBox(width: 8),
                _buildFilterChip('paid', 'Rent Paid'),
                const SizedBox(width: 8),
                _buildFilterChip('deposit_due', 'Deposit Pending'),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Tenant List
          Expanded(
            child: filteredTenants.isEmpty
                ? const Center(child: Text('No matching tenants found.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredTenants.length,
                    itemBuilder: (context, index) {
                      final t = filteredTenants[index];
                      final paid = _getPaidAmount(t.id);
                      final balance =
                          (t.monthlyRent - paid).clamp(0, t.monthlyRent);
                      final isPaid = paid >= t.monthlyRent;
                      final isPartial = paid > 0 && paid < t.monthlyRent;

                      final depBalance = (t.securityDeposit - t.depositPaid)
                          .clamp(0, t.securityDeposit);
                      final isDepPaid =
                          t.securityDeposit > 0 && depBalance == 0;

                      Color badgeColor = Colors.red.shade700;
                      Color badgeBg = Colors.red.shade50;
                      String statusText = 'Rent Due: ₹$balance';

                      if (isPaid) {
                        badgeColor = Colors.green.shade800;
                        badgeBg = Colors.green.shade50;
                        statusText = '✓ Rent Paid';
                      } else if (isPartial) {
                        badgeColor = Colors.orange.shade900;
                        badgeBg = Colors.orange.shade50;
                        statusText = 'Partial • Due: ₹$balance';
                      }

                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        t.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          t.room,
                                          style: TextStyle(
                                            color: Colors.indigo.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20),
                                    color: Colors.grey,
                                    onPressed: () {
                                      setState(() => _tenants
                                          .removeWhere((x) => x.id == t.id));
                                      _saveData();
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                'Rent: ₹${t.monthlyRent}/mo • Paid: ₹$paid • Due Day: ${t.dueDay}',
                                style: TextStyle(
                                    color: Colors.grey.shade700, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              // Deposit Status Line
                              Row(
                                children: [
                                  Icon(
                                    isDepPaid
                                        ? Icons.verified_user
                                        : Icons.account_balance_wallet_outlined,
                                    size: 14,
                                    color: isDepPaid
                                        ? Colors.green.shade700
                                        : Colors.blueGrey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    t.securityDeposit == 0
                                        ? 'Deposit: Not set'
                                        : isDepPaid
                                            ? 'Deposit: ₹${t.securityDeposit} (Fully Paid)'
                                            : 'Deposit: ₹${t.depositPaid} / ₹${t.securityDeposit} (Due: ₹$depBalance)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: depBalance > 0
                                          ? Colors.orange.shade900
                                          : Colors.teal.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              if (_getLastUpdated(t.id).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Last rent payment: ${_getLastUpdated(t.id)}',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11.5),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isPaid || depBalance > 0)
                                        IconButton(
                                          onPressed: () => _copyReminder(t),
                                          tooltip: 'Copy Reminder',
                                          icon: const Icon(Icons.copy, size: 18),
                                        ),
                                      OutlinedButton(
                                        onPressed: () => _showDepositDialog(t),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10),
                                        ),
                                        child: const Text('Deposit',
                                            style: TextStyle(fontSize: 12.5)),
                                      ),
                                      const SizedBox(width: 6),
                                      FilledButton.tonal(
                                        onPressed: () =>
                                            _showRentPaymentDialog(t),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                        ),
                                        child: const Text('Record Rent',
                                            style: TextStyle(fontSize: 12.5)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTenantDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Tenant'),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _filter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = key),
    );
  }
}
