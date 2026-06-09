#!/usr/bin/env python3
"""Parse rPPG-Toolbox stdout logs into structured metrics (JSON + markdown table).

Handles both:
  * unsupervised runs (multiple methods, each prefixed by "Used Unsupervised Method: NAME")
  * neural only_test runs (single block; method name taken from --label)

Usage:
  python parse_metrics.py --label POS_block --kind unsupervised  logs/E01_unsup.log
  python parse_metrics.py --label "PURE->UBFC PhysNet" --kind neural logs/E02_physnet.log
Outputs <log>.metrics.json next to the log and prints a markdown table.
"""
import argparse, json, re, sys, os

# matches e.g. "FFT MAE (FFT Label): 0.2197 +/- 0.19"  /  "MACC (avg): 0.76 +/- 0.03"
METRIC_RE = re.compile(
    r'^(?:FFT |PEAK |Peak )?(MAE|RMSE|MAPE|Pearson|SNR|MACC)\b[^:]*:\s*'
    r'([-\d.eE+]+)\s*(?:\+/-\s*([-\d.eE+]+))?', re.M)
METHOD_RE = re.compile(r'Used Unsupervised Method:\s*(\w+)')


def parse(text, kind, label):
    results = {}
    if kind == 'unsupervised':
        # split into per-method chunks
        parts = re.split(r'Used Unsupervised Method:\s*(\w+)', text)
        # parts = [pre, name1, body1, name2, body2, ...]
        for i in range(1, len(parts), 2):
            name = parts[i]
            body = parts[i + 1]
            results[name] = _grab(body)
    else:
        results[label] = _grab(text)
    return results


def _grab(text):
    d = {}
    for m in METRIC_RE.finditer(text):
        metric, val, se = m.group(1), float(m.group(2)), m.group(3)
        d[metric] = {'value': val, 'se': float(se) if se else None}
    return d


def to_markdown(results):
    cols = ['MAE', 'RMSE', 'MAPE', 'Pearson', 'SNR', 'MACC']
    lines = ['| Method | ' + ' | '.join(cols) + ' |',
             '|' + '---|' * (len(cols) + 1)]
    for name, d in results.items():
        row = [name]
        for c in cols:
            if c in d:
                v = d[c]['value']
                row.append(f'{v:.3f}')
            else:
                row.append('-')
        lines.append('| ' + ' | '.join(row) + ' |')
    return '\n'.join(lines)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('log')
    ap.add_argument('--kind', choices=['unsupervised', 'neural'], required=True)
    ap.add_argument('--label', default='model')
    args = ap.parse_args()
    text = open(args.log, errors='ignore').read()
    results = parse(text, args.kind, args.label)
    out = os.path.splitext(args.log)[0] + '.metrics.json'
    json.dump(results, open(out, 'w'), indent=2)
    print(to_markdown(results))
    print(f'\n[saved {out}]')
