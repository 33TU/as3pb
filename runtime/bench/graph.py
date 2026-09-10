#!/usr/bin/env python3
"""Render the mixed-message format benchmark as a standalone SVG (requires matplotlib)."""
import argparse
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
from matplotlib.ticker import FuncFormatter

ROOT = Path(__file__).resolve().parents[2]
COLORS = {'as3pb': '#34d399', 'amf3': '#60a5fa', 'json': '#fb923c'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, default=ROOT / 'runtime/bin/formats-bench/result.json')
    parser.add_argument('--output', type=Path, default=ROOT / 'assets/benchmark-summary.svg')
    args = parser.parse_args()
    data = {(r['format'], r['mode']): r for r in json.loads(args.input.read_text()) if r['workload'] == 'readme-mixed'}
    plt.rcParams.update({'font.family': 'DejaVu Sans', 'svg.fonttype': 'none', 'font.size': 10,
                         'text.color': '#edf3f8', 'axes.labelcolor': '#a9b8c7', 'xtick.color': '#a9b8c7',
                         'ytick.color': '#edf3f8'})
    metadata_path = args.input.with_name('metadata.json')
    metadata = json.loads(metadata_path.read_text()) if metadata_path.exists() else {}
    revision = metadata.get('commit', '')[:7]
    fig = plt.figure(figsize=(12, 8.6), facecolor='#101418')
    fig.text(.05, .943, 'AS3PB · AMF3 · JSON', fontsize=25, weight='bold')
    fig.text(.05, .903, 'Mixed-message benchmark  /  optimized AIR 51.3  /  mains power', color='#a9b8c7', fontsize=11)
    fig.text(.05, .868, '64 message fixtures · median of 9 samples · 150 ms target per sample', color='#a9b8c7', fontsize=10)

    def panel(col, row, title, subtitle, names, values, colors, limit, ticks, unit, full_width=False):
        left = .05 + col * .48
        bottom = .51 if row == 0 else .18
        fig.add_artist(FancyBboxPatch((left, bottom), .91 if full_width else .43, .30, boxstyle='round,pad=0.012,rounding_size=0.015',
                                     transform=fig.transFigure, facecolor='#192129', edgecolor='#2a3642', linewidth=.8, zorder=0))
        fig.text(left+.014, bottom+.259, title, fontsize=14, weight='bold')
        fig.text(left+.014, bottom+.231, subtitle, fontsize=9, color='#a9b8c7')
        ax = fig.add_axes([left + (.16 if full_width else .104), bottom+.061,
                           .715 if full_width else .293, .141], facecolor='none')
        ax.barh(range(len(values)), values, height=.5, color=colors, zorder=3)
        ax.set_yticks(range(len(names)), names)
        ax.set_ylim(len(names)-.45, -.65)
        ax.set_xlim(0, limit)
        ax.set_xticks(ticks)
        ax.xaxis.set_major_formatter(FuncFormatter(lambda x, _: f'{x/1000:g}k' if unit == 'rate' and x else f'{x:g}'))
        ax.tick_params(axis='both', length=0, labelsize=9, pad=8)
        ax.grid(axis='x', color='#33404b', linewidth=.6, zorder=0)
        for spine in ax.spines.values():
            spine.set_visible(False)
        for y, value in enumerate(values):
            label = f'{value:,.0f}' if unit == 'rate' else f'{value:.0f} B'
            ax.text(value+limit*.02, y, label, va='center', fontsize=9, weight='bold', color='#edf3f8')

    formats = ['as3pb', 'amf3', 'json']
    names = ['AS3PB', 'AMF3', 'JSON']
    colors = [COLORS[f] for f in formats]
    panel(0, 0, 'Encoding · reused output buffers', 'Messages / second · higher is better', names,
          [data[f, 'pack']['ops'] for f in formats], colors, 215000, [0, 50000, 100000, 150000], 'rate')
    panel(1, 0, 'Average payload', 'Bytes / message · lower is better', names,
          [data[f, 'pack']['bytes'] for f in formats], colors, 1170, [0, 250, 500, 750, 1000], 'bytes')
    panel(0, 1, 'Decoding', 'Messages / second · higher is better · fresh and reused destinations on the same scale',
          ['AS3PB · reused', 'AS3PB · fresh', 'AMF3 · fresh', 'JSON · fresh'],
          [data['as3pb', 'reuse']['ops'], data['as3pb', 'fresh']['ops'],
           data['amf3', 'fresh']['ops'], data['json', 'fresh']['ops']],
          ['#a7f3d0', '#34d399', COLORS['amf3'], COLORS['json']],
          500000, [0, 100000, 200000, 300000, 400000, 500000], 'rate', full_width=True)
    fig.text(.05, .112, 'All encoders reuse output buffers. AMF3 and JSON decode fresh plain objects.', fontsize=10, color='#b7c4d1')
    fig.text(.05, .080, '64-bit values use lossless low/high pairs; byte fields use unsigned-byte arrays for AMF3/JSON.', fontsize=9, color='#8e9dad')
    fig.text(.05, .046, f'AS3PB {revision} · Field values and cursors validated before timing · Workload-specific results', fontsize=9, color='#8e9dad')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.output, format='svg', facecolor=fig.get_facecolor(), metadata={
        'Title': 'AS3PB, AMF3 and JSON mixed-message benchmark',
        'Description': 'Encoding speed, fresh decoding speed, AS3PB destination reuse, and average payload size. All encoding buffers are reused; AMF3 and JSON use lossless plain-object representations.'})
    svg = args.output.read_text()
    svg = svg.replace('<svg ', '<svg role="img" aria-labelledby="benchmark-title benchmark-desc" ', 1)
    index = svg.index('>', svg.index('<svg ')) + 1
    svg = svg[:index] + '\n<title id="benchmark-title">AS3PB, AMF3 and JSON benchmark</title>\n<desc id="benchmark-desc">Three bar charts compare encoding, fresh and reused decoding on a shared scale, and average payload size for the same mixed-message fixtures.</desc>' + svg[index:]
    args.output.write_text('\n'.join(line.rstrip() for line in svg.splitlines()) + '\n')
    plt.close(fig)
    print(args.output)


if __name__ == '__main__':
    main()
