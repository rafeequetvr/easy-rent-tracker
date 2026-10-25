class RoomModel {
  String id, name, floor;
  int totalBeds, defaultRent;

  RoomModel({
    required this.id,
    required this.name,
    required this.floor,
    required this.totalBeds,
    required this.defaultRent,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'floor': floor,
        'totalBeds': totalBeds,
        'defaultRent': defaultRent,
      };

  factory RoomModel.fromJson(Map<String, dynamic> j) => RoomModel(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        floor: j['floor'] == null || '${j['floor']}'.isEmpty ? 'Ground Floor' : '${j['floor']}',
        totalBeds: int.tryParse('${j['totalBeds']}') ?? 4,
        defaultRent: int.tryParse('${j['defaultRent']}') ?? 4000,
      );
}
