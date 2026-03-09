import os
import struct
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


def render_background(width, height):
    pixels = bytearray(width * height * 4)
    top = (17, 24, 39, 255)
    mid = (30, 41, 59, 255)
    bot = (15, 23, 42, 255)
    for y in range(height):
        t = y / max(1, height - 1)
        if t < 0.6:
            k = t / 0.6
            r = int(top[0] + (mid[0] - top[0]) * k)
            g = int(top[1] + (mid[1] - top[1]) * k)
            b = int(top[2] + (mid[2] - top[2]) * k)
        else:
            k = (t - 0.6) / 0.4
            r = int(mid[0] + (bot[0] - mid[0]) * k)
            g = int(mid[1] + (bot[1] - mid[1]) * k)
            b = int(mid[2] + (bot[2] - mid[2]) * k)
        for x in range(width):
            idx = (y * width + x) * 4
            pixels[idx:idx + 4] = bytes((r, g, b, 255))

    def put(x, y, rgba):
        if 0 <= x < width and 0 <= y < height:
            idx = (y * width + x) * 4
            pixels[idx:idx + 4] = rgba

    for y in range(0, height, 18):
        for x in range(0, width, 18):
            put(x, y, bytes((51, 65, 85, 255)))

    return pixels


def main():
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    out_path = os.path.join(root, "Resources", "dmg-background.png")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    width = 600
    height = 380
    pixels = render_background(width, height)
    write_png(out_path, width, height, pixels)


if __name__ == "__main__":
    main()
