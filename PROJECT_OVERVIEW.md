# ShowSnap: Project Overview & Recent Implementations

This document serves as a high-level summary of the recent improvements made to the **ShowSnap** application, as well as a roadmap for potential future enhancements to make the app feel even more premium and robust.

---

## 🛠️ What We Have Done

### 1. UI/UX & Aesthetic Polishing
*   **Hero Section Redesign:** Integrated custom AI-generated promotional banners into a sleek, infinite-scrolling carousel. Removed pagination dots and manual navigation arrows for a cleaner, auto-playing cinematic feel.
*   **Profile Dashboard Cleanup:** Simplified the user dashboard by removing cluttered and unused metric cards (Quick Shortcuts, Taste Analysis, Wishlist, etc.), creating a much cleaner interface.
*   **Location-Aware Profile Edit:** Upgraded the "Edit Profile" bottom sheet. It now uses the device's GPS (`geolocator` & `geocoding`) to automatically fetch and populate the user's current city.
*   **Smart Phone Number Input:** Integrated `IntlPhoneField` with smart parsing to handle country codes flawlessly, preventing the database from saving duplicate prefixes (like `+91+91`).
*   **Seat Map Alignment:** Fixed visual bugs in the seat layout editor and user selection screens, ensuring seat numbers are perfectly centered within their touch targets.
*   **Toast Notifications:** Adjusted global toast notifications to use high-contrast black text, ensuring readability against light backgrounds.

### 2. Core Functionality & Admin Integration
*   **Smart Video Playback:** Fixed video playback lifecycle in the movie details screen. The background trailer now correctly pauses when the user clicks "Book Tickets" and no longer aggressively auto-resumes when returning from the booking flow.
*   **Dynamic "Unlock Milestone" Rewards:** Replaced hardcoded dummy data with real backend integration. The user's booking progress bar and reward coupons now dynamically map to offers configured by the Admin in the database.
*   **Responsive Desktop Dashboards:** Upgraded both the **Admin Dashboard** and the **Theater Manager Dashboard** with `LayoutBuilder`. They now dynamically scale their data grids (from 2 columns on mobile up to 6 columns on desktop) to utilize screen real estate effectively.

### 3. Security & Environment Configuration
*   **Environment Variables (`.env`):** Stripped all hardcoded API keys and secrets (Firebase, Cloudinary, Razorpay) out of the source code.
*   Integrated the `flutter_dotenv` package to securely load these variables at runtime.
*   Created a `.env.example` file for team onboarding and updated `.gitignore` to ensure real credentials are never leaked to GitHub.

---

## 👥 Roles and Abilities

ShowSnap operates on a robust Role-Based Access Control (RBAC) system. The three primary roles and their abilities are:

### 1. User (`user`)
*   **Primary Focus:** Browsing and booking movies.
*   **Abilities:**
    *   Browse movies, theaters, and upcoming events.
    *   Select specific seats using the interactive seat layout map.
    *   Book tickets and complete payments via Razorpay.
    *   View their digital E-Tickets (with QR codes) and booking history.
    *   Manage their profile, saved addresses, and unlock milestone rewards based on their booking count.

### 2. Theater Manager (`theaterManager`)
*   **Primary Focus:** Managing a specific theater's operations.
*   **Abilities:**
    *   Access the dedicated **Theater Manager Dashboard**.
    *   Create and edit Screen layouts (defining rows, columns, and pricing tiers).
    *   Add Movies to their specific theater.
    *   Schedule Shows (assigning a movie to a specific screen at a specific time).
    *   Use the integrated Ticket Scanner to scan user QR codes at the gate and mark tickets as 'Redeemed'.
    *   View daily revenue, seats sold, and upcoming shows for their assigned theater.

### 3. Administrator (`admin`)
*   **Primary Focus:** Platform-wide oversight and configuration.
*   **Abilities:**
    *   Access the **Admin Dashboard** with high-level platform metrics (Total Revenue, Total Users, Platform-wide ticket sales chart).
    *   Create new Theaters and assign specific users as the `theaterManager` for those theaters.
    *   Configure global promotional Banners (Hero carousel).
    *   Create and manage platform-wide Offers & Milestones (e.g., "Flat ₹100 Off after 5 Bookings").
    *   Review platform Ad Requests.
    *   Manage all users and audit tickets globally.

---

## 🚀 Future Enhancements (Making it Feel Better)

Here are some highly recommended features and optimizations to elevate ShowSnap into a truly world-class ticketing experience:

### 1. Immersive "Cinema" Dark Mode
*   **Implementation:** Movie apps inherently look better in dark mode. Implementing a deep black/charcoal theme with vibrant neon accents (using your primary brand colors) will make the movie posters and trailers pop, creating a premium "theater-like" aesthetic.

### 2. Advanced Micro-Animations
*   **Implementation:** Add `Hero` animations to movie posters. When a user taps a poster on the home screen, it should seamlessly scale and morph into the header image of the Movie Details screen. Add subtle parallax scrolling effects to the background trailers.

### 3. Offline Support & Ticket Caching
*   **Implementation:** Use a local database like `Hive` or `Isar` to cache purchased E-Tickets. If a user arrives at the theater with poor cell reception, they should still be able to open the app and display their QR code instantly.

### 4. Smart Video Pre-caching
*   **Implementation:** Background trailers currently load on demand. Implement a video caching layer so that when the user scrolls through the movie list, the first few seconds of the trailer are pre-buffered, allowing instant playback with zero loading spinners.

### 5. Advanced Seat Selection Gestures
*   **Implementation:** Add pinch-to-zoom and two-finger panning capabilities to the seat layout map, especially for large theaters or stadiums, making it easier for users to navigate crowded seating charts on small phone screens.

### 6. Social Sharing & Invites
*   **Implementation:** After booking, allow users to generate a dynamic link (Firebase Dynamic Links) that they can send via WhatsApp/iMessage. When friends click it, it opens ShowSnap directly to that specific showtime so they can book adjacent seats.

### 7. Haptic Feedback
*   **Implementation:** Integrate the `haptic_feedback` package. Add subtle device vibrations when a user successfully selects a seat, unlocks a milestone, or completes a payment. This physical feedback dramatically improves the perceived quality of the app.
