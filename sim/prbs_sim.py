import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock    import Clock
from cocotb.utils    import get_sim_time

import prbs31

@cocotb.test()
async def prbs_test(dut):

	start = 0x7FFF0000
	
	lfsr = start
	count = 0
	
	lfsr_length = 31
	poly_bits = (30, 27)
	
	lfsr_mask = 2**lfsr_length-1
	poly_mask = 0
	    
	for bit in poly_bits:
	    poly_mask += 1 << bit

	count_zeros = 0
	count_ones = 0

	lfsr = prbs31.lfsr_example(start, poly_bits, lfsr_mask)

	dut.init.value = 1
	dut.initial_state.value = start
	dut.polynomial.value = poly_mask
	dut.error_insert.value = 0
	dut.error_mask.value = 1	
	dut.prbs_sel.value = 1
	dut.data_in.value = 0		
	dut.data_req.value = 0

	print("Polynomial: ", hex(poly_mask))

	await cocotb.start(Clock(dut.clk, 10, units="ns").start())

	await Timer(1, "us")
	await RisingEdge(dut.clk)
	dut.init.value = 0

	while True:

		count += 1

		dut.data_req.value = 1

		await RisingEdge(dut.clk)

		dut.data_req.value = 0

		await RisingEdge(dut.clk)

		lfsr.step()

		assert lfsr.lfsr == dut.lfsr.value.integer, "LFSR Mismatch!"

		if lfsr.lfsr == start:
			dut._log.info("Simulation complete! LFSR Period: ", count)



