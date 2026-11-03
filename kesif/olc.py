"""Bütün modellerin vektörlerinden ölçümleri hesaplar, rapor.md, karsilastirma.html ve sonuc.json yazar.

Kullanım: python olc.py <test_klasoru>
Yalnız numpy gerekir. Modeller bitmemişse bitenlerle çalışır.
"""
import csv
import html
import json
import sys
from collections import Counter
from pathlib import Path

import numpy as np

SIRA = ["coreml_base", "coreml_so400m", "coreml_so400m_cpu_and_ne", "coreml_so400m_cpu_and_gpu", "jina_clip_v2", "siglip2_so400m", "siglip2_base", "qwen3_vl_emb_2b", "apple_featureprint"]
ADLAR = {"coreml_base": "SigLIP 2 Base Core ML", "coreml_so400m": "So400m Core ML (tümü)", "coreml_so400m_cpu_and_ne": "So400m Core ML (Neural Engine)", "coreml_so400m_cpu_and_gpu": "So400m Core ML (GPU)", "jina_clip_v2": "Jina-CLIP-v2 (bugünkü)", "siglip2_so400m": "SigLIP 2 So400m",
         "siglip2_base": "SigLIP 2 Base", "qwen3_vl_emb_2b": "Qwen3-VL-Embedding-2B",
         "apple_featureprint": "Apple görsel parmak izi"}
BICIM_AD = {"tr_kelime": "Türkçe kelime", "en_kelime": "İngilizce kelime",
            "tr_cumle": "\"bir … fotoğrafı\"", "en_cumle": "\"a photo of a …\"", "tr_cumle2": "\"fotoğrafta … var\""}
ALTI_KONU = {"Sokak", "Manzara", "Portre", "Cevresel_Portre", "Minimal", "ICM"}  # katalogdaki yazımla
K, OY, EN_AZ_ORNEK, P_AT = 15, 0.8, 5, 50
YESIL = {"Yeşil", "Green", "İşlendi"}  # Okan'ın kataloğunda Yeşil = "İşlendi"


def yukle(kok, ad):
    d = kok / "sonuc" / ad
    if not (d / "BITTI").exists():
        return None
    r = {"V": np.load(d / "kare_vektor.npy"), "kimlik": json.loads((d / "kare_kimlik.json").read_text()),
         "olcum": json.loads((d / "olcum.json").read_text())}
    if (d / "sorgu_vektor.npy").exists():
        r["Q"] = np.load(d / "sorgu_vektor.npy")
    return r


def dil_olcumu(m, asil_idx, etiket_kavram, sorgular, kimlikler):
    """6 Ekim yöntemi: kavram başına precision@50 (+ bu küme küçük olduğu için R-precision ve AP)."""
    V = m["V"][asil_idx]
    ids = [kimlikler[i] for i in asil_idx]
    sonuc = {}
    for b in BICIM_AD:
        p50, rp, ap, say = [], [], [], 0
        for qi, s in enumerate(sorgular):
            if s["bicim"] != b:
                continue
            dogru = np.array([s["kavram"] in etiket_kavram.get(k, ()) for k in ids])
            n = int(dogru.sum())
            if n < EN_AZ_ORNEK:
                continue
            say += 1
            sira = np.argsort(-(V @ m["Q"][qi]))
            d = dogru[sira]
            p50.append(d[:P_AT].mean())
            rp.append(d[:n].mean())
            isabet = np.cumsum(d)
            ap.append(float((isabet[d] / (np.nonzero(d)[0] + 1)).mean()))
        sonuc[b] = {"p50": float(np.mean(p50)) if p50 else None, "rprec": float(np.mean(rp)) if rp else None,
                    "ap": float(np.mean(ap)) if ap else None, "kavram_sayisi": say}
    return sonuc


def janra_olcumu(m, asil_idx, etiket, kimlikler):
    """6 Ekim yöntemi: K=15 komşu, kendisi ve aynı klasör hariç, oy = en sık janra / 15;
    tahmini 6 konudan biri ve oyu ≥ 0,8 olanlarda isabet. Test: Yeşil + janralı; havuz: janralı kareler."""
    ids = [kimlikler[i] for i in asil_idx]
    V = m["V"][asil_idx]
    gt = {k: (etiket[k]["lrskorer_gt"] or etiket[k]["janra"]) for k in ids}
    havuz = [i for i, k in enumerate(ids) if etiket[k]["janra"] and etiket[k]["janra"] not in ("Diğer", "Diger")]
    test = [i for i, k in enumerate(ids) if etiket[k]["renk"].strip() in YESIL and gt[k] and gt[k] not in ("Diğer", "Diger")]
    if not test or not havuz:
        return None
    Hv = V[havuz]
    klasor = [str(Path(etiket[ids[i]]["yol"]).parent) for i in havuz]
    dogru = sayilan = dogru_hepsi = 0
    konu = Counter()
    for i in test:
        k = ids[i]
        kl = str(Path(etiket[k]["yol"]).parent)
        skor = Hv @ V[i]
        komsu = []
        for j in np.argsort(-skor):
            if havuz[j] == i or klasor[j] == kl:
                continue
            komsu.append(etiket[ids[havuz[j]]]["janra"])
            if len(komsu) == K:
                break
        if not komsu:
            continue
        tahmin, adet = Counter(komsu).most_common(1)[0]
        dogru_hepsi += tahmin == gt[k]
        if tahmin in ALTI_KONU and adet / K >= OY:
            sayilan += 1
            dogru += tahmin == gt[k]
            konu[(tahmin, tahmin == gt[k])] += 1
    return {"isabet": dogru / sayilan if sayilan else None, "sayilan": sayilan, "test": len(test),
            "kapsama": sayilan / len(test), "isabet_hepsi": dogru_hepsi / len(test), "havuz": len(havuz),
            "konu": {f"{t}|{'doğru' if d else 'yanlış'}": n for (t, d), n in konu.items()}}


def benzer_olcumu(m, liste, kimlik_idx, asil_idx):
    """Değiştirilmiş kopya (kırpma, parlaklık, siyah-beyaz, küçük) aslını ilk sırada buluyor mu."""
    V = m["V"]
    A = V[asil_idx]
    asil_ids = [liste[i]["kimlik"] for i in asil_idx]
    yer = {k: j for j, k in enumerate(asil_ids)}
    tip_sonuc, benzerlik_asil, benzerlik_ilgisiz = {}, [], []
    for x in liste:
        if x["tip"] == "asil":
            continue
        v = V[kimlik_idx[x["kimlik"]]]
        skor = A @ v
        hedef = yer[x["kaynak"]]
        sira = int((skor > skor[hedef]).sum()) + 1
        tip_sonuc.setdefault(x["tip"], []).append(sira)
        benzerlik_asil.append(float(skor[hedef]))
        skor[hedef] = -9
        benzerlik_ilgisiz.append(float(skor.max()))
    ilk1 = {t: float(np.mean(np.array(s) == 1)) for t, s in tip_sonuc.items()}
    ba, bi = np.array(benzerlik_asil), np.array(benzerlik_ilgisiz)
    return {"ilk1": ilk1, "ilk1_ort": float(np.mean(list(ilk1.values()))) if ilk1 else None,
            "ilk5": float(np.mean([r <= 5 for s in tip_sonuc.values() for r in s])) if tip_sonuc else None,
            "asil_benzerlik_medyan": float(np.median(ba)) if len(ba) else None,
            "en_yakin_baska_medyan": float(np.median(bi)) if len(bi) else None}


def yuzde(x):
    return "—" if x is None else f"%{100 * x:.1f}"


def main():
    kok = Path(sys.argv[1])
    liste = json.loads((kok / "onbellek" / "liste.json").read_text())
    sorgular = json.loads((kok / "sorgular.json").read_text())
    etiket = {s["id_local"]: s for s in csv.DictReader(open(kok / "etiketler.csv", encoding="utf-8"))}
    etiket_kavram = {k: set(filter(None, s["kavramlar"].split("|"))) for k, s in etiket.items()}
    hazirlik = json.loads((kok / "hazirlik.json").read_text())

    tum = {}
    for ad in SIRA:
        m = yukle(kok, ad)
        if m is None:
            continue
        kimlikler = m["kimlik"]
        kimlik_idx = {k: i for i, k in enumerate(kimlikler)}
        asil_idx = [kimlik_idx[x["kimlik"]] for x in liste if x["tip"] == "asil"]
        r = {"olcum": m["olcum"], "benzer": benzer_olcumu(m, liste, kimlik_idx, asil_idx),
             "janra": janra_olcumu(m, asil_idx, etiket, kimlikler)}
        if "Q" in m:
            r["dil"] = dil_olcumu(m, asil_idx, etiket_kavram, sorgular, kimlikler)
        tum[ad] = r
        tum[ad]["_m"] = m
    (kok / "sonuc.json").write_text(json.dumps({a: {k: v for k, v in r.items() if k != "_m"} for a, r in tum.items()},
                                               ensure_ascii=False, indent=1))

    # --------- rapor.md ---------
    s = ["# Vektörel Arama model testi: sonuçlar", "",
         f"Küme: {hazirlik['kare']} kare (sanal kopya ve Mor hariç), benzer kare testi için {hazirlik['varyant']} değiştirilmiş kopya. "
         f"Okunamayan dosya: {len(hazirlik['hata'])}. Görüntü hazırlama: {hazirlik['sure_dk']} dk.", "",
         "## Hız ve boyut", "",
         "| Model | Yükleme | Kare başına | Bütün kareler | Sorgu | Tepe bellek (RAM / GPU) | Model diski | Vektör boyu | İndeks |",
         "|---|---|---|---|---|---|---|---|---|"]
    for ad, r in tum.items():
        o = r["olcum"]
        s.append(f"| {ADLAR[ad]} | {o['yukleme_sn']} sn | {o['kare_basina_sn']} sn | {o['kare_toplam_dk']} dk | "
                 f"{o.get('sorgu_ort_ms', '—')} ms | {o['tepe_ram_gb']} / {o['tepe_mps_gb']} GB | "
                 f"{o.get('model_disk_gb', '—')} GB | {o['vektor_boyu']} | {o['indeks_mb']} MB |")
    s += ["", f"200.000 kare için tahmin = kare başına süre × 200.000 (görüntü okuma hariç).", "",
          "## Yazıyla arama (dil ölçümü)", "",
          f"6 Ekim yöntemi: kavram başına ilk {P_AT} sonuçta doğru oranı (precision@{P_AT}). "
          f"Doğru = karede kavramla tam aynı anahtar kelime var. Bu kümede en az {EN_AZ_ORNEK} karede geçen kavramlar sayıldı. "
          f"Küme küçük olduğu için bazı kavramlarda 50'den az doğru kare var; bu yüzden ayrıca 'R-hassasiyet' "
          f"(doğru kare sayısı kadar ilk sonuçta doğru oranı) ve ortalama hassasiyet (AP) verildi. Asıl karşılaştırma için AP'ye bakın.", ""]
    dil_modeller = [a for a in tum if "dil" in tum[a]]
    if dil_modeller:
        s.append("| Sorgu biçimi | " + " | ".join(ADLAR[a] for a in dil_modeller) + " |")
        s.append("|---|" + "---|" * len(dil_modeller))
        for b, bad in BICIM_AD.items():
            s.append(f"| {bad} (AP / P@50 / R) | " + " | ".join(
                f"{yuzde(tum[a]['dil'][b]['ap'])} / {yuzde(tum[a]['dil'][b]['p50'])} / {yuzde(tum[a]['dil'][b]['rprec'])}"
                for a in dil_modeller) + " |")
        s.append(f"\nSayılan kavram: {tum[dil_modeller[0]]['dil']['tr_kelime']['kavram_sayisi']} / 36.")
    s += ["", "## Janra komşuluğu", "",
          f"6 Ekim yöntemi: {K} en yakın komşu, kendisi ve aynı klasördekiler hariç; oy ≥ {OY} ve tahmin 6 konudan biriyse sayılır. "
          "Test: Yeşil ve janrası belli kareler; komşu havuzu: janrası belli kareler.", "",
          "| Model | İsabet (oy ≥ 0,8) | Sayılan / test | Oy şartsız isabet |", "|---|---|---|---|"]
    for ad, r in tum.items():
        j = r["janra"]
        if j:
            s.append(f"| {ADLAR[ad]} | {yuzde(j['isabet'])} | {j['sayilan']} / {j['test']} | {yuzde(j['isabet_hepsi'])} |")
    s += ["", "## Benzer kare", "",
          "Rastgele 300 karenin kırpılmış, parlatılmış, siyah-beyaz ve küçültülmüş kopyaları arandı: aslı ilk sırada mı?", "",
          "| Model | Kırpma | Parlak | Siyah-beyaz | Küçük | İlk 5'te | Aslına benzerlik (medyan) | En yakın başka kare (medyan) |",
          "|---|---|---|---|---|---|---|---|"]
    for ad, r in tum.items():
        b = r["benzer"]
        s.append(f"| {ADLAR[ad]} | " + " | ".join(yuzde(b["ilk1"].get(t)) for t in ["kirpma", "parlak", "siyahbeyaz", "kucuk"])
                 + f" | {yuzde(b['ilk5'])} | {b['asil_benzerlik_medyan']:.3f} | {b['en_yakin_baska_medyan']:.3f} |")
    (kok / "rapor.md").write_text("\n".join(s), encoding="utf-8")

    # --------- karsilastirma.html: örnek sorgularda ilk 20 kare ---------
    if dil_modeller:
        asil = [x for x in liste if x["tip"] == "asil"]
        sayac = Counter(k for x in asil for k in etiket_kavram.get(x["kimlik"], ()))
        ornek = [k for k, _ in sayac.most_common(8)]
        h = ["<!doctype html><meta charset=utf-8><title>Model karşılaştırma</title><style>",
             "body{font-family:-apple-system,sans-serif;background:#111;color:#eee;margin:16px}",
             "img{height:90px;margin:2px;border:3px solid #333}img.d{border-color:#3c3}",
             "h2{margin-top:32px}h3{font-weight:normal;margin:8px 0 2px}</style>",
             "<h1>Örnek sorgularda ilk 20 kare</h1><p>Yeşil çerçeve: karede o anahtar kelime var.</p>"]
        for kv in ornek:
            for b in ["tr_cumle", "en_cumle"]:
                qi = next(i for i, q in enumerate(sorgular) if q["kavram"] == kv and q["bicim"] == b)
                h.append(f"<h2>{html.escape(sorgular[qi]['metin'])}</h2>")
                for a in dil_modeller:
                    m = tum[a]["_m"]
                    kimlik_idx = {k: i for i, k in enumerate(m["kimlik"])}
                    idx = [kimlik_idx[x["kimlik"]] for x in asil]
                    sira = np.argsort(-(m["V"][idx] @ m["Q"][qi]))[:20]
                    h.append(f"<h3>{ADLAR[a]}</h3><div>")
                    for j in sira:
                        x = asil[j]
                        c = " class=d" if kv in etiket_kavram.get(x["kimlik"], ()) else ""
                        h.append(f"<img{c} src='onbellek/{x['dosya']}' loading=lazy title='{x['kimlik']}'>")
                    h.append("</div>")
        (kok / "karsilastirma.html").write_text("\n".join(h), encoding="utf-8")
    print((kok / "rapor.md").read_text())


if __name__ == "__main__":
    main()
