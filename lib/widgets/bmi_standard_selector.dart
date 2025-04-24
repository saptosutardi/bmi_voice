import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bmi_standard.dart';

class BMIStandardSelector extends StatelessWidget {
  final BMIRegion selectedRegion;
  final ValueChanged<BMIRegion> onRegionChanged;
  final bool showDescription;

  const BMIStandardSelector({
    Key? key,
    required this.selectedRegion,
    required this.onRegionChanged,
    this.showDescription = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final standard = BMIStandard.standards[selectedRegion]!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDescription) ...[
          Text(
            'BMI Standard',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            standard.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildRegionSelector(context),
              _buildCategoryLegend(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegionSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.public,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<BMIRegion>(
                value: selectedRegion,
                isExpanded: true,
                items: BMIRegion.values.map((region) {
                  final standard = BMIStandard.standards[region]!;
                  return DropdownMenuItem(
                    value: region,
                    child: Text(
                      standard.name,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }).toList(),
                onChanged: (region) {
                  if (region != null) {
                    HapticFeedback.selectionClick();
                    onRegionChanged(region);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryLegend(BuildContext context) {
    final standard = BMIStandard.standards[selectedRegion]!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categories',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...standard.categories.map((category) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: category.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          '${category.range.start.toStringAsFixed(1)} - ${category.range.end == double.infinity ? '∞' : category.range.end.toStringAsFixed(1)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: category.description,
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.iconTheme.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
