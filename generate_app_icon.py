#!/usr/bin/env python3

"""
App Icon Generator for LinkShelf
Creates a 1024x1024 App Store icon from a source image
"""

import sys
import os
from PIL import Image, ImageDraw, ImageFont

def create_app_icon(source_image_path=None, output_path=None):
    """
    Create a 1024x1024 App Store icon
    
    If source_image is provided, it will be centered and scaled.
    Otherwise, creates a simple icon with SF Symbol-style link icon.
    """
    
    if output_path is None:
        output_path = os.path.expanduser("~/Desktop/LinkShelf_AppIcon_1024x1024.png")
    
    # Create 1024x1024 canvas
    size = 1024
    icon = Image.new('RGB', (size, size), color=(28, 28, 30))  # Dark gray background
    
    if source_image_path and os.path.exists(source_image_path):
        # Use provided source image
        try:
            source = Image.open(source_image_path)
            source.thumbnail((size - 200, size - 200), Image.Resampling.LANCZOS)
            
            # Center the source image
            x = (size - source.width) // 2
            y = (size - source.height) // 2
            
            if source.mode == 'RGBA':
                icon.paste(source, (x, y), source)
            else:
                icon.paste(source, (x, y))
            
            print(f"✅ Created icon from: {source_image_path}")
        except Exception as e:
            print(f"⚠️  Could not use source image: {e}")
            print("   Creating default icon instead...")
            create_default_icon(icon)
    else:
        # Create default icon with link symbol
        create_default_icon(icon)
    
    # Save
    icon.save(output_path, "PNG", optimize=True)
    print(f"✅ App icon saved to: {output_path}")
    print(f"📐 Size: 1024x1024px")
    print(f"📤 Ready to upload to App Store Connect!")
    
    return output_path

def create_default_icon(icon):
    """Create a simple default icon with link symbol"""
    draw = ImageDraw.Draw(icon)
    size = icon.width
    
    # Draw a simple link icon (two overlapping circles)
    # This is a placeholder - you should replace with your actual design
    center_x, center_y = size // 2, size // 2
    radius = size // 3
    
    # Draw two overlapping circles to represent a link
    # Left circle
    draw.ellipse(
        [center_x - radius - 50, center_y - radius//2, 
         center_x - 50, center_y + radius//2],
        outline=(100, 150, 255),  # Blue color
        width=30
    )
    
    # Right circle
    draw.ellipse(
        [center_x + 50, center_y - radius//2,
         center_x + radius + 50, center_y + radius//2],
        outline=(100, 150, 255),
        width=30
    )
    
    print("ℹ️  Created default icon (you should replace with your custom design)")

if __name__ == "__main__":
    source_image = None
    if len(sys.argv) > 1:
        source_image = sys.argv[1]
    
    output = None
    if len(sys.argv) > 2:
        output = sys.argv[2]
    
    create_app_icon(source_image, output)

