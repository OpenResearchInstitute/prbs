------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
--  _______                             ________                                            ______
--  __  __ \________ _____ _______      ___  __ \_____ _____________ ______ ___________________  /_
--  _  / / /___  __ \_  _ \__  __ \     __  /_/ /_  _ \__  ___/_  _ \_  __ `/__  ___/_  ___/__  __ \
--  / /_/ / __  /_/ //  __/_  / / /     _  _, _/ /  __/_(__  ) /  __// /_/ / _  /    / /__  _  / / /
--  \____/  _  .___/ \___/ /_/ /_/      /_/ |_|  \___/ /____/  \___/ \__,_/  /_/     \___/  /_/ /_/
--          /_/
--                   ________                _____ _____ _____         _____
--                   ____  _/_______ __________  /____(_)__  /_____  ____  /______
--                    __  /  __  __ \__  ___/_  __/__  / _  __/_  / / /_  __/_  _ \
--                   __/ /   _  / / /_(__  ) / /_  _  /  / /_  / /_/ / / /_  /  __/
--                   /___/   /_/ /_/ /____/  \__/  /_/   \__/  \__,_/  \__/  \___/
--
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
-- Copyright
------------------------------------------------------------------------------------------------------
--
-- Copyright 2024 by M. Wishek <matthew@wishek.com>
--
------------------------------------------------------------------------------------------------------
-- License
------------------------------------------------------------------------------------------------------
--
-- This source describes Open Hardware and is licensed under the CERN-OHL-W v2.
--
-- You may redistribute and modify this source and make products using it under
-- the terms of the CERN-OHL-W v2 (https://ohwr.org/cern_ohl_w_v2.txt).
--
-- This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING
-- OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A PARTICULAR PURPOSE.
-- Please see the CERN-OHL-W v2 for applicable conditions.
--
-- Source location: TBD
--
-- As per CERN-OHL-W v2 section 4.1, should You produce hardware based on this
-- source, You must maintain the Source Location visible on the external case of
-- the products you make using this source.
--
------------------------------------------------------------------------------------------------------
-- Block name and description
------------------------------------------------------------------------------------------------------
--
-- This block implements a PRBS generator and bit-error insertion.
--
-- Documentation location: TBD
--
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------
-- ╦  ┬┌┐ ┬─┐┌─┐┬─┐┬┌─┐┌─┐
-- ║  │├┴┐├┬┘├─┤├┬┘│├┤ └─┐
-- ╩═╝┴└─┘┴└─┴ ┴┴└─┴└─┘└─┘
------------------------------------------------------------------------------------------------------
-- Libraries

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_misc.ALL;
USE ieee.math_real.ALL;

------------------------------------------------------------------------------------------------------
-- ╔═╗┌┐┌┌┬┐┬┌┬┐┬ ┬
-- ║╣ │││ │ │ │ └┬┘
-- ╚═╝┘└┘ ┴ ┴ ┴  ┴ 
------------------------------------------------------------------------------------------------------
-- Entity

ENTITY prbs_mon IS 
	GENERIC (
		DATA_W 			: NATURAL :=  1;
		GENERATOR_W		: NATURAL := 31;
		COUNTER_W 		: NATURAL := 32;
		THRESHOLD_W 	: NATURAL := 16;
		TOGGLE_CONTROL  : BOOLEAN := True
	);
	PORT (
		clk 				: IN  std_logic;
		init 				: IN  std_logic;

		sync_manual 		: IN  std_logic;
		sync_threshold 		: IN  std_logic_vector(THRESHOLD_W -1 DOWNTO 0);
		initial_state 		: IN  std_logic_vector(GENERATOR_W -1 DOWNTO 0);
		polynomial 			: IN  std_logic_vector(GENERATOR_W -1 DOWNTO 0);
		count_reset 		: IN  std_logic;

		data_count 			: OUT std_logic_vector(COUNTER_W -1 DOWNTO 0);
		error_count 		: OUT std_logic_vector(COUNTER_W -1 DOWNTO 0);

		data_in				: IN  std_logic_vector(DATA_W -1 DOWNTO 0);
		data_in_valid		: IN  std_logic
	);
END ENTITY prbs_mon;


------------------------------------------------------------------------------------------------------
-- ╔═╗┬─┐┌─┐┬ ┬┬┌┬┐┌─┐┌─┐┌┬┐┬ ┬┬─┐┌─┐
-- ╠═╣├┬┘│  ├─┤│ │ ├┤ │   │ │ │├┬┘├┤ 
-- ╩ ╩┴└─└─┘┴ ┴┴ ┴ └─┘└─┘ ┴ └─┘┴└─└─┘
------------------------------------------------------------------------------------------------------
-- Architecture

ARCHITECTURE rtl OF prbs_mon IS 

	CONSTANT GENERATOR_BITS	: NATURAL :=  integer(ceil(log2(real(GENERATOR_W))));

	SIGNAL lfsr 			: std_logic_vector(GENERATOR_W -1 DOWNTO 0);

	SIGNAL sync_bits 		: unsigned(GENERATOR_BITS DOWNTO 0);

	SIGNAL count_update 	: std_logic;

	SIGNAL errors 			: std_logic_vector(DATA_W -1 DOWNTO 0);

	SIGNAL error_counter	: std_logic_vector(COUNTER_W -1 DOWNTO 0);
	SIGNAL data_counter 	: std_logic_vector(COUNTER_W -1 DOWNTO 0);

	SIGNAL sync_manual_d	: std_logic;
	SIGNAL count_reset_d	: std_logic;

	SIGNAL sync_now 		: std_logic;
	SIGNAL count_reset_now 	: std_logic;

	FUNCTION count_ones ( bits : std_logic_vector ) RETURN std_logic_vector IS 
		VARIABLE v_ones : NATURAL;
	BEGIN 

		v_ones := 0;

		FOR i IN 0 TO bits'LENGTH -1 LOOP 
			IF bits(i) = '1' THEN 
				v_ones := v_ones + 1;
			END IF;
		END LOOP;

		RETURN std_logic_vector(to_unsigned(v_ones,GENERATOR_BITS));

	END FUNCTION count_ones;

BEGIN

	sync_now 		<= '1' WHEN (sync_manual = '1' AND NOT TOGGLE_CONTROL) OR 
				         		(sync_manual /= sync_manual_d AND TOGGLE_CONTROL) OR 
				         		(to_integer(unsigned(sync_threshold)) > 0 AND 
				         			unsigned(error_counter) > unsigned(sync_threshold))
				        ELSE '0';

	count_reset_now <= '1' WHEN (count_reset = '1' AND NOT TOGGLE_CONTROL) OR 
				         		(count_reset /= count_reset_d AND TOGGLE_CONTROL) 
				        ELSE '0';

	lfsr_proc : PROCESS (clk)
		VARIABLE v_lfsr : std_logic_vector(GENERATOR_W -1 DOWNTO 0);
		VARIABLE v_bit 	 : std_logic;
	BEGIN
		IF clk'EVENT AND clk = '1' THEN

			sync_manual_d <= sync_manual;
			count_reset_d <= count_reset;

			IF sync_now = '1' THEN
				sync_bits <= to_unsigned(GENERATOR_W-1, GENERATOR_BITS + 1);
			ELSE

				v_lfsr 			:= lfsr;
				count_update 	<= '0';

				IF data_in_valid = '1' THEN
	
					IF sync_bits > 0 THEN
	
						lfsr <= lfsr(GENERATOR_W - DATA_W -1 DOWNTO DATA_W -1) & data_in;
						sync_bits <= sync_bits - to_unsigned(DATA_W, GENERATOR_BITS);
	
					ELSE
	
						FOR bit IN 0 TO DATA_W -1 LOOP 
							v_lfsr := v_lfsr AND polynomial;
							v_bit  := XOR_REDUCE(v_lfsr);
							v_lfsr := lfsr(GENERATOR_W -2 DOWNTO 0) & v_bit;
						END LOOP;
	
						errors 			<= std_logic_vector(resize(unsigned(data_in XOR v_lfsr(DATA_W -1 DOWNTO 0)), DATA_W));
						lfsr 			<= v_lfsr;
						count_update 	<= '1';
	
					END IF;
	
				END IF;

			END IF;

			IF init = '1' THEN 
				lfsr 			<= initial_state;
				sync_bits 		<= (OTHERS => '0');
				sync_manual_d 	<= '0';
				count_reset_d 	<= '0';
			END IF;

		END IF;

	END PROCESS lfsr_proc;

	error_count <= error_counter;
	data_count 	<= data_counter;

	count_proc : PROCESS (clk)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN

			IF to_integer(sync_bits) > 0 OR count_reset_now = '1' THEN 
				error_counter <= (OTHERS => '0');
				data_counter  <= (OTHERS => '0');
			ELSIF count_update = '1' THEN
				error_counter <= std_logic_vector(unsigned(error_counter) + unsigned(count_ones(errors)));
				data_counter  <= std_logic_vector(unsigned(data_counter)  + to_unsigned(DATA_W, COUNTER_W));
			END IF;

			IF init = '1' THEN
				error_counter <= (OTHERS => '0');
				data_counter  <= (OTHERS => '0');
			END IF;				

		END IF;
	END PROCESS count_proc;


END ARCHITECTURE rtl;
