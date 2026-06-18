class AppConstants {
  // RTDB collection paths
  static const String usersPath = 'users';
  static const String theatersPath = 'theaters';
  static const String screensPath = 'screens';
  static const String moviesPath = 'movies';
  static const String showsPath = 'shows';
  static const String bookingsPath = 'bookings';
  static const String couponsPath = 'coupons';
  static const String offersPath = 'offers';
  static const String adRequestsPath = 'adRequests';
  static const String eventsPath = 'events';
  static const String bannersPath = 'banners';
  static const String notificationsPath = 'notifications';

  // User roles
  static const String roleAdmin = 'admin';
  static const String roleTheaterManager = 'theaterManager';
  static const String roleEventManager = 'eventManager';
  static const String roleUser = 'user';

  // Cloudinary folders
  static const String cloudinaryMoviePosters = 'showsnap/movie_posters';
  static const String cloudinaryEventPosters = 'showsnap/event_posters';
  static const String cloudinaryAvatars = 'showsnap/avatars';
  static const String cloudinaryAdCreatives = 'showsnap/ad_creatives';
  static const String cloudinaryTheaterLogos = 'showsnap/theater_logos';
  static const String cloudinaryEtickets = 'showsnap/etickets';

  // FCM notification types
  static const String notifBookingConfirmed = 'booking_confirmed';
  static const String notifShowReminder = 'show_reminder';
  static const String notifRewardUnlocked = 'reward_unlocked';
  static const String notifAdRequestStatus = 'ad_request_status';
  static const String notifPromo = 'promo';

  // Seat locking
  static const int seatLockMinutes = 8;
  static const int maxSeatsPerBooking = 6;

  // Convenience fee
  static const int convenienceFeeRs = 20;

  // Pagination
  static const int usersPageSize = 20;
  static const int bookingsPageSize = 20;

  // Affinity scoring weights
  static const double genreAffinityWeight = 0.5;
  static const double recencyBoostWeight = 0.3;
  static const double trendingScoreWeight = 0.2;

  // Home section limits
  static const int homeSectionLimit = 10;
  static const int trendingDaysWindow = 7;

  // Event Categories
  static const List<String> eventCategories = [
    'Comedy Shows',
    'Music Shows',
    'Amusement Parks',
    'Adventure',
    'Workshops',
    'Kids Zone',
    'Unique Tours',
    'Movies',
    'Stream',
    'Performances',
    'Tourist Attractions',
    'Explore More',
    'Other',
  ];
}
