#!/usr/bin/env python3

"""
LinkShelf Screenshot Resizer (Padded Version)
Adds padding to fit 16:10 aspect ratio instead of cropping
Better for preserving all UI elements
"""

import sys
import os
from PIL import Image, ImageDraw

def resize_screenshot_padded(input_file, background_color=(28, 28, 30)):
    """
    Resize a screenshot to App Store dimensions by adding padding
    instead of cropping, preserving all UI elements
    """
    
    # Create output directory
    output_dir = os.path.expanduser("~/Desktop/LinkShelf_AppStore_Screenshots")
    os.makedirs(output_dir, exist_ok=True)
    
    print(f"📁 Output directory: {output_dir}\n")
    
    # Open and get original image
    try:
        img = Image.open(input_file)
        orig_width, orig_height = img.size
        print(f"📐 Original dimensions: {orig_width}x{orig_height}\n")
    except Exception as e:
        print(f"❌ Error opening image: {e}")
        return False
    
    # Target aspect ratio: 16:10 = 1.6
    target_aspect = 16 / 10
    
    # Get base filename
    basename = os.path.splitext(os.path.basename(input_file))[0]
    basename = basename.replace('.png', '').replace('.PNG', '')
    
    # Target dimensions
    targets = [
        (1280, 800, "1280x800"),
        (1440, 900, "1440x900"),
        (2560, 1600, "2560x1600"),
        (2880, 1800, "2880x1800")
    ]
    
    print("🔄 Resizing with padding to App Store dimensions...\n")
    
    success_count = 0
    for target_width, target_height, name in targets:
        try:
            # Calculate scale to fit within target dimensions while maintaining aspect
            scale_w = target_width / orig_width
            scale_h = target_height / orig_height
            scale = min(scale_w, scale_h)  # Use smaller scale to fit both dimensions
            
            # Calculate new dimensions after scaling
            new_width = int(orig_width * scale)
            new_height = int(orig_height * scale)
            
            # Resize the image
            resized_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
            
            # Create new image with target dimensions and background color
            final_img = Image.new('RGB', (target_width, target_height), background_color)
            
            # Calculate position to center the resized image
            paste_x = (target_width - new_width) // 2
            paste_y = (target_height - new_height) // 2
            
            # Paste the resized image onto the background
            # Convert to RGBA if needed for transparency
            if resized_img.mode == 'RGBA':
                final_img.paste(resized_img, (paste_x, paste_y), resized_img)
            else:
                final_img.paste(resized_img, (paste_x, paste_y))
            
            output_path = os.path.join(output_dir, f"{basename}_{name}.png")
            final_img.save(output_path, "PNG", optimize=True)
            print(f"  ✅ {basename}_{name}.png (scaled {scale:.2f}x, centered)")
            success_count += 1
        except Exception as e:
            print(f"  ❌ Failed to create {name}: {e}")
    
    print(f"\n✨ Done! Created {success_count}/{len(targets)} screenshots")
    print(f"📁 All files saved to: {output_dir}\n")
    print("📤 Ready to upload to App Store Connect!")
    print("\n💡 Tip: Screenshots now have padding to preserve all UI elements")
    
    return success_count == len(targets)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 resize_screenshots_padded.py <input_image.png>")
        print("\nExample: python3 resize_screenshots_padded.py ~/Desktop/LinkShelf1.png")
        sys.exit(1)
    
    input_file = sys.argv[1]
    
    if not os.path.exists(input_file):
        print(f"❌ Error: File not found: {input_file}")
        sys.exit(1)
    
    success = resize_screenshot_padded(input_file)
    sys.exit(0 if success else 1)

