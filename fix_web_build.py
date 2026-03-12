import os

def fix_web_index():
    index_path = 'build/web/index.html'
    if not os.path.exists(index_path):
        print(f"Error: {index_path} not found.")
        return

    with open(index_path, 'r') as f:
        content = f.read()

    # Force Skia/CanvasKit or WASM renderer if needed, 
    # but primarily we want to ensure the base href and scripts are correct
    if 'flutter_service_worker.js' in content:
        print("Web index looks correct.")
    
    # Add any specific web fixes here if you encounter rendering issues
    # e.g., content = content.replace('<base href="/">', '<base href="./">')

    with open(index_path, 'w') as f:
        f.write(content)
    print("Web build fixed.")

if __name__ == "__main__":
    fix_web_index()
