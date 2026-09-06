"""Gera os icones do PWA (web/icons/*) a partir do logo da marca
(assets/branding/soutracking_icon_lamp.png).

- Icon-192/512: logo com fundo transparente, redimensionado (para
  navegadores/launchers que respeitam transparencia).
- Icon-maskable-192/512: fundo solido na cor da marca (#1F6FEB) com o
  logo centralizado ocupando ~65% da area (zona segura do padrao
  maskable-icon -- launchers Android recortam em circulo/squircle e
  cortam ate 20% de cada borda).

2026-09-06 -- antes disso os 4 arquivos eram copias identicas do PNG
original (mesmo tamanho de arquivo), sem redimensionar nem gerar a
variante maskable de verdade.
"""
from PIL import Image

SRC = "assets/branding/soutracking_icon_lamp.png"
OUT_DIR = "web/icons"
BRAND_COLOR = (31, 111, 235, 255)  # #1F6FEB

def load_with_transparent_background() -> Image.Image:
    # O PNG de origem NAO tem alpha real -- fundo eh branco solido (o
    # "xadrez" que aparece ao visualizar eh so o placeholder do proprio
    # visualizador). Faz chroma-key no branco pra extrair so o desenho.
    src = Image.open(SRC).convert("RGBA")
    data = src.getdata()
    new_data = []
    for r, g, b, a in data:
        # Distancia ao branco -- pixels de anti-aliasing perto da borda dos
        # tracos ficam parcialmente brancos; um corte binario deixava
        # "ruido" serrilhado nessas bordas. Alpha proporcional a distancia
        # do branco resolve a transicao suave (branco puro = 0, cor solida
        # do desenho = 255).
        whiteness = min(r, g, b)
        if whiteness > 235:
            new_data.append((r, g, b, 0))
        elif whiteness > 180:
            fade = int((235 - whiteness) / (235 - 180) * 255)
            new_data.append((r, g, b, min(a, fade)))
        else:
            new_data.append((r, g, b, a))
    src.putdata(new_data)
    return src

def make_plain(size: int) -> Image.Image:
    src = load_with_transparent_background()
    return src.resize((size, size), Image.LANCZOS)

def make_maskable(size: int) -> Image.Image:
    src = load_with_transparent_background()
    canvas = Image.new("RGBA", (size, size), BRAND_COLOR)
    # Logo ocupa ~65% do canvas, centralizado -- deixa margem de sobra
    # dentro da "zona segura" de 80% que o padrao maskable exige.
    logo_size = int(size * 0.65)
    logo = src.resize((logo_size, logo_size), Image.LANCZOS)
    offset = ((size - logo_size) // 2, (size - logo_size) // 2)
    canvas.paste(logo, offset, logo)
    return canvas

for size in (192, 512):
    make_plain(size).save(f"{OUT_DIR}/Icon-{size}.png")
    make_maskable(size).save(f"{OUT_DIR}/Icon-maskable-{size}.png")

# Favicon -- antes era o PNG original de 1254x1254 sem redimensionar
# (mesmo arquivo pesado servido como icone de aba). 32x32 eh o tamanho
# padrao de favicon, arquivo bem mais leve.
make_plain(32).save("web/favicon.png")

print("Icones gerados com sucesso.")
