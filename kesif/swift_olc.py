"""Swift tarama motorunun dizinini keşif denemesindeki Core ML (Python) sonucuyla aynı ölçümle karşılaştırır.
Kullanım: python swift_olc.py <dizin.sqlite> <kareler.csv>   (kesif/ klasöründen)"""
import csv
import json
import sqlite3
import sys

import numpy as np

import olc

dizin, kareler = sys.argv[1], sys.argv[2]
uuid_id = {r["image_uuid"]: r["id_local"] for r in csv.DictReader(open(kareler, encoding="utf-8"))}
etiket = {s["id_local"]: s for s in csv.DictReader(open("etiketler.csv", encoding="utf-8"))}
etiket_kavram = {k: set(filter(None, s["kavramlar"].split("|"))) for k, s in etiket.items()}
sorgular = json.load(open("yon/sorgular.json"))

d = "yon/sonuc/coreml_so400m/"
ref = {"V": np.load(d + "kare_vektor.npy"), "Q": np.load(d + "sorgu_vektor.npy")}
ref_ids = json.load(open(d + "kare_kimlik.json"))
sw = {uuid_id[u]: np.frombuffer(b, dtype=np.float16).astype(np.float32)
      for u, b in sqlite3.connect(dizin).execute("SELECT uuid, vektor FROM kare WHERE durum='tamam'")}
ortak = [i for i, k in enumerate(ref_ids) if "_" not in k and k in sw]
ids = [ref_ids[i] for i in ortak]
Vs = np.stack([sw[k] for k in ids])
Vs /= np.linalg.norm(Vs, axis=1, keepdims=True)
Vr = ref["V"][ortak]
print(f"ortak kare: {len(ids)}, aynı karede benzerlik medyan {np.median((Vs * Vr).sum(1)):.4f}")
for ad, V in (("Python Core ML", Vr), ("Swift motoru", Vs)):
    m = {"V": V, "Q": ref["Q"]}
    idx = list(range(len(ids)))
    dil = olc.dil_olcumu(m, idx, etiket_kavram, sorgular, ids)
    j = olc.janra_olcumu(m, idx, etiket, ids)
    print(ad, " | ".join(f"{b} {100 * dil[b]['ap']:.1f}" for b in olc.BICIM_AD), f"| janra {100 * j['isabet']:.1f}")
