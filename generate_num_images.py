from PIL import Image, ImageDraw, ImageFont
import os

FONTS = {
    'ar': '/usr/share/fonts/chromeos/noto/NotoNaskhArabic-Regular.ttf',
    'hi': '/usr/share/fonts/chromeos/noto/NotoSansDevanagari-Regular.ttf',
    'zh': '/usr/share/fonts/chromeos/notocjk/NotoSerifCJK-Bold.ttc',
    'ja': '/usr/share/fonts/chromeos/notocjk/NotoSerifCJK-Bold.ttc',
    'ko': '/usr/share/fonts/chromeos/notocjk/NotoSerifCJK-Bold.ttc'
}

NUM_DATA = {
    'ar': ['١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩', '١٠', '١١', '١٢', '١٣', '١٤', '١٥', '١٦', '١٧', '١٨', '١٩', '٢٠'],
    'hi': ['१', '२', '३', '४', '५', '६', '७', '८', '९', '१०', '११', '१२', '१३', '१४', '१५', '१६', '१७', '१८', '१९', '२०'],
    'zh': ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十'],
    'ja': ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十'],
    'ko': ['일', '이', '삼', '사', '오', '육', '칠', '팔', '구', '십', '십일', '십이', '십삼', '십사', '십오', '십육', '십칠', '십팔', '십구', '이십']
}

os.makedirs('temp_nums', exist_ok=True)

def generate_images():
    for lang, nums in NUM_DATA.items():
        font_path = FONTS[lang]
        for i, text in enumerate(nums):
            num_val = i + 1
            img = Image.new('RGB', (512, 512), color='white')
            draw = ImageDraw.Draw(img)
            
            # Try to load font
            try:
                font = ImageFont.truetype(font_path, 250)
            except Exception as e:
                print(f"Error loading font {font_path}: {e}")
                continue
                
            # Center text
            # Use textbbox if available (Pillow 8+)
            try:
                bbox = draw.textbbox((0, 0), text, font=font)
                w = bbox[2] - bbox[0]
                h = bbox[3] - bbox[1]
            except AttributeError:
                # Fallback for older Pillow
                w, h = draw.textsize(text, font=font)
                
            draw.text(((512-w)/2, (512-h)/2 - 40), text, fill='black', font=font)
            
            filename = f"temp_nums/num_{lang}_{num_val}.png"
            img.save(filename)
            print(f"Generated {filename}")

if __name__ == "__main__":
    generate_images()
