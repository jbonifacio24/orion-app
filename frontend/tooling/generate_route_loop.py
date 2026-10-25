from math import sin
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


WIDTH = 480
HEIGHT = 100
FRAME_COUNT = 48
DURATION_MS = 63
ROAD = [
    (-30, 74),
    (28, 73),
    (70, 63),
    (110, 66),
    (150, 44),
    (192, 41),
    (226, 49),
    (263, 65),
    (300, 68),
    (338, 49),
    (380, 41),
    (425, 47),
    (510, 58),
]


def road_y(x):
    for index in range(len(ROAD) - 1):
        start_x, start_y = ROAD[index]
        end_x, end_y = ROAD[index + 1]
        if x <= end_x:
            progress = (x - start_x) / (end_x - start_x)
            return start_y + (end_y - start_y) * progress
    return ROAD[-1][1]


def make_frame(frame_index):
    image = Image.new("RGB", (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(image)

    for y in range(HEIGHT):
        progress = y / (HEIGHT - 1)
        color = (
            int(34 - 14 * progress),
            int(43 - 17 * progress),
            int(45 - 17 * progress),
        )
        draw.line((0, y, WIDTH, y), fill=color)

    draw.polygon(
        [
            (0, 55), (40, 34), (82, 48), (124, 25), (174, 51),
            (220, 34), (270, 52), (321, 27), (366, 48), (420, 29),
            (480, 51), (480, HEIGHT), (0, HEIGHT),
        ],
        fill=(31, 40, 42),
    )

    for contour in range(5):
        points = []
        base_y = 18 + contour * 10
        for x in range(-8, WIDTH + 12, 8):
            y = base_y + 5 * sin((x / 42) + contour * 0.8)
            points.append((x, y))
        draw.line(points, fill=(48, 61, 64), width=1)

    draw.line(ROAD, fill=(80, 97, 106), width=19, joint="curve")
    draw.line(ROAD, fill=(36, 45, 47), width=15, joint="curve")

    phase = (frame_index * 12) % 34
    for start_x in range(-40 + phase, WIDTH + 30, 34):
        end_x = min(start_x + 11, WIDTH + 20)
        draw.line(
            (start_x, road_y(start_x), end_x, road_y(end_x)),
            fill=(154, 106, 36),
            width=2,
        )

    start_marker = (63, int(road_y(63) - 13))
    end_marker = (420, int(road_y(420) - 13))
    for x, y, color in (
        (*start_marker, (226, 184, 102)),
        (*end_marker, (255, 128, 109)),
    ):
        draw.ellipse((x - 5, y - 5, x + 5, y + 5), outline=color, width=2)
        draw.ellipse((x - 1, y - 1, x + 1, y + 1), fill=color)

    progress = frame_index / (FRAME_COUNT - 1)
    bike_x = -25 + progress * (WIDTH + 50)
    bike_y = road_y(bike_x)
    rear_wheel = (int(bike_x - 8), int(bike_y - 3))
    front_wheel = (int(bike_x + 9), int(bike_y - 3))

    for x, y in (rear_wheel, front_wheel):
        draw.ellipse((x - 4, y - 4, x + 4, y + 4), fill=(24, 30, 32))
        draw.ellipse((x - 3, y - 3, x + 3, y + 3), outline=(243, 242, 237), width=1)

    draw.line(
        [
            rear_wheel,
            (int(bike_x - 1), int(bike_y - 9)),
            (int(bike_x + 5), int(bike_y - 3)),
            front_wheel,
            (int(bike_x - 1), int(bike_y - 9)),
        ],
        fill=(255, 128, 109),
        width=2,
        joint="curve",
    )
    draw.line(
        (int(bike_x - 2), int(bike_y - 9), int(bike_x + 2), int(bike_y - 16)),
        fill=(243, 242, 237),
        width=3,
    )
    draw.ellipse(
        (int(bike_x), int(bike_y - 21), int(bike_x + 6), int(bike_y - 15)),
        fill=(255, 128, 109),
    )
    draw.ellipse(
        (int(bike_x + 10), int(bike_y - 9), int(bike_x + 14), int(bike_y - 5)),
        fill=(226, 184, 102),
    )

    font_path = Path("C:/Windows/Fonts/seguisb.ttf")
    font = ImageFont.truetype(str(font_path), 8) if font_path.exists() else ImageFont.load_default()
    draw.rounded_rectangle((14, 12, 122, 30), radius=8, fill=(25, 32, 34))
    draw.rectangle((22, 19, 27, 23), fill=(255, 128, 109))
    draw.text((33, 15), "RUTA COMPARTIDA", fill=(243, 242, 237), font=font)

    return image


def main():
    frames = [make_frame(index) for index in range(FRAME_COUNT)]
    palette_sheet = Image.new("RGB", (WIDTH, HEIGHT * FRAME_COUNT))
    for index, frame in enumerate(frames):
        palette_sheet.paste(frame, (0, index * HEIGHT))

    palette = palette_sheet.quantize(colors=96, method=Image.Quantize.MEDIANCUT)
    palette_image = Image.new("P", (1, 1))
    palette_image.putpalette(palette.getpalette())
    indexed_frames = [
        frame.quantize(palette=palette_image, dither=Image.Dither.NONE)
        for frame in frames
    ]

    output = Path(__file__).resolve().parents[1] / "assets" / "videos" / "motohub_route_loop.gif"
    indexed_frames[0].save(
        output,
        save_all=True,
        append_images=indexed_frames[1:],
        duration=DURATION_MS,
        loop=0,
        optimize=True,
        disposal=2,
    )
    print(f"Created {output} ({FRAME_COUNT} frames, {WIDTH}x{HEIGHT}, {output.stat().st_size / 1024:.1f} KB)")


if __name__ == "__main__":
    main()