class AppEnv {
  // Cloudinary — unsigned upload only (API secret lives in Cloud Functions)
  static const String cloudinaryCloudName = 'dfvoosm9v';
  static const String cloudinaryUploadPreset = 'ml_default';
  static const String cloudinaryApiKey = '329914567685393';

  // Firebase project
  static const String firebaseProjectId = 'showsnap-2';
  static const String firebaseDatabaseUrl =
      'https://showsnap-2-default-rtdb.firebaseio.com';

  // Razorpay — replace with live key for production
  // TODO: Add your Razorpay Key ID (test mode) from razorpay.com → API Keys
  static const String razorpayKeyId = 'rzp_test_REPLACE_WITH_YOUR_KEY';

  // Convenience fee applied per booking (in paise for Razorpay, shown as ₹)
  static const int convenienceFeeRupees = 20;

  // Seat lock TTL in minutes
  static const int seatLockTtlMinutes = 8;
}
