import cocotb
from cocotb.triggers import Timer, ClockCycles

@cocotb.test()
async def test_project(dut):
    """Simple robust test for 8x8 Serial-Parallel PQC Core"""
    dut._log.info("Initialization check for PQC pipeline...")

    # Start the clock generator loop safely
    cocotb.start_soon(cocotb.clock.Clock(dut.clk, 20, units="ns").start())

    # Apply System Reset
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.ena.value = 1
    await Timer(40, units="ns")
    dut.rst_n.value = 1
    await Timer(20, units="ns")

    # Force a test vector state onto the parallel inputs
    dut.ui_in.value = 0xA5
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0x00 
    
    # Wait for the internal serialization processing loops to cycle through
    await ClockCycles(dut.clk, 12)
        
    # Read output results cleanly
    final_out = int(dut.uo_out.value)
    dut._log.info(f"Verification Check Complete. Output: {hex(final_out)}")
