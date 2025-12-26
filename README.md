# SocialVideo - Next-Gen Social Video Platform

A premium, futuristic social video platform combining Instagram, YouTube, and Messenger features with a stunning glassmorphism UI design.

## 🎨 Design Features

- **Glassmorphism UI**: Frosted glass cards with backdrop blur and subtle transparency
- **AMOLED Dark Theme**: Deep dark backgrounds (#0B0F1A, #0E1325)
- **Neon Accents**: Purple (#7C6CFF), Cyan (#2DE2E6), and Blue (#4DA3FF) highlights
- **Smooth Animations**: Page transitions, parallax effects, elastic physics
- **Premium Feel**: Rounded corners (16-24px), floating elements, clean spacing

## 📱 Screens Implemented

### 1. **Auth Screen**
- Social login buttons (Google, Apple, Facebook)
- Glass card centered design
- Logo with animated glow effect
- Smooth transition to home

### 2. **Home Feed**
- Infinite scrolling feed
- Mixed content (images and videos)
- Video cards with play overlay
- Like/comment/share counters
- Floating glass bottom navigation
- Stories bar with animated gradient rings

### 3. **Reels Screen**
- Full-screen vertical swipe videos
- Auto-play on focus
- Like/comment/share overlay icons
- Music title scrolling animation
- Progress bar on right edge
- Elastic swipe physics

### 4. **Long Video Player**
- YouTube-style player UI
- Video scrubber with time display
- Quality selector (UI only)
- Mini-player animation ready
- Title + channel card below
- Full controls overlay

### 5. **Stories**
- Horizontal story bar
- Circular gradient ring animation
- Full-screen story viewer
- Progress indicators on top
- Swipe gestures (next/exit)
- Auto-advance after 5 seconds

### 6. **User Profile**
- Glass header with gradient
- Profile image with glow ring
- Followers/Following/Posts counters
- Grid of posts
- Follow/Message buttons
- Smooth expand animations

### 7. **Chat UI**
- Messenger-style chat bubbles
- Glass message bubbles
- Typing indicator animation
- Online status glow dot
- Media message UI
- Input bar with blur effect

### 8. **Search**
- Glass search bar
- Trending hashtags
- User cards with avatars
- Animated list appearance
- Real-time search filtering

### 9. **Notifications**
- Activity feed
- Like/comment/follow cards
- Subtle pulse animation for new items
- Mark all as read functionality
- Color-coded notification types

### 10. **Settings**
- Toggle switches (glass style)
- Profile options
- Dark mode toggle
- Clean grouped sections
- Logout button

## 🏗️ Architecture

```
lib/
├── core/
│   ├── theme/
│   │   ├── app_colors.dart      # Color palette
│   │   └── app_theme.dart       # Theme configuration
│   ├── widgets/
│   │   ├── glass_card.dart      # Reusable glass card
│   │   ├── glass_button.dart    # Glass button with glow
│   │   ├── story_avatar.dart    # Story avatar with ring
│   │   ├── video_tile.dart      # Video card widget
│   │   └── bottom_nav_bar.dart  # Glass navigation bar
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── post_model.dart
│   │   ├── story_model.dart
│   │   └── message_model.dart
│   └── services/
│       └── mock_data_service.dart  # Mock data provider
├── features/
│   ├── auth/
│   ├── home/
│   ├── reels/
│   ├── video/
│   ├── stories/
│   ├── profile/
│   ├── chat/
│   ├── search/
│   ├── notifications/
│   └── settings/
└── main.dart
```

## 🎯 Key Features

### Animations
- **Page Transitions**: Fade + slide animations
- **Feed Scroll**: Subtle parallax effects
- **Reels Swipe**: Elastic physics
- **Buttons**: Scale + glow on tap
- **Cards**: Hover/focus elevation
- **Story Ring**: Animated gradient stroke
- **Video Cards**: Shimmer loading skeletons

### Reusable Components
- `GlassCard`: Frosted glass container
- `GlassButton`: Button with glow effect
- `StoryAvatar`: Avatar with animated ring
- `VideoTile`: Video card with stats
- `BottomNavBar`: Glass navigation bar

## 🚀 Getting Started

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Run the app**:
   ```bash
   flutter run
   ```

3. **Build for production**:
   ```bash
   flutter build apk  # Android
   flutter build ios   # iOS
   ```

## 📦 Dependencies

- `flutter`: SDK
- `video_player`: Video playback
- `animations`: Smooth animations
- `cached_network_image`: Image caching
- `flutter_staggered_animations`: List animations

## 🎨 Color Palette

### Backgrounds
- Primary: `#0B0F1A`
- Secondary: `#0E1325`

### Glass Surfaces
- Surface: `rgba(255,255,255,0.06)`
- Border: `rgba(255,255,255,0.12)`

### Accents
- Neon Purple: `#7C6CFF`
- Cyan Glow: `#2DE2E6`
- Soft Blue: `#4DA3FF`
- Warning: `#FF6B6B`

### Text
- Primary: `#FFFFFF`
- Secondary: `#A0A6C3`
- Muted: `#6E7391`

## 🔮 Future Enhancements

- Backend integration
- Real video playback
- User authentication
- Real-time chat
- Push notifications
- Video upload
- Story creation
- Post creation

## 📝 Notes

- All data is currently mocked for frontend development
- Backend integration points are ready
- UI is fully responsive
- Dark mode is the default (light mode ready)
- All animations are smooth and performant

## 🎉 Credits

Built with Flutter and designed for a premium user experience.

---

**Status**: Frontend UI Complete ✅ | Backend Integration: Pending
# vidmate
