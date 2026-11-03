"""Core ML'e çevrilmiş So400m ile gom.py'nin yaptığını yapar; çıktı biçimi aynı (olc.py okur).
Kullanım: HF_HOME=hf python coreml_gom.py <coreml_klasoru> <test_klasoru> [ALL|CPU_AND_NE|CPU_AND_GPU]
Çıktı: <test_klasoru>/sonuc/coreml_so400m[_<birim>]/"""
import json
import platform
import sys
import time
from pathlib import Path

import coremltools as ct
import numpy as np
import psutil
from PIL import Image
from transformers import AutoProcessor

ml_dir, kok = Path(sys.argv[1]), Path(sys.argv[2])
birim = sys.argv[3] if len(sys.argv) > 3 else "ALL"
HF = sys.argv[4] if len(sys.argv) > 4 else "google/siglip2-so400m-patch16-384"
ad = sys.argv[5] if len(sys.argv) > 5 else ("coreml_so400m" if birim == "ALL" else f"coreml_so400m_{birim.lower()}")
cikti = kok / "sonuc" / ad
cikti.mkdir(parents=True, exist_ok=True)
liste = json.loads((kok / "onbellek" / "liste.json").read_text())
sorgular = json.loads((kok / "sorgular.json").read_text())
p = AutoProcessor.from_pretrained(HF)
cu = getattr(ct.ComputeUnit, birim)

t0 = time.time()
g = ct.models.MLModel(str(ml_dir / "goruntu.mlpackage"), compute_units=cu)
m = ct.models.MLModel(str(ml_dir / "metin.mlpackage"), compute_units=cu)
yukleme = time.time() - t0


def kare(yol):
    x = p(images=[Image.open(yol).convert("RGB")], return_tensors="np")["pixel_values"].astype(np.float32)
    return g.predict({"pixel_values": x.astype(np.float32)})["vektor"][0]


kare(kok / "onbellek" / liste[0]["dosya"])  # ısınma
V, t_model = [], 0.0
for i, x in enumerate(liste):
    t = time.time()
    V.append(kare(kok / "onbellek" / x["dosya"]))
    t_model += time.time() - t
    if i % 1000 == 0:
        print(f"{ad}: {i}/{len(liste)}", flush=True)
V = np.stack(V).astype(np.float32)
V /= np.linalg.norm(V, axis=1, keepdims=True).clip(1e-12)
np.save(cikti / "kare_vektor.npy", V)
(cikti / "kare_kimlik.json").write_text(json.dumps([x["kimlik"] for x in liste]))

Q, sureler = [], []
for s in sorgular:
    t = time.time()
    ids = p(text=[s["metin"].lower()], padding="max_length", max_length=64, truncation=True,
            return_tensors="np")["input_ids"].astype(np.int32)
    Q.append(m.predict({"input_ids": ids})["vektor"][0])
    sureler.append(time.time() - t)
Q = np.stack(Q).astype(np.float32)
np.save(cikti / "sorgu_vektor.npy", Q / np.linalg.norm(Q, axis=1, keepdims=True))

boyut = sum(f.stat().st_size for f in ml_dir.rglob("*") if f.is_file()) / 1e9
olcum = {"model": ad, "hf": HF, "makine": platform.machine(), "birim": birim,
         "ram_gb": round(psutil.virtual_memory().total / 1e9, 1), "yukleme_sn": round(yukleme, 1),
         "model_disk_gb": round(boyut, 2), "kare_sayisi": len(liste), "kare_toplam_dk": round(t_model / 60, 1),
         "kare_basina_sn": round(t_model / len(liste), 3), "vektor_boyu": int(V.shape[1]),
         "indeks_mb": round(V.nbytes / 1e6, 1), "sorgu_ort_ms": round(1000 * float(np.mean(sureler)), 1),
         "tepe_ram_gb": round(psutil.Process().memory_info().rss / 1e9, 2), "tepe_mps_gb": 0}
(cikti / "olcum.json").write_text(json.dumps(olcum, ensure_ascii=False, indent=2))
(cikti / "BITTI").write_text("tamam")
print(f"{ad}: bitti {olcum}")
