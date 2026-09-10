"""Reduz os sprites de veículo do mapa de 1024x1024 pra 128x128.

Os sprites eram renders 3D em alta resolução (1024px, ~110KB cada, 384
arquivos = ~42MB). No mapa eles aparecem em ~40-50px -- 128px já é 2.5x
disso, mais que suficiente pra telas retina. O bundle web de 200MB
estava crashando o Chrome do celular por falta de memória (2026-09-10).

Sobrescreve os PNGs no lugar. Se precisar dos originais em alta,
recuperar do git (assets/3d_source/*.glb + re-render) ou do commit
anterior.
"""
import glob
from PIL import Image

TARGET = 128
files = glob.glob("assets/icons/map_sprites/**/*.png", recursive=True)
total_before = 0
total_after = 0
import os

for f in files:
    total_before += os.path.getsize(f)
    im = Image.open(f).convert("RGBA")
    if im.size != (TARGET, TARGET):
        im = im.resize((TARGET, TARGET), Image.LANCZOS)
    im.save(f, optimize=True)
    total_after += os.path.getsize(f)

print(f"{len(files)} sprites: {total_before/1e6:.1f}MB -> {total_after/1e6:.1f}MB")
