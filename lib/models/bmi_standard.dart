import 'package:flutter/material.dart';

enum BMIRegion {
  who,
  asiaPacific,
  china,
  japan,
  india,
  singapore,
}

class BMIStandard {
  final String name;
  final String description;
  final List<BMICategory> categories;
  final Color primaryColor;
  final String regionCode;

  const BMIStandard({
    required this.name,
    required this.description,
    required this.categories,
    required this.primaryColor,
    required this.regionCode,
  });

  static final Map<BMIRegion, BMIStandard> standards = {
    BMIRegion.who: BMIStandard(
      name: 'WHO International',
      description: 'Global standard suitable for international comparison',
      regionCode: 'global',
      primaryColor: Colors.blue,
      categories: [
        BMICategory(
          name: 'Underweight',
          range: Range(0, 18.5),
          color: Colors.blue.shade100,
          description: 'Below normal weight range',
          riskLevel: 'Low',
        ),
        BMICategory(
          name: 'Normal',
          range: Range(18.5, 24.9),
          color: Colors.green,
          description: 'Healthy weight range',
          riskLevel: 'Normal',
        ),
        BMICategory(
          name: 'Overweight',
          range: Range(25, 29.9),
          color: Colors.orange,
          description: 'Above normal weight range',
          riskLevel: 'Increased',
        ),
        BMICategory(
          name: 'Obese',
          range: Range(30, double.infinity),
          color: Colors.red,
          description: 'Significantly above normal weight range',
          riskLevel: 'High',
        ),
      ],
    ),
    BMIRegion.asiaPacific: BMIStandard(
      name: 'Asia-Pacific',
      description: 'More sensitive standard for Asian populations',
      regionCode: 'asia',
      primaryColor: Colors.purple,
      categories: [
        BMICategory(
          name: 'Underweight',
          range: Range(0, 18.5),
          color: Colors.purple.shade100,
          description: 'Below normal weight range',
          riskLevel: 'Low',
        ),
        BMICategory(
          name: 'Normal',
          range: Range(18.5, 22.9),
          color: Colors.green,
          description: 'Healthy weight range',
          riskLevel: 'Normal',
        ),
        BMICategory(
          name: 'Overweight',
          range: Range(23, 24.9),
          color: Colors.orange,
          description: 'At risk of overweight',
          riskLevel: 'Increased',
        ),
        BMICategory(
          name: 'Obese',
          range: Range(25, double.infinity),
          color: Colors.red,
          description: 'Significantly above normal weight range',
          riskLevel: 'High',
        ),
      ],
    ),
    BMIRegion.china: BMIStandard(
      name: 'China (WGOC)',
      description: 'Chinese-specific BMI classification',
      regionCode: 'cn',
      primaryColor: Colors.red,
      categories: [
        BMICategory(
          name: 'Underweight',
          range: Range(0, 18.5),
          color: Colors.red.shade100,
          description: 'Below normal weight range',
          riskLevel: 'Low',
        ),
        BMICategory(
          name: 'Normal',
          range: Range(18.5, 23.9),
          color: Colors.green,
          description: 'Healthy weight range',
          riskLevel: 'Normal',
        ),
        BMICategory(
          name: 'Overweight',
          range: Range(24, 27.9),
          color: Colors.orange,
          description: 'Above normal weight range',
          riskLevel: 'Increased',
        ),
        BMICategory(
          name: 'Obese',
          range: Range(28, double.infinity),
          color: Colors.red,
          description: 'Significantly above normal weight range',
          riskLevel: 'High',
        ),
      ],
    ),
    BMIRegion.japan: BMIStandard(
      name: 'Japan (JASSO)',
      description:
          'Japanese-specific BMI classification with detailed categories',
      regionCode: 'jp',
      primaryColor: Colors.indigo,
      categories: [
        BMICategory(
          name: 'Underweight',
          range: Range(0, 18.5),
          color: Colors.indigo.shade100,
          description: 'Below normal weight range',
          riskLevel: 'Low',
        ),
        BMICategory(
          name: 'Normal',
          range: Range(18.5, 22.9),
          color: Colors.green,
          description: 'Healthy weight range',
          riskLevel: 'Normal',
        ),
        BMICategory(
          name: 'Pre-obese',
          range: Range(23, 24.9),
          color: Colors.orange.shade200,
          description: 'At risk of overweight',
          riskLevel: 'Slightly Increased',
        ),
        BMICategory(
          name: 'Obese I',
          range: Range(25, 29.9),
          color: Colors.orange,
          description: 'Class I obesity',
          riskLevel: 'Increased',
        ),
        BMICategory(
          name: 'Obese II',
          range: Range(30, 34.9),
          color: Colors.red.shade300,
          description: 'Class II obesity',
          riskLevel: 'High',
        ),
        BMICategory(
          name: 'Obese III',
          range: Range(35, 39.9),
          color: Colors.red.shade600,
          description: 'Class III obesity',
          riskLevel: 'Very High',
        ),
        BMICategory(
          name: 'Obese IV',
          range: Range(40, double.infinity),
          color: Colors.red.shade900,
          description: 'Class IV obesity',
          riskLevel: 'Extremely High',
        ),
      ],
    ),
    BMIRegion.india: BMIStandard(
      name: 'India',
      description: 'Indian-specific BMI classification',
      regionCode: 'in',
      primaryColor: Colors.orange,
      categories: [
        BMICategory(
          name: 'Underweight',
          range: Range(0, 18.5),
          color: Colors.orange.shade100,
          description: 'Below normal weight range',
          riskLevel: 'Low',
        ),
        BMICategory(
          name: 'Normal',
          range: Range(18.5, 22.9),
          color: Colors.green,
          description: 'Healthy weight range',
          riskLevel: 'Normal',
        ),
        BMICategory(
          name: 'Overweight',
          range: Range(23, 24.9),
          color: Colors.orange,
          description: 'Above normal weight range',
          riskLevel: 'Increased',
        ),
        BMICategory(
          name: 'Obese',
          range: Range(25, double.infinity),
          color: Colors.red,
          description: 'Significantly above normal weight range',
          riskLevel: 'High',
        ),
      ],
    ),
    BMIRegion.singapore: BMIStandard(
      name: 'Singapore',
      description: 'Singapore-specific BMI classification',
      regionCode: 'sg',
      primaryColor: Colors.teal,
      categories: [
        BMICategory(
          name: 'Underweight',
          range: Range(0, 18.5),
          color: Colors.teal.shade100,
          description: 'Below normal weight range',
          riskLevel: 'Low',
        ),
        BMICategory(
          name: 'Normal',
          range: Range(18.5, 22.9),
          color: Colors.green,
          description: 'Healthy weight range',
          riskLevel: 'Normal',
        ),
        BMICategory(
          name: 'Mild-Moderate Overweight',
          range: Range(23, 27.4),
          color: Colors.orange,
          description: 'Mild to moderate overweight',
          riskLevel: 'Increased',
        ),
        BMICategory(
          name: 'Obese',
          range: Range(27.5, double.infinity),
          color: Colors.red,
          description: 'Significantly above normal weight range',
          riskLevel: 'High',
        ),
      ],
    ),
  };
}

class BMICategory {
  final String name;
  final Range range;
  final Color color;
  final String description;
  final String riskLevel;

  const BMICategory({
    required this.name,
    required this.range,
    required this.color,
    required this.description,
    required this.riskLevel,
  });

  bool contains(double bmi) {
    return bmi >= range.start && bmi < range.end;
  }
}

class Range {
  final double start;
  final double end;

  const Range(this.start, this.end);
}
