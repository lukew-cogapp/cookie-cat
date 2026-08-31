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
ICONS = Path(__file__).resolve().parents[2] / "icons"
STORE = Path(__file__).resolve().parents[2] / "store"

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
    "K": (44, 36, 48, 255),  # pupils, and the heart's outline
    "Y": (255, 214, 92, 255),  # star / coin gold
    "y": (255, 240, 176, 255),
    "R": (240, 108, 124, 255),  # heart
    "r": (255, 160, 170, 255),
    "G": (124, 200, 108, 255),  # grub green
    "g": (168, 226, 148, 255),
    "V": (150, 124, 208, 255),  # beetle violet
    "N": (108, 84, 62, 255),  # dung beetle, darker than its ball
    "v": (192, 174, 236, 255),
    "O": (240, 156, 90, 255),  # snail orange
    "S": (120, 210, 170, 255),  # slime
    "s": (176, 238, 214, 255),
    "Z": (250, 226, 120, 255),  # wasp yellow
    "N": (86, 74, 96, 255),  # wasp stripes
    "M": (188, 176, 200, 255),  # toy mouse grey
    "Q": (46, 96, 150, 255),  # deep water, the bottom of a trap
    "L": (140, 200, 246, 255),  # water / milk blue
    "l": (214, 240, 255, 255),
    "E": (110, 216, 128, 255),  # green xp gem
    "e": (176, 244, 186, 255),
    "F": (240, 96, 110, 255),  # red xp gem
    "f": (255, 168, 176, 255),
    "T": (126, 186, 108, 255),  # lawn
    "t": (134, 194, 116, 255),  # lawn, a shade lighter
    "d": (116, 176, 100, 255),  # lawn, a shade darker
    "M": (158, 132, 98, 255),  # mud, edge
    "m": (140, 114, 82, 255),  # mud
    "n": (122, 98, 70, 255),  # mud, wet middle
    "X": (156, 152, 158, 255),  # stone
    "x": (186, 182, 190, 255),  # stone highlight
    "A": (233, 209, 156, 255),  # sand
    "a": (247, 229, 182, 255),  # sand light
    "h": (208, 178, 128, 255),  # sand dark
    "H": (178, 148, 102, 255),  # wet sand
    "I": (226, 238, 248, 255),  # snow
    "i": (242, 248, 255, 255),  # snow light
    "j": (198, 216, 234, 255),  # snow shade
    "U": (140, 192, 232, 255),  # ice
    "u": (196, 228, 248, 255),  # ice light
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
# A teardrop, not a blob: one narrow rounded peak over a base that spreads
# wider than any other kind, and no legs at all. The beetle was the same
# 12-wide rounded rectangle in another hue, so the hit flash made them one
# sprite; kinds must differ by silhouette, not by hue.
SLIME = [
    "................",
    "................",
    "......oo........",
    ".....osSo.......",
    ".....oSSo.......",
    "....osSSSo......",
    "....oSSSSo......",
    "...oSSoSSo......",
    "...oSKSSKSo.....",
    "..oSSSSSSSSo....",
    ".oSSSSSSSSSSo...",
    "oSSSSSooSSSSSo..",
    "oSSSSSSSSSSSSo..",
    "oSSSSSSSSSSSSo..",
    ".oooooooooooo...",
    "................",
]
# The spider is all legs: four splayed each side, so the silhouette reads at
# a glance where another round body in a new hue would not.
SPIDER = [
    "................",
    "................",
    "..o...o..o...o..",
    "..o...o..o...o..",
    "...o..o..o..o...",
    "....oooooooo....",
    "...oNNNNNNNNo...",
    "..oNvNNWWNWWNo..",
    "..oNNNNWKNWKNo..",
    "..oNNNNNNNNNNo..",
    "...oNNNNNNNNo...",
    "....oooooooo....",
    "...o..o..o..o...",
    "..o...o..o...o..",
    "..o...o..o...o..",
    "................",
]
# A rounder, darker body than the plain beetle, tilted nose-down onto a ball
# it is pushing, with a horn. Two earlier tries failed the silhouette rule that
# the snail already taught: a big ball with a small body read as an upside-down
# snail, and an oversized body read as the ordinary beetle in another colour.
DUNG = [
    "................",
    ".............o..",
    "...o........oNo.",
    "..oNo......oNo..",
    "...oNoooooNo....",
    "....oNNNNNNo....",
    "..ooNNNNNNNNoo..",
    ".oNNWKNNNWKNNNo.",
    "oBBoNNNNNNNNNNo.",
    "oBbBoNNNNNNNNo..",
    "oBbBBoNNNNNNo...",
    "oBBBBooNNNNo....",
    ".oBBo..o..o.....",
    "..oo..o....o....",
    "................",
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

# The three xp tiers differ by SHAPE as well as colour: the hit flash and a
# busy lawn both eat hue, and a child should read "better" at a glance.
GEM = [
    "................",
    "................",
    "................",
    "......oo........",
    ".....oLLo.......",
    "....oLllLo......",
    "...oLlLLlLo.....",
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
GEM_GREEN = [
    "................",
    "................",
    "......oooo......",
    ".....oEeeEo.....",
    "....oEeEEeEo....",
    "...oEEEEEEEEo...",
    "..oEEEEEEEEEEo..",
    "..oEEEEEEEEEEo..",
    "...oEEEEEEEEo...",
    "....oEEEEEEo....",
    ".....oEEEEo.....",
    "......oEEo......",
    ".......oo.......",
    "................",
    "................",
    "................",
]
GEM_RED = [
    "................",
    "....o......o....",
    "...oFo....oFo...",
    "..ooFooooooFoo..",
    ".oFfFFFFFFFFfFo.",
    "oFfFFFFFFFFFFfFo",
    "oFFFFFFFFFFFFFFo",
    ".oFFFFFFFFFFFFo.",
    "..oFFFFFFFFFFo..",
    "...oFFFFFFFFo...",
    "....oFFFFFFo....",
    ".....oFFFFo.....",
    "......oFFo......",
    ".......oo.......",
    "................",
    "................",
]
# Hard black outline, two clear lobes, and a SHORT point: the old heart tapered
# over five rows to a single pixel, which reads as a spade or an arrow.
HEART = [
    "................",
    "................",
    "...KKKK..KKKK...",
    "..KrrrrKKrrrrK..",
    ".KrrrrrrrrrrrrK.",
    ".KrrRRrrrrRRrrK.",
    ".KrRRRRrrRRRRrK.",
    ".KRRRRRRRRRRRRK.",
    "..KRRRRRRRRRRK..",
    "...KRRRRRRRRK...",
    "....KRRRRRRK....",
    ".....KRRRRK.....",
    "......KRRK......",
    ".......KK.......",
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
# The burst particle. Fat arms, because the previous one-pixel arms vanished
# the moment a burst scaled it down.
STAR = [
    "................",
    ".......oo.......",
    "......oYYo......",
    "......oYYo......",
    ".....oYyyYo.....",
    "ooooooYyyYoooooo",
    "oYYYYYYyyYYYYYYo",
    ".oYyyyyyyyyyyYo.",
    "..oYYyyyyyyyYo..",
    "...oYYyyyyyYo...",
    "....oYYyyyYo....",
    "...oYYo.oYYo....",
    "..oYYo...oYYo...",
    ".oYYo.....oYYo..",
    "..oo.......oo...",
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
ICON_MUSIC = [
    "................",
    "..........oo....",
    "........ooYYo...",
    "......ooYYYYo...",
    ".....oYYYYYYo...",
    ".....oYYoooo....",
    ".....oYYo.......",
    ".....oYYo.......",
    "...oooYYo.......",
    "..oYYYoo........",
    ".oYyYYo.........",
    ".oYYYYo.........",
    "..oooo..........",
    "................",
    "................",
    "................",
]
ICON_SOUND = [
    "................",
    "................",
    ".....oo.........",
    "...ooLLo...o....",
    "..oLLLLo...o....",
    ".oLLLLLoo...o...",
    ".oLLlLLLo..o....",
    ".oLLlLLLo..o....",
    ".oLLLLLoo...o...",
    "..oLLLLo...o....",
    "...ooLLo...o....",
    ".....oo.........",
    "................",
    "................",
    "................",
    "................",
]

# A four-point twinkle for pickups and kill bursts. White core so an instance
# tint can turn one grid gold, pink or mint.
SPARKLE = [
    "................",
    "................",
    "................",
    ".......W........",
    ".......W........",
    "......yWy.......",
    ".....yWWWy......",
    "...WWWWWWWWW....",
    ".....yWWWy......",
    "......yWy.......",
    ".......W........",
    ".......W........",
    "................",
    "................",
    "................",
    "................",
]

# A soft cloud for spawns and the boss telegraph. Also tinted per instance.
POOF = [
    "................",
    "................",
    "................",
    "....llll........",
    "...lWWWWll......",
    "..lWWWWWWWl.....",
    ".lWWWWWWWWWl....",
    ".lWWWWWWWWWWl...",
    ".lWWWWWWWWWl....",
    "..lWWWWWWWl.....",
    "...llWWWll......",
    ".....lll........",
    "................",
    "................",
    "................",
    "................",
]

# Breakable props. Each is bigger and stiller than a bug, so nothing is
# mistaken for one, and each looks like something a cat would knock over.
PROP_POT = [
    "................",
    "................",
    "..oooooooooo....",
    ".oOOOOOOOOOOo...",
    ".oObbbbbbbbOo...",
    ".oOOOOOOOOOOo...",
    "..oooooooooo....",
    "..oOOOOOOOOo....",
    "..oObOOOObOo....",
    "..oOOOOOOOOo....",
    "...oOOOOOOo.....",
    "...oOObbOOo.....",
    "....oOOOOo......",
    "....oooooo......",
    "................",
    "................",
]
PROP_BUSH = [
    "................",
    "................",
    "......oooo......",
    "....ooGGGGoo....",
    "...oGgGGGGGGo...",
    "..oGGGGGGGGGGo..",
    ".oGgGGGGGGGGGGo.",
    ".oGGGGGRGGGGGGo.",
    ".oGGGRGGGGGRGGo.",
    ".oGgGGGGGGGGGGo.",
    "..oGGGGGGGGGGo..",
    "...oGGGGGGGGo...",
    "....ooGGGGoo....",
    "......oooo......",
    "................",
    "................",
]
PROP_BOX = [
    "................",
    "................",
    "..oooooooooooo..",
    "..oBbBBBBBBbBo..",
    "..oBBBBBBBBBBo..",
    "..oBBooooooBBo..",
    "..oBBoWWWWoBBo..",
    "..oBBoWKKWoBBo..",
    "..oBBoWWWWoBBo..",
    "..oBBooooooBBo..",
    "..oBBBBBBBBBBo..",
    "..oBbBBBBBBbBo..",
    "..oooooooooooo..",
    "................",
    "................",
    "................",
]

# Ground decals, scattered under everything. Low contrast on purpose: the lawn
# needs variety, but a patch that reads as loudly as a bug makes the crowd hard
# to pick out, which is the one thing that must stay legible.
GROUND_MUD = [
    "....MMMMMMM.....",
    "..MMMmmmmmMMM...",
    ".MMmmmmmmmmmMM..",
    "MMmmmmnnmmmmmMM.",
    "MmmmmnnnnmmmmmMM",
    "MmmmnnnnnnmmmmmM",
    "MmmmnnnnnnnmmmmM",
    "MmmmmnnnnnnmmmmM",
    "MMmmmmnnnnmmmmmM",
    ".MMmmmmnnmmmmmMM",
    "..MMmmmmmmmmmMM.",
    "...MMmmmmmmmMM..",
    "....MMMmmmMMM...",
    "......MMMMM.....",
    "................",
    "................",
]
GROUND_PATCH = [
    "................",
    "....ttttt.......",
    "..tttdddttt.....",
    ".ttdddddddtt....",
    ".tdddddddddt....",
    "ttddddddddddt...",
    "tddddddddddddt..",
    "tddddddddddddt..",
    ".tddddddddddt...",
    ".ttdddddddddt...",
    "..tttdddddtt....",
    "....tttttt......",
    "................",
    "................",
    "................",
    "................",
]
GROUND_FLOWERS = [
    "................",
    "...W....R.......",
    "..WYW..RYR...W..",
    "...W....R...WYW.",
    "....g.g......W..",
    ".....g..g...g...",
    "..Y....g...g....",
    ".YWY....g.g.....",
    "..Y......g......",
    "....g.g.........",
    "..R..g..........",
    ".RYR..W.....R...",
    "..R..WYW...RYR..",
    "......W.....R...",
    "................",
    "................",
]
GROUND_STONES = [
    "................",
    "................",
    "...oooo.........",
    "..oXXXXo....oo..",
    "..oXxXXo...oXXo.",
    "...oooo....oXxo.",
    "..........oooo..",
    "................",
    ".....oooooo.....",
    "....oXXXXXXo....",
    "....oXxXXXXo....",
    ".....oooooo.....",
    "................",
    "..oo............",
    ".oXXo...........",
    "..oo............",
]

# The feather wand: a real cat toy, and the string is what explains the
# return. It replaced a boomerang, whose V read as a slug, a boot, a blob and
# a tick at this size. The barbs sit OUTSIDE the spine with the outline broken
# between them: a smooth outline reads as a sausage whatever is drawn inside.
BOOMER = [
    "................",
    ".............o..",
    "...........o.Po.",
    "..........oPoPo.",
    ".........oPoPo..",
    "..o.....oPoPPo..",
    ".oWo...oPoPPo...",
    "..oWo.oPoPPo....",
    "...oWo.oPPo.....",
    "....oWo.oPo.....",
    ".....oWo.o......",
    "......oWo.......",
    ".......o........",
    "................",
    "................",
    "................",
]
ICON_BOOMER = [
    "................",
    "............o.o.",
    "..........o.PoPo",
    ".........oPoPoP.",
    ".........oPoPo..",
    "........oPoPo.o.",
    ".......oPoPoPo..",
    "..o...oPoPPo....",
    ".oWo.oPoPPo.....",
    "..oWo.oPPo......",
    "...oWo.oPo......",
    "....oWo.o.......",
    "..oBWo..........",
    ".oBBo...........",
    ".oBo............",
    "..o.............",
]
ICON_TRAIL = [
    "................",
    "................",
    "..oo............",
    ".oBBo...........",
    "..oo....oo......",
    ".......oBBo.....",
    "........oo......",
    "................",
    "....oo.....oo...",
    "...oBBo...oBBo..",
    "....oo.....oo...",
    "................",
    "..........oo....",
    ".........oBBo...",
    "..........oo....",
    "................",
]

# The dung beetle's lob: a cartoon swirl with stink lines, drawn small. It has
# to read as the beetle's ball in flight, so it shares the ball's mud tones.
POOP = [
    "................",
    "................",
    "....g......g....",
    "....g..oo..g....",
    "....g.onno.g....",
    "......onnno.....",
    ".....oonnnoo....",
    "....omnnnnnmo...",
    "...omnnnnnnnmo..",
    "..ommnnnnnnmmo..",
    "..oMmmmmmmmmMo..",
    "...oooooooooo...",
    "................",
    "................",
    "................",
    "................",
]

# Beach and arctic decals that are a garden shape in that map's ground tones.
# Sharing the silhouette is deliberate: a wet patch is the beach's worn grass
# and an ice sheet is its mud, so each map's floor reads the same way.
GROUND_SHELLS = [
    "................",
    "...ooo..........",
    "..opWpo.........",
    "..oWpDo.....oo..",
    "...ooo.....opWo.",
    "...........oWpo.",
    "............oo..",
    "................",
    ".....oooo.......",
    "....opWpWo......",
    "....oWpDpo......",
    ".....oooo.......",
    "................",
    "..oo............",
    ".opWo...........",
    "..oo............",
]
GROUND_SEAWEED = [
    "................",
    "..G.............",
    "..gG......G.....",
    "...gG....Gg.....",
    "....G....G......",
    "....Gg..gG......",
    ".....G...G......",
    "................",
    ".........G..G...",
    ".G......gG..Gg..",
    ".Gg......G...G..",
    "..G......Gg..G..",
    "..Gg......G.....",
    "...G............",
    "................",
    "................",
]
GROUND_CRACKS = [
    "................",
    ".j..............",
    "..jj............",
    "...Ujj..........",
    ".....jUj........",
    ".......j........",
    ".......jj.......",
    "........Uj......",
    ".........jj.....",
    "..........j.....",
    "...j......jU....",
    "..jU.......jj...",
    "..j.........j...",
    ".jj.............",
    ".j..............",
    "................",
]

PROP_SANDCASTLE = [
    "................",
    "...oo..oo..oo...",
    "...oAooAAooAo...",
    "...oAAAAAAAAo...",
    "...oAaAAAAaAo...",
    "...oAAAAAAAAo...",
    "..oAAAAAAAAAAo..",
    "..oAaAAaaAAaAo..",
    "..oAAAohhoAAAo..",
    "..oAAAohhoAAAo..",
    ".oAAAAohhoAAAAo.",
    ".oAaAAohhoAAaAo.",
    ".oAAAAAAAAAAAAo.",
    ".oooooooooooooo.",
    "................",
    "................",
]
PROP_DRIFTWOOD = [
    "................",
    "................",
    "................",
    "......oo........",
    ".....obbo...oo..",
    "..ooobBBboooBo..",
    ".obBBBBBBBBBbo..",
    ".oBnnBBBBnnBBo..",
    ".obBBBBBBBBbo...",
    "..oooooooooo....",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]
PROP_BUCKET = [
    "................",
    "....oooooo......",
    "...oo....oo.....",
    "...o......o.....",
    "..oooooooooo....",
    "..orrrrrrrro....",
    "..oRRRRRRRRo....",
    "...oRRrRRRo.....",
    "...oRRRRRRo.....",
    "...oRRrRRRo.....",
    "....oRRRRo......",
    "....oooooo......",
    "................",
    "................",
    "................",
    "................",
]
PROP_SNOWMAN = [
    "................",
    ".....oooo.......",
    "....oWWWWo......",
    "...oWKWWKWo.....",
    "...oWWOOWWo.....",
    "....oWWWWo......",
    "...oRRRRRRo.....",
    "..oWWWWWWWWo....",
    ".oWWiWWWWWWWo...",
    ".oWWWWKWWWWWo...",
    ".oWiWWKWWWiWo...",
    "..oWWWWWWWWo....",
    "...oWWWWWWo.....",
    "....oooooo......",
    "................",
    "................",
]
PROP_ICEBLOCK = [
    "................",
    "................",
    "..oooooooooooo..",
    "..ouuuuuuuuuUo..",
    "..ouUUUUUUUUUo..",
    "..ouUUWUUUUUUo..",
    "..ouUUUWUUUUUo..",
    "..ouUUUUUUWUUo..",
    "..ouUUUUUUUWUo..",
    "..ouUUUUUUUUUo..",
    "..oUUUUUUUUUUo..",
    "..oooooooooooo..",
    "................",
    "................",
    "................",
    "................",
]
PROP_SAPLING = [
    "................",
    ".......oo.......",
    "......oGGo......",
    ".....oGWGGo.....",
    "....oGGGGGGo....",
    ".....oGGGo......",
    "....oGWGGGo.....",
    "...oGGGGGGGGo...",
    "....oGGGGGo.....",
    "...oGGWGGGGo....",
    "..oGGGGGGGGGo...",
    "...ooooooooo....",
    "......oBBo......",
    "......oooo......",
    "................",
    "................",
]

# Map pictures for the start screen: a postcard of the place, not an icon,
# because the child picks the place by picture the way they pick the cat.
MAP_GARDEN = [
    "oooooooooooooooo",
    "oLLLLLLLLLLLLLLo",
    "olLLLLlLLLLLlLLo",
    "oLLWWLLLLWWWLLLo",
    "oTTTTTTTTTTTTTTo",
    "oTtTTdTTTtTTTdTo",
    "oTTRTTTTWTTTYTTo",
    "oTRYRTTWYWTTYWTo",
    "oTTRTTTTWTTTTTTo",
    "oTtTTTdTTTtTTdTo",
    "oTTGgTTTTTTGgTTo",
    "oTdTTTtTTdTTTTTo",
    "oTTTYWTTTTTRTTTo",
    "oTtTTTTTdTTRYRTo",
    "oTTTTTTTTTTTRTTo",
    "oooooooooooooooo",
]
MAP_BEACH = [
    "oooooooooooooooo",
    "olllllllllllYYlo",
    "ollllllllllYYYlo",
    "olllllllllllYYlo",
    "oLLLLLLLLLLLLLLo",
    "oLLlWLLLLlWLLLLo",
    "oLLLLLLLLLLLLLLo",
    "oWLWLWLWLWLWLWLo",
    "oAaAAAAaAAAAaAAo",
    "oAAAAhAAAAAAAAAo",
    "oAApWAAAAhAAAaAo",
    "oAaAAAAAAAAhAAAo",
    "oAAAAAhAAAAAAAAo",
    "oAAhAAAAAaAAhAAo",
    "oAAAAAAAAAAAAAAo",
    "oooooooooooooooo",
]
MAP_ARCTIC = [
    "oooooooooooooooo",
    "ojjjjjjjjjjjjjjo",
    "ojjjjWjjjjjjjjjo",
    "ojWjjjjjjWjjjjjo",
    "ojjjjjjjjjjjWjjo",
    "oIIIIIIIIIIIIIIo",
    "oIiIIjIIIiIIIjIo",
    "oIIIWWIIIIIGGIIo",
    "oIIWWWWIIIGGGGIo",
    "oIIIWWIIIIIGGIIo",
    "oIIWWWWIIIIBBIIo",
    "oIiIIIIjIIIIIIIo",
    "oIIUUIIIIIiIIjIo",
    "oIIUUUIIIIIIIIIo",
    "oIiIIIIIIjIIIiIo",
    "oooooooooooooooo",
]

# Hats. Cookies buy these and nothing else: they change no number in the game,
# which is the point. Each is drawn to sit on the 16x16 cat's head, so they
# share an origin and the game just draws one over the other.
HAT_PARTY = [
    ".......oo.......",
    "......oYyo......",
    ".....oRRRRo.....",
    "....oYYYYYYo....",
    "....oooooooo....",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]
HAT_CROWN = [
    "....o...o...o...",
    "...oYo.oYo.oYo..",
    "...oYYYYYYYYYo..",
    "...oYyYRYYRYYo..",
    "...ooooooooooo..",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]
HAT_BOW = [
    "...oo......oo...",
    "..oRRo....oRRo..",
    "..oRrRoRRoRRRo..",
    "..oRRRoRRoRRRo..",
    "...ooooRRoooo...",
    ".......oo.......",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]
HAT_CAP = [
    ".....oooo.......",
    "...ooCCCCoo.....",
    "..oCcCCCCCCoooo.",
    "..oCCCCCCCCCCCo.",
    "..ooooooooooooo.",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]

# A spider web, drawn on the ground. Pale and open rather than solid: it has to
# read as something to avoid without hiding the bugs standing on it.
WEB = [
    "................",
    "....W..W..W.....",
    "..W..W.W.W..W...",
    "...W..WWW..W....",
    "....WWWWWWW.....",
    "..WWWWWWWWWWW...",
    ".W..WWWWWWW..W..",
    "W.W.WWWWWWW.W.W.",
    ".W..WWWWWWW..W..",
    "..WWWWWWWWWWW...",
    "....WWWWWWW.....",
    "...W..WWW..W....",
    "..W..W.W.W..W...",
    "....W..W..W.....",
    "................",
    "................",
]

# The traps, one per map: a pond in the lawn, a dug hole in the sand, a hole in
# the ice. All three read as a HOLE rather than a lump, which is what the dark
# middle and the pale near rim are for: a raised thing lights from the top, a
# recessed one is dark at the bottom and bright at the near lip. They also share
# one squashed-oval outline so the shape says "opening" before the colour says
# which map. Wider than they are tall, because the ground is seen from above at
# a slight angle like every other decal.
TRAP_POND = [
    "................",
    "................",
    "....oooooooo....",
    "..oolLLLLLLloo..",
    ".olLLLQQQQLLLLo.",
    ".oLLQQQQQQQQLLo.",
    ".oLQQQQQQQQQQLo.",
    ".oLQQQQQQQQQQLo.",
    ".oLLQQQQQQQQLLo.",
    ".olLLLQQQQLLLLo.",
    "..oolLLLLLLloo..",
    "....oooooooo....",
    "................",
    "................",
    "................",
    "................",
]
TRAP_SANDPIT = [
    "................",
    "................",
    "....oooooooo....",
    "..oohmmmmmmhoo..",
    ".ohmmmnnnnmmmho.",
    ".ommnnnnnnnnmmo.",
    ".omnnnnnnnnnnmo.",
    ".omnnnnnnnnnnmo.",
    ".ommnnnnnnnnmmo.",
    ".ohmmmnnnnmmmho.",
    "..oohmmmmmmhoo..",
    "....oooooooo....",
    "................",
    "................",
    "................",
    "................",
]
TRAP_ICEHOLE = [
    "................",
    "................",
    "....oooooooo....",
    "..ooiKKKKKKioo..",
    ".oiQKKKKKKKKQio.",
    ".oQKKKKKKKKKKQo.",
    ".oQKKKKKKKKKKQo.",
    ".oQKKKKKKKKKKQo.",
    ".oQKKKKKKKKKKQo.",
    ".oiQKKKKKKKKQio.",
    "..ooiKKKKKKioo..",
    "....oooooooo....",
    "................",
    "................",
    "................",
    "................",
]


# A clock for the pause screen's time-left line. The number beside it is the
# one stat with no picture, and a bare number is exactly what a child who
# cannot read has no way into.
#
# One hand up and one to the right, meeting at the middle. Tick marks were
# tried at every hour and read as a keypad at this size: four is enough to say
# "clock face" and leaves the hands somewhere to be.
CLOCK = [
    "................",
    ".....oooooo.....",
    "...ooyyyyyyoo...",
    "..oyyyyyyyyyyo..",
    ".oyyyyyKyyyyyyo.",
    ".oyyyyyKyyyyyyo.",
    "oyyyyyyKyyyyyyyo",
    "oyKyyyyKyyyyKyyo",
    "oyyyyyyKKKKKyyyo",
    "oyyyyyyyyyyyyyyo",
    ".oyyyyyKyyyyyyo.",
    ".oyyyyyyyyyyyyo.",
    "..oyyyyyyyyyyo..",
    "...ooyyyyyyoo...",
    ".....oooooo.....",
    "................",
]

SPRITES = {
    "cat": CAT_STAND,
    "clock": CLOCK,
    "web": WEB,
    "trap_pond": TRAP_POND,
    "trap_sandpit": TRAP_SANDPIT,
    "trap_icehole": TRAP_ICEHOLE,
    "hat_party": HAT_PARTY,
    "hat_crown": HAT_CROWN,
    "hat_bow": HAT_BOW,
    "hat_cap": HAT_CAP,
    "boomer": BOOMER,
    "icon_boomer": ICON_BOOMER,
    "icon_trail": ICON_TRAIL,
    "ground_mud": GROUND_MUD,
    "ground_patch": GROUND_PATCH,
    "ground_flowers": GROUND_FLOWERS,
    "ground_stones": GROUND_STONES,
    "ground_shells": GROUND_SHELLS,
    "ground_seaweed": GROUND_SEAWEED,
    "ground_cracks": GROUND_CRACKS,
    "prop_pot": PROP_POT,
    "prop_bush": PROP_BUSH,
    "prop_box": PROP_BOX,
    "prop_sandcastle": PROP_SANDCASTLE,
    "prop_driftwood": PROP_DRIFTWOOD,
    "prop_bucket": PROP_BUCKET,
    "prop_snowman": PROP_SNOWMAN,
    "prop_iceblock": PROP_ICEBLOCK,
    "prop_sapling": PROP_SAPLING,
    "map_garden": MAP_GARDEN,
    "map_beach": MAP_BEACH,
    "map_arctic": MAP_ARCTIC,
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
    "icon_music": ICON_MUSIC,
    "icon_sound": ICON_SOUND,
    "cat_step_a": CAT_STEP_A,
    "cat_step_b": CAT_STEP_B,
    "grub": GRUB,
    "beetle": BEETLE,
    "snail": SNAIL,
    "wasp": WASP,
    "slime": SLIME,
    "big": BIG,
    "spider": SPIDER,
    "dung": DUNG,
    "poop": POOP,
    "gem": GEM,
    "gem_green": GEM_GREEN,
    "gem_red": GEM_RED,
    "heart": HEART,
    "cookie": COOKIE,
    "yarn": YARN,
    "mouse": MOUSE,
    "fish": FISH,
    "star": STAR,
    "sparkle": SPARKLE,
    "poof": POOF,
}

# Decals that borrow a garden silhouette in another map's tones, and the sand
# and snow lawn tiles. name -> (source grid, palette letter swap).
RECOLOURED = {
    "ground_wet": (GROUND_PATCH, {"t": "h", "d": "H"}),
    "ground_pool": (GROUND_MUD, {"M": "h", "m": "L", "n": "l"}),
    "ground_ice": (GROUND_MUD, {"M": "u", "m": "U", "n": "l"}),
    "ground_drift": (GROUND_PATCH, {"t": "j", "d": "W"}),
}


# The lawn is a tile, not a sprite: four tones in a fixed pseudo-random
# scatter, so the ground has texture without a visible grid. The earlier
# two-tone check read as graph paper and fought with the bugs standing on it.
# Module-level because the store's feature graphic tiles the same ground.
LAWN_SCATTER = [
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


def write_icon(path, grid, size, pad=0, background=None):
    """One square launcher icon, nearest-neighbour scaled from a 16x16 grid.

    Android wants 192 for the legacy icon and 432 for each adaptive layer, and
    a pixel grid only survives that if it is scaled by whole pixels. `pad` is
    in grid cells, and is what keeps the cat clear of the circular mask an
    adaptive icon is cropped to.
    """
    cells = len(grid) + pad * 2
    if size % cells:
        raise SystemExit(f"{path.name}: {size} is not a whole multiple of {cells}")
    step = size // cells
    blank = background if background else (0, 0, 0, 0)
    rows = []
    for y in range(size):
        row = bytearray([0])
        gy = y // step - pad
        for x in range(size):
            gx = x // step - pad
            pixel = blank
            if 0 <= gy < len(grid) and 0 <= gx < len(grid[gy]):
                ch = grid[gy][gx]
                if ch not in PALETTE:
                    raise SystemExit(f"{path.name}: no palette entry for {ch!r}")
                here = PALETTE[ch]
                pixel = here if here[3] else blank
            row += bytes(pixel)
        rows.append(bytes(row))
    raw = zlib.compress(b"".join(rows), 9)

    def chunk(tag, data):
        head = struct.pack(">I", len(data)) + tag
        return head + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", raw)
        + chunk(b"IEND", b"")
    )
    return size


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


# The Play listing title, five rows per glyph. Only the letters the title
# needs: this is banner lettering, not a font.
GLYPHS = {
    "A": [".XX.", "X..X", "XXXX", "X..X", "X..X"],
    "B": ["XXX.", "X..X", "XXX.", "X..X", "XXX."],
    "C": [".XXX", "X...", "X...", "X...", ".XXX"],
    "G": [".XXX", "X...", "X.XX", "X..X", ".XX."],
    "S": [".XXX", "X...", ".XX.", "...X", "XXX."],
    "T": ["XXXXX", "..X..", "..X..", "..X..", "..X.."],
    "U": ["X..X", "X..X", "X..X", "X..X", ".XX."],
    "V": ["X...X", "X...X", "X...X", ".X.X.", "..X.."],
    " ": ["..", "..", "..", "..", ".."],
}


def text_grid(text):
    """A line of title text as a sprite grid, white with the game's outline.

    Outlined because flat white on the mid-green lawn reads as gaps between
    the letters; the dark edge is what every sprite here already wears.
    """
    rows = ["", "", "", "", ""]
    for ch in text:
        glyph = GLYPHS[ch]
        for i in range(5):
            rows[i] += glyph[i] + "."
    height = len(rows) + 2
    width = len(rows[0]) + 2
    grid = [["."] * width for _ in range(height)]
    for y, line in enumerate(rows):
        for x, ch in enumerate(line):
            if ch == "X":
                grid[y + 1][x + 1] = "W"
    for y in range(height):
        for x in range(width):
            if grid[y][x] != ".":
                continue
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < height and 0 <= nx < width and grid[ny][nx] == "W":
                        grid[y][x] = "o"
    return grid


def blank_canvas(width, height, letter):
    return [[PALETTE[letter]] * width for _ in range(height)]


def blit(rows, grid, left, top, scale):
    """Nearest-neighbour paste of a grid onto a canvas, skipping transparency.

    Clips at the canvas edge, which is what lets the feature graphic's ground
    tiles overhang the 500px height without a special last row.
    """
    for gy, line in enumerate(grid):
        for gx, ch in enumerate(line):
            colour = PALETTE[ch]
            if not colour[3]:
                continue
            for y in range(top + gy * scale, top + (gy + 1) * scale):
                if not 0 <= y < len(rows):
                    continue
                row = rows[y]
                for x in range(left + gx * scale, left + (gx + 1) * scale):
                    if 0 <= x < len(row):
                        row[x] = colour


def write_canvas(path, rows, alpha):
    """A composed canvas as PNG.

    Play's feature graphic must be a 24-bit PNG with no alpha channel, so
    `alpha=False` emits colour type 2; the listing icon keeps the 32-bit
    type the rest of the art uses.
    """
    height = len(rows)
    width = len(rows[0])
    out = []
    for line in rows:
        row = bytearray([0])
        for pixel in line:
            row += bytes(pixel if alpha else pixel[:3])
        out.append(bytes(row))
    raw = zlib.compress(b"".join(out), 9)

    def chunk(tag, data):
        head = struct.pack(">I", len(data)) + tag
        return head + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6 if alpha else 2, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", raw)
        + chunk(b"IEND", b"")
    )


def store_icon():
    """The Play listing icon: the launcher cat with a margin.

    Play rounds the corners at about thirty percent of the width, and the
    full-bleed web_512 puts the ear outline within a few pixels of that arc.
    32px of lawn all round clears it without shrinking the cat much.
    """
    rows = blank_canvas(512, 512, "T")
    blit(rows, CAT_STAND, 32, 32, 28)
    return rows


def feature_graphic():
    """The 1024x500 Play banner: title, cat and bugs on the lawn.

    Composed from the game's own grids so the banner shows what the screen
    shows. Title and cat sit centred because Play crops the edges in some
    placements.
    """
    rows = blank_canvas(1024, 500, "T")
    for ty in range(4):
        for tx in range(8):
            blit(rows, LAWN_SCATTER, tx * 128, ty * 128, 8)
    # Placed by hand so nothing overlaps: two sprites sharing pixels read as
    # one merged creature at this size.
    for grid, x, y, scale in (
        (GROUND_FLOWERS, 30, 340, 6),
        (GROUND_PATCH, 730, 40, 6),
        (GROUND_STONES, 180, 400, 6),
        (GRUB, 60, 110, 7),
        (SPIDER, 250, 120, 6),
        (WASP, 800, 120, 7),
        (SNAIL, 140, 280, 7),
        (BEETLE, 872, 270, 7),
        (SLIME, 765, 370, 6),
        (STAR, 315, 350, 5),
        (COOKIE, 655, 320, 6),
        (CAT_STAND, 400, 180, 14),
    ):
        blit(rows, grid, x, y, scale)
    title = text_grid("CAT VS BUGS")
    blit(rows, title, (1024 - len(title[0]) * 12) // 2, 40, 12)
    return rows


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, grid in SPRITES.items():
        w, h = write_png(OUT / f"{name}.png", grid)
        print(f"{name}.png {w}x{h}", flush=True)
    for name, swap in CAT_FLAVOURS.items():
        # Stand and both step frames, or a walking cat flickers back to the
        # base cat's pink on every other frame.
        for suffix, source in (
            ("", CAT_STAND),
            ("_step_a", CAT_STEP_A),
            ("_step_b", CAT_STEP_B),
        ):
            grid, extra = recolour(source, swap)
            PALETTE.update(extra)
            w, h = write_png(OUT / f"{name}{suffix}.png", grid)
            print(f"{name}{suffix}.png {w}x{h}", flush=True)
    # The lawn is a tile, not a sprite: two greens in a soft check so movement
    # over open ground is visible without drawing grass.
    # Four tones in a fixed pseudo-random scatter, so the ground has texture
    # without a visible grid: the earlier two-tone check read as graph paper
    # and fought with the bugs standing on it.
    tile = LAWN_SCATTER
    write_png(OUT / "lawn.png", tile)
    print("lawn.png 16x16", flush=True)
    # The beach and arctic floors are the same scatter in that map's tones, so
    # every map's ground has identical texture and only the palette changes.
    for name, swap in (
        ("lawn_beach", {"T": "A", "t": "a", "d": "h"}),
        ("lawn_arctic", {"T": "I", "t": "i", "d": "j"}),
    ):
        grid, _ = recolour(tile, swap)
        write_png(OUT / f"{name}.png", grid)
        print(f"{name}.png 16x16", flush=True)
    for name, (source, swap) in RECOLOURED.items():
        grid, _ = recolour(source, swap)
        write_png(OUT / f"{name}.png", grid)
        print(f"{name}.png 16x16", flush=True)
    # Android launcher icons. The adaptive pair is padded because the launcher
    # crops it to a circle on most phones, and an unpadded cat loses its ears.
    ICONS.mkdir(parents=True, exist_ok=True)
    lawn = PALETTE["T"]
    write_icon(ICONS / "icon.png", CAT_STAND, 192, background=lawn)
    print("icons/icon.png 192x192", flush=True)
    write_icon(ICONS / "icon_foreground.png", CAT_STAND, 432, pad=4)
    print("icons/icon_foreground.png 432x432", flush=True)
    write_icon(ICONS / "icon_background.png", [["T"] * 16] * 16, 432)
    print("icons/icon_background.png 432x432", flush=True)
    # The web app's icons, for a browser that offers to keep the game on a
    # home screen. Same cat on the same lawn, at the three sizes Godot asks
    # for; 144 and 512 divide by 16, and 180 needs the pad to reach a multiple.
    for size, pad in ((144, 0), (180, 2), (512, 0)):
        write_icon(ICONS / f"web_{size}.png", CAT_STAND, size, pad=pad, background=lawn)
        print(f"icons/web_{size}.png {size}x{size}", flush=True)
    # Play Store listing assets. store/.gdignore keeps them out of the import
    # cache and the export; they exist for the Play Console, not the game.
    STORE.mkdir(parents=True, exist_ok=True)
    write_canvas(STORE / "icon_512.png", store_icon(), alpha=True)
    print("store/icon_512.png 512x512", flush=True)
    write_canvas(STORE / "feature.png", feature_graphic(), alpha=False)
    print("store/feature.png 1024x500", flush=True)


if __name__ == "__main__":
    main()
