#!/usr/bin/env python3
"""Generate MR-NIRP configs for both streams (NIR/RGB) x {unsup + 5 PURE-pretrained neural}.

Mirrors the UBFC full-set configs but with DATASET=MR-NIRP, FS=30, and a per-stream
EXP_DATA_NAME so NIR and RGB caches don't collide. The stream itself is selected at
runtime via the MRNIRP_STREAM env var (read by MRNIRPLoader); these configs only name
the cache. Writes to configs/repro/MRNIRP_<STREAM>_<METHOD>.yaml.
"""
import os

ROOT = "/home/lsg/rPPG"
OUT = os.path.join(ROOT, "configs/repro")
DATA_PATH = "/media/amdin/Drive1/rppg_data/MR-NIRP_Car_driving"
CACHED = "/media/amdin/Drive1/rppg_data/processed"
CROP = """      CROP_FACE:
        DO_CROP_FACE: True
        BACKEND: 'HC'
        USE_LARGE_FACE_BOX: True
        LARGE_BOX_COEF: 1.5
        DETECTION:
          DO_DYNAMIC_DETECTION: False
          DYNAMIC_DETECTION_FREQUENCY: 30
          USE_MEDIAN_FACE_BOX: False"""

# NIR is single-channel: replicated to 3 identical channels, chrominance methods are
# degenerate (POS/CHROM -> nan) and ICA crashes (singular matrix). Only GREEN is valid.
# RGB has real (NIR-contaminated) color, so the full suite applies.
UNSUP_METHODS = {"NIR": '["GREEN"]',
                 "RGB": '["POS", "CHROM", "ICA", "GREEN", "LGI", "PBV", "OMIT"]'}

UNSUP = """BASE: ['']
TOOLBOX_MODE: "unsupervised_method"
UNSUPERVISED:
  METHOD: {methods}
  METRICS: ['MAE', 'RMSE', 'MAPE', 'Pearson', 'SNR', 'MACC']
  DATA:
    FS: 30
    DATASET: MR-NIRP
    DO_PREPROCESS: True
    DATA_FORMAT: NDHWC
    DATA_PATH: "{dp}"
    CACHED_PATH: "{cp}"
    EXP_DATA_NAME: "MRNIRP_{s}_unsup"
    BEGIN: 0.0
    END: 1.0
    PREPROCESS:
      DATA_TYPE: ['Raw']
      DATA_AUG: ['None']
      LABEL_TYPE: Raw
      DO_CHUNK: False
      CHUNK_LENGTH: 180
{crop}
      RESIZE:
        H: 72
        W: 72
INFERENCE:
  EVALUATION_METHOD: "FFT"
  EVALUATION_WINDOW:
    USE_SMALLER_WINDOW: False
    WINDOW_SIZE: 10
"""

# neural method specs: (name, model_name, data_type, label_type, chunk, resize, fmt, model_path, extra_model)
NEURAL = {
    "physnet": ("Physnet", "['DiffNormalized']", "DiffNormalized", 128, 72, "NCDHW",
                "./final_model_release/PURE_PhysNet_DiffNormalized.pth",
                "  PHYSNET:\n    FRAME_NUM: 128"),
    "tscan": ("Tscan", "[ 'DiffNormalized','Standardized' ]", "DiffNormalized", 180, 72, "NDCHW",
              "./final_model_release/PURE_TSCAN.pth", "  TSCAN:\n    FRAME_DEPTH: 10"),
    "deepphys": ("DeepPhys", "[ 'DiffNormalized','Standardized' ]", "DiffNormalized", 180, 72, "NDCHW",
                 "./final_model_release/PURE_DeepPhys.pth", None),
    "efficientphys": ("EfficientPhys", "['Standardized']", "DiffNormalized", 180, 72, "NDCHW",
                      "./final_model_release/PURE_EfficientPhys.pth", "  EFFICIENTPHYS:\n    FRAME_DEPTH: 10"),
    "physformer": ("PhysFormer", "['DiffNormalized']", "DiffNormalized", 160, 128, "NCDHW",
                   "./final_model_release/PURE_PhysFormer_DiffNormalized.pth",
                   "  PHYSFORMER:\n    PATCH_SIZE: 4\n    DIM: 96\n    FF_DIM: 144\n    NUM_HEADS: 4\n    NUM_LAYERS: 12\n    THETA: 0.7"),
}

NEURAL_TMPL = """BASE: ['']
TOOLBOX_MODE: "only_test"
TEST:
  METRICS: ['MAE', 'RMSE', 'MAPE', 'Pearson', 'SNR', 'MACC']
  USE_LAST_EPOCH: True
  DATA:
    FS: 30
    DATASET: MR-NIRP
    DO_PREPROCESS: True
    DATA_FORMAT: {fmt}
    DATA_PATH: "{dp}"
    CACHED_PATH: "{cp}"
    EXP_DATA_NAME: "MRNIRP_{s}_{method}"
    BEGIN: 0.0
    END: 1.0
    PREPROCESS:
      DATA_TYPE: {dtype}
      LABEL_TYPE: {ltype}
      DO_CHUNK: True
      CHUNK_LENGTH: {chunk}
{crop}
      RESIZE:
        H: {res}
        W: {res}
DEVICE: cuda:0
NUM_OF_GPU_TRAIN: 1
LOG:
  PATH: runs/exp
MODEL:
  DROP_RATE: 0.2
  NAME: {model}
{extra}INFERENCE:
  BATCH_SIZE: 4
  EVALUATION_METHOD: FFT
  EVALUATION_WINDOW:
    USE_SMALLER_WINDOW: False
    WINDOW_SIZE: 10
  MODEL_PATH: "{mpath}"
"""

written = []
for s in ["NIR", "RGB"]:
    p = os.path.join(OUT, f"MRNIRP_{s}_UNSUPERVISED.yaml")
    open(p, "w").write(UNSUP.format(dp=DATA_PATH, cp=CACHED, s=s, crop=CROP, methods=UNSUP_METHODS[s]))
    written.append(p)
    for method, (model, dtype, ltype, chunk, res, fmt, mpath, extra) in NEURAL.items():
        extra_s = (extra + "\n") if extra else ""
        cfg = NEURAL_TMPL.format(fmt=fmt, dp=DATA_PATH, cp=CACHED, s=s, method=method,
                                 dtype=dtype, ltype=ltype, chunk=chunk, crop=CROP, res=res,
                                 model=model, extra=extra_s, mpath=mpath)
        p = os.path.join(OUT, f"MRNIRP_{s}_{method.upper()}.yaml")
        open(p, "w").write(cfg)
        written.append(p)

for p in written:
    print("wrote", os.path.relpath(p, ROOT))
print(f"\n{len(written)} configs generated.")
