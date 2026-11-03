"""Test kümesini hazırlar: kareleri Vektörel Arama'nın yaptığı gibi okuyup önbelleğe JPEG olarak yazar,
benzer kare testi için değiştirilmiş kopyalar üretir, sorgu listesini yazar.

Kullanım: python hazirla.py <test_klasoru> <fotograf_koku> [--deneme]
  fotograf_koku: etiketler.csv'deki 'yol' sütununun başına eklenecek klasör (örn. /Volumes/Disk/Fotograflar)
Fotoğraflara yalnızca okumak için erişir.
"""
import csv
import json
import random
import sys
import time
from pathlib import Path

from PIL import Image, ImageEnhance, ImageOps

KAVRAMLAR = [
    ("merdiven", "stairs"), ("bisiklet", "bicycle"), ("şemsiye", "umbrella"), ("köpek", "dog"),
    ("kedi", "cat"), ("köprü", "bridge"), ("cami", "mosque"), ("tren", "train"), ("kar", "snow"),
    ("sis", "fog"), ("gün batımı", "sunset"), ("tekne", "boat"), ("motosiklet", "motorcycle"),
    ("heykel", "statue"), ("inek", "cow"), ("koyun", "sheep"), ("minare", "minaret"),
    ("güvercin", "pigeon"), ("martı", "seagull"), ("tramvay", "tram"), ("otobüs", "bus"),
    ("balon", "balloon"), ("ayna", "mirror"), ("gözlük", "glasses"), ("şapka", "hat"),
    ("bayrak", "flag"), ("uçak", "airplane"), ("maske", "mask"), ("kuş", "bird"), ("çiçek", "flower"),
    ("yağmur", "rain"), ("plaj", "beach"), ("balıkçı", "fisherman"), ("araba", "car"),
    ("kapı", "door"), ("pencere", "window"),
]
# 6 Ekim 2026 dil ölçümündeki beş yazım biçimi
BICIMLER = {
    "tr_kelime": lambda tr, en: tr,
    "en_kelime": lambda tr, en: en,
    "tr_cumle": lambda tr, en: f"bir {tr} fotoğrafı",
    "en_cumle": lambda tr, en: f"a photo of a {en}",
    "tr_cumle2": lambda tr, en: f"fotoğrafta {tr} var",
}
MOR = {"Mor", "Purple", "Anı"}  # Okan'ın kataloğunda Mor = "Anı"
VARYANT_SAYISI = 300
RAW = {".raf", ".dng", ".cr2", ".cr3", ".nef", ".arw", ".orf", ".rw2", ".pef"}


def oku(yol: Path) -> Image.Image:
    """Vektörel Arama ile aynı: RAW'da gömülü kamera önizlemesi (kısa kenar < 500 ise yarım boy
    demosaic), diğerlerinde dosyanın kendisi. EXIF'e göre döndürme YOK (canlı sistem de yapmıyor)."""
    if yol.suffix.lower() in RAW:
        import io
        import rawpy
        with rawpy.imread(str(yol)) as r:
            try:
                th = r.extract_thumb()
                if th.format == rawpy.ThumbFormat.JPEG:
                    img = Image.open(io.BytesIO(th.data))
                else:
                    img = Image.fromarray(th.data)
                if min(img.size) >= 500:
                    return img.convert("RGB")
            except Exception:
                pass
            return Image.fromarray(r.postprocess(half_size=True, use_camera_wb=True, no_auto_bright=True)).convert("RGB")
    if yol.suffix.lower() == ".heic":
        import pillow_heif
        pillow_heif.register_heif_opener()
    return Image.open(yol).convert("RGB")


def varyantlar(img: Image.Image):
    w, h = img.size
    yield "kirpma", img.crop((int(w * .1), int(h * .1), int(w * .9), int(h * .9)))
    yield "parlak", ImageEnhance.Brightness(img).enhance(1.4)
    yield "siyahbeyaz", ImageOps.grayscale(img).convert("RGB")
    k = img.copy()
    k.thumbnail((400, 400))
    yield "kucuk", k


def main():
    kok, foto_kok = Path(sys.argv[1]), Path(sys.argv[2])
    deneme = "--deneme" in sys.argv
    ob = kok / "onbellek"
    (ob / "varyant").mkdir(parents=True, exist_ok=True)

    satirlar = list(csv.DictReader(open(kok / "etiketler.csv", encoding="utf-8")))
    secili = [s for s in satirlar if s["sanal"] != "1" and s["renk"].strip() not in MOR]
    if deneme:
        secili = secili[:8]
    print(f"{len(satirlar)} satır; sanal kopya ve Mor dışarıda: {len(secili)} kare")

    liste, hatalar, t0 = [], [], time.time()
    for i, s in enumerate(secili):
        hedef = ob / f"{s['id_local']}.jpg"
        if not hedef.exists():
            try:
                oku(foto_kok / s["yol"]).save(hedef, quality=95)
            except Exception as e:
                hatalar.append({"id_local": s["id_local"], "yol": s["yol"], "hata": str(e)})
                continue
        liste.append({"kimlik": s["id_local"], "dosya": hedef.name, "kaynak": None, "tip": "asil"})
        if i % 250 == 0:
            print(f"hazırlık {i}/{len(secili)}", flush=True)
    sure = time.time() - t0

    random.seed(2026)
    for k in random.sample(liste, min(VARYANT_SAYISI, len(liste)) if not deneme else 2):
        img = Image.open(ob / k["dosya"])
        for tip, v in varyantlar(img):
            ad = f"{k['kimlik']}_{tip}.jpg"
            if not (ob / "varyant" / ad).exists():
                v.save(ob / "varyant" / ad, quality=90)
            liste.append({"kimlik": f"{k['kimlik']}_{tip}", "dosya": f"varyant/{ad}",
                          "kaynak": k["kimlik"], "tip": tip})

    sorgular = [{"kavram": tr, "bicim": b, "metin": f(tr, en)}
                for tr, en in KAVRAMLAR for b, f in BICIMLER.items()]
    (ob / "liste.json").write_text(json.dumps(liste, ensure_ascii=False))
    (kok / "sorgular.json").write_text(json.dumps(sorgular, ensure_ascii=False, indent=1))
    (kok / "hazirlik.json").write_text(json.dumps(
        {"kare": sum(1 for x in liste if x["tip"] == "asil"), "varyant": sum(1 for x in liste if x["tip"] != "asil"),
         "hata": hatalar, "sure_dk": round(sure / 60, 1)}, ensure_ascii=False, indent=1))
    print(f"bitti: {len(liste)} görüntü, {len(hatalar)} hata, {sure / 60:.1f} dk")


if __name__ == "__main__":
    main()
