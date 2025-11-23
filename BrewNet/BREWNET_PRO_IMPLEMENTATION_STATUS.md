# BrewNet Pro Implementation Status

## ✅ Completed Features

### 1. Database Schema
- ✅ Created SQL migration script (`add_brewnet_pro_columns.sql`)
- ✅ Added columns: `is_pro`, `pro_start`, `pro_end`, `likes_remaining`, `likes_depleted_at`
- ✅ Created triggers for auto-reset likes after 24h
- ✅ Created function to check Pro expiration

### 2. Models Updated
- ✅ Updated `SupabaseUser` model with Pro fields
- ✅ Updated `AppUser` model with Pro fields
- ✅ Added helper methods (`isProActive`, `canLike`)

### 3. UI Components Created
- ✅ `ProBadge.swift` - Reusable golden Pro badge component
- ✅ `SubscriptionPaymentView.swift` - Full payment UI with 4 pricing tiers
- ✅ `ProExpiryPopup` - Popup when Pro expires

### 4. SupabaseService Methods
- ✅ `upgradeUserToPro()` - Handles subscription purchase
- ✅ `checkAndUpdateProExpiration()` - Checks if Pro expired
- ✅ `decrementUserLikes()` - Handles like counting for non-Pro users
- ✅ `getUserLikesRemaining()` - Gets remaining likes
- ✅ `canSendTemporaryChat()` - Checks if user can send temp chat

### 5. Pro Badge Added To
- ✅ ProfileView (user's own profile)
- ✅ ProfileDisplayView (user's own profile expanded)
- ✅ UserProfileCardView (swipe cards showing other users)

### 6. Registration Flow
- ✅ Auto-grant 1 week free Pro to new users in `AuthManager.supabaseRegister()`

### 7. Profile Tab Enhancements
- ✅ "Get BrewNet Pro" upgrade card for non-Pro users
- ✅ Subscription payment sheet integration
- ✅ Pro expiry popup integration

### 8. AuthManager
- ✅ Added `refreshUser()` method to reload user data after subscription

## 🚧 Remaining Tasks

### 1. Add Pro Badge to Remaining Views
- ❌ BrewNetMatchesView
- ❌ ExploreView
- ❌ ConnectionRequestsView
- ❌ ChatInterfaceView (chat list)
- ❌ Chat conversation header

### 2. Implement Likes Gating
Need to integrate `decrementUserLikes()` in:
- ❌ BrewNetMatchesView (right swipe action)
- ❌ ExploreView (if it has like functionality)
- ❌ ConnectionRequestsView (when sending request)
- ❌ Show subscription payment when likes depleted

### 3. Temporary Chat Restrictions
- ❌ Find where temporary chat is initiated
- ❌ Check `canSendTemporaryChat()` before allowing
- ❌ Show subscription payment for non-Pro users

### 4. Filter Restrictions
- ❌ Identify "Pro-only" filters (you need to define which filters are Pro)
- ❌ Gray out Pro-only filters for non-Pro users
- ❌ Add text "Become Pro to unlock these filters"
- ❌ Show subscription payment when clicking Pro-only filter

### 5. Pro User Boost in Recommendations
- ❌ Update `RecommendationService.swift`
- ❌ Add scoring boost for Pro users
- ❌ Prioritize Pro users in request lists

### 6. Pro Check on App Launch
- ❌ Check and update Pro expiration when app launches
- ❌ Show Pro expired popup if needed

## 📋 Implementation Guide for Remaining Tasks

### Adding Pro Badge to Views

For each view, follow this pattern:

1. Add state variable to fetch Pro status:
```swift
@State private var userProStatus: [String: Bool] = [:] // userId -> isPro
```

2. Fetch Pro status when loading users:
```swift
private func loadProStatus(for userId: String) {
    Task {
        do {
            let user = try await supabaseService.getUser(userId: userId)
            await MainActor.run {
                userProStatus[userId] = user?.isProActive ?? false
            }
        } catch {
            print("Failed to load Pro status: \(error)")
        }
    }
}
```

3. Display badge next to name:
```swift
HStack {
    Text(userName)
    if userProStatus[userId] == true {
        ProBadge(size: .small)
    }
}
```

### Implementing Likes Gating

Where users like/swipe:
```swift
private func handleLike(userId: String) async {
    do {
        let canLike = try await supabaseService.decrementUserLikes(userId: currentUserId)
        if !canLike {
            // Show subscription payment
            showSubscriptionPayment = true
            return
        }
        // Proceed with like action
    } catch {
        print("Error: \(error)")
    }
}
```

### Finding Filter UI

Search for filter-related code:
```bash
grep -r "filter" BrewNet/ExploreView.swift
grep -r "Filter" BrewNet/
```

Then add Pro checks:
```swift
.disabled(!currentUser.isProActive)
.opacity(!currentUser.isProActive ? 0.5 : 1.0)
.onTapGesture {
    if !currentUser.isProActive {
        showSubscriptionPayment = true
    }
}
```

### Recommendation Boost

In `RecommendationService.swift`:
```swift
private func calculateScore(for user: User) -> Double {
    var score = baseScore
    
    // Boost Pro users
    if user.isProActive {
        score *= 1.5  // 50% boost for Pro users
    }
    
    return score
}
```

## 🎯 Entry Points to Payment Page

All entry points are implemented via:
```swift
@State private var showSubscriptionPayment = false

// Then show sheet:
.sheet(isPresented: $showSubscriptionPayment) {
    if let userId = authManager.currentUser?.id {
        SubscriptionPaymentView(currentUserId: userId) {
            Task {
                await authManager.refreshUser()
            }
        }
    }
}
```

Trigger points:
1. ✅ Profile tab "Get BrewNet Pro" card
2. ❌ When likes depleted (implement in swipe/like handlers)
3. ❌ When clicking Pro-only filters (implement in filter UI)
4. ❌ When clicking temporary chat as non-Pro (implement in chat)
5. ✅ Pro expiry popup "Stay Pro" button

## 📝 Testing Checklist

After implementation, test:
- [ ] SQL migration runs successfully
- [ ] New user gets 1 week free Pro
- [ ] Pro badge shows correctly everywhere
- [ ] Subscription payment works
- [ ] Pro renewal adds time (doesn't replace)
- [ ] Likes decrement correctly
- [ ] Likes reset after 24h
- [ ] Likes unlimited for Pro users
- [ ] Temporary chat blocked for non-Pro
- [ ] Filters disabled for non-Pro
- [ ] Pro users boosted in recommendations
- [ ] Pro expiry popup shows at right time
- [ ] RefreshUser updates UI after subscription

## 🔧 Required Database Setup

Before testing, run in Supabase SQL Editor:
```sql
-- Execute the migration script
\i add_brewnet_pro_columns.sql
```

Or copy-paste the contents of `add_brewnet_pro_columns.sql` into Supabase Dashboard > SQL Editor and run.

## 📚 Files Modified

1. `/BrewNet/ProBadge.swift` (NEW)
2. `/BrewNet/SubscriptionPaymentView.swift` (NEW)
3. `/BrewNet/SupabaseModels.swift` (MODIFIED)
4. `/BrewNet/SupabaseService.swift` (MODIFIED)
5. `/BrewNet/AuthManager.swift` (MODIFIED)
6. `/BrewNet/ProfileView.swift` (MODIFIED)
7. `/BrewNet/ProfileDisplayView.swift` (MODIFIED)
8. `/BrewNet/UserProfileCardView.swift` (MODIFIED)
9. `/add_brewnet_pro_columns.sql` (NEW)

## 🎨 Design Assets

Pro Badge:
- Colors: Gold gradient (#FFD700 to #FFA500)
- Font: Bold, size varies (small/medium/large)
- Shape: Rounded rectangle with shadow

Payment View:
- 4 pricing tiers following Hinge-style design
- Purple accent color (#9966CC)
- Golden "Get BrewNet Pro" button

