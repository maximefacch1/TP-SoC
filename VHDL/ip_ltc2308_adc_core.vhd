-- =========================================================
-- Fichier : ltc2308_adc_core.vhd
-- Description :
-- Coeur métier ADC LTC2308
-- Gestion SPI + FSM de conversion
-- =========================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ltc2308_adc_core is
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
end entity;

architecture rtl of ltc2308_adc_core is

    constant SCK_DIV_CYCLES       : integer := 250;
    constant CONV_WAIT_CYCLES     : integer := 100;
    constant CONV_LOW_WAIT_CYCLES : integer := 20;

    type state_t is (
        ST_IDLE,
        ST_CONV_HIGH,
        ST_CONV_LOW,
        ST_SCK_LOW,
        ST_SCK_HIGH,
        ST_FRAME_DONE
    );

    signal state : state_t;

    signal busy_reg : std_logic;
    signal done_reg : std_logic;
    signal data_reg : std_logic_vector(11 downto 0);

    signal command_word : std_logic_vector(5 downto 0);

    signal pass_index : std_logic;

    signal conv_counter : integer range 0 to CONV_WAIT_CYCLES;
    signal low_counter  : integer range 0 to CONV_LOW_WAIT_CYCLES;
    signal sck_counter  : integer range 0 to SCK_DIV_CYCLES;

    signal bit_index : integer range 0 to 11;

    signal rx_shift : std_logic_vector(11 downto 0);

    signal adc_convst_i : std_logic;
    signal adc_sck_i    : std_logic;
    signal adc_sdi_i    : std_logic;

    function make_command(ch : std_logic_vector(2 downto 0))
        return std_logic_vector
    is
        variable cmd : std_logic_vector(5 downto 0);
    begin
        cmd(5) := '1';
        cmd(4) := ch(0);
        cmd(3) := ch(2);
        cmd(2) := ch(1);
        cmd(1) := '1';
        cmd(0) := '0';
        return cmd;
    end function;

begin

    busy <= busy_reg;
    done <= done_reg;
    data <= data_reg;

    adc_convst <= adc_convst_i;
    adc_sck    <= adc_sck_i;
    adc_sdi    <= adc_sdi_i;

    process(clk, reset_n)
    begin

        if reset_n = '0' then

            state <= ST_IDLE;

            busy_reg <= '0';
            done_reg <= '0';

            data_reg <= (others => '0');

            command_word <= (others => '0');

            pass_index <= '0';

            conv_counter <= 0;
            low_counter  <= 0;
            sck_counter  <= 0;

            bit_index <= 0;

            rx_shift <= (others => '0');

            adc_convst_i <= '0';
            adc_sck_i    <= '0';
            adc_sdi_i    <= '0';

        elsif rising_edge(clk) then

            done_reg <= '0';

            case state is

                when ST_IDLE =>

                    busy_reg <= '0';

                    adc_convst_i <= '0';
                    adc_sck_i    <= '0';
                    adc_sdi_i    <= '0';

                    if start = '1' then

                        busy_reg <= '1';

                        command_word <= make_command(channel);

                        pass_index <= '0';

                        conv_counter <= 0;

                        adc_convst_i <= '1';

                        state <= ST_CONV_HIGH;

                    end if;

                when ST_CONV_HIGH =>

                    adc_convst_i <= '1';

                    if conv_counter >= CONV_WAIT_CYCLES - 1 then

                        conv_counter <= 0;

                        adc_convst_i <= '0';

                        state <= ST_CONV_LOW;

                    else

                        conv_counter <= conv_counter + 1;

                    end if;

                when ST_CONV_LOW =>

                    if low_counter >= CONV_LOW_WAIT_CYCLES - 1 then

                        low_counter <= 0;

                        sck_counter <= 0;

                        bit_index <= 0;

                        rx_shift <= (others => '0');

                        adc_sdi_i <= command_word(5);

                        state <= ST_SCK_LOW;

                    else

                        low_counter <= low_counter + 1;

                    end if;

                when ST_SCK_LOW =>

                    adc_sck_i <= '0';

                    if sck_counter >= SCK_DIV_CYCLES - 1 then

                        sck_counter <= 0;

                        adc_sck_i <= '1';

                        state <= ST_SCK_HIGH;

                    else

                        sck_counter <= sck_counter + 1;

                    end if;

                when ST_SCK_HIGH =>

                    adc_sck_i <= '1';

                    if sck_counter >= SCK_DIV_CYCLES - 1 then

                        sck_counter <= 0;

                        rx_shift(11 - bit_index) <= adc_sdo;

                        adc_sck_i <= '0';

                        if bit_index >= 11 then

                            state <= ST_FRAME_DONE;

                        else

                            bit_index <= bit_index + 1;

                            if bit_index + 1 < 6 then

                                adc_sdi_i <= command_word(5 - (bit_index + 1));
                            else
                                adc_sdi_i <= '0';
                            end if;

                            state <= ST_SCK_LOW;

                        end if;

                    else

                        sck_counter <= sck_counter + 1;

                    end if;

                when ST_FRAME_DONE =>

                    adc_sck_i <= '0';

                    adc_convst_i <= '0';

                    adc_sdi_i <= '0';

                    if pass_index = '0' then

                        pass_index <= '1';

                        conv_counter <= 0;
                        low_counter  <= 0;

                        rx_shift <= (others => '0');

                        adc_convst_i <= '1';

                        state <= ST_CONV_HIGH;

                    else

                        data_reg <= rx_shift;

                        busy_reg <= '0';

                        done_reg <= '1';

                        state <= ST_IDLE;

                    end if;

            end case;

        end if;

    end process;

end architecture rtl;