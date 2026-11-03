#!/bin/bash
# Keşif zinciri: hazırlık bitince PyTorch (düz, yönlü) ve Core ML (yönlü) gömme, sonra ölçüm.
K="$(cd "$(dirname "$0")" && pwd)"; cd "$K"
export HF_HOME="$K/hf" HF_HUB_OFFLINE=1
until grep -q "^bitti" hazirla.log; do sleep 20; done
for t in duz yon; do .venv/bin/python gom.py siglip2_so400m $t > gom_$t.log 2>&1 || echo "HATA gom $t"; done
.venv/bin/python coreml_gom.py coreml yon ALL > coreml_all.log 2>&1 || echo "HATA coreml ALL"
.venv/bin/python coreml_gom.py coreml yon CPU_AND_NE > coreml_ne.log 2>&1 || echo "HATA coreml NE"
for t in duz yon; do .venv/bin/python olc.py $t > olc_$t.log 2>&1 || echo "HATA olc $t"; done
echo "ZINCIR BITTI"
