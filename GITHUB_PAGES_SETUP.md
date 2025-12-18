# Setting Up GitHub Pages for Privacy Policy

## Quick Setup (5 minutes)

### Option 1: Use the HTML file directly (Easiest)

1. **Commit and push the files:**
   ```bash
   git add PRIVACY_POLICY.md index.html
   git commit -m "Add privacy policy for App Store"
   git push origin main
   ```

2. **Enable GitHub Pages:**
   - Go to your repository: https://github.com/RajChanchal/LinkShelf
   - Click **Settings** (top menu)
   - Scroll down to **Pages** (left sidebar)
   - Under **Source**, select **Deploy from a branch**
   - Select branch: **main**
   - Select folder: **/ (root)**
   - Click **Save**

3. **Your Privacy Policy URL will be:**
   ```
   https://rajchanchal.github.io/LinkShelf/
   ```
   (It may take a few minutes to become active)

### Option 2: Use Markdown file (Alternative)

If you prefer to use the markdown file directly:

**Privacy Policy URL:**
```
https://github.com/RajChanchal/LinkShelf/blob/main/PRIVACY_POLICY.md
```

This works immediately without any setup, but the formatting will be GitHub's default markdown rendering.

## Recommended: Use GitHub Pages (Option 1)

GitHub Pages provides a professional, standalone webpage that's perfect for App Store requirements. The HTML version (`index.html`) is already styled and ready to use.

## For App Store Connect

Once GitHub Pages is set up, use this URL in App Store Connect:

```
https://rajchanchal.github.io/LinkShelf/
```

Or if using the markdown file directly:

```
https://github.com/RajChanchal/LinkShelf/blob/main/PRIVACY_POLICY.md
```

## Verification

After enabling GitHub Pages, wait 2-5 minutes, then visit:
- https://rajchanchal.github.io/LinkShelf/

You should see your privacy policy page.

## Troubleshooting

- **Page not loading?** Wait a few minutes for GitHub to build the page
- **404 error?** Make sure `index.html` is in the root directory
- **Wrong content?** Clear your browser cache and try again

