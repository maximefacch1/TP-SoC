
-- --------------------------------------------------------------------
--   Ver  :| Author            :| Mod. Date   :| Changes Made:
--   V1.0 :| Peli  Li          :| 2010/03/22  :| Initial Revision
--   V2.0 :| Samir Bouaziz     :| 2016/12/05  :| VHDL version correct
-- --------------------------------------------------------------------

--clk   50MHz
--reset
--IRDA code input
--read command
--data ready
--decode data output
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_arith.all;
--use ieee.std_logic_unsigned.all;

entity IRDA_RECEIVER_id is
	port (
	--//////port ////////////

		iCLK	: in  std_logic;	--input clk,50MHz
		iRST_n	: in  std_logic;	--rst
		iIRDA	: in  std_logic;	--Irda RX output decoded data
		oDATA_READY	: out std_logic;	--data ready flag
		oDATA	: out std_logic_vector(7 downto 0) ;	--output data ,8bits 
				-- selecteur telecommande
		select_id : in std_logic_vector(7 downto 0);
		-- identifiant telecommande
		ir_id : out std_logic_vector(7 downto 0)

	);
end IRDA_RECEIVER_id;

architecture RTL of IRDA_RECEIVER_id is
--/////////////parameter///////////////
	constant IDLE	: std_logic_vector(1 downto 0) := "00";	--always high voltage level
	constant GUIDANCE	: std_logic_vector(1 downto 0) := "01";	--9 ms low voltage and 4.5 ms high voltage
	constant DATAREAD	: std_logic_vector(1 downto 0) := "10";	--0.6ms low voltage start and with 0.52ms high voltage is 0,with 1.66ms high voltage is 1, 32bit in sum.


	constant IDLE_HIGH_DUR	: unsigned(17 downto 0) := to_unsigned(262143,18);	-- data_count    131071*0.02us = 5.24ms, threshold for DATAREAD-----> IDLE
	constant GUIDE_LOW_DUR	: unsigned(17 downto 0) := to_unsigned(230000,18);	-- idle_count    230000*0.02us = 4.60ms, threshold for IDLE--------->GUIDANCE
	constant GUIDE_HIGH_DUR	: unsigned(17 downto 0) := to_unsigned(210000,18);	-- state_count   210000*0.02us = 4.20ms,  4.5-4.2 = 0.3ms<BIT_AVAILABLE_DUR = 0.4ms,threshold for GUIDANCE------->DATAREAD
	constant DATA_HIGH_DUR	: unsigned(17 downto 0) := to_unsigned(41500,18);	-- data_count    41500 *0.02us = 0.83ms, sample time from the posedge of iIRDA
	constant BIT_AVAILABLE_DUR	: unsigned(17 downto 0) := to_unsigned(20000,18);	-- data_count  20000.0.02us = 0.4ms,the sample bit pointer,can inhibit the interference from iIRDA signal
	--///////reg or wire/////////////////////

	signal DATA_REAY, detect_id	: std_logic;	--data ready flag

	signal idle_count	: unsigned(17 downto 0);	--idle_count counter work under data_read state
	signal idle_count_flag	: std_logic;	--idle_count conter flag

	signal state_count	: unsigned(17 downto 0);	--state_count counter work under guide state
	signal state_count_flag	: std_logic;	--state_count conter flag

	signal data_count	: unsigned(17 downto 0);	--data_count counter work under data_read state
	signal data_count_flag	: std_logic;	--data_count conter flag


	signal bitcount	: unsigned(5 downto 0);	--sample bit pointer
	signal state	: std_logic_vector(1 downto 0);	--state reg
	signal DATA	: std_logic_vector(31 downto 0);	--data reg
	signal DATA_BUF	: std_logic_vector(31 downto 0);	--data buf
	--data output reg

begin

	oDATA_READY	<= DATA_REAY;

	--idle count work on iclk under IDLE  state only
	v2v_pr_0:process (iCLK, iRST_n)
	begin
		if (not (iRST_n = '1')) then
			idle_count	<=  (others => '0');			--rst
		elsif (iCLK'event and iCLK = '1') then
			if (idle_count_flag = '1') then	--the counter start when the  flag is set 1
				idle_count	<= idle_count + 1;
			else
				idle_count	<= (others => '0');	--the counter stop when the  flag is set 0		      		 	
			end if;
		end if;
	end process;


	--idle counter switch when iIRDA is low under IDLE state

	v2v_pr_1:process (iCLK, iRST_n)
	begin
		if (not (iRST_n = '1')) then
			idle_count_flag	<= '0';			-- reset off
		elsif (iCLK'event and iCLK = '1') then
			if ((state = IDLE) and (not (iIRDA = '1'))) then			-- negedge start
				idle_count_flag	<= '1';				--on
			else
				--negedge
				idle_count_flag	<= '0';				--off     		 	
			end if;
		end if;
	end process;
	--state count work on iclk under GUIDE  state only
	v2v_pr_2:process (iCLK, iRST_n)
	begin
		if (not (iRST_n = '1')) then
			state_count	<= (others => '0');			--rst
		elsif (iCLK'event and iCLK = '1') then
			if (state_count_flag = '1') then			--the counter start when the  flag is set 1
				state_count	<= state_count + 1;
			else
				state_count	<= (others => '0');				--the counter stop when the  flag is set 0		      		 	
			end if;
		end if;
	end process;


	--state counter switch when iIRDA is high under GUIDE state

	v2v_pr_3:process (iCLK, iRST_n)
	begin
		if (not (iRST_n = '1')) then
			state_count_flag	<= '0';			-- reset off
		elsif (iCLK'event and iCLK = '1') then
			if ((state = GUIDANCE) and (iIRDA = '1')) then			-- posedge start
				state_count_flag	<= '1';				--on
			else
				--negedge
				state_count_flag	<= '0';				--off     		 	
			end if;
		end if;
	end process;


	--state change between IDLE,GUIDE,DATA_READ according to irda edge or counter
	v2v_pr_4:process (iCLK, iRST_n)
	begin
		if (not (iRST_n = '1')) then
			state	<= IDLE;			--RST 
		elsif (iCLK'event and iCLK = '1') then
			if ((state = IDLE) and (idle_count > GUIDE_LOW_DUR)) then			-- state chang from IDLE to Guidance when detect the negedge and the low voltage last for >2.6ms
				state	<= GUIDANCE;
			elsif (state = GUIDANCE) then			--state change from GUIDANCE to dataread if state_coun>13107 =2.6ms
				if (state_count > GUIDE_HIGH_DUR) then
					state	<= DATAREAD;
				end if;
			elsif (state = DATAREAD) then			--state change from DATAREAD to IDLE when data_count >IDLE_HIGH_DUR = 5.2ms,or the bit count = 33
				if ((data_count >= IDLE_HIGH_DUR) or (bitcount >="100001")) then
					state	<= IDLE;
				end if;
			else
				state	<= IDLE;				--default
			end if;
		end if;
	end process;


	-- data read decode counter based on iCLK
	v2v_pr_5:process (iCLK, iRST_n)
	begin
		if (not (iRST_n = '1')) then
			data_count	<= (others => '0');			--clear
		elsif (iCLK'event and iCLK = '1') then
			if (data_count_flag = '1') then
				data_count	<= data_count + 1;
			else
				data_count	<= (others => '0');				--stop and clear
			end if;
		end if;
	end process;
	--data counter switch
	v2v_pr_6:process (iCLK, iRST_n)
	begin
		if (not (iRST_n = '1')) then
			data_count_flag	<= '0';			--reset off the counter
		elsif (iCLK'event and iCLK = '1') then
			if (state = DATAREAD) then
				if (iIRDA = '1') then
					data_count_flag	<= '1';					--on when posedge
				else
					data_count_flag	<= '0';					--off when negedge
				end if;
			else
				data_count_flag	<= '0';				--off when other state				
			end if;
		end if;
	end process;


	-- data decode base on the value of data_count 	
	v2v_pr_7:process (iCLK, iRST_n)
	begin
		if ((not (iRST_n = '1'))) then
			DATA	<= (others => '0');			--rst
		elsif (iCLK'event and iCLK = '1') then
			if (state = DATAREAD) then
				if (data_count >= DATA_HIGH_DUR) then				--2^15 = 32767*0.02us = 0.64us
					DATA(to_integer(bitcount) - 1)	<= '1';					-->0.52ms  sample the bit 1
				elsif (DATA(to_integer(bitcount) - 1) = '1') then
					DATA(to_integer(bitcount) - 1)	<= DATA(to_integer(bitcount) - 1);					--<=0.52   sample the bit 0
				else
					DATA(to_integer(bitcount) - 1)	<= '0';
				end if;
			else
				DATA	<= (others => '0');
			end if;
		end if;
	end process;
	-- data reg pointer counter 
	v2v_pr_8:process (iCLK, iRST_n)
	begin
		if (not (iRST_n = '1')) then
			bitcount	<= (others => '0');			--rst
		elsif (iCLK'event and iCLK = '1') then
			if (state = DATAREAD) then
				if (data_count = 20000) then
					bitcount	<= bitcount + 1;					--add 1 when iIRDA posedge
				end if;
			else
				bitcount	<= (others => '0');
			end if;
		end if;
	end process;


	-- set the data_ready flag 
	v2v_pr_9:process (iCLK, iRST_n)
	begin
		if (not (iRST_n = '1')) then
			DATA_REAY	<= '0';			--rst
		elsif (iCLK'event and iCLK = '1') then
			if (bitcount = "100000") then			--32bit sample over
			   ir_id<=  DATA(7 downto 0);
				if (DATA(31 downto 24) = not DATA(23 downto 16)) and (detect_id='1') then
					DATA_BUF	<= DATA;					--fetch the value to the databuf from the data reg
					oDATA <= DATA(23 downto 16);
					DATA_REAY	<= '1';					--set the data ready flag
				else
					
					DATA_REAY	<= '0';					--data error
				end if;
			else
				DATA_REAY	<= '0';				--not ready
			end if;
		end if;
	end process;
	--read data

	detect_id <= '1' when (DATA(7 downto 0)=select_id) or (select_id=X"FF") else
					 '0';

end RTL;
