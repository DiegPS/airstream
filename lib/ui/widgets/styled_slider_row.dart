import 'package:flutter/material.dart';

class StyledSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int? divisions;
  final String? unit;
  final String Function(double)? formatValue;
  final Color? accentColor;

  const StyledSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.unit,
    this.formatValue,
    this.accentColor,
  });

  String _formatText(double v) {
    if (formatValue != null) return formatValue!(v);
    if (unit == '%') return '${(v * 100).round()}%';
    if (unit != null && unit!.isNotEmpty) {
      return '${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)} $unit';
    }
    if (v.truncateToDouble() == v) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? const Color(0xFF53FC18);
    final clampedValue = value.clamp(min, max);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Text(
                  _formatText(clampedValue),
                  style: TextStyle(
                    color: effectiveAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: effectiveAccent,
              inactiveTrackColor: const Color(0xFF2C2C2C),
              thumbColor: Colors.white,
              overlayColor: effectiveAccent.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: clampedValue,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
