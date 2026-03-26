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
      renderer: "canvaskit",
    };
  </script>
"""
        content = content.replace('<head>', '<head>' + config_script)
    else:
        # Force canvaskit for icons
        content = content.replace('renderer: "auto"', 'renderer: "canvaskit"')

    # Ensure the base href is correct
    if '<base href="$FLUTTER_BASE_HREF">' in content:
        content = content.replace('<base href="$FLUTTER_BASE_HREF">', '<base href="/">')

    # Unique build identifier for cache busting confirmation
    build_id = f"Build-Time: {os.popen('date').read().strip()}"
    build_tag = f'<script>console.log("Aliolo Web Build - {build_id}");</script>'
    if 'Aliolo Web Build' not in content:
        content = content.replace('</head>', build_tag + '</head>')
    else:
        # Update existing tag if present
        import re
        content = re.sub(r'<script>console\.log\("Aliolo Web Build - .*?"\);</script>', build_tag, content)

    # REMOVE any previous manual font injections that might be broken
    import re
    content = re.sub(r'\n  <link rel="preload" href="assets/fonts/MaterialIcons-Regular\.otf".*?</style>', '', content, flags=re.DOTALL)

    with open(index_path, 'w') as f:
        f.write(content)
    print("Web build fixed with canvaskit renderer and cleaned up fonts.")

if __name__ == "__main__":
    fix_web_index()
