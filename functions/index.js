const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cloudinary = require('cloudinary').v2;

admin.initializeApp();
const db = admin.database();

// Cloudinary is configured from environment variables set via:
// firebase functions:config:set cloudinary.api_key="..." cloudinary.api_secret="..." cloudinary.cloud_name="..."
cloudinary.config({
  cloud_name: functions.config().cloudinary.cloud_name,
  api_key: functions.config().cloudinary.api_key,
  api_secret: functions.config().cloudinary.api_secret,
});

// CF-01: Release expired seat locks — runs every minute
exports.releaseSeatLocks = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async () => {
    const now = Date.now();
    const showsSnap = await db.ref('shows').once('value');
    if (!showsSnap.exists()) return null;

    const updates = {};
    showsSnap.forEach((showSnap) => {
      const showId = showSnap.key;
      const seatsSnap = showSnap.child('seats');
      seatsSnap.forEach((seatSnap) => {
        const seat = seatSnap.val();
        if (
          seat.status === 'locked' &&
          seat.lockedAt &&
          seat.lockedBy &&
          now - seat.lockedAt > 8 * 60 * 1000
        ) {
          const seatId = seatSnap.key;
          updates[`shows/${showId}/seats/${seatId}/status`] = 'available';
          updates[`shows/${showId}/seats/${seatId}/lockedBy`] = null;
          updates[`shows/${showId}/seats/${seatId}/lockedAt`] = null;
          // Increment seatsAvailable counter
          // (Handled by incrementing in a separate step below)
        }
      });
    });

    if (Object.keys(updates).length === 0) return null;

    // Recalculate seatsAvailable for affected shows
    const affectedShows = new Set(
      Object.keys(updates)
        .filter((k) => k.includes('/seats/'))
        .map((k) => k.split('/')[1])
    );

    for (const showId of affectedShows) {
      const seatsSnap = await db.ref(`shows/${showId}/seats`).once('value');
      let available = 0;
      seatsSnap.forEach((s) => {
        if (s.val().status === 'available') available++;
      });
      updates[`shows/${showId}/seatsAvailable`] = available;
    }

    return db.ref().update(updates);
  });

// CF-02: Evaluate milestone rewards on booking confirmed
exports.evaluateMilestones = functions.database
  .ref('bookings/{bookingId}')
  .onCreate(async (snap, context) => {
    const booking = snap.val();
    if (!booking || booking.status !== 'confirmed') return null;

    const uid = booking.uid;
    const userRef = db.ref(`users/${uid}`);
    const userSnap = await userRef.once('value');
    if (!userSnap.exists()) return null;

    const user = userSnap.val();
    const currentMovies = user.totalUniqueMoviesBooked || 0;

    // Count unique movies this user has booked
    const bookingsSnap = await db
      .ref('bookings')
      .orderByChild('userId')
      .equalTo(uid)
      .once('value');

    const movieIds = new Set();
    bookingsSnap.forEach((b) => {
      const bVal = b.val();
      if (
        bVal.movieId &&
        (bVal.status === 'confirmed' || bVal.status === 'redeemed')
      ) {
        movieIds.add(bVal.movieId);
      }
    });
    const uniqueMoviesCount = movieIds.size;

    // Check milestone offers
    const offersSnap = await db.ref('offers').once('value');
    const rewards = { ...(user.rewards || {}) };
    let updated = false;

    offersSnap.forEach((offerSnap) => {
      const offer = offerSnap.val();
      const offerId = offerSnap.key;

      if (!offer.active) return;

      let milestoneHit = false;
      if (offer.milestoneType === 'uniqueMovies' && uniqueMoviesCount >= offer.milestoneCount) {
        milestoneHit = true;
      } else if (offer.milestoneType === 'totalBookings' && bookingsSnap.numChildren() >= offer.milestoneCount) {
        milestoneHit = true;
      }

      if (milestoneHit && !rewards[offerId]) {
        rewards[offerId] = {
          offerId,
          earnedAt: Date.now(),
          redeemed: false,
          rewardType: offer.rewardType,
          rewardValue: offer.rewardValue,
        };
        updated = true;
      }
    });

    const userUpdates = {};
    if (updated) userUpdates[`users/${uid}/rewards`] = rewards;
    userUpdates[`users/${uid}/totalUniqueMoviesBooked`] = uniqueMoviesCount;

    return db.ref().update(userUpdates);
  });

// CF-03: Get Cloudinary signature for signed uploads (admin/TM use only)
// Flutter app uses unsigned preset; this is for future signed uploads if needed
exports.getCloudinarySignature = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  // Only admin or theater managers can get signed URLs
  const uid = context.auth.uid;
  const userSnap = await db.ref(`users/${uid}`).once('value');
  const role = userSnap.val()?.role;

  if (role !== 'admin' && role !== 'theaterManager') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admin or theater managers can request signed uploads'
    );
  }

  const folder = data.folder || 'showsnap/misc';
  const timestamp = Math.round(Date.now() / 1000);
  const paramsToSign = { folder, timestamp };
  const signature = cloudinary.utils.api_sign_request(
    paramsToSign,
    functions.config().cloudinary.api_secret
  );

  return {
    signature,
    timestamp,
    apiKey: functions.config().cloudinary.api_key,
    cloudName: functions.config().cloudinary.cloud_name,
    folder,
  };
});

// CF-04: Handle booking cancellation — release seats and refund seatsAvailable
exports.onBookingCancelled = functions.database
  .ref('bookings/{bookingId}/status')
  .onUpdate(async (change, context) => {
    const newStatus = change.after.val();
    if (newStatus !== 'cancelled') return null;

    const bookingSnap = await db
      .ref(`bookings/${context.params.bookingId}`)
      .once('value');
    const booking = bookingSnap.val();
    if (!booking) return null;

    const { showId, seats } = booking;
    if (!showId || !seats) return null;

    const updates = {};
    for (const seat of seats) {
      const seatId = seat.seatId;
      updates[`shows/${showId}/seats/${seatId}/status`] = 'available';
      updates[`shows/${showId}/seats/${seatId}/lockedBy`] = null;
      updates[`shows/${showId}/seats/${seatId}/lockedAt`] = null;
      updates[`shows/${showId}/seats/${seatId}/bookedBy`] = null;
    }

    // Recalculate seatsAvailable
    const seatsSnap = await db.ref(`shows/${showId}/seats`).once('value');
    let available = seats.length; // start with the released count
    seatsSnap.forEach((s) => {
      if (s.val().status === 'available') available++;
    });

    // Avoid double-counting (the seats above are not yet written as available in DB)
    // Instead recount after writing
    updates[`shows/${showId}/seatsAvailable`] = admin.database.ServerValue.increment(seats.length);

    return db.ref().update(updates);
  });

// CF-05: Send show reminders — runs every hour, notifies users 2h before show
exports.sendShowReminders = functions.pubsub
  .schedule('every 60 minutes')
  .onRun(async () => {
    const now = Date.now();
    const twoHoursFromNow = now + 2 * 60 * 60 * 1000;
    const windowMs = 5 * 60 * 1000; // 5-min window to avoid duplicate sends

    const bookingsSnap = await db.ref('bookings').once('value');
    const messaging = admin.messaging();
    const promises = [];

    bookingsSnap.forEach((bookingSnap) => {
      const booking = bookingSnap.val();
      if (booking.status !== 'confirmed') return;
      if (!booking.showStartTs) return;

      const diff = booking.showStartTs - twoHoursFromNow;
      if (Math.abs(diff) > windowMs) return;

      // Get FCM token for this user
      const tokenPromise = db
        .ref(`users/${booking.userId}/fcmToken`)
        .once('value')
        .then((snap) => {
          const token = snap.val();
          if (!token) return null;
          return messaging.send({
            token,
            notification: {
              title: '🎬 Show in 2 hours!',
              body: `${booking.movieTitle} at ${booking.theaterName}`,
            },
            data: {
              type: 'show_reminder',
              bookingId: bookingSnap.key,
            },
          });
        })
        .catch(() => null); // Don't fail the whole run for one bad token

      promises.push(tokenPromise);
    });

    await Promise.allSettled(promises);
    return null;
  });
