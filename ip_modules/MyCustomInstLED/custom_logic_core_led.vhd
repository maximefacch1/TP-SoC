library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity custom_logic_core_led is
    port (
        core_clk    : in  std_logic;                    -- Horloge interne
        core_en     : in  std_logic;                    -- Activation interne
        --core_start  : in  std_logic;                    -- Début de l’opération
        --core_done   : out std_logic;                    -- Fin de l’opération
        core_dataa  : in  std_logic_vector(31 downto 0); -- Premier opérande
        --core_datab  : in  std_logic_vector(31 downto 0); -- Deuxième opérande
        core_n      : in  std_logic_vector(7 downto 0);  -- Sélecteur
        core_result : out std_logic_vector(31 downto 0);  -- Résultat
		  core_export : out std_logic_vector(7 downto 0)  -- Résultat
		  
    );
end entity custom_logic_core_led;

architecture behavioral of custom_logic_core_led is
SIGNAL tmp : std_logic_vector(31 downto 0);
begin
    process(core_clk)
    begin
        if rising_edge(core_clk) then
            if core_en = '1' then
                case core_n is
                    when x"00" => -- XOR simple
                        tmp <= core_dataa;
                        --core_done <= '1';
                    when x"01" => -- XOR avec décalage de 1 bit
								tmp <= std_logic_vector(shift_left(unsigned(core_dataa), 1));
                    when x"02" => -- Addition
								tmp <= std_logic_vector(shift_left(unsigned(core_dataa), 2));
                        --core_done <= '1';
                    when others =>
                        tmp <= (others => '0');
                        --core_done <= '1';
                end case;
            --else
                --core_done <= '0';
            end if;
        end if;
    end process;
	 core_export <= tmp(7 downto 0);
	 core_result <= tmp;
	 
end architecture behavioral;