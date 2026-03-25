import os

def fix_web_index():
    index_path = 'build/web/index.html'
    if not os.path.exists(index_path):
        print(f"Error: {index_path} not found.")
        return

    with open(index_path, 'r') as f:
        content = f.read()

    # Configuration script for Flutter
    if 'window.flutterConfiguration' not in content:
        config_script = """
  <script>
    window.flutterConfiguration = {
      renderer: "auto",
    };
  </script>
"""
        content = content.replace('<head>', '<head>' + config_script)

    # Font preload and style for Material Icons
    font_preload = '\n  <link rel="preload" href="assets/fonts/MaterialIcons-Regular.otf" as="font" type="font/otf" crossorigin>'
    font_style = """
  <style>
    @font-face {
      font-family: 'MaterialIcons';
      font-style: normal;
      font-weight: 400;
      src: url(assets/fonts/MaterialIcons-Regular.otf);
    }
  </style>
"""
    
    if 'MaterialIcons-Regular.otf' not in content:
        content = content.replace('</head>', font_preload + font_style + '</head>')

    # Ensure the base href is correct
    if '<base href="$FLUTTER_BASE_HREF">' in content:
        content = content.replace('<base href="$FLUTTER_BASE_HREF">', '<base href="/">')

    with open(index_path, 'w') as f:
        f.write(content)
    print("Web build fixed with font preloading and auto renderer.")

if __name__ == "__main__":
    fix_web_index()
