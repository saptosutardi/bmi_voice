import 'package:flutter/material.dart';

class BMIThresholds {
  final String name;
  final List<double> thresholds;
  final List<String> categories;
  final List<Color> colors;

  BMIThresholds({
    required this.name,
    required this.thresholds,
    required this.categories,
    required this.colors,
  });
}

final Map<String, BMIThresholds> bmiStandards = {
  'WHO': BMIThresholds(
    name: 'WHO (Global)',
    thresholds: [18.5, 25.0, 30.0, 35.0, 40.0],
    categories: [
      'Underweight',
      'Normal',
      'Overweight',
      'Obese I',
      'Obese II',
      'Obese III'
    ],
    colors: [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.red[700]!,
      Colors.red[900]!
    ],
  ),
  'WPRO': BMIThresholds(
    name: 'Asia-Pasifik (WPRO)',
    thresholds: [18.5, 23.0, 25.0, 30.0],
    categories: ['Underweight', 'Normal', 'Overweight', 'Obese I', 'Obese II'],
    colors: [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.red[900]!
    ],
  ),
  'CN': BMIThresholds(
    name: 'China (WGOC)',
    thresholds: [18.5, 24.0, 28.0],
    categories: ['Underweight', 'Normal', 'Overweight', 'Obese'],
    colors: [Colors.blue, Colors.green, Colors.orange, Colors.red],
  ),
  'JP': BMIThresholds(
    name: 'Japan (JASSO)',
    thresholds: [18.5, 23.0, 25.0, 30.0, 35.0, 40.0],
    categories: [
      'Underweight',
      'Normal',
      'Pre-obese',
      'Obese I',
      'Obese II',
      'Obese III',
      'Obese IV'
    ],
    colors: [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.deepOrange,
      Colors.red,
      Colors.red[700]!,
      Colors.red[900]!
    ],
  ),
  'IN': BMIThresholds(
    name: 'India',
    thresholds: [18.5, 23.0, 25.0, 30.0],
    categories: ['Underweight', 'Normal', 'Overweight', 'Obese I', 'Obese II'],
    colors: [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.red[900]!
    ],
  ),
  'SG': BMIThresholds(
    name: 'Singapore',
    thresholds: [18.5, 23.0, 27.5],
    categories: ['Underweight', 'Normal', 'Overweight', 'Obese'],
    colors: [Colors.blue, Colors.green, Colors.orange, Colors.red],
  ),
};
