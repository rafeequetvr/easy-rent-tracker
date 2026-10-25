class Tenant {
  String id, roomId, name, phone;
  String joined; // first month (yyyy-MM) the tenant is active
  String lastMonth; // last month (yyyy-MM) the tenant is active; '' = still staying
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
    this.joined = '',
    this.lastMonth = '',
  });

  bool activeIn(String k) =>
      joined.compareTo(k) <= 0 && (lastMonth.isEmpty || k.compareTo(lastMonth) <= 0);

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
        'joined': joined,
        'lastMonth': lastMonth,
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
        joined: '${j['joined'] ?? ''}',
        lastMonth: '${j['lastMonth'] ?? ''}',
      );
}

class MonthSummary {
  int expected = 0,
      collected = 0,
      overdue = 0,
      upcoming = 0,
      expenses = 0,
      depHeld = 0,
      depPending = 0;
  final List<Tenant> overdueList = [];
  int get net => collected - expenses;
}
