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

ENTITY prbs_tb IS 
	GENERIC (
		DATA_W 			: NATURAL :=  1;
		GENERATOR_W		: NATURAL := 31;
		GENERATOR_BITS 	: NATURAL :=  5;
		COUNTER_W 		: NATURAL := 32
	);
	PORT (
		clk 				: IN  std_logic;
		init 				: IN  std_logic;

		initial_state 		: IN  std_logic_vector(GENERATOR_W -1 DOWNTO 0);
		polynomial 			: IN  std_logic_vector(GENERATOR_W -1 DOWNTO 0);

		prbs_sel 			: IN  std_logic;

		error_insert 		: IN  std_logic;
		error_mask 			: IN  std_logic_vector(DATA_W -1 DOWNTO 0);

		sync 				: IN  std_logic;
		count_reset 		: IN  std_logic;

		data_in				: IN  std_logic_vector(DATA_W -1 DOWNTO 0);
		data_req			: IN  std_logic;

		data_count 			: OUT std_logic_vector(COUNTER_W -1 DOWNTO 0);
		error_count 		: OUT std_logic_vector(COUNTER_W -1 DOWNTO 0)

	);
END ENTITY prbs_tb;

------------------------------------------------------------------------------------------------------
-- ╔═╗┬─┐┌─┐┬ ┬┬┌┬┐┌─┐┌─┐┌┬┐┬ ┬┬─┐┌─┐
-- ╠═╣├┬┘│  ├─┤│ │ ├┤ │   │ │ │├┬┘├┤ 
-- ╩ ╩┴└─└─┘┴ ┴┴ ┴ └─┘└─┘ ┴ └─┘┴└─└─┘
------------------------------------------------------------------------------------------------------
-- Architecture

ARCHITECTURE testbench OF prbs_tb IS 

	SIGNAL prbs_data 	: std_logic_vector(DATA_W -1 DOWNTO 0);
	SIGNAL prbs_valid	: std_logic;

BEGIN

	data_clk : PROCESS (clk)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN 

			prbs_valid <= data_req;

			IF init = '1' THEN
				prbs_valid <= '0';
			END IF;

		END IF;
	END PROCESS data_clk;

	U_prbs_gen : ENTITY work.prbs_gen(rtl)
		GENERIC MAP (
			DATA_W 			=> DATA_W,
			GENERATOR_W		=> GENERATOR_W,
			GENERATOR_BITS 	=> GENERATOR_BITS
		)
		PORT MAP (
			clk 				=> clk,
			init 				=> init,
	
			initial_state 		=> initial_state,
			polynomial 			=> polynomial,
	
			error_insert 		=> error_insert,
			error_mask 			=> error_mask,
	
			prbs_sel 			=> prbs_sel,
	
			data_in				=> data_in,
			data_req			=> data_req,
	
			data_out 			=> prbs_data
		);

		U_prbs_mon : ENTITY work.prbs_mon(rtl)
		GENERIC MAP (
			DATA_W 			=> DATA_W,
			GENERATOR_W		=> GENERATOR_W,
			COUNTER_W 		=> COUNTER_W,
			GENERATOR_BITS 	=> GENERATOR_BITS
		)
		PORT MAP (
			clk 				=> clk,
			init 				=> init,
	
			initial_state 		=> initial_state,
			polynomial 			=> polynomial,

			sync 				=> sync,
			count_reset 		=> count_reset,
	
			data_count 			=> data_count,
			error_count 		=> error_count,
	
			data_in				=> prbs_data,
			data_in_valid 		=> prbs_valid
		);

END ARCHITECTURE testbench;
