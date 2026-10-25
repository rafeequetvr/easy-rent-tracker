import 'package:flutter/material.dart';
import '../models/room.dart';
import '../models/tenant.dart';

class RoomCard extends StatelessWidget {
  final RoomModel room;
  final List<Tenant> activeRoomTenants;
  final int Function(Tenant t) getRent;
  final int Function(Tenant t) getPaid;
  final bool Function(Tenant t) isOverdue;
  final VoidCallback onEditRoom;
  final void Function(int bedIdx, Tenant? tenant) onTapBed;

  const RoomCard({
    super.key,
    required this.room,
    required this.activeRoomTenants,
    required this.getRent,
    required this.getPaid,
    required this.isOverdue,
    required this.onEditRoom,
    required this.onTapBed,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF15803D);
    const red = Color(0xFFDC2626);
    const blue = Color(0xFF2563EB);

    final occ = activeRoomTenants.length;
    final full = occ >= room.totalBeds;
    final vacant = occ == 0;
    final bg = full
        ? const Color(0xFFE6F6EC)
        : (vacant ? const Color(0xFFE8F0FE) : const Color(0xFFFEF3E2));
    final fg = full
        ? green
        : (vacant ? const Color(0xFF1D4ED8) : const Color(0xFFB45309));
    final label =
        full ? 'Fully occupied' : (vacant ? 'Vacant' : 'Partially occupied');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onEditRoom,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.door_front_door_outlined, color: fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$occ/${room.totalBeds} beds full • Rent: ₹${room.defaultRent}\nPer bed',
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            height: 1.2),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: bg, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    label,
                    style: TextStyle(
                        color: fg, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: Colors.grey.shade600, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: room.totalBeds,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3.6,
            ),
            itemBuilder: (_, bed) {
              final m = activeRoomTenants.where((x) => x.bedIndex == bed);
              final t = m.isEmpty ? null : m.first;
              if (t == null) {
                return InkWell(
                  onTap: () => onTapBed(bed, null),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bed_outlined, size: 16, color: green),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Vacant',
                            style: TextStyle(
                              color: green,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(Icons.add, size: 16, color: green),
                      ],
                    ),
                  ),
                );
              }
              final rent = getRent(t);
              final bal = (rent - getPaid(t)).clamp(0, rent);
              final color = bal == 0 ? green : (isOverdue(t) ? red : blue);
              return InkWell(
                onTap: () => onTapBed(bed, t),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade900
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          t.name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${bal == 0 ? rent : bal}',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      Icon(Icons.chevron_right,
                          size: 14, color: Colors.grey.shade500),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
