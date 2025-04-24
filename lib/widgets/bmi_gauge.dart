import 'package:flutter/material.dart';
import '../models/bmi_standard.dart';

class BMIGauge extends StatelessWidget {
  final double bmi;
  final BMIRegion region;
  final double height;
  final double width;

  const BMIGauge({
    Key? key,
    required this.bmi,
    required this.region,
    this.height = 200,
    this.width = double.infinity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final standard = BMIStandard.standards[region]!;
    final theme = Theme.of(context);

    return Container(
      height: height,
      width: width,
      padding: const EdgeInsets.all(16),
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
          _buildGauge(context, standard),
          const SizedBox(height: 16),
          _buildBMIText(context, standard),
        ],
      ),
    );
  }

  Widget _buildGauge(BuildContext context, BMIStandard standard) {
    final maxBMI = standard.categories.last.range.end;
    final normalizedBMI = bmi.clamp(0, maxBMI);
    final percentage = normalizedBMI / maxBMI;
    final theme = Theme.of(context);

    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gaugeWidth = constraints.maxWidth;
          final gaugeHeight = constraints.maxHeight;
          final segmentWidth = gaugeWidth / standard.categories.length;

          return Stack(
            children: [
              // Background segments
              Row(
                children: standard.categories.map((category) {
                  return Container(
                    width: segmentWidth,
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.2),
                      border: Border(
                        right: BorderSide(
                          color: theme.dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // BMI indicator
              Positioned(
                left: percentage * gaugeWidth - 2,
                child: Container(
                  width: 4,
                  height: gaugeHeight,
                  decoration: BoxDecoration(
                    color: standard.primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // BMI value
              Positioned(
                left: percentage * gaugeWidth - 20,
                top: gaugeHeight - 30,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: standard.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    bmi.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBMIText(BuildContext context, BMIStandard standard) {
    final category = standard.categories.firstWhere(
      (c) => c.contains(bmi),
      orElse: () => standard.categories.last,
    );

    return Column(
      children: [
        Text(
          category.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: category.color,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          category.description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: category.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: category.color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            'Risk Level: ${category.riskLevel}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: category.color,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}
