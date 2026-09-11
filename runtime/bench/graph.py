#!/usr/bin/env python3
"""Render the mixed-message format benchmark as a standalone SVG (requires matplotlib)."""
import argparse
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
from matplotlib.ticker import FuncFormatter, MaxNLocator

ROOT = Path(__file__).resolve().parents[2]
COLORS = {'avm2': '#c084fc', 'as3pb': '#34d399', 'amf3': '#60a5fa', 'json': '#fb923c'}


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
    fig = plt.figure(figsize=(14, 10), facecolor='#101418')
    fig.text(.05, .948, 'AS3PB · AMF3 · JSON', fontsize=25, weight='bold')
    fig.text(.05, .908, 'ByteArray and AVM2 backends  /  optimized AIR 51.3  /  mains power', color='#a9b8c7', fontsize=11)
    fig.text(.05, .875, f"{metadata.get('fixtures', 64)} message fixtures · median of {metadata.get('samples', 9)} samples · "
             f"{metadata.get('targetMs', 150)} ms target per sample", color='#a9b8c7', fontsize=10)

    def panel(left, bottom, width, height, title, subtitle, names, values, colors, unit, label_width):
        fig.add_artist(FancyBboxPatch((left, bottom), width, height, boxstyle='round,pad=0.012,rounding_size=0.015',
                                     transform=fig.transFigure, facecolor='#192129', edgecolor='#2a3642', linewidth=.8, zorder=0))
        fig.text(left+.014, bottom+height-.038, title, fontsize=14, weight='bold')
        fig.text(left+.014, bottom+height-.067, subtitle, fontsize=9, color='#a9b8c7')
        ax = fig.add_axes([left+label_width, bottom+.043, width-label_width-.025, height-.14], facecolor='none')
        ax.barh(range(len(values)), values, height=.54, color=colors, zorder=3)
        ax.set_yticks(range(len(names)), names)
        ax.set_ylim(len(names)-.45, -.65)
        limit = max(values) * 1.26
        ax.set_xlim(0, limit)
        ax.xaxis.set_major_locator(MaxNLocator(nbins=4))
        ax.xaxis.set_major_formatter(FuncFormatter(lambda x, _: f'{x/1000:g}k' if unit == 'rate' and x else f'{x:g}'))
        ax.tick_params(axis='both', length=0, labelsize=10, pad=8)
        ax.grid(axis='x', color='#33404b', linewidth=.6, zorder=0)
        for spine in ax.spines.values():
            spine.set_visible(False)
        for y, value in enumerate(values):
            label = f'{value:,.0f}' if unit == 'rate' else f'{value:.0f} B'
            ax.text(value+limit*.018, y, label, va='center', fontsize=10, weight='bold', color='#edf3f8')

    formats = ['avm2', 'as3pb', 'amf3', 'json']
    panel(.05, .535, .55, .29, 'Encoding', 'Messages / second · reused output buffers · higher is better',
          ['AS3PB AVM2', 'AS3PB ByteArray', 'AMF3', 'JSON'],
          [data[f, 'pack']['ops'] for f in formats], [COLORS[f] for f in formats], 'rate', .125)
    panel(.64, .535, .31, .29, 'Average payload', 'Bytes / message · both AS3PB backends match',
          ['AS3PB', 'AMF3', 'JSON'], [data[f, 'pack']['bytes'] for f in ['as3pb', 'amf3', 'json']],
          [COLORS[f] for f in ['as3pb', 'amf3', 'json']], 'bytes', .065)
    rows = [('avm2', 'reuse'), ('as3pb', 'reuse'), ('avm2', 'fresh'), ('as3pb', 'fresh'), ('amf3', 'fresh'), ('json', 'fresh')]
    panel(.05, .165, .90, .32, 'Decoding', 'Messages / second · fresh and reused destinations on the same scale · higher is better',
          ['AVM2 · reused', 'ByteArray · reused', 'AVM2 · fresh', 'ByteArray · fresh', 'AMF3 · fresh', 'JSON · fresh'],
          [data[key]['ops'] for key in rows], ['#e9d5ff', '#a7f3d0', COLORS['avm2'], COLORS['as3pb'], COLORS['amf3'], COLORS['json']],
          'rate', .16)
    fig.text(.05, .113, 'AVM2: attach/detach per message included · existing binding · prepared input · no input copy timed', fontsize=10, color='#b7c4d1')
    fig.text(.05, .081, 'Buffers and contexts reused. AMF3/JSON decode fresh plain objects; 64-bit values use lossless word pairs.', fontsize=9, color='#8e9dad')
    fig.text(.05, .049, f'AS3PB {revision} · Values, wire bytes and cursors validated · Workload-specific results; small messages may favor ByteArray', fontsize=9, color='#8e9dad')
    description = ('Encoding, fresh and reused decoding, and payload size for AS3PB ByteArray, AS3PB AVM2, AMF3 and JSON. '
                   'AVM2 includes attach/detach per message but excludes domain binding and input preparation/copying. '
                   'AMF3 and JSON decode fresh plain objects with lossless representations.')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.output, format='svg', facecolor=fig.get_facecolor(), metadata={
        'Title': 'AS3PB ByteArray and AVM2, AMF3 and JSON mixed-message benchmark', 'Description': description})
    svg = args.output.read_text().replace('<svg ', '<svg role="img" aria-labelledby="benchmark-title benchmark-desc" ', 1)
    index = svg.index('>', svg.index('<svg ')) + 1
    svg = svg[:index] + '\n<title id="benchmark-title">AS3PB ByteArray and AVM2 benchmark</title>\n<desc id="benchmark-desc">' + description + '</desc>' + svg[index:]
    args.output.write_text('\n'.join(line.rstrip() for line in svg.splitlines()) + '\n')
    plt.close(fig)
    print(args.output)


if __name__ == '__main__':
    main()
