// models.dart
int _i(dynamic v, int d) => int.tryParse('$v') ?? d;
String _s(dynamic v, [String d = '']) => v == null ? d : '$v';

class RoomModel {
  String id, name, floor;
  int totalBeds, defaultRent;
  RoomModel({required this.id, required this.name, required this.floor, required this.totalBeds, required this.defaultRent});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'floor': floor, 'totalBeds': totalBeds, 'defaultRent': defaultRent};
  factory RoomModel.fromJson(Map<String, dynamic> j) => RoomModel(
      id: _s(j['id']), name: _s(j['name']), floor: _s(j['floor'], 'Ground Floor'),
      totalBeds: _i(j['totalBeds'], 4), defaultRent: _i(j['defaultRent'], 4000));
}

class Tenant {
  String id, roomId, name, phone;
  String joined;
  String lastMonth;
  int bedIndex, monthlyRent, dueDay, depositAmount, depositPaid;
  Tenant({
    required this.id, required this.roomId, required this.bedIndex, required this.name, required this.phone,
    required this.monthlyRent, required this.dueDay, required this.depositAmount, required this.depositPaid,
    this.joined = '', this.lastMonth = '',
  });
  bool activeIn(String k) => joined.compareTo(k) <= 0 && (lastMonth.isEmpty || k.compareTo(lastMonth) <= 0);
  Map<String, dynamic> toJson() => {
        'id': id, 'roomId': roomId, 'bedIndex': bedIndex, 'name': name, 'phone': phone, 'monthlyRent': monthlyRent,
        'dueDay': dueDay, 'depositAmount': depositAmount, 'depositPaid': depositPaid, 'joined': joined, 'lastMonth': lastMonth,
      };
  factory Tenant.fromJson(Map<String, dynamic> j) => Tenant(
      id: _s(j['id']), roomId: _s(j['roomId']), bedIndex: _i(j['bedIndex'], 0), name: _s(j['name']), phone: _s(j['phone']),
      monthlyRent: _i(j['monthlyRent'], 4000), dueDay: _i(j['dueDay'], 5), depositAmount: _i(j['depositAmount'], 0),
      depositPaid: _i(j['depositPaid'], 0), joined: _s(j['joined']), lastMonth: _s(j['lastMonth']));
}

class ExpenseItem {
  String id, title, category, date, monthKey;
  int amount;
  ExpenseItem({required this.id, required this.title, required this.category, required this.amount, required this.date, required this.monthKey});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'category': category, 'amount': amount, 'date': date, 'monthKey': monthKey};
  factory ExpenseItem.fromJson(Map<String, dynamic> j) {
    var date = _s(j['date']);
    final p = date.split('/');
    if (p.length == 3) date = '\( {p[2]}- \){p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}';
    return ExpenseItem(
        id: _s(j['id']), title: _s(j['title']), category: _s(j['category'], 'Other'), amount: _i(j['amount'], 0), date: date,
        monthKey: _s(j['monthKey'], date.length >= 7 ? date.substring(0, 7) : ''));
  }
}

class LogEntry {
  String id, title, subtitle, type, time, monthKey, tenantId;
  LogEntry({required this.id, required this.title, required this.subtitle, required this.type, required this.time, required this.monthKey, this.tenantId = ''});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'subtitle': subtitle, 'type': type, 'time': time, 'monthKey': monthKey, 'tenantId': tenantId};
  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
      id: _s(j['id']), title: _s(j['title']), subtitle: _s(j['subtitle']), type: _s(j['type'], 'info'),
      time: _s(j['time']), monthKey: _s(j['monthKey']), tenantId: _s(j['tenantId']));
}

class MonthSummary {
  int expected = 0, collected = 0, overdue = 0, upcoming = 0, expenses = 0, depHeld = 0, depPending = 0;
  final List<Tenant> overdueList = [];
  int get net => collected - expenses;
}