import os
import struct
import subprocess
import zlib


def write_png(path, width, height, rgba):
    def chunk(tag, data):
        return struct.pack("!I", len(data)) + tag + data + struct.pack("!I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(rgba[y * stride:(y + 1) * stride])
    compressed = zlib.compress(bytes(raw), 9)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack("!IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", compressed)
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def draw_rounded_rect(pixels, width, height, x0, y0, x1, y1, radius, color):
    r2 = radius * radius
    for y in range(y0, y1):
        row_index = y * width
        for x in range(x0, x1):
            dx = 0
            dy = 0
            if x < x0 + radius:
                dx = x0 + radius - x
            elif x >= x1 - radius:
                dx = x - (x1 - radius - 1)
            if y < y0 + radius:
                dy = y0 + radius - y
            elif y >= y1 - radius:
                dy = y - (y1 - radius - 1)
            if dx == 0 or dy == 0 or dx * dx + dy * dy <= r2:
                idx = (row_index + x) * 4
                pixels[idx:idx + 4] = color


def draw_rect(pixels, width, x0, y0, x1, y1, color):
    row = color * (x1 - x0)
    for y in range(y0, y1):
        idx = (y * width + x0) * 4
        pixels[idx:idx + (x1 - x0) * 4] = row


def draw_circle(pixels, width, x0, y0, radius, color):
    r2 = radius * radius
    for y in range(-radius, radius + 1):
        yy = y0 + y
        if yy < 0:
            continue
        for x in range(-radius, radius + 1):
            xx = x0 + x
            if xx < 0:
                continue
            if x * x + y * y <= r2:
                idx = (yy * width + xx) * 4
                pixels[idx:idx + 4] = color


def render_icon(size):
    width = size
    height = size
    pixels = bytearray(width * height * 4)
    top = (46, 125, 255, 255)
    bottom = (106, 27, 154, 255)
    for y in range(height):
        for x in range(width):
            t = (x + y) / (width + height - 2)
            r = int(top[0] + (bottom[0] - top[0]) * t)
            g = int(top[1] + (bottom[1] - top[1]) * t)
            b = int(top[2] + (bottom[2] - top[2]) * t)
            idx = (y * width + x) * 4
            pixels[idx:idx + 4] = bytes((r, g, b, 255))

    kb_x0 = int(width * 0.16)
    kb_x1 = int(width * 0.84)
    kb_y0 = int(height * 0.48)
    kb_y1 = int(height * 0.80)
    draw_rounded_rect(pixels, width, height, kb_x0, kb_y0, kb_x1, kb_y1, int(width * 0.06), bytes((31, 41, 55, 255)))

    row_gap = int(width * 0.02)
    key_gap = int(width * 0.015)
    key_w = int((kb_x1 - kb_x0 - key_gap * 6) / 7)
    key_h = int((kb_y1 - kb_y0 - row_gap * 4) / 3)
    for row in range(3):
        y0 = kb_y0 + row_gap + row * (key_h + row_gap)
        y1 = y0 + key_h
        for col in range(7):
            x0 = kb_x0 + key_gap + col * (key_w + key_gap)
            x1 = x0 + key_w
            draw_rounded_rect(pixels, width, height, x0, y0, x1, y1, int(width * 0.01), bytes((248, 250, 252, 255)))

    space_y0 = kb_y0 + row_gap + 2 * (key_h + row_gap) + int(key_h * 0.15)
    space_y1 = space_y0 + int(key_h * 0.7)
    space_x0 = kb_x0 + int((kb_x1 - kb_x0) * 0.2)
    space_x1 = kb_x1 - int((kb_x1 - kb_x0) * 0.2)
    draw_rounded_rect(pixels, width, height, space_x0, space_y0, space_x1, space_y1, int(width * 0.012), bytes((226, 232, 240, 255)))

    badge_x0 = int(width * 0.58)
    badge_x1 = int(width * 0.86)
    badge_y0 = int(height * 0.24)
    badge_y1 = int(height * 0.38)
    draw_rounded_rect(pixels, width, height, badge_x0, badge_y0, badge_x1, badge_y1, int(width * 0.08), bytes((226, 232, 240, 255)))
    mid = (badge_x0 + badge_x1) // 2
    draw_rect(pixels, width, badge_x0, badge_y0, mid, badge_y1, bytes((255, 255, 255, 255)))
    draw_circle(pixels, width, badge_x0 + int(width * 0.06), badge_y0 + int(height * 0.07), int(width * 0.02), bytes((59, 130, 246, 255)))
    draw_circle(pixels, width, mid + int(width * 0.06), badge_y0 + int(height * 0.07), int(width * 0.02), bytes((148, 163, 184, 255)))

    return pixels


def iconset_entries():
    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]
    return sizes


def main():
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    resources = os.path.join(root, "Resources")
    iconset = os.path.join(resources, "AppIcon.iconset")
    os.makedirs(iconset, exist_ok=True)
    for size, name in iconset_entries():
        path = os.path.join(iconset, name)
        pixels = render_icon(size)
        write_png(path, size, size, pixels)
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", os.path.join(resources, "AppIcon.icns")], check=True)


if __name__ == "__main__":
    main()
