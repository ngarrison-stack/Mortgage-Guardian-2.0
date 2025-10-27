import os

# Create a simple SVG that we can convert to PNG
svg_content = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" xmlns="http://www.w3.org/2000/svg">
  <rect width="1024" height="1024" fill="#007AFF" rx="180"/>
  <text x="512" y="600" font-family="Arial, sans-serif" font-size="400" font-weight="bold" 
        text-anchor="middle" fill="white">MG</text>
</svg>'''

with open('base_icon.svg', 'w') as f:
    f.write(svg_content)
    
print("Created base_icon.svg")
