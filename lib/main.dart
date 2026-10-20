import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final int depositAmount;
  final int depositPaid;

  Tenant({
    required this.id,
    required this.name,
    required this.room,
    required this.phone,
    required this.monthlyRent,
    required this.dueDay,
    required this.depositAmount,
    required this.depositPaid,
  });

  Tenant copyWith({
    String? id,
    String? name,
    String? room,
    String? phone,
    int? monthlyRent,
    int? dueDay,
    int? depositAmount,
    int? depositPaid,
  }) {
    return Tenant(
      id: id ?? this.id,
      name: name ?? this.name,
      room: room ?? this.room,
      phone: phone ?? this.phone,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      dueDay: dueDay ?? this.dueDay,
      depositAmount: depositAmount ?? this.depositAmount,
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
        'depositAmount': depositAmount,
        'depositPaid': depositPaid,
      };

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
        id: json['id'],
        name: json['name'],
        room: json['room'],
        phone: json['phone'] ?? '',
        monthlyRent: json['monthlyRent'] ?? 0,
        dueDay: json['dueDay'] ?? 5,
        depositAmount: json['depositAmount'] ?? 0,
        depositPaid: json['depositPaid'] ?? 0,
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
        paidAmount: json['paidAmount'] ?? 0,
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
  // Format: { "YYYY-MM": { "tenantId": PaymentRecord } }
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
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final decoded = jsonDecode(raw);
      final List<dynamic> tenantList = decoded['tenants'] ?? [];
      final Map<String, dynamic> paymentMap = decoded['payments'] ?? {};

      setState(() {
        _tenants = tenantList.map((e) => Tenant.fromJson(e)).toList();
        _payments = paymentMap.map((month, records) {
          final Map<String, dynamic> tenantRecords = records;
          return MapEntry(
            month,
            tenantRecords.map(
              (tId, rec) => MapEntry(tId, PaymentRecord.fromJson(rec)),
            ),
          );
        });
      });
    } else {
      // Sample Data in English
      _tenants = [
        Tenant(
          id: '1',
          name: 'Rahul Nair',
          room: '101-A',
          phone: '9876543210',
          monthlyRent: 8000,
          dueDay: 5,
          depositAmount: 15000,
          depositPaid: 15000,
        ),
        Tenant(
          id: '2',
          name: 'Ajay Krishnan',
          room: '102-B',
          phone: '9811223344',
          monthlyRent: 7500,
          dueDay: 5,
          depositAmount: 15000,
          depositPaid: 10000,
        ),
      ];
      _saveData();
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'tenants': _tenants.map((t) => t.toJson()).toList(),
      'payments': _payments.map((month, records) => MapEntry(
            month,
            records.map((tId, rec) => MapEntry(tId, rec.toJson())),
          )),
    };
    await prefs.setString(_storageKey, jsonEncode(data));
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

  void _updateDeposit(Tenant tenant, int newDepositPaid, {int? newDepositTotal}) {
    final totalDep = newDepositTotal ?? tenant.depositAmount;
    setState(() {
      final index = _tenants.indexWhere((t) => t.id == tenant.id);
      if (index != -1) {
        _tenants[index] = tenant.copyWith(
          depositAmount: totalDep,
          depositPaid: newDepositPaid.clamp(0, totalDep > 0 ? totalDep * 2 : 1000000),
        );
      }
    });
    _saveData();
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    });
  }

  void _showPaymentDialog(Tenant tenant) {
    final currentPaid = _getPaidAmount(tenant.id);
    final balance = (tenant.monthlyRent - currentPaid).clamp(0, tenant.monthlyRent);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${tenant.name} (${tenant.room}) - Rent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monthly Rent: ₹${tenant.monthlyRent}'),
            const SizedBox(height: 4),
            Text(
              'Paid so far: ₹$currentPaid',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Balance Due: ₹$balance',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Add Rent Received Now (₹)',
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
              child: const Text('Reset (₹0)', style: TextStyle(color: Colors.red)),
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

  void _showDepositDialog(Tenant tenant) {
    final currentDepPaid = tenant.depositPaid;
    final depBalance = (tenant.depositAmount - currentDepPaid).clamp(0, tenant.depositAmount);
    final addDepositCtrl = TextEditingController();
    final totalDepositCtrl = TextEditingController(text: tenant.depositAmount.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${tenant.name} (${tenant.room}) - Deposit'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: totalDepositCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total Agreed Deposit (₹)',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Deposit Collected: ₹$currentDepPaid',
                style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Pending Deposit: ₹$depBalance',
                style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
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
            ],
          ),
        ),
        actions: [
          if (currentDepPaid > 0)
            TextButton(
              onPressed: () {
                final updatedTotal =
                    int.tryParse(totalDepositCtrl.text.trim()) ?? tenant.depositAmount;
                _updateDeposit(tenant, 0, newDepositTotal: updatedTotal);
                Navigator.pop(context);
              },
              child: const Text('Reset (₹0)', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () {
              final updatedTotal =
                  int.tryParse(totalDepositCtrl.text.trim()) ?? tenant.depositAmount;
              _updateDeposit(tenant, updatedTotal, newDepositTotal: updatedTotal);
              Navigator.pop(context);
            },
            child: const Text('Full Deposit'),
          ),
          FilledButton(
            onPressed: () {
              final updatedTotal =
                  int.tryParse(totalDepositCtrl.text.trim()) ?? tenant.depositAmount;
              final added = int.tryParse(addDepositCtrl.text.trim()) ?? 0;
              _updateDeposit(
                tenant,
                currentDepPaid + added,
                newDepositTotal: updatedTotal,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddTenantDialog() {
    final nameCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final rentCtrl = TextEditingController();
    final dueCtrl = TextEditingController(text: '5');
    final depositTotalCtrl = TextEditingController();
    final depositPaidCtrl = TextEditingController();

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
                decoration: const InputDecoration(labelText: 'Tenant Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: roomCtrl,
                decoration: const InputDecoration(labelText: 'Room / Bed No. (e.g. 101-A)'),
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
                decoration: const InputDecoration(labelText: 'Monthly Rent (₹)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: depositTotalCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Security Deposit (₹)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: depositPaidCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Initial Deposit Paid (₹)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dueCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Rent Due Day (1-31)'),
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
              final due = int.tryParse(dueCtrl.text.trim()) ?? 5;
              final depTotal = int.tryParse(depositTotalCtrl.text.trim()) ?? 0;
              final depPaid = int.tryParse(depositPaidCtrl.text.trim()) ?? 0;

              if (name.isNotEmpty && room.isNotEmpty && rent > 0) {
                setState(() {
                  _tenants.add(Tenant(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    room: room,
                    phone: phoneCtrl.text.trim(),
                    monthlyRent: rent,
                    dueDay: due.clamp(1, 31),
                    depositAmount: depTotal,
                    depositPaid: depPaid.clamp(0, depTotal > 0 ? depTotal : 1000000),
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
    final balance = (tenant.monthlyRent - paid).clamp(0, tenant.monthlyRent);
    final depBalance = (tenant.depositAmount - tenant.depositPaid).clamp(0, tenant.depositAmount);

    String msg = paid > 0
        ? 'Hello ${tenant.name} (Room ${tenant.room}), out of your $_monthDisplay rent of ₹${tenant.monthlyRent}, we have received ₹$paid. Kindly pay the remaining balance of ₹$balance soon.'
        : 'Hello ${tenant.name} (Room ${tenant.room}), your rent of ₹${tenant.monthlyRent} for $_monthDisplay is due by the ${tenant.dueDay}th of this month. Kindly make the payment on time.';

    if (depBalance > 0) {
      msg += ' Also, your pending security deposit balance is ₹$depBalance.';
    }

    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WhatsApp reminder message copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalExpected = 0;
    int totalCollected = 0;
    int totalDepositExpected = 0;
    int totalDepositCollected = 0;

    for (final t in _tenants) {
      totalExpected += t.monthlyRent;
      totalCollected += _getPaidAmount(t.id);
      totalDepositExpected += t.depositAmount;
      totalDepositCollected += t.depositPaid;
    }
    final int totalPending = (totalExpected - totalCollected).clamp(0, totalExpected);
    final int totalDepositPending =
        (totalDepositExpected - totalDepositCollected).clamp(0, totalDepositExpected);

    final filteredTenants = _tenants.where((t) {
      final paid = _getPaidAmount(t.id);
      final depPending = t.depositAmount - t.depositPaid;

      if (_filter == 'paid' && paid < t.monthlyRent) return false;
      if (_filter == 'partial' && (paid == 0 || paid >= t.monthlyRent)) return false;
      if (_filter == 'due' && paid >= t.monthlyRent) return false;
      if (_filter == 'deposit_due' && depPending <= 0) return false;

      final q = _searchQuery.toLowerCase();
      return t.name.toLowerCase().contains(q) || t.room.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('EasyRent Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          IconButton(
            onPressed: () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: Column(
        children: [
          // Rent Summary Cards
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                _buildStatCard('Total Rent', '₹$totalExpected', Colors.blue.shade800),
                const SizedBox(width: 8),
                _buildStatCard('Collected', '₹$totalCollected', Colors.green.shade700),
                const SizedBox(width: 8),
                _buildStatCard('Pending Due', '₹$totalPending', Colors.red.shade700),
              ],
            ),
          ),

          // Deposit Summary Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: Colors.teal.shade800),
                      const SizedBox(width: 6),
                      Text(
                        'Deposit Held: ₹$totalDepositCollected / ₹$totalDepositExpected',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.teal.shade900,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    totalDepositPending > 0
                        ? 'Pending: ₹$totalDepositPending'
                        : 'All Collected ✓',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: totalDepositPending > 0
                          ? Colors.deepOrange.shade800
                          : Colors.teal.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search & Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by tenant name or room number...',
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
          const SizedBox(height: 8),

          // Tenant List
          Expanded(
            child: filteredTenants.isEmpty
                ? const Center(child: Text('No tenants found.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredTenants.length,
                    itemBuilder: (context, index) {
                      final t = filteredTenants[index];
                      final paid = _getPaidAmount(t.id);
                      final balance = (t.monthlyRent - paid).clamp(0, t.monthlyRent);
                      final isPaid = paid >= t.monthlyRent;
                      final isPartial = paid > 0 && paid < t.monthlyRent;

                      final depBalance =
                          (t.depositAmount - t.depositPaid).clamp(0, t.depositAmount);
                      final isDepPaid = t.depositAmount > 0 && depBalance == 0;

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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                          borderRadius: BorderRadius.circular(6),
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
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    color: Colors.grey,
                                    onPressed: () {
                                      setState(() => _tenants.removeWhere((x) => x.id == t.id));
                                      _saveData();
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                'Monthly Rent: ₹${t.monthlyRent} • Paid: ₹$paid • Due Day: ${t.dueDay}',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 14,
                                    color: isDepPaid
                                        ? Colors.teal.shade700
                                        : Colors.deepOrange.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    t.depositAmount > 0
                                        ? 'Deposit: ₹${t.depositPaid} / ₹${t.depositAmount}'
                                        : 'No Deposit Set',
                                    style: TextStyle(
                                      color: isDepPaid
                                          ? Colors.teal.shade800
                                          : Colors.deepOrange.shade800,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (depBalance > 0)
                                    Text(
                                      ' (Due: ₹$depBalance)',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              if (_getLastUpdated(t.id).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Last Rent Updated: ${_getLastUpdated(t.id)}',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
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
                                          tooltip: 'Copy Reminder',
                                          onPressed: () => _copyReminder(t),
                                          icon: const Icon(Icons.copy, size: 18),
                                        ),
                                      OutlinedButton(
                                        onPressed: () => _showDepositDialog(t),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: const Text('Deposit'),
                                      ),
                                      const SizedBox(width: 6),
                                      FilledButton.tonal(
                                        onPressed: () => _showPaymentDialog(t),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: const Text('Add Rent'),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
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
