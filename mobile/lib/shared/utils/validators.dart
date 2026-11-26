/// Shared input validators — single source of truth across auth and care-circle forms.
class AppValidators {
  AppValidators._();

  /// Egyptian mobile: `010/011/012/015` + 8 digits, or `+20` / `20` with
  /// optional leading `0` (e.g. `01012345678`, `+201012345678`, `+2001012345678`).
  static final RegExp egyptianPhone =
      RegExp(r'^(?:\+?200?|0)(?:10|11|12|15)\d{8}$');

  static bool isValidEmail(String raw) {
    final clean = raw.trim();
    return clean.contains('@') && clean.contains('.');
  }

  static bool isValidEgyptianPhone(String raw) {
    final clean = raw.trim().replaceAll(' ', '');
    return clean.isNotEmpty && egyptianPhone.hasMatch(clean);
  }

  static bool isValidEmailOrPhone(String raw) =>
      isValidEmail(raw) || isValidEgyptianPhone(raw);
}
