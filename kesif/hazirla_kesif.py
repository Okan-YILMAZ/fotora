"""Keşif denemesi: 2024 kümesini iki biçimde hazırlar (duz/ ve yon/), model testindeki küme ve ölçümlerle.
Kullanım: python hazirla_kesif.py <kesif_klasoru> <kareler.csv> <fotograf_koku>"""
import csv, json, random, sys, time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from PIL import Image
sys.path.insert(0, str(Path(__file__).parent))
import goruntu, hazirla

kok, kareler, foto = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
yon = {r["id_local"]: r["yon"] for r in csv.DictReader(open(kareler, encoding="utf-8"))}
satir = [s for s in csv.DictReader(open(kok / "etiketler.csv", encoding="utf-8"))
         if s["sanal"] != "1" and s["renk"].strip() not in hazirla.MOR]
for ad in ("duz", "yon"):
    (kok / ad / "onbellek" / "varyant").mkdir(parents=True, exist_ok=True)
    (kok / ad / "etiketler.csv").write_bytes((kok / "etiketler.csv").read_bytes())

def isle(s):
    hedefler = [kok / ad / "onbellek" / f"{s['id_local']}.jpg" for ad in ("duz", "yon")]
    if all(h.exists() for h in hedefler):
        return s, None
    try:
        for h, d in zip(hedefler, (False, True)):
            goruntu.oku(foto / s["yol"], yon[s["id_local"]], dondur=d).save(h, quality=95)
        return s, None
    except Exception as e:
        return s, str(e)

t0 = time.time(); hatalar = []; tamam = []
with ThreadPoolExecutor(6) as ex:
    for i, (s, h) in enumerate(ex.map(isle, satir)):
        (hatalar.append({"id_local": s["id_local"], "yol": s["yol"], "hata": h}) if h else tamam.append(s["id_local"]))
        if i % 500 == 0: print(i, len(satir), flush=True)
sure = (time.time() - t0) / 60
random.seed(2026)
ornek = random.sample(tamam, 300)
sorgular = [{"kavram": tr, "bicim": b, "metin": f(tr, en)} for tr, en in hazirla.KAVRAMLAR for b, f in hazirla.BICIMLER.items()]
for ad in ("duz", "yon"):
    ob = kok / ad / "onbellek"
    liste = [{"kimlik": k, "dosya": f"{k}.jpg", "kaynak": None, "tip": "asil"} for k in tamam]
    for k in ornek:
        img = Image.open(ob / f"{k}.jpg")
        for tip, v in hazirla.varyantlar(img):
            n = f"{k}_{tip}.jpg"
            if not (ob / "varyant" / n).exists(): v.save(ob / "varyant" / n, quality=90)
            liste.append({"kimlik": f"{k}_{tip}", "dosya": f"varyant/{n}", "kaynak": k, "tip": tip})
    (ob / "liste.json").write_text(json.dumps(liste, ensure_ascii=False))
    (kok / ad / "sorgular.json").write_text(json.dumps(sorgular, ensure_ascii=False, indent=1))
    (kok / ad / "hazirlik.json").write_text(json.dumps({"kare": len(tamam), "varyant": len(liste) - len(tamam), "hata": hatalar, "sure_dk": round(sure, 1)}, ensure_ascii=False, indent=1))
print("bitti", len(tamam), "hata", len(hatalar), f"{sure:.1f} dk")
