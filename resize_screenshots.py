#!/usr/bin/env python3

"""
LinkShelf Screenshot Resizer (Fixed - maintains aspect ratio)
Crops to 16:10 aspect ratio first, then resizes to App Store dimensions
"""

import sys
import os
from PIL import Image

def resize_screenshot(input_file):
    """Resize a screenshot to all App Store required dimensions"""
    
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
    
    # Calculate crop dimensions
    current_aspect = orig_width / orig_height
    
    if current_aspect > target_aspect:
        # Image is wider than 16:10, crop width (center crop)
        crop_height = orig_height
        crop_width = int(crop_height * target_aspect)
        crop_x = (orig_width - crop_width) // 2
        crop_y = 0
    else:
        # Image is taller than 16:10, crop height (center crop)
        crop_width = orig_width
        crop_height = int(crop_width / target_aspect)
        crop_x = 0
        crop_y = (orig_height - crop_height) // 2
    
    print(f"✂️  Cropping to 16:10 aspect ratio...")
    print(f"   Crop area: {crop_width}x{crop_height} at position ({crop_x}, {crop_y})\n")
    
    # Crop the image
    cropped_img = img.crop((crop_x, crop_y, crop_x + crop_width, crop_y + crop_height))
    
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
    
    print("🔄 Resizing to App Store dimensions...\n")
    
    success_count = 0
    for width, height, name in targets:
        try:
            resized = cropped_img.resize((width, height), Image.Resampling.LANCZOS)
            output_path = os.path.join(output_dir, f"{basename}_{name}.png")
            resized.save(output_path, "PNG", optimize=True)
            print(f"  ✅ {basename}_{name}.png")
            success_count += 1
        except Exception as e:
            print(f"  ❌ Failed to create {name}: {e}")
    
    print(f"\n✨ Done! Created {success_count}/{len(targets)} screenshots")
    print(f"📁 All files saved to: {output_dir}\n")
    print("📤 Ready to upload to App Store Connect!")
    
    return success_count == len(targets)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 resize_screenshots.py <input_image.png>")
        print("\nExample: python3 resize_screenshots.py ~/Desktop/LinkShelf1.png")
        sys.exit(1)
    
    input_file = sys.argv[1]
    
    if not os.path.exists(input_file):
        print(f"❌ Error: File not found: {input_file}")
        sys.exit(1)
    
    success = resize_screenshot(input_file)
    sys.exit(0 if success else 1)

