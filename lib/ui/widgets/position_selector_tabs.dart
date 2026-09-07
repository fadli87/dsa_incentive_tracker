import 'package:flutter/material.dart';
import '../../core/models/calculator_models.dart';

class PositionSelectorTabs extends StatelessWidget {
  final PositionType selectedPosition;
  final ValueChanged<PositionType> onPositionChanged;

  const PositionSelectorTabs({
    super.key,
    required this.selectedPosition,
    required this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6.0),
      child: Row(
        children: PositionType.values.map((pos) {
          final isSelected = pos == selectedPosition;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onPositionChanged(pos),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF002B66)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      pos.icon,
                      size: 24,
                      color: isSelected
                          ? Colors.amberAccent
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pos.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSelected ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pos.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: isSelected
                            ? Colors.white70
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
