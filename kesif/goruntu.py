"""Kare okuma: Vektörel Arama ile aynı kaynak (RAW gömülü önizleme / dosya), uzun kenar 1024.
dondur=True: LrC yönüne çevir (katalog 'yon'). dondur=False: canlı sistem gibi, döndürme yok."""
import csv
import io
import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import numpy as np
from PIL import Image

MODELLER = {"so400m": ("google/siglip2-so400m-patch16-384", 8), "base": ("google/siglip2-base-patch16-256", 16)}
PARCA = 1024
RAW = {".raf", ".nef", ".nrw", ".arw", ".arq", ".sr2", ".srf", ".cr2", ".cr3", ".crw", ".dng", ".orf", ".rw2",
       ".pef", ".srw", ".rwl", ".3fr", ".iiq", ".x3f", ".dcr", ".kdc", ".mrw", ".mos", ".erf", ".raw"}
# LrC yönü -> saat yönünde derece. Aynalı kodlar (BA, CB, DC: arşivde 7 kare) döndürülmez.
LRC_ACI = {"AB": 0, "BC": 90, "CD": 180, "DA": 270}
FLIP_ACI = {0: 0, 3: 180, 5: 270, 6: 90}  # LibRaw flip -> derece
DONDUR = {90: Image.Transpose.ROTATE_270, 180: Image.Transpose.ROTATE_180, 270: Image.Transpose.ROTATE_90}
ON_BOYUT = 1024  # modele 384 px gider; okurken uzun kenarı 1024'e indirmek belleği ve süreyi düşürür


def oku(yol: Path, yon: str, dondur: bool = True) -> Image.Image:
    """Kareyi okur, LrC'de göründüğü yöne çevirir. Dönen görüntü uzun kenarı en çok ON_BOYUT."""
    aci = LRC_ACI.get(yon, 0)
    ext = yol.suffix.lower()
    img = None
    if ext in RAW:
        import rawpy
        with rawpy.imread(str(yol)) as r:
            dosya_aci = FLIP_ACI.get(r.sizes.flip, 0)
            sensor_yatay = r.sizes.width >= r.sizes.height
            try:
                th = r.extract_thumb()
                img = Image.open(io.BytesIO(th.data)) if th.format == rawpy.ThumbFormat.JPEG else Image.fromarray(th.data)
                if min(img.size) < 500:
                    img = None
                elif dosya_aci in (90, 270) and (img.width >= img.height) != sensor_yatay:
                    aci -= dosya_aci  # bazı Nikon önizlemeleri zaten dik gömülü
            except Exception:
                img = None
            if img is None:
                # LibRaw demosaic dosyanın kendi yönünü zaten uygular
                img = Image.fromarray(r.postprocess(half_size=True, use_camera_wb=True, no_auto_bright=True))
                aci -= dosya_aci
    elif ext in (".heic", ".heif"):
        import pillow_heif
        pillow_heif.register_heif_opener()
        img = Image.open(yol)
        aci = 0  # pillow-heif yönü kendisi uygular
    else:
        img = Image.open(yol)
    img.draft("RGB", (ON_BOYUT, ON_BOYUT))  # JPEG'de hızlı küçültülmüş açma; diğerlerinde etkisiz
    img = img.convert("RGB")
    img.thumbnail((ON_BOYUT, ON_BOYUT), Image.Resampling.LANCZOS)
    if not dondur:
        return img  # canlı sistem gibi: hiç döndürme yok
    aci %= 360
    return img.transpose(DONDUR[aci]) if aci else img


