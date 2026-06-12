import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String get cloudinaryCloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get cloudinaryUploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
  static String get cloudinaryApiKey => dotenv.env['CLOUDINARY_API_KEY'] ?? '';

  static String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get firebaseDatabaseUrl => dotenv.env['FIREBASE_DATABASE_URL'] ?? '';

  static String get razorpayKeyId => dotenv.env['RAZORPAY_KEY_ID'] ?? '';

  static int get convenienceFeeRupees => int.tryParse(dotenv.env['CONVENIENCE_FEE_RUPEES'] ?? '') ?? 20;
  static int get seatLockTtlMinutes => int.tryParse(dotenv.env['SEAT_LOCK_TTL_MINUTES'] ?? '') ?? 8;
}
