import os
from collections import Counter
from statistics import mean
from scipy.stats import entropy
from matplotlib import pyplot as plt
import numpy as np
from math import sqrt
import json

# hammer count tested
_act_list = [500000, 1000000, 5000000, 10000000]
# folder structure
bg_list: list[str] = ['SOL0', 'SOL1', 'CHK1', 'ROS1']
n_act_list: list[str] = list(map(str, _act_list))
test_list: list[str] = ['control', 'rand_rows_rep', 'rand_rows_uniq', 'seq_rows_rep']

# shorten string to appear in file name
short_act: dict[str, str] = {
    '500000': '500k',
    '1000000': '1M',
    '5000000': '5M',
    '10000000': '10M',
}

import sys

if len(sys.argv) < 4:
    print(f'usage: python3 ./{__file__} [micron|zentel] [SOL0|SOL1|CHK1|ROS1] [500000|1000000|5000000|10000000]')
    exit(-1)

mft = sys.argv[1]
if not (mft == 'micron' or mft == 'zentel'):
    print(f'invalid manufacturer, valid values are "micron", "zentel", found {mft}')
    exit(-2)

bg = sys.argv[2]
if bg not in bg_list:
    print(f'invalid background, valid values are SOL0, SOL1, CHK1, ROS1, found {bg}')
    exit(-3)

act = sys.argv[3]
if act not in short_act:
    print(f'invalid n_act, valid values are 500000, 1000000, 5000000, 10000000, found {act}')
    exit(-4)

# setup base paths
data_in_folder = f'./raw-data/{mft}'
# plots_out_folder = f'./results/{mft}/plots'
# data_out_folder = f'./results/{mft}/data'
plots_out_folder = f'./figs/{mft}/plots'
data_out_folder = f'./figs/{mft}/data'
os.makedirs(plots_out_folder, exist_ok=True)
os.makedirs(data_out_folder, exist_ok=True)

print('analyzing data')
print(mft, bg, act, data_in_folder, sep="\n")

## quick online mean, used to keep track of jinter
## (too many pairs to store all and do it at the end)
class WelfordMean:
    def __init__(self):
        self.mean: float = 0.0
        self.count: int = 0

    def update(self, val):
        self.count += 1
        delta = val - self.mean
        self.mean += delta / self.count

## shorthand to print statistics. prints and returns string
def print_avg_min_max(data: list[int] | list[float], *, id : str = 'stats') -> str:
    s = f'[{id}] avg: {mean(data):.3f} (min: {min(data):.3f} - max: {max(data):.3f})'
    print(s)
    return s

## parse an output file from the campaing and produce a list of positions
def read_flips(full_path: str) -> set[int]:
    with open(full_path, 'r') as f:
        lines = f.readlines()
    positions: set[int] = set()
    for l in lines[1:]:
        els = l.split(',', 3)
        col = int(els[0])
        word = int(els[1])
        bit = int(els[2])
        positions.add(128*col + 32*word + bit) # nexys video component configuration
    return positions

## expected jaccard index according to the flips observed
def expected_jaccard(t1: set[int], t2: set[int]):
    n = len(t1)
    K = len(t2)
    if n == 0 and K == 0:
        return 0.0
    N = 2**14 # row size in bits
    e = n*K / N
    return e / (n + K -e)

## compute the jaccard index between two sets of positions
def jaccard(t1: set[int], t2: set[int]) -> float:
    # if no flips, return 0
    if len(t1) == 0 and len(t2) == 0:
        return 0.0
    inters = t1.intersection(t2)
    union = t1.union(t2)
    return len(inters) / len(union)

# plot the distribution across columns
def plot_cols(cols: list[int], name: str):
    x = list(range(2**14))
    y = cols
    assert len(x) == len(y)
    plt.figure(figsize=(25, 4))
    plt.title('Bit-flip count for each position')
    plt.xlabel('column position')
    plt.ylabel('bit-flip count')
    plt.bar(x, y)
    plt.savefig(os.path.join(plots_out_folder, f'{name}_col_distr.pdf'), format='pdf')
    plt.clf()
    plt.close()
    lines = ['idx,count\n']
    for xi, yi in zip(x, y):
        lines.append(f'{xi},{yi}\n')
    with open(os.path.join(data_out_folder, f'{name}_col_distr.csv'), 'w') as f:
        f.writelines(lines)

# same function as `plot_cols` but it shows if there are patterns
# in the columns, represented each burst per line, to highlight recurring
# behaviour
def plot_heatmap(cols: list[int], name: str):
    mat = np.ndarray((2**7, 2**7), dtype=int)
    for i, el in enumerate(cols):
        mat[i // 2**7][i % 2**7] = el
    im = plt.imshow(mat)
    plt.colorbar(im)
    plt.title('Bit-flip heatmap per burst')
    plt.xlabel('position in burst')
    plt.ylabel('burst number')
    plt.savefig(os.path.join(plots_out_folder, f'{name}_col_distr_heatmap.pdf'), format='pdf')
    plt.clf()
    plt.close()

## dump python object to json file with name id_trailer.json
def dump_to_json(id: str, trailer: str, data) -> None:
    with open(os.path.join(data_out_folder, f'{id}_{trailer}.json'), 'w') as f:
        json.dump(data, f, indent=4)


## analyze all tests from the campaign
for test in test_list:
    base_folder = os.path.join(data_in_folder, bg, act, test)
    id = f'{mft}_{bg}_{short_act[act]}'
    print(f'##### {id} #####')
    match test:
        case "control":
            # for control test, just read all files and ensure that no fails are shown
            # this is to exclude retention failures
            # no data is saved and no plot is needed here
            control_data: list[int] = []
            non_zero: int = 0
            for file in os.listdir(base_folder):
                flip_count = len(read_flips(os.path.join(base_folder, file)))
                control_data.append(flip_count)
                if flip_count != 0:
                    non_zero += 1
            total = len(control_data)
            passed = total - non_zero
            print(f'[{test}] control passed {passed}/{total} ({(passed*100/total):.2f}%)')
            print_avg_min_max(control_data, id=f'{test}')
        case "rand_rows_rep" | "seq_rows_rep":
            # there is a subfolder for each row, each containing a certain number of repeated tests
            # (usually 100 repetition)
            # for each subfolder compute the average jaccard then average the result
            # TODO: plot and data saving
            for row in os.listdir(base_folder):
                row_data: list[set[int]] = []
                flip_counts: list[int] = []
                for file in os.listdir(os.path.join(base_folder, row)):
                    flips = read_flips(os.path.join(base_folder, row, file))
                    row_data.append(flips)
                    flip_counts.append(len(flips))
                print_avg_min_max(flip_counts, id=f'{test}_flip_count')
                dump_to_json(id, f'{test}_flip_count', flip_counts)
                # not significant enough
                if mean(flip_counts) < 5:
                    print(f'[{test}] insufficient flip count, skipping jaccard')
                    continue
                # compute jaccards
                row_jaccards: list[float] = []
                for i, t1 in enumerate(row_data):
                    for t2 in row_data[i+1:]:
                        row_jaccards.append(jaccard(t1, t2))
                dump_to_json(f'{id}_{row}', 'jintra', row_jaccards)
                print_avg_min_max(row_jaccards, id=f'{test}_jintra')
        case "rand_rows_uniq" | "seq_rows_uniq":
            # plot the flip count by column and print the average flip count
            # TODO: jinter between all pairs
            data: list[set[int]] = []
            counts_by_col: Counter[int] = Counter()
            flip_counts: list[int] = []
            for file in os.listdir(base_folder):
                flips = read_flips(os.path.join(base_folder, file))
                data.append(flips)
                counts_by_col.update(flips)
                flip_counts.append(len(flips))
            print_avg_min_max(flip_counts, id=f'{test}_flip_count')
            dump_to_json(id, f'{test}_flip_count', flip_counts)
            # not significant enough
            if mean(flip_counts) < 5:
                print(f'[{test}] insufficient flip count, skipping plots and jaccards')
                continue
            # sort colums by position
            cols = []
            for i in range(16384):
                cols.append(counts_by_col.get(i, 0))
            print(f'[{test}] col distr entropy: {entropy(cols, base=2):.3f} bits')
            plot_cols(cols, id)
            plot_heatmap(cols, id)
            # compute jinter for all pairs, do not store all values to
            # avoid going oom. track max and min
            #js_inter: WelfordMean = WelfordMean()
            #max_j = 0
            #min_j = 1
            #js_inter_expected: WelfordMean = WelfordMean()
            #max_exp_j = 0
            #min_exp_j = 1
            #for i, t1 in enumerate(data):
            #    if i % 100 == 0:
            #        print(f'row = {i}')
            #    for t2 in data[i+1:]:
            #        # comput index + update stats
            #        j = jaccard(t1, t2)
            #        exp_j = expected_jaccard(t1, t2)
            #        # update stas
            #        js_inter.update(j)
            #        js_inter_expected.update(exp_j)
            #        if j > max_j:
            #            max_j = j
            #        if j < min_j:
            #            min_j = j
            #        if exp_j > max_exp_j:
            #            max_exp_j = exp_j
            #        if exp_j < min_exp_j:
            #            min_exp_j = exp_j
            #print(f'[{id}jinter] avg: {js_inter.mean:.3f} (min: {min_j:.3f} - max: {max_j:.3f})')
            #print(f'[{id}jinter_exp] avg: {js_inter_expected.mean:.3f} (min: {min_exp_j:.3f} - max: {max_exp_j:.3f})')
        case _:
            print(f'test case "{test}" is not defined')
