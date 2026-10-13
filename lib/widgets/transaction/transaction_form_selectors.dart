import 'package:flutter/material.dart';
import '../../models/app_config.dart';

/// Horizontal Chip Selectors for Member profiles and Bill Categories
class TransactionFormSelectors {
  static Widget buildMemberSelector(
    List<MemberConfig> members,
    String? selectedId,
    ValueChanged<String> onSelect,
    Color activeColor, {
    GlobalKey Function(String)? keyGetter,
    ScrollController? scrollController,
  }) {
    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: members.map((m) {
          final isSelected = selectedId == m.id;
          final key = keyGetter != null ? keyGetter(m.id) : null;
          return Padding(
            key: key,
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,
              avatar: CircleAvatar(
                radius: 12,
                backgroundColor: isSelected ? Colors.white24 : activeColor.withValues(alpha: 0.15),
                child: Text(
                  m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : activeColor,
                  ),
                ),
              ),
              label: Text(m.name + (!m.active ? ' (Inactive)' : '')),
              selected: isSelected,
              selectedColor: activeColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => onSelect(m.id),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  static Widget buildBillTypeSelector(
    List<BillTypeConfig> billTypes,
    String? selectedId,
    ValueChanged<String> onSelect,
    Color activeColor, {
    GlobalKey Function(String)? keyGetter,
    ScrollController? scrollController,
  }) {
    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: billTypes.map((b) {
          final isSelected = selectedId == b.id;
          final key = keyGetter != null ? keyGetter(b.id) : null;
          return Padding(
            key: key,
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,
              avatar: Text(b.icon, style: const TextStyle(fontSize: 16)),
              label: Text(b.name),
              selected: isSelected,
              selectedColor: activeColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => onSelect(b.id),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
