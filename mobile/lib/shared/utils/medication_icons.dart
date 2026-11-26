import 'package:flutter/material.dart';

/// Shared dosage-form iconography and normalized meal-relation mapping so every
/// card (Today, Medications, Caregiver, Alarm) renders consistent visual cues.
class MedicationIcons {
  MedicationIcons._();

  static IconData forForm(String? formType) =>
      switch ((formType ?? '').toUpperCase()) {
        'TABLET' => Icons.medication_rounded,
        'CAPSULE' => Icons.medication_outlined,
        'SYRUP' => Icons.local_drink_outlined,
        'INJECTION' => Icons.vaccines_outlined,
        'DROP' => Icons.water_drop_outlined,
        'CREAM' => Icons.spa_outlined,
        _ => Icons.healing_outlined,
      };

  static String normalizeMeal(String? raw) =>
      switch ((raw ?? '').toUpperCase()) {
        'BEFORE' || 'BEFORE_MEAL' || 'BEFORE_MEALS' => 'BEFORE_MEALS',
        'AFTER' || 'AFTER_MEAL' || 'AFTER_MEALS' => 'AFTER_MEALS',
        'WITH' || 'WITH_FOOD' => 'WITH_FOOD',
        'EMPTY' || 'ON_EMPTY_STOMACH' => 'ON_EMPTY_STOMACH',
        _ => 'NONE',
      };

  static String? mealLabelKey(String? raw) => switch (normalizeMeal(raw)) {
        'BEFORE_MEALS' => 'meds.meal.before',
        'AFTER_MEALS' => 'meds.meal.after',
        'WITH_FOOD' => 'meds.meal.with',
        'ON_EMPTY_STOMACH' => 'meds.meal.empty',
        _ => null,
      };
}
