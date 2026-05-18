library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lpm;
use lpm.all;

------------------------------------
-- FREQUENCE FPGA: 50 MHZ ----
------------------------------------

entity PWM_generation is
	port(
		clk,reset_n:in std_logic;
		s_writedataR,s_writedataL: in std_logic_vector(13 downto 0);		
			-- Le bit13 : bit de go(1)/stop(0). 
			-- Le bit12: bit de forward(0)/backward(1). 
			-- Les bits 11 à 0: vitesse=durée état haut
			dc_motor_p_R,dc_motor_n_R, dc_motor_p_L,dc_motor_n_L: out std_logic
			);
end entity;


architecture arch of PWM_generation is

-- constantes et signaux internes
constant freqfpga: integer:=50000000;
constant freqpwm: integer:=16000;
signal PWMr,PWMl: std_logic;
signal tick: unsigned(31 downto 0):=(others=>'0');
signal total_dur: std_logic_vector(11 downto 0);

begin
total_dur<=std_logic_vector(to_unsigned(freqfpga/freqpwm,12));

process(clk,reset_n)
begin
			 if rising_edge(clk) then
                    if (reset_n='0') then
                            tick <= to_unsigned(0,32);
                            PWMr <='0';
									 PWMl <='0';
                    elsif (tick >= unsigned(total_dur)) then
                            tick <=to_unsigned(0,32);
                            PWMr <='1';
									 PWMl <='1';
                    else    
									tick<=tick+1;
                            if (tick > unsigned(s_writedataL(11 downto 0))) then
                                    PWMl <= '0';
                            end if;
									 if (tick > unsigned(s_writedataR(11 downto 0))) then
                                    PWMr <= '0';
                            end if;
                    end if;
            end if;
end proCESS;

dc_motor_p_R <= PWMR when  s_writedataR(13)='1' and s_writedataR(12)='0' else
					'0';
dc_motor_n_R <= PWMR when  s_writedataR(13)='1' and s_writedataR(12)='1' else
					'0';
dc_motor_p_L <= '0' when  s_writedataL(13)='1' and s_writedataL(12)='0' else
					PWML;
dc_motor_n_L <= '0' when  s_writedataL(13)='1' and s_writedataL(12)='1' else
					PWML;				




end architecture arch;

			
