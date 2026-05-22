import os
import random
import serial
from tqdm import tqdm

import sys

if len(sys.argv) < 3:
    print(f'usage: python3 ./{__file__} <serial_port> <output_folder>')
    print('''
<serial_port> the serial used to talk to the board, e.g. /dev/ttyUSB0 on linux or COM4 on windows
<output_folder> base folder used to save the output of this script (relative to current folder)
          ''')
    exit(-1)

port = sys.argv[1]
vendor = sys.argv[2]    # in our campaign we associated output folder to vendor
save_folder = f'./{vendor}'

ser = serial.Serial(
    port=port,           # Device path
    baudrate=115200,               # Communication speed
    bytesize=serial.EIGHTBITS,     # Data bits (5, 6, 7, 8)
    parity=serial.PARITY_NONE,     # Parity checking
    stopbits=serial.STOPBITS_ONE,  # Stop bits (1, 1.5, 2)
    timeout=3,                     # Read timeout in seconds
    xonxoff=False,                 # Software flow control
    rtscts=False,                  # Hardware (RTS/CTS) flow control
    write_timeout=None,            # Write timeout in seconds
    dsrdtr=False,                  # DSR/DTR flow control
    inter_byte_timeout=None,       # Inter-byte timeout
    exclusive=None                 # Exclusive access (Linux)
)

# pattern use to sync across operation
# chosen because it is not a valid value for any param
SYNC_DATA = bytearray([0xFF]*4)
uniqueness_tests = 1000   # different rows, unused here
repeatability_tests = 50 # repeated runs on same row
repeatability_runs_per_test = 100    # rows to run repeated runs on
# tests to check the decay, making sure that flips seen are due to hammer
# to do this properly i should make it
control_tests = 500

# choose randomly the rows to test
random.seed(42)
# uniqueness, unused here but kept for consistency in the rng with other runs we did
uniq_rand_rows: list[int] = random.sample(range(0, 2**15), uniqueness_tests)
uniq_seq_start: int = random.randint(0, 2**15-1-uniqueness_tests) # leave space for range
uniq_seq_rows: list[int] = list(range(uniq_seq_start, uniq_seq_start+uniqueness_tests))
# repeatability
rep_rand_rows: list[int] = random.sample(range(0, 2**15), repeatability_tests)
rep_seq_start: int = random.randint(0, 2**15-1-repeatability_tests) # leave space for range
rep_seq_rows: list[int] = list(range(rep_seq_start, rep_seq_start+repeatability_tests))
# control rows
control_rows: list[int] = random.sample(range(0, 2**15), control_tests)
# other test parameters
n_act_list: list[int] = [500000, 1000000, 5000000, 10000000]
pattern_list: list[int] = [0, 1, 2, 3] # SOL0, SOL1, CHK1, ROS1
pattern_map: dict[int, str] = {
    0: 'SOL0',
    1: 'SOL1',
    2: 'CHK1',
    3: 'ROS1',
}

# to characterize all rows for uniqueness
all_rows_uniq = list(range(1, 32768-1))

# send data and wait for it to be echoed back as confirmation
def send_and_check(val: int):
    val_b = val.to_bytes(4, 'big')
    # tqdm.write(str(val_b))
    ser.write(val_b)
    a = ser.read(4)
    if int.from_bytes(a) != val:
        tqdm.write(f'MISMATCHED DATA: expected {val} received {int.from_bytes(a)}')
    # tqdm.write(f'{str(a)} {int.from_bytes(a)}')

# configure the peripheral, wait for hammering to be completed and the read back the results
# results are returned as is, a list of strings encoding column,word,bit where
#   column: corresponds to the current burst being read (burst is 128bits on this specific component)
#   word: which word in the burst is affected
#   bit: which bit in the word is affected
def do_test(ag1: int, ag2: int, victim: int, n_act: int, pattern: int) -> list[str]:
    tqdm.write(f'[new test] {ag1}, {ag2}, {victim}, {n_act}, {pattern_map[pattern]}')
    ser.write(SYNC_DATA)
    a = ser.read(4)
    if a != SYNC_DATA:
        tqdm.write(f'MISMATCH SYNC {a} vs {SYNC_DATA}')
    # tqdm.write(str(a))
    send_and_check(ag1)
    send_and_check(ag2)
    send_and_check(victim)
    send_and_check(n_act)
    send_and_check(pattern)

    # wait for hammer to be done and receive sync
    a = ser.read(4)
    while a != SYNC_DATA:
        a = ser.read(4)

    # read all flips until the sync data is received
    # and store the strings to return them
    flip_list: list[str] = []
    while True:
        a = ser.read(4)
        if a == SYNC_DATA:
            break
        a += ser.readline()
        # tqdm.write(str(a))
        flip_list.append(str(a))
    return flip_list

# writes the list of bitflip positions from the test to the file
def write_to_file(full_path, name: str, content: list[str]):
    # ensure dir exists
    os.makedirs(full_path, exist_ok=True)
    # clean up lines
    lines = ["col,word,bit\n"]
    for line in content[1:]: # exclude echoed settings
        lines.append(line.removeprefix("b'").removesuffix(r"\r\n'") + '\n')
    # write to file (csv)
    with open(os.path.join(full_path, name), 'w') as f:
        f.writelines(lines)

flips: list[str] = []

# # quick test, uncomment for troubleshoot
# flips = do_test(1, 3, 2, 10000000, 1)
# print(flips)
# write_to_file('~', 'test.txt', flips)
# exit()

if __name__ == '__main__':
    # launch the campaign and show some progress bars
    # takes care of saving the result
    with tqdm(pattern_list, desc="Pattern", position=0) as pattern_pbar:
        for pattern in pattern_pbar:
            pattern_pbar.set_description(f'[Pattern : {pattern_map[pattern]}]')
            with tqdm(n_act_list, desc="Hammer count", position=1, leave=False) as n_act_pbar:
                for n_act in n_act_pbar:
                    n_act_pbar.set_description(f'[Hammers: {n_act//1000000}M]')
                    # repeatabililty tests
                    # random
                    with tqdm(rep_rand_rows, desc='[rand rows repeatability]', position=2, leave=False) as rep_rand_rows_pbar:
                        for row in rep_rand_rows_pbar:
                            for i in range(repeatability_runs_per_test):
                                flips = do_test(row-1, row+1, row, n_act, pattern)
                                path = os.path.join(save_folder, pattern_map[pattern], str(n_act), 'rand_rows_rep', f'r{row:05d}')
                                write_to_file(path, f'{i:03d}.csv', flips)
                    # sequential
                    with tqdm(rep_seq_rows, desc='[seq rows repeatability]', position=2, leave=False) as rep_seq_rows_pbar:
                        for row in rep_seq_rows_pbar:
                            for i in range(repeatability_runs_per_test):
                                flips = do_test(row-1, row+1, row, n_act, pattern)
                                path = os.path.join(save_folder, pattern_map[pattern], str(n_act), 'seq_rows_rep', f'r{row:05d}')
                                write_to_file(path, f'{i:03d}.csv', flips)

                    # uniqueness tests
                    with tqdm(all_rows_uniq, desc='[all rows uniqueness]', position=2, leave=False) as uniq_all_rows_pbar:
                        for row in uniq_all_rows_pbar:
                            flips = do_test(row-1, row+1, row, n_act, pattern)
                            path = os.path.join(save_folder, pattern_map[pattern], str(n_act), 'rand_rows_uniq')
                            write_to_file(path, f'r{row:05d}.csv', flips)

                    # control tests
                    with tqdm(control_rows, desc='[control]', position=2, leave=False) as control_pbar:
                        for row in control_pbar:
                            # hammer far away rows to test for flips due to decay
                            flips = do_test((row+10000) % 2**15, (row+2+10000) % 2**15, row, n_act, pattern)
                            path = os.path.join(save_folder, pattern_map[pattern], str(n_act), 'control')
                            write_to_file(path, f'r{row:05d}.csv', flips)
