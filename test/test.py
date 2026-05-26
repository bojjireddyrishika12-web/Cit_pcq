import cocotb
from cocotb.triggers import Timer, ClockCycles

@cocotb.test()
async def test_project(dut):
    dut._log.info("Starting Parallel ECC Tests")

    # Start the clock
    cocotb.start_soon(cocotb.clock.Clock(dut.clk, 20, units="ns").start())

    # Reset the chip
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.ena.value = 1
    await Timer(40, units="ns")
    dut.rst_n.value = 1
    await Timer(20, units="ns")

    # TEST CASE 1: Healthy Parallel Input Data (0xA5)
    dut.ui_in.value = 0xA5
    await ClockCycles(dut.clk, 2)
    assert dut.uo_out.value == 0xA5, f"Expected 0xA5, got {hex(dut.uo_out.value)}"
    assert (dut.uio_out.value & 0x01) == 0, "Error flag should be LOW for clean data"

    # TEST CASE 2: Corrupted Channel Data (0xAD) - Bit 3 is flipped
    dut.ui_in.value = 0xAD
    await ClockCycles(dut.clk, 2)
    # The matrix must catch the single bit flip and self-heal it back to 0xA5!
    assert dut.uo_out.value == 0xA5, f"ECC Failed! Expected fixed 0xA5, got {hex(dut.uo_out.value)}"
    assert (dut.uio_out.value & 0x01) == 1, "Error flag should be HIGH for corrupted data"

    dut._log.info("All parallel 8-bit ECC test assertions passed successfully!")
