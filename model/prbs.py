"""
Python model of prbs_gen.vhd and prbs_mon.vhd — PRBS Generator and Monitor.

prbs_gen RTL:
  - LFSR with configurable polynomial and initial state
  - On data_req: shift LFSR by DATA_W bits (XOR_REDUCE feedback)
  - prbs_sel muxes between LFSR output and data_in
  - error_insert arms a one-shot XOR with error_mask
  - TOGGLE_CONTROL: edge-triggered (toggle) vs level-triggered error insert

prbs_mon RTL:
  - Shadow LFSR tracks expected sequence
  - sync_now: reloads LFSR from received data (GENERATOR_W bits over multiple cycles)
  - Auto-sync when error_count exceeds sync_threshold
  - count_reset: clears data_count and error_count
  - TOGGLE_CONTROL: edge-triggered controls for sync_manual and count_reset
"""

import sys
import os
import math
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
from model_utils import unsigned


def _xor_reduce(val):
    """XOR all bits of val."""
    result = 0
    while val:
        result ^= (val & 1)
        val >>= 1
    return result


def _count_ones(val, width):
    """Count number of '1' bits in val (width bits)."""
    count = 0
    for i in range(width):
        if (val >> i) & 1:
            count += 1
    return count


class PrbsGenerator:
    def __init__(self, data_w=1, generator_w=31, toggle_control=True,
                 fixed_point=False):
        self.DATA_W = data_w
        self.GENERATOR_W = generator_w
        self.TOGGLE_CONTROL = toggle_control
        self.fixed_point = fixed_point  # PRBS is inherently integer-based
        self.LFSR_MASK = (1 << generator_w) - 1
        self.DATA_MASK = (1 << data_w) - 1
        self.reset(initial_state=1, polynomial=0)

    def reset(self, initial_state=1, polynomial=0):
        self.lfsr = initial_state & self.LFSR_MASK
        self.polynomial = polynomial & self.LFSR_MASK
        self.error_arm = 0
        self.error_insert_d = 0
        self._data_out = 0

    def step(self, data_req, prbs_sel, data_in=0, error_insert=0, error_mask=1):
        """One clock cycle. Returns dict(data_out)."""
        GW = self.GENERATOR_W
        DW = self.DATA_W

        # Error insert edge/toggle detection
        if self.TOGGLE_CONTROL:
            if error_insert != self.error_insert_d:
                self.error_arm = 1
        else:
            if error_insert == 0 and self.error_insert_d == 1:
                self.error_arm = 1
        self.error_insert_d = error_insert

        # Data mux
        if prbs_sel:
            v_data_mux = self.lfsr & self.DATA_MASK
        else:
            v_data_mux = data_in & self.DATA_MASK

        # Output with optional error
        if data_req:
            if self.error_arm:
                self._data_out = (v_data_mux ^ error_mask) & self.DATA_MASK
                self.error_arm = 0
            else:
                self._data_out = v_data_mux

        # LFSR advance (on data_req)
        # RTL: for bit in 0 to DATA_W-1:
        #   v_lfsr := v_lfsr AND polynomial
        #   v_bit  := XOR_REDUCE(v_lfsr)
        #   v_lfsr := lfsr(GW-2 downto 0) & v_bit   <-- shift left, insert at bit 0
        if data_req:
            v_lfsr = self.lfsr
            for bit in range(DW):
                masked = v_lfsr & self.polynomial
                v_bit = _xor_reduce(masked)
                v_lfsr = ((v_lfsr << 1) | v_bit) & self.LFSR_MASK
            self.lfsr = v_lfsr

        return {'data_out': self._data_out}


class PrbsMonitor:
    def __init__(self, data_w=1, generator_w=31, counter_w=32, threshold_w=16,
                 toggle_control=True, fixed_point=False):
        self.DATA_W = data_w
        self.GENERATOR_W = generator_w
        self.COUNTER_W = counter_w
        self.THRESHOLD_W = threshold_w
        self.TOGGLE_CONTROL = toggle_control
        self.fixed_point = fixed_point
        self.LFSR_MASK = (1 << generator_w) - 1
        self.DATA_MASK = (1 << data_w) - 1
        self.COUNTER_MASK = (1 << counter_w) - 1
        self.GEN_BITS = int(math.ceil(math.log2(generator_w)))
        self.reset(initial_state=1, polynomial=0)

    def reset(self, initial_state=1, polynomial=0):
        self.lfsr = initial_state & self.LFSR_MASK
        self.polynomial = polynomial & self.LFSR_MASK
        self.sync_bits = 0
        self.sync_manual_d = 0
        self.count_reset_d = 0
        self.count_update = 0
        self.errors = 0
        self.error_counter = 0
        self.data_counter = 0

    def step(self, data_in, data_in_valid, sync_manual=0, sync_threshold=0,
             count_reset=0):
        """One clock cycle. Returns dict(data_count, error_count)."""
        DW = self.DATA_W
        GW = self.GENERATOR_W
        CW = self.COUNTER_W

        # Sync and count_reset edge/toggle detection
        if self.TOGGLE_CONTROL:
            sync_trigger = (sync_manual != self.sync_manual_d)
            count_reset_trigger = (count_reset != self.count_reset_d)
        else:
            sync_trigger = (sync_manual == 1)
            count_reset_trigger = (count_reset == 1)

        # Auto-sync: threshold > 0 and error_count > threshold
        auto_sync = (sync_threshold > 0 and self.error_counter > sync_threshold)

        sync_now = 1 if (sync_trigger or auto_sync) else 0
        count_reset_now = 1 if count_reset_trigger else 0

        self.sync_manual_d = sync_manual
        self.count_reset_d = count_reset

        if sync_now:
            self.sync_bits = GW - 1
            self.lfsr = 0
        else:
            prev_count_update = self.count_update
            self.count_update = 0

            if data_in_valid:
                if self.sync_bits > 0:
                    # Loading received data into LFSR for sync
                    # lfsr <= lfsr(GW-DW-1 downto DW-1) & data_in
                    # This shifts in data_in at the LSB end
                    self.lfsr = ((self.lfsr << DW) | (data_in & self.DATA_MASK)) & self.LFSR_MASK
                    self.sync_bits -= DW
                    if self.sync_bits < 0:
                        self.sync_bits = 0
                else:
                    # Normal operation: advance shadow LFSR and compare
                    v_lfsr = self.lfsr
                    for bit in range(DW):
                        masked = v_lfsr & self.polynomial
                        v_bit = _xor_reduce(masked)
                        v_lfsr = ((v_lfsr << 1) | v_bit) & self.LFSR_MASK
                    self.errors = (data_in ^ (v_lfsr & self.DATA_MASK)) & self.DATA_MASK
                    self.lfsr = v_lfsr
                    self.count_update = 1

        # Counter update
        if self.sync_bits > 0 or count_reset_now:
            self.error_counter = 0
            self.data_counter = 0
        elif self.count_update:
            self.error_counter = (self.error_counter + _count_ones(self.errors, DW)) & self.COUNTER_MASK
            self.data_counter = (self.data_counter + DW) & self.COUNTER_MASK

        return {
            'data_count': self.data_counter,
            'error_count': self.error_counter
        }


if __name__ == "__main__":
    # PRBS-7 loopback test
    poly_bits = (6, 5)  # x^7 + x^6 + 1 -> taps at 6,5 (0-indexed)
    poly_mask = 0
    for b in poly_bits:
        poly_mask |= (1 << b)

    gen = PrbsGenerator(data_w=1, generator_w=7)
    gen.reset(initial_state=0x02, polynomial=poly_mask)

    mon = PrbsMonitor(data_w=1, generator_w=7)
    mon.reset(initial_state=0x02, polynomial=poly_mask)

    print(f"PRBS-7 loopback test (polynomial=0x{poly_mask:02x})")
    errors_total = 0
    for i in range(200):
        gen_out = gen.step(data_req=1, prbs_sel=1)
        bit = gen_out['data_out']
        mon_out = mon.step(data_in=bit, data_in_valid=1, sync_manual=1 if i == 0 else 0)
        if i < 20 or mon_out['error_count'] > 0:
            print(f"  [{i:3d}] bit={bit}  data_count={mon_out['data_count']:4d}  "
                  f"error_count={mon_out['error_count']:4d}")
    print(f"  Final: data_count={mon_out['data_count']}  error_count={mon_out['error_count']}")
