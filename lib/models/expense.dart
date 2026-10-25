class ExpenseItem {
  String id, title, category, date, monthKey; // date is ISO yyyy-MM-dd
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

  factory ExpenseItem.fromJson(Map<String, dynamic> j) {
    var date = '${j['date'] ?? ''}';
    final p = date.split('/'); // migrate old d/m/yyyy format if present
    if (p.length == 3) {
      date = '${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}';
    }
    final mk = '${j['monthKey'] ?? ''}';
    return ExpenseItem(
      id: '${j['id'] ?? ''}',
      title: '${j['title'] ?? ''}',
      category: j['category'] == null || '${j['category']}'.isEmpty ? 'Other' : '${j['category']}',
      amount: int.tryParse('${j['amount']}') ?? 0,
      date: date,
      monthKey: mk.isNotEmpty ? mk : (date.length >= 7 ? date.substring(0, 7) : ''),
    );
  }
}
