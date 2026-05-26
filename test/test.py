# SPDX-FileCopyrightText: 2024 Bojjireddy Rishika
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock                   # ✅ Fix: was cocotb.clock.Clock
from cocotb.triggers import Timer, ClockCycles

@cocotb.test()
async def test_project(dut):
    """Robust parallel test for PQC Core"""
    dut._log.info("Starting PQC Core Verification...")

    # ✅ Fix: Clock imported directly, not via cocotb.clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    # Apply reset (active-low)
    dut.rst_n.value  = 0
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.ena.value    = 1

    await Timer(40, units="ns")   # Hold reset for 2 cycles

    # Release reset
    dut.rst_n.value = 1
    await Timer(20, units="ns")   # 1 cycle settle

    # --- Test vectors: expected = (ui_in XOR 0x5A) + 0x0F ---
    test_vectors = [
        (0x00, ((0x00 ^ 0x5A) + 0x0F) & 0xFF),  # 0x69
        (0xA5, ((0xA5 ^ 0x5A) + 0x0F) & 0xFF),  # 0x0E
        (0xFF, ((0xFF ^ 0x5A) + 0x0F) & 0xFF),  # 0xB4
        (0x5A, ((0x5A ^ 0x5A) + 0x0F) & 0xFF),  # 0x0F
        (0x01, ((0x01 ^ 0x5A) + 0x0F) & 0xFF),  # 0x6A
    ]

    for ui_val, expected in test_vectors:
        dut.ui_in.value = ui_val
        await ClockCycles(dut.clk, 2)            # Wait for register to update

        # Check crypto output
        got = int(dut.uo_out.value)
        assert got == expected, \
            f"FAIL ui_in=0x{ui_val:02X}: got 0x{got:02X}, expected 0x{expected:02X}"

        # Check status flags: ready=1, done=1 → uio_out[1:0] = 0b11
        status = int(dut.uio_out.value) & 0x03
        assert status == 0x03, \
            f"FAIL: Status flags wrong, uio_out=0x{int(dut.uio_out.value):02X}"

        # Check output enables
        assert int(dut.uio_oe.value) == 0x03, \
            f"FAIL: uio_oe expected 0x03, got 0x{int(dut.uio_oe.value):02X}"

        dut._log.info(f"PASS: ui_in=0x{ui_val:02X} → uo_out=0x{got:02X} ✓")

    dut._log.info("All verification checks passed!")
