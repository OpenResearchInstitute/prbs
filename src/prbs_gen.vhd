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


------------------------------------------------------------------------------------------------------
-- ╔═╗┌┐┌┌┬┐┬┌┬┐┬ ┬
-- ║╣ │││ │ │ │ └┬┘
-- ╚═╝┘└┘ ┴ ┴ ┴  ┴ 
------------------------------------------------------------------------------------------------------
-- Entity

ENTITY prbs_gen IS 
	GENERIC (
		DATA_W 			: NATURAL :=  1;
		GENERATOR_W		: NATURAL := 32;
		GENERATOR_BITS 	: NATURAL :=  5
	);
	PORT (
		clk 				: IN  std_logic;
		init 				: IN  std_logic;

		initial_state 		: IN  std_logic_vector(GENERATOR_W -1 DOWNTO 0);
		polynomial 			: IN  std_logic_vector(GENERATOR_W -1 DOWNTO 0);

		error_insert 		: IN  std_logic;
		error_mask 			: IN  std_logic_vector(DATA_W -1 DOWNTO 0);

		prbs_sel 			: IN  std_logic;

		data_in				: IN  std_logic_vector(DATA_W -1 DOWNTO 0);
		data_req			: IN  std_logic;

		data_out 			: OUT std_logic_vector(DATA_W -1 DOWNTO 0)
	);
END ENTITY prbs_gen;


------------------------------------------------------------------------------------------------------
-- ╔═╗┬─┐┌─┐┬ ┬┬┌┬┐┌─┐┌─┐┌┬┐┬ ┬┬─┐┌─┐
-- ╠═╣├┬┘│  ├─┤│ │ ├┤ │   │ │ │├┬┘├┤ 
-- ╩ ╩┴└─└─┘┴ ┴┴ ┴ └─┘└─┘ ┴ └─┘┴└─└─┘
------------------------------------------------------------------------------------------------------
-- Architecture

ARCHITECTURE rtl OF prbs_gen IS 

	SIGNAL lfsr : std_logic_vector(GENERATOR_W -1 DOWNTO 0);
	SIGNAL error_arm : std_logic;
	SIGNAL lfsr_and : std_logic_vector(GENERATOR_W -1 DOWNTO 0);
	SIGNAL lfsr_bit : std_logic;

BEGIN

	data_proc : PROCESS (clk)
		VARIABLE v_data_mux : std_logic_vector(DATA_W -1 DOWNTO 0);
	BEGIN
		IF clk'EVENT AND clk = '1' THEN

			IF error_insert = '1' THEN
				error_arm <= '1';
			END IF;

			IF prbs_sel = '1' THEN
				v_data_mux := lfsr(DATA_W -1 DOWNTO 0);
			ELSE
				v_data_mux := data_in;
			END IF;

			IF data_req = '1' THEN
				IF error_arm = '1' THEN
					data_out 	<= v_data_mux XOR error_mask;
					error_arm 	<= '0';
				ELSE
					data_out 	<= v_data_mux;
				END IF;
			END IF;

			IF init = '1' THEN
				error_arm 	<= '0';
				data_out	<= (OTHERS => '0');
			END IF;

		END IF;
	END PROCESS data_proc;


	lfsr_proc : PROCESS (clk)
		VARIABLE v_lfsr : std_logic_vector(GENERATOR_W -1 DOWNTO 0);
		VARIABLE v_bit 	 : std_logic;
	BEGIN
		IF clk'EVENT AND clk = '1' THEN

			IF data_req = '1' THEN
				v_lfsr := lfsr;
	
				FOR bit IN 0 TO DATA_W -1 LOOP 
					v_lfsr := v_lfsr AND polynomial;
					lfsr_and <= v_lfsr;
					v_bit  := XOR_REDUCE(v_lfsr);
					lfsr_bit <= v_bit;
					v_lfsr := lfsr(GENERATOR_W -2 DOWNTO 0) & v_bit;
				END LOOP;
	
				lfsr 	<= v_lfsr;
			END IF;

			IF init = '1' THEN 
				lfsr <= initial_state;
			END IF;

		END IF;

	END PROCESS lfsr_proc;

END ARCHITECTURE rtl;