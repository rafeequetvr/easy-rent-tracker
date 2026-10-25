class LogEntry {
  String id, title, subtitle, type, time, monthKey, tenantId;

  LogEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.time,
    required this.monthKey,
    this.tenantId = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'type': type,
        'time': time,
        'monthKey': monthKey,
        'tenantId': tenantId,
      };

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        subtitle: '${j['subtitle'] ?? ''}',
        type: '${j['type'] ?? 'info'}',
        time: '${j['time'] ?? ''}',
        monthKey: '${j['monthKey'] ?? ''}',
        tenantId: '${j['tenantId'] ?? ''}',
      );
}
