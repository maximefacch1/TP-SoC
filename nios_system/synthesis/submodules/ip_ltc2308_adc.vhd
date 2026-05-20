-- =========================================================
-- Fichier : ip_ltc2308_adc.vhd
-- Description :
-- Interface Avalon-MM pour Qsys
-- Communication Nios II <-> ADC core
-- =========================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ip_ltc2308_adc is
    port (

        clk      : in  std_logic;
        reset_n  : in  std_logic;

        chipselect : in  std_logic;
        write      : in  std_logic;
        read       : in  std_logic;

        address    : in  std_logic_vector(3 downto 0);

        writedata  : in  std_logic_vector(31 downto 0);

        readdata   : out std_logic_vector(31 downto 0);

        adc_convst : out std_logic;
        adc_sck    : out std_logic;
        adc_sdo    : in  std_logic;
        adc_sdi    : out std_logic;

        ir_led_on  : out std_logic
    );
end entity;

architecture rtl of ip_ltc2308_adc is

    signal control_reg : std_logic_vector(31 downto 0);

    signal channel_reg : std_logic_vector(2 downto 0);

    signal start_core : std_logic;

    signal busy_core : std_logic;
    signal done_core : std_logic;

    signal data_core : std_logic_vector(11 downto 0);

    signal data_reg : std_logic_vector(11 downto 0);

    type channel_array_t is array (0 to 7)
        of std_logic_vector(11 downto 0);

    signal channel_data : channel_array_t;

    component ltc2308_adc_core is
        port (

            clk      : in  std_logic;
            reset_n  : in  std_logic;

            start    : in  std_logic;
            channel  : in  std_logic_vector(2 downto 0);

            busy     : out std_logic;
            done     : out std_logic;

            data     : out std_logic_vector(11 downto 0);

            adc_convst : out std_logic;
            adc_sck    : out std_logic;
            adc_sdo    : in  std_logic;
            adc_sdi    : out std_logic
        );
    end component;

begin

    ir_led_on <= control_reg(1);

    adc_core_inst : ltc2308_adc_core
        port map (

            clk      => clk,
            reset_n  => reset_n,

            start    => start_core,
            channel  => channel_reg,

            busy     => busy_core,
            done     => done_core,

            data     => data_core,

            adc_convst => adc_convst,
            adc_sck    => adc_sck,
            adc_sdo    => adc_sdo,
            adc_sdi    => adc_sdi
        );

    process(
        address,
        control_reg,
        channel_reg,
        data_reg,
        channel_data,
        busy_core,
        done_core,
        adc_sdo
    )
    begin

        readdata <= (others => '0');

        case address is

            when "0000" =>

                readdata <= control_reg;

            when "0001" =>

                readdata(2 downto 0) <= channel_reg;

            when "0010" =>

                readdata(11 downto 0) <= data_reg;

            when "0011" =>

                readdata(0) <= busy_core;
                readdata(1) <= done_core;
                readdata(2) <= adc_sdo;

            when "0100" =>

                readdata(11 downto 0) <= channel_data(0);

            when "0101" =>

                readdata(11 downto 0) <= channel_data(1);

            when "0110" =>

                readdata(11 downto 0) <= channel_data(2);

            when "0111" =>

                readdata(11 downto 0) <= channel_data(3);

            when "1000" =>

                readdata(11 downto 0) <= channel_data(4);

            when "1001" =>

                readdata(11 downto 0) <= channel_data(5);

            when "1010" =>

                readdata(11 downto 0) <= channel_data(6);

            when "1011" =>

                readdata(11 downto 0) <= channel_data(7);

            when others =>

                readdata <= (others => '0');

        end case;

    end process;

    process(clk, reset_n)
    begin

        if reset_n = '0' then

            control_reg <= (others => '0');

            channel_reg <= (others => '0');

            start_core <= '0';

            data_reg <= (others => '0');

            for i in 0 to 7 loop
                channel_data(i) <= (others => '0');
            end loop;

        elsif rising_edge(clk) then

            start_core <= '0';

            if done_core = '1' then

                data_reg <= data_core;

                channel_data(
                    to_integer(unsigned(channel_reg))
                ) <= data_core;

            end if;

            if chipselect = '1' and write = '1' then

                case address is

                    when "0000" =>

                        control_reg <= writedata;

                        if writedata(0) = '1' and busy_core = '0' then
                            start_core <= '1';
                        end if;

                    when "0001" =>

                        channel_reg <= writedata(2 downto 0);

                    when others =>

                        null;

                end case;

            end if;

        end if;

    end process;

end architecture rtl;