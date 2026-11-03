"""SigLIP 2 modelinin görüntü ve metin kollarını Core ML'e (yarım hassasiyet) çevirir.
Kullanım: HF_HOME=hf python coreml_cevir.py <cikti_klasoru> [hf_model]  (varsayılan So400m)
Çıktı: goruntu.mlpackage (girdi: 1x3x384x384, işlemcinin normalize ettiği piksel), metin.mlpackage (girdi: 1x64 token)."""
import sys
import time
from pathlib import Path

import coremltools as ct
import numpy as np
import torch
from transformers import AutoModel

cikti = Path(sys.argv[1])
HF = sys.argv[2] if len(sys.argv) > 2 else "google/siglip2-so400m-patch16-384"
cikti.mkdir(parents=True, exist_ok=True)
m = AutoModel.from_pretrained(HF, torch_dtype=torch.float32).eval()


def bas_ileri(self, h):
    """Havuzlama başı: nn.MultiheadAttention Core ML'e çevrilemiyor; aynı hesap elle (tek sorgu = probe)."""
    a = self.attention
    E, H = a.embed_dim, a.num_heads
    d = E // H
    Wq, Wk, Wv = a.in_proj_weight.split(E)
    bq, bk, bv = a.in_proj_bias.split(E)
    B, N, _ = h.shape
    q = (self.probe @ Wq.T + bq).reshape(1, 1, H, d).transpose(1, 2)            # 1,H,1,d
    k = (h @ Wk.T + bk).reshape(B, N, H, d).transpose(1, 2)                    # B,H,N,d
    v = (h @ Wv.T + bv).reshape(B, N, H, d).transpose(1, 2)
    w = torch.softmax((q @ k.transpose(-1, -2)) / d ** 0.5, dim=-1)            # B,H,1,N
    x = (w @ v).transpose(1, 2).reshape(B, 1, E)
    x = a.out_proj(x)
    x = x + self.mlp(self.layernorm(x))
    return x[:, 0]


bas = m.vision_model.head
with torch.no_grad():
    vc = m.config.vision_config
    ornek_h = torch.randn(2, (vc.image_size // vc.patch_size) ** 2, vc.hidden_size)
    fark = (bas(ornek_h) - bas_ileri(bas, ornek_h)).abs().max().item()
assert fark < 1e-4, fark
bas.forward = bas_ileri.__get__(bas)


class Goruntu(torch.nn.Module):
    def __init__(self, m):
        super().__init__()
        self.m = m

    def forward(self, pixel_values):
        return self.m.get_image_features(pixel_values=pixel_values)


class Metin(torch.nn.Module):
    def __init__(self, m):
        super().__init__()
        self.m = m

    def forward(self, input_ids):
        return self.m.get_text_features(input_ids=input_ids)


for ad, mod, ornek, girdi in [
    ("goruntu", Goruntu(m), torch.rand(1, 3, m.config.vision_config.image_size, m.config.vision_config.image_size) * 2 - 1, ct.TensorType(name="pixel_values", shape=(1, 3, m.config.vision_config.image_size, m.config.vision_config.image_size))),
    ("metin", Metin(m), torch.randint(0, 1000, (1, 64)), ct.TensorType(name="input_ids", shape=(1, 64), dtype=np.int32)),
]:
    t = time.time()
    with torch.no_grad():
        iz = torch.jit.trace(mod, ornek)
    ml = ct.convert(iz, inputs=[girdi], outputs=[ct.TensorType(name="vektor")],
                    compute_precision=ct.precision.FLOAT16, minimum_deployment_target=ct.target.macOS15,
                    convert_to="mlprogram")
    ml.save(str(cikti / f"{ad}.mlpackage"))
    print(ad, f"{time.time() - t:.0f} sn", flush=True)
