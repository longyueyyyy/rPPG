"""MR-NIRP Car (driving) dataset loader for rPPG-Toolbox.

PROJECT-SPECIFIC loader — NOT part of upstream rPPG-Toolbox (pinned at b7500b8).
Canonical copy lives here; `scripts/mrnirp/install_into_toolbox.sh` installs it into
external/rPPG-Toolbox and registers it in main.py + data_loader/__init__.py.

Dataset layout (read-only, on the data drive):
  <root>/SubjectN/subjectN_<scenario>_<motion>_<wavelength>/
      NIR.zip      Frame#####.pgm (1..) + frame-#.pgm  — 16-bit 640x640 grayscale, ~60 fps
      RGB.zip      Frame#.pgm                           — 16-bit 640x640 raw Bayer, ~30 fps
      PulseOX.zip  PulseOX/pulseOx.mat (pulseOxRecord, pulseOxTime) — PPG, 1 sample per frame

Design choices (see project README / reports for rationale):
  * Stream chosen via env MRNIRP_STREAM = NIR | RGB  (default NIR).
  * Scope filters via env MRNIRP_SUBJECTS (e.g. "Subject1,Subject2") and
    MRNIRP_SESSIONS (substrings, e.g. "driving_still_975"); empty = all.
  * 16-bit -> 8-bit by /256. NIR replicated to 3ch; RGB Bayer-demosaiced (GB pattern).
    NB: RGB color is heavily NIR-illuminator contaminated -> chrominance methods unreliable.
  * NIR decimated by 2 (~60->~30 fps) to match RGB and the 30fps-pretrained models.
  * PPG resampled (linear) to the frame count: its samples are 1:1 with camera timestamps.
"""
import glob
import os
import re
import zipfile

import cv2
import numpy as np
import scipy.io as sio
from dataset.data_loader.BaseLoader import BaseLoader


class MRNIRPLoader(BaseLoader):
    """Data loader for the MR-NIRP Car (driving) dataset."""

    def __init__(self, name, data_path, config_data, device=None):
        # NB: must be set before super().__init__ (it calls get_raw_data -> uses self.stream)
        self.stream = os.environ.get("MRNIRP_STREAM", "NIR").upper()
        super().__init__(name, data_path, config_data, device)

    def get_raw_data(self, data_path):
        """Returns session directories, filtered by MRNIRP_SUBJECTS / MRNIRP_SESSIONS env vars."""
        sub_filter = [s for s in os.environ.get("MRNIRP_SUBJECTS", "").split(",") if s]
        sess_filter = [s for s in os.environ.get("MRNIRP_SESSIONS", "").split(",") if s]
        dirs = []
        for sub in sorted(glob.glob(os.path.join(data_path, "Subject*"))):
            if sub_filter and os.path.basename(sub) not in sub_filter:
                continue
            for sess in sorted(glob.glob(os.path.join(sub, "subject*"))):
                base = os.path.basename(sess)
                if not os.path.isdir(sess):
                    continue
                if sess_filter and not any(tok in base for tok in sess_filter):
                    continue
                # require both the chosen video stream AND the PulseOX ground truth
                # (the download is partial: some sessions have video but no GT, or vice versa)
                stream_zip = os.path.join(sess, self.stream + ".zip")
                if self._find_pox(sess) is None:  # case-insensitive (some are PulseOx.zip)
                    continue
                # zipfile.is_zipfile() rejects truncated/corrupt zips up front, so a bad
                # download is skipped here instead of crashing the worker mid-preprocess.
                if not (os.path.exists(stream_zip) and zipfile.is_zipfile(stream_zip)):
                    continue
                dirs.append({"index": base, "path": sess})
        if not dirs:
            raise ValueError(self.dataset_name + " data paths empty! (stream=%s)" % self.stream)
        return dirs

    def split_raw_data(self, data_dirs, begin, end):
        """Returns a subset of data dirs split by begin/end fractions of the session list."""
        if begin == 0 and end == 1:
            return data_dirs
        file_num = len(data_dirs)
        choose_range = range(int(begin * file_num), int(end * file_num))
        return [data_dirs[i] for i in choose_range]

    def preprocess_dataset_subprocess(self, data_dirs, config_preprocess, i, file_list_dict):
        """Invoked by preprocess_dataset for each session (multiprocessing)."""
        session = data_dirs[i]["path"]
        saved_filename = data_dirs[i]["index"]

        frames = self.read_video(session)
        if config_preprocess.USE_PSUEDO_PPG_LABEL:
            bvps = self.generate_pos_psuedo_labels(frames, fs=self.config_data.FS)
        else:
            bvps = self.read_wave(session, target_len=frames.shape[0])

        frames_clips, bvps_clips = self.preprocess(frames, bvps, config_preprocess)
        input_name_list, label_name_list = self.save_multi_process(frames_clips, bvps_clips, saved_filename)
        file_list_dict[i] = input_name_list

    # ---- dataset-specific readers ----

    @staticmethod
    def _find_pox(session_path):
        """Path to the PulseOX zip, matched case-insensitively (some are 'PulseOx.zip')."""
        try:
            for f in os.listdir(session_path):
                if f.lower() == "pulseox.zip":
                    p = os.path.join(session_path, f)
                    if os.path.getsize(p) > 100:
                        return p
        except OSError:
            pass
        return None

    @staticmethod
    def _ordered_frame_names(zf):
        """PGM entries in temporal order: 'Frame#####' scheme first, then 'frame-#', by index."""
        names = [n for n in zf.namelist() if n.lower().endswith(".pgm")]

        def key(n):
            b = os.path.basename(n)
            m = re.search(r"(\d+)", b)
            rank = 0 if b[:1] == "F" else 1  # 'Frame00001' before 'frame-12706'
            return (rank, int(m.group(1)) if m else 0)

        return sorted(names, key=key)

    def read_video(self, session_path):
        """Reads frames from the session's stream zip. Returns (T, H, W, 3) uint8 RGB."""
        zpath = os.path.join(session_path, self.stream + ".zip")
        stride = 2 if self.stream == "NIR" else 1  # NIR ~60fps -> ~30fps
        max_frames = int(os.environ.get("MRNIRP_MAX_FRAMES", "0"))  # 0 = all; else cap (post-stride)
        frames = []
        with zipfile.ZipFile(zpath) as zf:
            names = self._ordered_frame_names(zf)[::stride]
            if max_frames > 0:
                names = names[:max_frames]
            for n in names:
                img = cv2.imdecode(np.frombuffer(zf.read(n), np.uint8), cv2.IMREAD_UNCHANGED)
                if img is None:
                    continue
                if img.dtype == np.uint16:
                    img = (img / 256.0).astype(np.uint8)
                if self.stream == "RGB":
                    bgr = cv2.cvtColor(img, cv2.COLOR_BayerGB2BGR)  # NIR-contaminated color
                    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
                else:
                    rgb = cv2.cvtColor(img, cv2.COLOR_GRAY2RGB)     # replicate NIR to 3ch
                frames.append(rgb)
        return np.asarray(frames)

    @staticmethod
    def read_wave(session_path, target_len):
        """Reads PPG from the PulseOX zip and resamples (linear) to target_len."""
        with zipfile.ZipFile(MRNIRPLoader._find_pox(session_path)) as zf:
            name = [n for n in zf.namelist() if n.lower().endswith("pulseox.mat")][0]
            with zf.open(name) as f:
                mat = sio.loadmat(f)
        wave = np.asarray(mat["pulseOxRecord"], dtype=np.float64).ravel()
        if len(wave) != target_len:
            x_old = np.linspace(0.0, 1.0, num=len(wave))
            x_new = np.linspace(0.0, 1.0, num=target_len)
            wave = np.interp(x_new, x_old, wave)
        return wave
