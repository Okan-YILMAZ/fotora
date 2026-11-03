"""Bir modelle önbellekteki kareleri ve sorguları vektöre çevirir, süre/bellek ölçer.

Kullanım: python gom.py <model_adi> <test_klasoru>
Çıktı: <test_klasoru>/sonuc/<model_adi>/ altında
  kare_vektor.npy, kare_kimlik.json, sorgu_vektor.npy, sorgu.json, olcum.json, BITTI
Kaldığı yerden devam eder: kare vektörleri parça parça (her 256 kare) kaydedilir.
"""
import json
import os
import platform
import subprocess
import sys
import threading
import time
from pathlib import Path

import numpy as np
import psutil

MODELLER = {
    "jina_clip_v2": {"hf": "jinaai/jina-clip-v2", "parti": 8},
    "siglip2_so400m": {"hf": "google/siglip2-so400m-patch16-384", "parti": 8},
    "siglip2_base": {"hf": "google/siglip2-base-patch16-256", "parti": 16},
    "qwen3_vl_emb_2b": {"hf": "Qwen/Qwen3-VL-Embedding-2B", "parti": 2},
    "apple_featureprint": {"hf": None, "parti": 1},
}
PARCA = 256


class BellekIzci:
    """Süreç belleğinin (RSS) ve MPS ayrılmış belleğinin tepe değerini izler."""

    def __init__(self):
        self.tepe_rss = 0
        self.tepe_mps = 0
        self._dur = False
        self._p = psutil.Process()
        threading.Thread(target=self._dongu, daemon=True).start()

    def _dongu(self):
        while not self._dur:
            self.tepe_rss = max(self.tepe_rss, self._p.memory_info().rss)
            try:
                import torch
                if torch.backends.mps.is_available():
                    self.tepe_mps = max(self.tepe_mps, torch.mps.driver_allocated_memory())
            except Exception:
                pass
            time.sleep(0.5)

    def ozet(self):
        return {"tepe_ram_gb": round(self.tepe_rss / 1e9, 2), "tepe_mps_gb": round(self.tepe_mps / 1e9, 2)}


def hf_boyut(hf_id):
    """Modelin Hugging Face önbelleğindeki disk boyutu (GB)."""
    from huggingface_hub import scan_cache_dir
    for repo in scan_cache_dir().repos:
        if repo.repo_id == hf_id:
            return round(repo.size_on_disk / 1e9, 2)
    return None


# ---------------- model sarmalayıcıları ----------------

def cihaz():
    import torch
    return "mps" if torch.backends.mps.is_available() else "cpu"


class Jina:
    def __init__(self, hf):
        import torch
        from transformers import AutoModel
        self.torch = torch
        self.m = AutoModel.from_pretrained(hf, trust_remote_code=True).to(cihaz()).eval()
        self.boyut = int(os.environ.get("JINA_BOYUT", "512"))

    def kareler(self, yollar):
        with self.torch.no_grad():
            v = self.m.encode_image(yollar, truncate_dim=self.boyut)
        return np.asarray(v, dtype=np.float32)

    def metinler(self, metinler):
        with self.torch.no_grad():
            v = self.m.encode_text(metinler, truncate_dim=self.boyut)
        return np.asarray(v, dtype=np.float32)


class Siglip:
    def __init__(self, hf):
        import torch
        from transformers import AutoModel, AutoProcessor
        self.torch = torch
        self.d = cihaz()
        self.m = AutoModel.from_pretrained(hf).to(self.d).eval()
        self.p = AutoProcessor.from_pretrained(hf)

    def kareler(self, yollar):
        from PIL import Image
        imgs = [Image.open(y).convert("RGB") for y in yollar]
        x = self.p(images=imgs, return_tensors="pt").to(self.d)
        with self.torch.no_grad():
            v = self.m.get_image_features(**x)
        return v.float().cpu().numpy()

    def metinler(self, metinler):
        # SigLIP küçük harfli metinle eğitildi
        x = self.p(text=[t.lower() for t in metinler], padding="max_length", max_length=64,
                   truncation=True, return_tensors="pt").to(self.d)
        with self.torch.no_grad():
            v = self.m.get_text_features(**x)
        return v.float().cpu().numpy()


class Qwen:
    TALIMAT_SORGU = "Retrieve photographs that match the user's description."

    def __init__(self, hf):
        import torch
        from sentence_transformers import SentenceTransformer
        self.m = SentenceTransformer(hf, device=cihaz(), model_kwargs={"torch_dtype": torch.float16})

    def kareler(self, yollar):
        return np.asarray(self.m.encode([{"image": str(Path(y).resolve())} for y in yollar]),
                          dtype=np.float32)

    def metinler(self, metinler):
        return np.asarray(self.m.encode(metinler, prompt=self.TALIMAT_SORGU), dtype=np.float32)


class AppleParmakIzi:
    """macOS Vision VNGenerateImageFeaturePrintRequest. Yalnız kareden kareye."""

    def __init__(self, hf):
        import Vision  # pyobjc-framework-Vision
        from Foundation import NSURL
        self.V, self.NSURL = Vision, NSURL

    def kareler(self, yollar):
        out = []
        for y in yollar:
            req = self.V.VNGenerateImageFeaturePrintRequest.alloc().init()
            h = self.V.VNImageRequestHandler.alloc().initWithURL_options_(
                self.NSURL.fileURLWithPath_(str(y)), None)
            ok, err = h.performRequests_error_([req], None)
            if not ok:
                raise RuntimeError(str(err))
            obs = req.results()[0]
            n = obs.elementCount()
            veri = bytes(obs.data())
            dt = np.float32 if obs.elementType() == 1 else np.float64
            out.append(np.frombuffer(veri, dtype=dt)[:n].astype(np.float32))
        return np.stack(out)

    def metinler(self, metinler):
        return None


SINIF = {"jina_clip_v2": Jina, "siglip2_so400m": Siglip, "siglip2_base": Siglip,
         "qwen3_vl_emb_2b": Qwen, "apple_featureprint": AppleParmakIzi}


def normalize(v):
    return v / np.linalg.norm(v, axis=1, keepdims=True).clip(1e-12)


def main():
    ad, kok = sys.argv[1], Path(sys.argv[2])
    ayar = MODELLER[ad]
    cikti = kok / "sonuc" / ad
    cikti.mkdir(parents=True, exist_ok=True)
    if (cikti / "BITTI").exists():
        print(f"{ad}: zaten bitmiş, atlanıyor")
        return
    liste = json.loads((kok / "onbellek" / "liste.json").read_text())
    kimlikler = [k["kimlik"] for k in liste]
    yollar = [str(kok / "onbellek" / k["dosya"]) for k in liste]
    sorgular = json.loads((kok / "sorgular.json").read_text())

    izci = BellekIzci()
    olcum = {"model": ad, "hf": ayar["hf"], "makine": platform.machine(),
             "islemci": subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"],
                                       capture_output=True, text=True).stdout.strip(),
             "ram_gb": round(psutil.virtual_memory().total / 1e9, 1)}

    t0 = time.time()
    model = SINIF[ad](ayar["hf"])
    olcum["yukleme_sn"] = round(time.time() - t0, 1)
    if ayar["hf"]:
        olcum["model_disk_gb"] = hf_boyut(ayar["hf"])

    # Kareler: parça parça, kaldığı yerden devam
    parca_dir = cikti / "parcalar"
    parca_dir.mkdir(exist_ok=True)
    sure_kare = float(json.loads((cikti / "sure.json").read_text())["sn"]) if (cikti / "sure.json").exists() else 0.0
    # ısınma (ilk çağrı ölçüme girmez)
    model.kareler(yollar[:1])
    for bas in range(0, len(yollar), PARCA):
        dosya = parca_dir / f"{bas:06d}.npy"
        if dosya.exists():
            continue
        t = time.time()
        vs = []
        for i in range(bas, min(bas + PARCA, len(yollar)), ayar["parti"]):
            vs.append(model.kareler(yollar[i:i + ayar["parti"]]))
        np.save(dosya, np.concatenate(vs))
        sure_kare += time.time() - t
        (cikti / "sure.json").write_text(json.dumps({"sn": sure_kare}))
        print(f"{ad}: {min(bas + PARCA, len(yollar))}/{len(yollar)} kare, {sure_kare / 60:.1f} dk", flush=True)
    V = normalize(np.concatenate([np.load(f) for f in sorted(parca_dir.glob("*.npy"))]))
    np.save(cikti / "kare_vektor.npy", V)
    (cikti / "kare_kimlik.json").write_text(json.dumps(kimlikler))
    olcum["kare_sayisi"] = len(yollar)
    olcum["kare_toplam_dk"] = round(sure_kare / 60, 1)
    olcum["kare_basina_sn"] = round(sure_kare / len(yollar), 3)
    olcum["vektor_boyu"] = int(V.shape[1])
    olcum["indeks_mb"] = round(V.astype(np.float32).nbytes / 1e6, 1)

    # Sorgular (her biri tek tek: arama anındaki gecikmeyi ölçmek için)
    metinler = [s["metin"] for s in sorgular]
    if model.metinler(metinler[:1]) is not None:
        sureler, Q = [], []
        for m in metinler:
            t = time.time()
            Q.append(model.metinler([m])[0])
            sureler.append(time.time() - t)
        np.save(cikti / "sorgu_vektor.npy", normalize(np.stack(Q)))
        olcum["sorgu_ort_ms"] = round(1000 * float(np.mean(sureler)), 1)
    olcum.update(izci.ozet())
    (cikti / "olcum.json").write_text(json.dumps(olcum, ensure_ascii=False, indent=2))
    (cikti / "BITTI").write_text("tamam")
    print(f"{ad}: bitti {olcum}")


if __name__ == "__main__":
    main()
