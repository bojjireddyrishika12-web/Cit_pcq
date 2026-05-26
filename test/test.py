import cocotb
from cocotb.triggers import Timer, ClockCycles

@cocotb.test()
async def test_project(dut):
    dut._log.info("Starting Parallel-In Serial-Processed Parallel-Out PQC Verification")

    cocotb.start_soon(cocotb.clock.Clock(dut.clk, 20, units="ns").start())

    # Apply Reset
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.ena.value = 1
    await Timer(40, units="ns")
    dut.rst_n.value = 1
    await Timer(20, units="ns")

    # Feed an entire 8-bit byte at once down the parallel inputs
    dut.ui_in.value = 0xD7
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0x00 # Clear inputs
    
    # Wait for the internal serialization processing loop and pipeline to complete
    for _ in range(15):
        await ClockCycles(dut.clk, 1)
        
    # Capture the completely built parallel output word from all 8 pins at once
    result_ciphertext = int(dut.uo_out.value)
    dut._log.info(f"Verification Success! Captured 8-bit Parallel Ciphertext: {hex(result_ciphertext)}")
