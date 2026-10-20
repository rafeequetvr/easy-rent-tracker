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

  Tenant({
    required this.id,
    required this.name,
    required this.room,
    required this.phone,
    required this.monthlyRent,
    required this.dueDay,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'room': room,
        'phone': phone,
        'monthlyRent': monthlyRent,
        'dueDay': dueDay,
      };

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
        id: json['id'],
        name: json['name'],
        room: json['room'],
        phone: json['phone'],
        monthlyRent: json['monthlyRent'],
        dueDay: json['dueDay'],
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
  static const String _storageKey = 'easyrent_flutter_v1';

  List<Tenant> _tenants = [];
  // Format: { "YYYY-MM": { "tenantId": PaymentRecord } }
  Map<String, Map<String, PaymentRecord>> _payments = {};

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _filter = 'all'; // 'all', 'due', 'partial', 'paid'
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
      'ജനുവരി', 'ഫെബ്രുവരി', 'മാർച്ച്', 'ഏപ്രിൽ', 'മെയ്', 'ജൂൺ',
      'ജൂലൈ', 'ഓഗസ്റ്റ്', 'സെപ്റ്റംബർ', 'ഒക്ടോബർ', 'നവംബർ', 'ഡിസംബർ'
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
      // പ്രാരംഭ മാതൃക ഡാറ്റ (Sample Data)
      _tenants = [
        Tenant(
          id: '1',
          name: 'രാഹുൽ നായർ',
          room: '101-A',
          phone: '9876543210',
          monthlyRent: 8000,
          dueDay: 5,
        ),
        Tenant(
          id: '2',
          name: 'അജയ് കൃഷ്ണൻ',
          room: '102-B',
          phone: '9811223344',
          monthlyRent: 7500,
          dueDay: 5,
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
        title: Text('${tenant.name} (${tenant.room})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('മാസ വാടക: ₹${tenant.monthlyRent}'),
            Text(
              'ഇതുവരെ ലഭിച്ചത്: ₹$currentPaid',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
            ),
            Text(
              'ഇനി ലഭിക്കാനുള്ള ബാക്കി: ₹$balance',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ഇപ്പോൾ ലഭിച്ച തുക ചേർക്കുക (₹)',
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
              child: const Text('റീസെറ്റ് (₹0)', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () {
              _updatePayment(tenant, tenant.monthlyRent);
              Navigator.pop(context);
            },
            child: const Text('മുഴുവൻ തുകയും (Full)'),
          ),
          FilledButton(
            onPressed: () {
              final added = int.tryParse(controller.text.trim()) ?? 0;
              if (added > 0) {
                _updatePayment(tenant, currentPaid + added);
              }
              Navigator.pop(context);
            },
            child: const Text('സേവ് ചെയ്യുക'),
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('പുതിയ താമസക്കാരനെ ചേർക്കുക'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'പേര് (Name)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: roomCtrl,
                decoration: const InputDecoration(labelText: 'റൂം / ബെഡ് നമ്പർ (e.g. 101-A)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'ഫോൺ നമ്പർ'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rentCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'മാസ വാടക (₹)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dueCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'വാടക നൽകേണ്ട തീയതി (1-31)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('റദ്ദാക്കുക'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final room = roomCtrl.text.trim();
              final rent = int.tryParse(rentCtrl.text.trim()) ?? 0;
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
                  ));
                });
                _saveData();
                Navigator.pop(context);
              }
            },
            child: const Text('ചേർക്കുക'),
          ),
        ],
      ),
    );
  }

  void _copyReminder(Tenant tenant) {
    final paid = _getPaidAmount(tenant.id);
    final balance = tenant.monthlyRent - paid;
    final msg = paid > 0
        ? 'നമസ്കാരം ${tenant.name} (Room ${tenant.room}), $_monthDisplay മാസത്തെ വാടകയായ ₹${tenant.monthlyRent}-ൽ ₹$paid ലഭിച്ചിട്ടുണ്ട്. ബാക്കി തുകയായ ₹$balance ദയവായി ഉടൻ അടയ്ക്കുക.'
        : 'നമസ്കാരം ${tenant.name} (Room ${tenant.room}), $_monthDisplay മാസത്തെ വാടകയായ ₹${tenant.monthlyRent} ഈ മാസം ${tenant.dueDay}-ാം തീയതിക്കുള്ളിൽ അടയ്ക്കേണ്ടതാണ്.';

    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('വാട്സ്ആപ്പ് റിമൈൻഡർ സന്ദേശം കോപ്പി ചെയ്തു!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalExpected = 0;
    int totalCollected = 0;

    for (final t in _tenants) {
      totalExpected += t.monthlyRent;
      totalCollected += _getPaidAmount(t.id);
    }
    final int totalPending = (totalExpected - totalCollected).clamp(0, totalExpected);

    final filteredTenants = _tenants.where((t) {
      final paid = _getPaidAmount(t.id);
      if (_filter == 'paid' && paid < t.monthlyRent) return false;
      if (_filter == 'partial' && (paid == 0 || paid >= t.monthlyRent)) return false;
      if (_filter == 'due' && paid >= t.monthlyRent) return false;

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
          // Summary Cards
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                _buildStatCard('ആകെ വാടക', '₹$totalExpected', Colors.blue.shade800),
                const SizedBox(width: 8),
                _buildStatCard('ലഭിച്ചത്', '₹$totalCollected', Colors.green.shade700),
                const SizedBox(width: 8),
                _buildStatCard('ബാക്കി (Due)', '₹$totalPending', Colors.red.shade700),
              ],
            ),
          ),

          // Search & Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'പേര് അല്ലെങ്കിൽ റൂം നമ്പർ തിരയുക...',
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
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildFilterChip('all', 'എല്ലാം (All)'),
                const SizedBox(width: 8),
                _buildFilterChip('due', 'ബാക്കിയുള്ളവ (Pending)'),
                const SizedBox(width: 8),
                _buildFilterChip('partial', 'ഭാഗികം (Partial)'),
                const SizedBox(width: 8),
                _buildFilterChip('paid', 'ലഭിച്ചവ (Paid)'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tenant List
          Expanded(
            child: filteredTenants.isEmpty
                ? const Center(child: Text('താമസക്കാരുടെ വിവരങ്ങൾ ലഭ്യമല്ല.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredTenants.length,
                    itemBuilder: (context, index) {
                      final t = filteredTenants[index];
                      final paid = _getPaidAmount(t.id);
                      final balance = (t.monthlyRent - paid).clamp(0, t.monthlyRent);
                      final isPaid = paid >= t.monthlyRent;
                      final isPartial = paid > 0 && paid < t.monthlyRent;

                      Color badgeColor = Colors.red.shade700;
                      Color badgeBg = Colors.red.shade50;
                      String statusText = 'ബാക്കി: ₹$balance';

                      if (isPaid) {
                        badgeColor = Colors.green.shade800;
                        badgeBg = Colors.green.shade50;
                        statusText = '✓ പൂർണ്ണമായി ലഭിച്ചു';
                      } else if (isPartial) {
                        badgeColor = Colors.orange.shade900;
                        badgeBg = Colors.orange.shade50;
                        statusText = 'ഭാഗികം • ബാക്കി: ₹$balance';
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
                                'മാസ വാടക: ₹${t.monthlyRent} • ലഭിച്ചത്: ₹$paid • തീയതി: ${t.dueDay}',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                              if (_getLastUpdated(t.id).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'അവസാനം രേഖപ്പെടുത്തിയത്: ${_getLastUpdated(t.id)}',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    children: [
                                      if (!isPaid)
                                        TextButton.icon(
                                          onPressed: () => _copyReminder(t),
                                          icon: const Icon(Icons.copy, size: 16),
                                          label: const Text('റിമൈൻഡർ'),
                                        ),
                                      FilledButton.tonal(
                                        onPressed: () => _showPaymentDialog(t),
                                        child: const Text('വാടക ചേർക്കുക'),
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
        label: const Text('താമസക്കാരനെ ചേർക്കുക'),
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
