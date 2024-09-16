import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock    import Clock
from cocotb.utils    import get_sim_time

import prbs31

@cocotb.test()
async def prbs_mon_test(dut):

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


@cocotb.test()
async def prbs_loopback_test(dut):

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

	dut.init.value = 1
	dut.initial_state.value = start
	dut.polynomial.value = poly_mask
	dut.error_insert.value = 0
	dut.error_mask.value = 1	
	dut.prbs_sel.value = 1
	dut.data_in.value = 0		
	dut.data_req.value = 0
	dut.sync.value = 1
	dut.count_reset.value = 1

	print("Polynomial: ", hex(poly_mask))

	await cocotb.start(Clock(dut.clk, 10, units="ns").start())

	await Timer(1, "us")
	await RisingEdge(dut.clk)
	dut.init.value = 0
	await RisingEdge(dut.clk)
	dut.data_req.value = 1
	dut.sync.value = 0
	dut.count_reset.value = 0

	dut._log.info("Simulation starting")

	while dut.data_count.value.integer <= 10000:

		await RisingEdge(dut.clk)

		if (dut.data_count.value.integer % 0x100_0000) == 0 and dut.data_count.value.integer > 0:
			print("Count: ", hex(dut.data_count.value.integer))

		assert dut.error_count.value.integer == 0, "Unexpected error!"

	dut._log.info("No errors for 10000 values")

	dut._log.info("Inserting bit error")
	dut.error_insert.value = 1
	await RisingEdge(dut.clk)
	dut.error_insert.value = 0

	while True:

		await RisingEdge(dut.clk)

		if dut.error_count.value.integer > 0:
			dut._log.info("Error detected")
			break		
	
	dut._log.info("Simulating 1 clock sync")

	dut.sync.value = 1
	await RisingEdge(dut.clk)
	dut.sync.value = 0

	while dut.error_count.value.integer > 0:
		await RisingEdge(dut.clk)

	while dut.data_count.value.integer <= 10000:

		await RisingEdge(dut.clk)

		if (dut.data_count.value.integer % 0x100_0000) == 0 and dut.data_count.value.integer > 0:
			print("Count: ", hex(dut.data_count.value.integer))

		assert dut.error_count.value.integer == 0, "Unexpected error!"

	dut._log.info("No errors for 10000 values")

	dut._log.info("Inserting bit error")
	dut.error_insert.value = 1
	await Timer(10, "us")
	await RisingEdge(dut.clk)
	dut.error_insert.value = 0

	while True:

		await RisingEdge(dut.clk)

		if dut.error_count.value.integer > 0:
			dut._log.info("Error detected")
			break
	
	dut._log.info("Simulating 10 us sync")
	dut.sync.value = 1
	await Timer(10, "us")
	await RisingEdge(dut.clk)
	dut.sync.value = 0

	while dut.data_count.value.integer <= 10000:

		await RisingEdge(dut.clk)

		if (dut.data_count.value.integer % 0x100_0000) == 0 and dut.data_count.value.integer > 0:
			print("Count: ", hex(dut.data_count.value.integer))

		assert dut.error_count.value.integer == 0, "Unexpected error!"

	dut._log.info("No errors for 10000 values")

	dut._log.info("Inserting bit error")
	dut.error_insert.value = 1
	await RisingEdge(dut.clk)
	dut.error_insert.value = 0

	while True:

		await RisingEdge(dut.clk)

		if dut.error_count.value.integer > 0:
			dut._log.info("Error detected")
			break
	

	dut._log.info("Simulating 1 clock count reset")
	dut.count_reset.value = 1
	await RisingEdge(dut.clk)
	dut.count_reset.value = 0

	while dut.error_count.value.integer > 0:
		await RisingEdge(dut.clk)

	while dut.data_count.value.integer <= 10000:

		await RisingEdge(dut.clk)

		if (dut.data_count.value.integer % 0x100_0000) == 0 and dut.data_count.value.integer > 0:
			print("Count: ", hex(dut.data_count.value.integer))

		assert dut.error_count.value.integer == 0, "Unexpected error!"

	dut._log.info("No errors for 10000 values")

	dut._log.info("Inserting bit error")
	dut.error_insert.value = 1
	await Timer(10, "us")
	await RisingEdge(dut.clk)
	dut.error_insert.value = 0

	while True:

		await RisingEdge(dut.clk)

		if dut.error_count.value.integer > 0:
			dut._log.info("Error detected")
			break
	

	dut._log.info("Simulating 10 us count reset")
	dut.count_reset.value = 1
	await Timer(10, "us")
	await RisingEdge(dut.clk)
	dut.count_reset.value = 0

	while dut.data_count.value.integer <= 10000:

		await RisingEdge(dut.clk)

		if (dut.data_count.value.integer % 0x100_0000) == 0 and dut.data_count.value.integer > 0:
			print("Count: ", hex(dut.data_count.value.integer))

		assert dut.error_count.value.integer == 0, "Unexpected error!"

	dut._log.info("No errors for 10000 values")
	dut._log.info("Simulating for 0x150_0000 values")

	while dut.data_count.value.integer <= 0x150_0000:

		await RisingEdge(dut.clk)

		if (dut.data_count.value.integer % 0x100_0000) == 0 and dut.data_count.value.integer > 0:
			print("Count: ", hex(dut.data_count.value.integer))

		assert dut.error_count.value.integer == 0, "Unexpected error!"

		if dut.data_count.value.integer == lfsr_mask:
			dut._log.info("Simulation complete!")
			break

	dut._log.info("No errors. Simulation Complete!")