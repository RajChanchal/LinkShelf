# App Store Submission Checklist

## ✅ Completed Steps

- [x] App ID created
- [x] App Sandbox entitlements configured
- [x] App icon placeholder created (1024x1024)
- [x] Screenshots prepared (3 sets, 4 resolutions each)
- [x] Support URL (README_SUPPORT.md) - https://github.com/RajChanchal/LinkShelf/blob/main/README_SUPPORT.md
- [x] Privacy Policy URL (GitHub Pages) - https://rajchanchal.github.io/LinkShelf/
- [x] Code committed and pushed to GitHub

## 📋 Next Steps for App Store Submission

### Step 1: Verify GitHub Pages (2 minutes)

1. **Wait 2-5 minutes** for GitHub Pages to build
2. **Visit your privacy policy URL:**
   ```
   https://rajchanchal.github.io/LinkShelf/
   ```
3. **Verify it loads correctly** - You should see a styled privacy policy page

### Step 2: Finalize App Icon (15-30 minutes)

**Current Status:** Placeholder icon exists at `~/Desktop/LinkShelf_AppIcon_1024x1024.png`

**Action Required:**
- [ ] Create or finalize your 1024x1024 app icon
- [ ] Design should match your menu bar icon (link/chain concept)
- [ ] Export as PNG (no transparency)
- [ ] Save as `LinkShelf_AppIcon_1024x1024.png`

**Tools to use:**
- Figma (free) - https://www.figma.com
- Sketch
- Photoshop
- Or use the generator: `python3 generate_app_icon.py`

### Step 3: Create App in App Store Connect (10 minutes)

1. **Go to App Store Connect:**
   - https://appstoreconnect.apple.com
   - Sign in with your Apple Developer account

2. **Create New App:**
   - Click **My Apps** → **+** button
   - Select **New App**
   - Fill in:
     - **Platform:** macOS
     - **Name:** LinkShelf
     - **Primary Language:** English
     - **Bundle ID:** com.chanchalgeek.LinkShelf (select the one you created)
     - **SKU:** LinkShelf (or any unique identifier)
     - **User Access:** Full Access (unless you have a team)

3. **Click Create**

### Step 4: Fill App Information (20-30 minutes)

In App Store Connect, complete these sections:

#### App Information Tab:
- [ ] **Name:** LinkShelf
- [ ] **Subtitle:** (Optional) Quick link access for your menu bar
- [ ] **Category:** 
  - Primary: Utilities
  - Secondary: (Optional) Productivity
- [ ] **Content Rights:** (If applicable)
- [ ] **Age Rating:** Complete the questionnaire (likely 4+)

#### Pricing and Availability:
- [ ] Set your price (Free or Paid)
- [ ] Select countries/regions (usually "All countries or regions")

#### App Privacy Tab:
- [ ] **Privacy Policy URL:** https://rajchanchal.github.io/LinkShelf/
- [ ] **Privacy Practices:** Answer questions about data collection
  - Since LinkShelf stores data locally only, most answers will be "No"
  - No data collection
  - No tracking
  - No third-party sharing

### Step 5: Prepare App Store Listing (30-45 minutes)

#### Version Information:

**Screenshots:**
- [ ] Upload screenshots from: `~/Desktop/LinkShelf_AppStore_Screenshots/`
- [ ] Upload at least one set (all 4 resolutions for one screenshot)
- [ ] Recommended: Upload all 3 screenshots (12 files total)
- [ ] App Store Connect will organize them by resolution

**App Preview:** (Optional)
- [ ] Can add a short video preview later

**Description:**
```
LinkShelf is a minimal macOS menu bar app that helps you store and quickly access your frequently used links.

KEY FEATURES:
• One-click copy - Copy any link to clipboard instantly
• Quick access - Access links from your menu bar
• Visual feedback - See confirmation when links are copied
• Open in browser - Launch links directly in your default browser
• Full management - Add, edit, delete, and reorder links
• Local storage - All data stored securely on your Mac
• Native macOS UI - Beautiful, minimal interface
• Fast & lightweight - No bloat, just works

PERFECT FOR:
• Developers sharing GitHub, LinkedIn, Portfolio links
• Professionals with frequently accessed resources
• Anyone who wants quick access to important links

PRIVACY FIRST:
• All data stored locally on your device
• No tracking or analytics
• No data sent to external servers
• Your links remain private

Get started in seconds - just click the menu bar icon and add your links!
```

**Keywords:** (100 characters max)
```
link,bookmark,menu bar,clipboard,quick access,productivity,utility,links,url
```

**Support URL:**
```
https://github.com/RajChanchal/LinkShelf/blob/main/README_SUPPORT.md
```

**Marketing URL:** (Optional)
```
https://github.com/RajChanchal/LinkShelf
```

**Promotional Text:** (Optional, 170 characters)
```
Quick access to your frequently used links. Store, copy, and open links with one click from your menu bar.
```

**What's New in This Version:**
```
Initial release of LinkShelf - a minimal menu bar app for storing and quickly accessing your frequently used links.
```

### Step 6: Build and Archive Your App (15-20 minutes)

1. **Open Xcode:**
   ```bash
   open LinkShelf.xcodeproj
   ```

2. **Configure for Release:**
   - Select **Product** → **Scheme** → **Edit Scheme**
   - Select **Archive** in left sidebar
   - Set **Build Configuration** to **Release**
   - Click **Close**

3. **Set Version and Build Number:**
   - Select project in navigator
   - Select **LinkShelf** target
   - Go to **General** tab
   - **Version:** 1.0
   - **Build:** 1 (or increment for each submission)

4. **Archive:**
   - Select **Any Mac** as destination (top toolbar)
   - Go to **Product** → **Archive**
   - Wait for build to complete

5. **Upload to App Store Connect:**
   - In Organizer window, select your archive
   - Click **Distribute App**
   - Select **App Store Connect**
   - Click **Next**
   - Select **Upload**
   - Click **Next**
   - Select your distribution options
   - Click **Upload**
   - Wait for upload to complete (may take 10-20 minutes)

### Step 7: Select Build in App Store Connect (5 minutes)

1. **Go back to App Store Connect**
2. **Navigate to your app** → **TestFlight** or **App Store** tab
3. **Wait for processing** (can take 30 minutes to several hours)
4. **Select your build** in the version information
5. **Complete any remaining metadata**

### Step 8: Submit for Review (5 minutes)

1. **Review all information** one more time
2. **Click "Submit for Review"**
3. **Answer export compliance questions:**
   - Usually "No" for encryption questions (unless you use custom encryption)
4. **Submit**

### Step 9: Wait for Review

- **Typical review time:** 24-48 hours
- **You'll receive email notifications** about status changes
- **Check App Store Connect** for updates

## 📝 Important URLs to Save

- **Privacy Policy:** https://rajchanchal.github.io/LinkShelf/
- **Support:** https://github.com/RajChanchal/LinkShelf/blob/main/README_SUPPORT.md
- **Repository:** https://github.com/RajChanchal/LinkShelf
- **App Store Connect:** https://appstoreconnect.apple.com

## ⚠️ Common Issues & Solutions

### Build Upload Fails
- Check code signing certificates
- Ensure "Automatically manage signing" is enabled
- Verify your Apple Developer account is active

### Screenshots Rejected
- Ensure exact dimensions (1280x800, 1440x900, etc.)
- No UI elements cut off
- Clear and readable text

### Privacy Policy Not Found
- Wait a few more minutes for GitHub Pages
- Check URL is correct
- Verify index.html is in root directory

### App Rejected
- Read rejection reason carefully
- Address specific issues mentioned
- Resubmit with fixes

## 🎯 Current Priority

**Right now, focus on:**
1. ✅ Verify GitHub Pages is working
2. ⏭️ Create/finalize your app icon (1024x1024)
3. ⏭️ Create app in App Store Connect
4. ⏭️ Build and archive your app

## 📞 Need Help?

- Check the support README: https://github.com/RajChanchal/LinkShelf/blob/main/README_SUPPORT.md
- GitHub Issues: https://github.com/RajChanchal/LinkShelf/issues

---

**Good luck with your submission! 🚀**

