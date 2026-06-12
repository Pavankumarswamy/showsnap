class Validators {
  static String? required(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    final regex = RegExp(r'^\+?[0-9]{10,13}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid phone number';
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? positiveNumber(String? value, [String field = 'Value']) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    final num = int.tryParse(value.trim());
    if (num == null) return 'Enter a valid number';
    if (num <= 0) return '$field must be greater than 0';
    return null;
  }

  static String? couponCode(String? value) {
    if (value == null || value.trim().isEmpty) return 'Coupon code is required';
    final regex = RegExp(r'^[A-Z0-9]{4,20}$');
    if (!regex.hasMatch(value.trim().toUpperCase())) {
      return 'Code must be 4-20 uppercase letters/numbers';
    }
    return null;
  }
}
