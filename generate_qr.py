import qrcode
from PIL import Image, ImageDraw, ImageFont

# The secret code that the QR will contain
QR_SECRET = "IDM_GATE_ENTRY_2026"

# Create QR code
qr = qrcode.QRCode(
    version=1,
    error_correction=qrcode.constants.ERROR_CORRECT_H,
    box_size=10,
    border=4,
)
qr.add_data(QR_SECRET)
qr.make(fit=True)

# Create image
img = qr.make_image(fill_color="black", back_color="white")

# Make it bigger for printing
img = img.resize((800, 800), Image.Resampling.NEAREST)

# Add text below QR code
final_img = Image.new('RGB', (800, 900), 'white')
final_img.paste(img, (0, 0))

# Add text
draw = ImageDraw.Draw(final_img)
try:
    font = ImageFont.truetype("arial.ttf", 40)
except:
    font = ImageFont.load_default()

text = "GATE ENTRANCE\nScan to Verify"
bbox = draw.textbbox((0, 0), text, font=font)
text_width = bbox[2] - bbox[0]
text_height = bbox[3] - bbox[1]
draw.text(((800 - text_width) / 2, 820), text, fill='black', font=font, align='center')

# Save
final_img.save('gate_qr_code.png')
print("✅ QR Code created: gate_qr_code.png")
print(f"QR Code contains: {QR_SECRET}")
print("\nPrint this and place it at the gate entrance!")