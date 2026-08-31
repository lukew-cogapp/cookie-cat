#!/usr/bin/env python3
"""Draws every sprite in the game from the pixel grids below.

The art is generated rather than downloaded because the game needs one
coherent look across a cat, eight weapon effects, six bugs and the pickups,
and no CC0 pack covers that set: the closest (Clint Bellanger's Tiny
Creatures) is a fantasy bestiary of orcs and dragons, so a garden of bugs
would have been a collage.

Each sprite is a list of strings, one character per pixel, keyed into PALETTE.
'.' is transparent. Sixteen by sixteen, drawn at 1:1 and scaled by the game,
so the grids stay legible here.

    uv run scripts/tools/make_art.py

Rerun after editing a grid; it overwrites assets/*.png.
"""

import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "assets"

# Cookie Cat: a pink ice-cream cat sandwiched in biscuit. The palette is the
# whole game's, so a new sprite reuses these letters rather than adding a hue.
PALETTE = {
    ".": (0, 0, 0, 0),
    "o": (58, 42, 58, 255),  # outline, warm near-black
    "P": (255, 175, 204, 255),  # cookie-cat pink
    "p": (255, 214, 230, 255),  # pink highlight
    "D": (214, 120, 158, 255),  # pink shadow
    "B": (196, 140, 92, 255),  # biscuit
    "b": (232, 184, 132, 255),  # biscuit light
    "C": (110, 224, 214, 255),  # mint ice cream
    "c": (176, 245, 240, 255),  # mint light
    "W": (255, 255, 255, 255),
    "K": (44, 36, 48, 255),  # pupils
    "Y": (255, 214, 92, 255),  # star / coin gold
    "y": (255, 240, 176, 255),
    "R": (240, 108, 124, 255),  # heart
    "r": (255, 160, 170, 255),
    "G": (124, 200, 108, 255),  # grub green
    "g": (168, 226, 148, 255),
    "V": (150, 124, 208, 255),  # beetle violet
    "v": (192, 174, 236, 255),
    "O": (240, 156, 90, 255),  # snail orange
    "S": (120, 210, 170, 255),  # slime
    "s": (176, 238, 214, 255),
    "Z": (250, 226, 120, 255),  # wasp yellow
    "N": (86, 74, 96, 255),  # wasp stripes
    "M": (188, 176, 200, 255),  # toy mouse grey
    "L": (140, 200, 246, 255),  # water / milk blue
    "l": (214, 240, 255, 255),
    "T": (126, 186, 108, 255),  # lawn
    "t": (134, 194, 116, 255),  # lawn, a shade lighter
    "d": (116, 176, 100, 255),  # lawn, a shade darker
}

# The cat, facing right, three frames: stand, step, step-other. Chunky enough
# that a five-year-old reads the face across a room.
CAT_STAND = [
    "................",
    "....oooo....oo..",
    "...oPPPPoooPPo..",
    "..oPpPPPPPPPPo..",
    "..oPPoPPPPoPPo..",
    "..oPWKPPPPWKPo..",
    "..oPPPPDDPPPPo..",
    "..oPPPoPPoPPPo..",
    "...oPPPPPPPPo...",
    "..oobbbbbbbboo..",
    ".oBbCCcCCcCCbBo.",
    ".oBbCCCCCCCCbBo.",
    ".oobbbbbbbbboo..",
    "...oPo....oPo...",
    "...ooo....ooo...",
    "................",
]
CAT_STEP_A = [
    "................",
    "....oooo....oo..",
    "...oPPPPoooPPo..",
    "..oPpPPPPPPPPo..",
    "..oPPoPPPPoPPo..",
    "..oPWKPPPPWKPo..",
    "..oPPPPDDPPPPo..",
    "..oPPPoPPoPPPo..",
    "...oPPPPPPPPo...",
    "..oobbbbbbbboo..",
    ".oBbCCcCCcCCbBo.",
    ".oBbCCCCCCCCbBo.",
    ".oobbbbbbbbboo..",
    "..oPo......oPo..",
    "..ooo......ooo..",
    "................",
]
CAT_STEP_B = [
    "................",
    "................",
    "....oooo....oo..",
    "...oPPPPoooPPo..",
    "..oPpPPPPPPPPo..",
    "..oPPoPPPPoPPo..",
    "..oPWKPPPPWKPo..",
    "..oPPPPDDPPPPo..",
    "..oPPPoPPoPPPo..",
    "...oPPPPPPPPo...",
    "..oobbbbbbbboo..",
    ".oBbCCcCCcCCbBo.",
    ".oBbCCCCCCCCbBo.",
    ".oobbbbbbbbboo..",
    "....oPoooPo.....",
    "....ooooooo.....",
]

# Bugs. Each silhouette differs, so a child can tell a fast wasp from a tanky
# snail without reading the colour.
GRUB = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "....ooo.ooo.oo..",
    "...oGGGoGGGoGGo.",
    "..oGgGGoGGGoGGo.",
    ".oGgGGGoGGGoWKo.",
    ".oGGGGGoGGGoGGo.",
    ".oGGGGGoGGGoGGo.",
    "..oGGGGoGGGoGGo.",
    "...ooooooooooo..",
    "..o..o.o..o.....",
    "................",
    "................",
]
BEETLE = [
    "................",
    "................",
    "...o......o.....",
    "....o....o......",
    "...oooooooo.....",
    "..oVVVVVVVVo....",
    ".oVvVVVVVVVVo...",
    ".oVVoVVVVoVVo...",
    ".oVVKVVVVKVVo...",
    ".oVVVVooVVVVo...",
    ".oVVVVVVVVVVo...",
    ".oVVVVVVVVVVo...",
    "..oVVVVVVVVo....",
    "...oooooooo.....",
    "..o..o..o..o....",
    "................",
]
SNAIL = [
    "................",
    "................",
    "..........o..o..",
    "...ooooo..o..o..",
    "..oOOOOOo.o..o..",
    ".oOObbbOOo.oo...",
    ".oObOOObOo.ooo..",
    ".oObOoOObOoWKWo.",
    ".oOObbbOOOoWWWo.",
    ".oOOOOOOOOoWWWo.",
    ".ooOOOOOOooWWWo.",
    "..oWWWWWWWWWWWo.",
    ".oWWWWWWWWWWWWo.",
    ".oWWWWWWWWWWWo..",
    "..ooooooooooo...",
    "................",
]
WASP = [
    "................",
    "...o......o.....",
    "..oCo....oCo....",
    "..oCCo..oCCo....",
    "...oCCooCCo.....",
    "....oooooo......",
    "...oZZZZZZo.....",
    "..oZZoZZoZZo....",
    "..oZZKZZKZZo....",
    "..oNNNNNNNNo....",
    "..oZZZZZZZZo....",
    "..oNNNNNNNNo....",
    "...oZZZZZZo.....",
    "....oooooo......",
    "......oo........",
    "................",
]
SLIME = [
    "................",
    "................",
    "................",
    ".....oooo.......",
    "....osssSo......",
    "...oSsSSSSo.....",
    "..oSSSSSSSSo....",
    "..oSSoSSoSSo....",
    ".oSSSKSSKSSSo...",
    ".oSSSSSSSSSSo...",
    ".oSSSSooSSSSo...",
    ".oSSSSSSSSSSo...",
    ".oSSSSSSSSSSo...",
    "..ooSoSSoSooo...",
    "....ooooooo.....",
    "................",
]
# The boss: the same slime shape scaled up in-engine would read as a big
# slime, so this one gets a crown and a face of its own.
BIG = [
    "....Y....Y......",
    "...YyY..YyY.....",
    "..oYYYYYYYYo....",
    "...oooooooo.....",
    "..oDDDDDDDDo....",
    ".oDDPPPPPPDDo...",
    "oDPPPPPPPPPPDo..",
    "oDPPoPPPPoPPDo..",
    "oDPPKPPPPKPPDo..",
    "oDPPPPPPPPPPDo..",
    "oDPPWWWWWWPPDo..",
    "oDPPPWWWWPPPDo..",
    ".oDPPPPPPPPDo...",
    "..oDDDDDDDDo....",
    "...oooooooo.....",
    "................",
]

# Pickups. A gem is XP, a cookie is the meta currency, a heart heals.
GEM = [
    "................",
    "................",
    "......oo........",
    ".....oLLo.......",
    "....oLllLo......",
    "...oLlLLlLo.....",
    "..oLLLLLLLLo....",
    "...oLLLLLLo.....",
    "....oLLLLo......",
    ".....oLLo.......",
    "......oo........",
    "................",
    "................",
    "................",
    "................",
    "................",
]
HEART = [
    "................",
    "................",
    "..oo......oo....",
    ".oRRo....oRRo...",
    "oRrRRo..oRRRRo..",
    "oRrRRRoORRRRRo..",
    "oRRRRRRRRRRRRo..",
    ".oRRRRRRRRRRo...",
    "..oRRRRRRRRo....",
    "...oRRRRRRo.....",
    "....oRRRRo......",
    ".....oRRo.......",
    "......oo........",
    "................",
    "................",
    "................",
]
# Cookie Cat itself: the ice cream sandwich, and the currency that unlocks
# the other cats.
COOKIE = [
    "................",
    "....oooooo......",
    "..ooBBBBBBoo....",
    ".oBbBBBBBBbBo...",
    ".oBBoBBBBoBBo...",
    ".oBBBBBBBBBBo...",
    ".ooooooooooooo..",
    "oCcCCCCCCCCCCo..",
    "oCCCCCCCCCCCCo..",
    ".ooooooooooooo..",
    ".oBBoBBBBoBBo...",
    ".oBbBBBBBBbBo...",
    "..ooBBBBBBoo....",
    "....oooooo......",
    "................",
    "................",
]

# Weapon effect sprites, drawn rather than shapes, so the toys read as toys.
YARN = [
    "................",
    "................",
    "................",
    "................",
    ".....oooo.......",
    "....oPPPPo......",
    "...oPpPDPPo.....",
    "...oPPDPpPo.....",
    "...oPpPPDPo.....",
    "...oPDPpPPo.....",
    "....oPPPPo......",
    ".....oooo.......",
    "................",
    "................",
    "................",
    "................",
]
MOUSE = [
    "................",
    "................",
    "................",
    "...oo....oo.....",
    "..oMMo..oMMo....",
    "..oMMoooMMo.....",
    "..oMMMMMMMMo....",
    ".oMMoMMMMoMMo...",
    ".oMMKMMMMKMMoooo",
    ".oMMMMMMMMMMoPPP",
    ".oMMMMWWMMMMoooo",
    "..oMMMMMMMMo....",
    "...oooooooo.....",
    "................",
    "................",
    "................",
]
FISH = [
    "................",
    "................",
    "................",
    "................",
    "......oooo..oo..",
    ".....oLllLoLLo..",
    "....oLlLLLLLLo..",
    "...oLWKLLLLLLo..",
    "...oLLLLLLLLLo..",
    "....oLLLLLLLLo..",
    ".....oLLLLoLLo..",
    "......oooo..oo..",
    "................",
    "................",
    "................",
    "................",
]
STAR = [
    "................",
    "................",
    "......oo........",
    "......yy........",
    "...o..YY..o.....",
    "...oy.YY.yo.....",
    "....oYYYYo......",
    "..ooYYYYYYoo....",
    "..oyYYYYYYyo....",
    "....oYYYYo......",
    "...oYY..YYo.....",
    "...oY....Yo.....",
    "....o....o......",
    "................",
    "................",
    "................",
]

# The other cats are the same cat in another flavour: one palette swap each,
# so a new cat is three colours here rather than a new grid to draw and keep in
# step with the first. Keys are the letters CAT_STAND uses for fur and filling.
CAT_FLAVOURS = {
    "cat_mint": {"P": "C", "p": "c", "D": (72, 186, 176, 255), "C": "P", "c": "p"},
    "cat_berry": {
        "P": (196, 122, 208, 255),
        "p": (232, 178, 240, 255),
        "D": (150, 84, 164, 255),
        "C": (255, 200, 120, 255),
        "c": (255, 226, 176, 255),
    },
    "cat_choc": {
        "P": (150, 106, 78, 255),
        "p": (196, 148, 112, 255),
        "D": (108, 72, 52, 255),
        "C": (250, 240, 220, 255),
        "c": (255, 250, 240, 255),
    },
    "cat_lion": {
        "P": (250, 196, 96, 255),
        "p": (255, 226, 158, 255),
        "D": (206, 146, 60, 255),
        "C": (240, 120, 96, 255),
        "c": (255, 172, 148, 255),
    },
}

# Card icons: one per weapon and passive, drawn at the same 16x16 as
# everything else and shown large on the pick screen. A child picks by picture,
# so each has to be readable at a glance and unmistakable for another.
ICON_PAW = [
    "................",
    "................",
    "...oo..oo..oo...",
    "..oPPooPPooPPo..",
    "..oPPooPPooPPo..",
    "...ooooooooo....",
    "..oPPPPPPPPPPo..",
    ".oPpPPPPPPPPPPo.",
    ".oPPPPPPPPPPPPo.",
    ".oPPPPPPPPPPPPo.",
    ".oPPPPPPPPPPPPo.",
    "..oPPPPPPPPPPo..",
    "...oooooooooo...",
    "................",
    "................",
    "................",
]
ICON_PURR = [
    "................",
    "......oooo......",
    "....ooCCCCoo....",
    "...oCCccccCCo...",
    "..oCcCooooCcCo..",
    "..oCCo....oCCo..",
    ".oCcCo.oo.oCcCo.",
    ".oCCo..oo..oCCo.",
    ".oCCo......oCCo.",
    ".oCcCo....oCcCo.",
    "..oCCoo..ooCCo..",
    "..oCcCCooCCcCo..",
    "...oCCCCCCCCo...",
    "....ooCCCCoo....",
    "......oooo......",
    "................",
]
ICON_MILK = [
    "................",
    "................",
    "....oooooo......",
    "...oWWWWWWo.....",
    "...oWllllWoo....",
    "...oWlLLlWWo....",
    "...oWlLLlWoo....",
    "...ooWllWo......",
    ".....oWWo.......",
    "......olo.......",
    ".....ollo.......",
    "...oooooooooo...",
    "..olLllllllLlo..",
    "..ooooooooooo...",
    "................",
    "................",
]
ICON_NAP = [
    "................",
    "..........oo....",
    ".....ooo..oZo...",
    "...ooPPPoo.oo...",
    "..oPPPPPPPo.....",
    ".oPPoPPPoPPo.oo.",
    ".oPPKPPPKPPooZZo",
    ".oPPPPPPPPPo.oo.",
    ".oPPoooooPPo....",
    ".oPoWWWWWoPo....",
    ".oPPoooooPPo....",
    "..oPPPPPPPo.....",
    "...oooooooo.....",
    "................",
    "................",
    "................",
]
ICON_ZAP = [
    "................",
    ".......oo.......",
    "......oYYo......",
    ".....oYYYo......",
    "....oYYYo.......",
    "...oYYYYooo.....",
    "..oYYYYYYYYo....",
    "...ooooYYYYo....",
    ".......oYYYo....",
    "......oYYYo.....",
    "......oYYo......",
    ".....oYYo.......",
    ".....oYo........",
    "......o.........",
    "................",
    "................",
]
ICON_BOOTS = [
    "................",
    "................",
    "....oooo........",
    "...oPPPPo.......",
    "...oPpPPo.......",
    "...oPPPPo.......",
    "...oPPPPoooo....",
    "...oPPPPPPPPo...",
    "..oPPPPPPPPPPo..",
    "..oWWWWWWWWWWo..",
    "..oooooooooooo..",
    "................",
    "..o..o..o..o....",
    ".o..o..o..o.....",
    "................",
    "................",
]
ICON_CLAW = [
    "................",
    "..o...o...o.....",
    ".oWo.oWo.oWo....",
    ".oWo.oWo.oWo....",
    ".oWo.oWo.oWo....",
    ".oWWooWWooWWo...",
    "..oWWWWWWWWo....",
    "..oPPPPPPPPo....",
    ".oPpPPPPPPPPo...",
    ".oPPPPPPPPPPo...",
    ".oPPPPPPPPPPo...",
    "..oPPPPPPPPo....",
    "...oooooooo.....",
    "................",
    "................",
    "................",
]
ICON_BELL = [
    "................",
    "......oo........",
    ".....oYYo.......",
    "....ooooooo.....",
    "...oYYYYYYYo....",
    "..oYyYYYYYYYo...",
    "..oYYYYYYYYYo...",
    ".oYyYYYYYYYYYo..",
    ".oYYYYYYYYYYYo..",
    ".oYYYoooooYYYo..",
    ".ooooo...ooooo..",
    "......ooo.......",
    ".....oYYYo......",
    "......ooo.......",
    "................",
    "................",
]
ICON_MAGNET = [
    "................",
    "................",
    "..ooo....ooo....",
    ".oRRRo..oLLLo...",
    ".oRRRo..oLLLo...",
    ".oRRRo..oLLLo...",
    ".oRRRoooLLLo....",
    ".oRRRRRRLLLLo...",
    ".oRRRRRRLLLLo...",
    "..oRRRRLLLLo....",
    "...oooooooo.....",
    "....o....o......",
    "...oYo..oYo.....",
    "....o....o......",
    "................",
    "................",
]
ICON_VEST = [
    "................",
    "................",
    "....oooooo......",
    "..ooBBBBBBoo....",
    ".oBbBBBBBBbBo...",
    ".oBBBBBBBBBBo...",
    ".ooooooooooooo..",
    "oRrRRRRRRRRRRo..",
    "oRRRRRRRRRRRRo..",
    ".ooooooooooooo..",
    ".oBbBBBBBBbBo...",
    "..ooBBBBBBoo....",
    "....oooooo......",
    "................",
    "................",
    "................",
]
ICON_BOWL = [
    "................",
    "................",
    "................",
    "..o..o...o..o...",
    "...o..o.o..o....",
    "................",
    "oooooooooooooo..",
    "oLllllllllllLo..",
    ".oLLllllllLLo...",
    ".oBBBBBBBBBBo...",
    "..oBbBBBBbBo....",
    "...oBBBBBBo.....",
    "....oooooo......",
    "................",
    "................",
    "................",
]

SPRITES = {
    "cat": CAT_STAND,
    "icon_paw": ICON_PAW,
    "icon_purr": ICON_PURR,
    "icon_milk": ICON_MILK,
    "icon_nap": ICON_NAP,
    "icon_zap": ICON_ZAP,
    "icon_boots": ICON_BOOTS,
    "icon_claw": ICON_CLAW,
    "icon_bell": ICON_BELL,
    "icon_magnet": ICON_MAGNET,
    "icon_vest": ICON_VEST,
    "icon_bowl": ICON_BOWL,
    "cat_step_a": CAT_STEP_A,
    "cat_step_b": CAT_STEP_B,
    "grub": GRUB,
    "beetle": BEETLE,
    "snail": SNAIL,
    "wasp": WASP,
    "slime": SLIME,
    "big": BIG,
    "gem": GEM,
    "heart": HEART,
    "cookie": COOKIE,
    "yarn": YARN,
    "mouse": MOUSE,
    "fish": FISH,
    "star": STAR,
}


def write_png(path, grid):
    """One RGBA PNG per grid, no dependencies beyond zlib."""
    height = len(grid)
    width = max(len(row) for row in grid)
    rows = []
    for line in grid:
        row = bytearray([0])
        for x in range(width):
            ch = line[x] if x < len(line) else "."
            if ch not in PALETTE:
                raise SystemExit(f"{path.name}: no palette entry for {ch!r}")
            row += bytes(PALETTE[ch])
        rows.append(bytes(row))
    raw = zlib.compress(b"".join(rows), 9)

    def chunk(tag, data):
        head = struct.pack(">I", len(data)) + tag
        return head + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", raw)
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)
    return width, height


def recolour(grid, swap):
    """A copy of the grid with palette letters remapped.

    A value that is a letter reuses that palette entry; a value that is an RGBA
    tuple is a colour this flavour adds. Letters are swapped simultaneously, so
    a pair that trades places (mint's fur and filling) does not collapse into
    one colour.
    """
    extra = {}
    mapping = {}
    for src, dst in swap.items():
        if isinstance(dst, str):
            mapping[src] = dst
        else:
            key = f"#{src}"
            extra[key] = dst
            mapping[src] = key
    return [[mapping.get(ch, ch) for ch in row] for row in grid], extra


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, grid in SPRITES.items():
        w, h = write_png(OUT / f"{name}.png", grid)
        print(f"{name}.png {w}x{h}", flush=True)
    for name, swap in CAT_FLAVOURS.items():
        grid, extra = recolour(CAT_STAND, swap)
        PALETTE.update(extra)
        w, h = write_png(OUT / f"{name}.png", grid)
        print(f"{name}.png {w}x{h}", flush=True)
    # The lawn is a tile, not a sprite: two greens in a soft check so movement
    # over open ground is visible without drawing grass.
    # Four tones in a fixed pseudo-random scatter, so the ground has texture
    # without a visible grid: the earlier two-tone check read as graph paper
    # and fought with the bugs standing on it.
    tile = []
    scatter = [
        "TTtTTTTtTTTTtTTT",
        "TTTTTdTTTTtTTTTT",
        "tTTTTTTTTTTTTdTT",
        "TTTTtTTTdTTTTTTt",
        "TTdTTTTTTTTtTTTT",
        "TTTTTTtTTTTTTTTT",
        "TdTTTTTTTTTTtTdT",
        "TTTTtTTTTdTTTTTT",
        "TTTTTTTTTTTTTTtT",
        "TtTTTdTTtTTTTTTT",
        "TTTTTTTTTTTdTTTT",
        "TTTdTTTtTTTTTTtT",
        "tTTTTTTTTTTTTTTT",
        "TTTTTtTTTTdTTTTT",
        "TTdTTTTTTTTTtTTT",
        "TTTTTTTtTTTTTTTT",
    ]
    for row in scatter:
        tile.append(row)
    write_png(OUT / "lawn.png", tile)
    print("lawn.png 16x16", flush=True)


if __name__ == "__main__":
    main()
