library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ip_ltc2308_adc is
    port (
        --------------------------------------------------------------------
        -- Clock / Reset
        --------------------------------------------------------------------
        clk      : in  std_logic;
        reset_n  : in  std_logic;

        --------------------------------------------------------------------
        -- Avalon-MM Slave
        --------------------------------------------------------------------
        chipselect : in  std_logic;
        write      : in  std_logic;
        read       : in  std_logic;
        address    : in  std_logic_vector(3 downto 0);
        writedata  : in  std_logic_vector(31 downto 0);
        readdata   : out std_logic_vector(31 downto 0);
        byteenable : in  std_logic_vector(3 downto 0);

        --------------------------------------------------------------------
        -- Conduit vers ADC LTC2308 / CuteCar
        --------------------------------------------------------------------
        adc_convst : out std_logic;
        adc_sck    : out std_logic;
        adc_sdo    : in  std_logic;
        adc_sdi    : out std_logic;
        ir_led_on  : out std_logic
    );
end entity ip_ltc2308_adc;

architecture rtl of ip_ltc2308_adc is

    --------------------------------------------------------------------
    -- Réglages temporels
    --------------------------------------------------------------------
    -- clk = 50 MHz
    -- SCK_DIV_CYCLES = 250 :
    -- demi-période SCK = 250 cycles = 5 us
    -- période SCK      = 10 us
    -- fréquence SCK    = environ 100 kHz
    --------------------------------------------------------------------
    constant SCK_DIV_CYCLES       : integer := 250;
    constant CONV_WAIT_CYCLES     : integer := 100;
    constant CONV_LOW_WAIT_CYCLES : integer := 20;

    --------------------------------------------------------------------
    -- Registres Avalon-MM
    --------------------------------------------------------------------
    -- address = 0  : CONTROL
    -- address = 1  : CHANNEL
    -- address = 2  : DATA
    -- address = 3  : STATUS
    -- address = 4  : CH0
    -- address = 5  : CH1
    -- address = 6  : CH2
    -- address = 7  : CH3
    -- address = 8  : CH4
    -- address = 9  : CH5
    -- address = 10 : CH6
    -- address = 11 : CH7
    --
    -- CONTROL :
    -- bit 0 : START
    -- bit 1 : IR_LED_ON
    --
    -- CHANNEL :
    -- bits 2 downto 0 : canal ADC à lire, de 0 à 7
    --
    -- DATA :
    -- bits 11 downto 0 : dernière donnée lue
    --
    -- STATUS :
    -- bit 0 : BUSY
    -- bit 1 : DONE
    -- bit 2 : état brut ADC_SDO
    --------------------------------------------------------------------

    signal control_reg : std_logic_vector(31 downto 0);
    signal channel_reg : unsigned(2 downto 0);

    signal data_reg : std_logic_vector(11 downto 0);

    type channel_array_t is array (0 to 7) of std_logic_vector(11 downto 0);
    signal channel_data : channel_array_t;

    signal busy_reg : std_logic;
    signal done_reg : std_logic;

    --------------------------------------------------------------------
    -- Machine d'état SPI
    --------------------------------------------------------------------
    type state_t is (
        ST_IDLE,
        ST_CONV_HIGH,
        ST_CONV_LOW,
        ST_SCK_LOW,
        ST_SCK_HIGH,
        ST_FRAME_DONE
    );

    signal state : state_t;

    signal pending_start : std_logic;

    signal requested_channel : unsigned(2 downto 0);
    signal command_word      : std_logic_vector(5 downto 0);

    signal pass_index : std_logic;

    signal conv_counter : integer range 0 to CONV_WAIT_CYCLES;
    signal low_counter  : integer range 0 to CONV_LOW_WAIT_CYCLES;
    signal sck_counter  : integer range 0 to SCK_DIV_CYCLES;

    signal bit_index : integer range 0 to 11;
    signal rx_shift  : std_logic_vector(11 downto 0);

    signal adc_convst_i : std_logic;
    signal adc_sck_i    : std_logic;
    signal adc_sdi_i    : std_logic;

    --------------------------------------------------------------------
    -- Génération de la commande LTC2308
    --------------------------------------------------------------------
    -- Commande 6 bits envoyée sur ADC_SDI.
    -- ch = canal demandé de 0 à 7.
    --------------------------------------------------------------------
    function make_command(ch : unsigned(2 downto 0)) return std_logic_vector is
        variable cmd : std_logic_vector(5 downto 0);
    begin
        cmd(5) := '1';              -- Single-ended
        cmd(4) := std_logic(ch(0));
        cmd(3) := std_logic(ch(2));
        cmd(2) := std_logic(ch(1));
        cmd(1) := '1';              -- Unipolaire
        cmd(0) := '0';              -- Pas de sleep
        return cmd;
    end function;

begin

    adc_convst <= adc_convst_i;
    adc_sck    <= adc_sck_i;
    adc_sdi    <= adc_sdi_i;

    ir_led_on <= control_reg(1);

    --------------------------------------------------------------------
    -- Lecture Avalon-MM
    --------------------------------------------------------------------
    process(address, control_reg, channel_reg, data_reg, channel_data, busy_reg, done_reg, adc_sdo)
    begin
        readdata <= (others => '0');

        case address is

            when "0000" =>
                readdata <= control_reg;

            when "0001" =>
                readdata(2 downto 0) <= std_logic_vector(channel_reg);

            when "0010" =>
                readdata(11 downto 0) <= data_reg;

            when "0011" =>
                readdata(0) <= busy_reg;
                readdata(1) <= done_reg;
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

    --------------------------------------------------------------------
    -- Écriture Avalon-MM + machine SPI
    --------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then

            control_reg <= (others => '0');
            channel_reg <= (others => '0');

            data_reg <= (others => '0');

            channel_data(0) <= (others => '0');
            channel_data(1) <= (others => '0');
            channel_data(2) <= (others => '0');
            channel_data(3) <= (others => '0');
            channel_data(4) <= (others => '0');
            channel_data(5) <= (others => '0');
            channel_data(6) <= (others => '0');
            channel_data(7) <= (others => '0');

            busy_reg <= '0';
            done_reg <= '0';

            pending_start <= '0';

            requested_channel <= (others => '0');
            command_word      <= (others => '0');

            pass_index <= '0';

            conv_counter <= 0;
            low_counter  <= 0;
            sck_counter  <= 0;
            bit_index    <= 0;
            rx_shift     <= (others => '0');

            adc_convst_i <= '0';
            adc_sck_i    <= '0';
            adc_sdi_i    <= '0';

            state <= ST_IDLE;

        elsif rising_edge(clk) then

            ----------------------------------------------------------------
            -- Écritures Avalon-MM
            ----------------------------------------------------------------
            if chipselect = '1' and write = '1' then

                case address is

                    --------------------------------------------------------
                    -- CONTROL
                    --------------------------------------------------------
                    when "0000" =>
                        if byteenable(0) = '1' then
                            control_reg(7 downto 1) <= writedata(7 downto 1);

                            if writedata(0) = '1' and busy_reg = '0' then
                                pending_start <= '1';
                                done_reg <= '0';
                            end if;
                        end if;

                        if byteenable(1) = '1' then
                            control_reg(15 downto 8) <= writedata(15 downto 8);
                        end if;

                        if byteenable(2) = '1' then
                            control_reg(23 downto 16) <= writedata(23 downto 16);
                        end if;

                        if byteenable(3) = '1' then
                            control_reg(31 downto 24) <= writedata(31 downto 24);
                        end if;

                    --------------------------------------------------------
                    -- CHANNEL
                    --------------------------------------------------------
                    when "0001" =>
                        if byteenable(0) = '1' then
                            channel_reg <= unsigned(writedata(2 downto 0));
                        end if;

                    when others =>
                        null;

                end case;
            end if;

            ----------------------------------------------------------------
            -- Machine SPI LTC2308
            ----------------------------------------------------------------
            case state is

                ------------------------------------------------------------
                -- Attente d'un ordre START
                ------------------------------------------------------------
                when ST_IDLE =>
                    adc_convst_i <= '0';
                    adc_sck_i    <= '0';
                    adc_sdi_i    <= '0';

                    conv_counter <= 0;
                    low_counter  <= 0;
                    sck_counter  <= 0;
                    bit_index    <= 0;

                    if pending_start = '1' then
                        pending_start <= '0';

                        busy_reg <= '1';
                        done_reg <= '0';

                        requested_channel <= channel_reg;
                        command_word      <= make_command(channel_reg);

                        pass_index <= '0';

                        rx_shift <= (others => '0');

                        adc_convst_i <= '1';
                        state <= ST_CONV_HIGH;
                    end if;

                ------------------------------------------------------------
                -- Pulse CONVST haut
                ------------------------------------------------------------
                when ST_CONV_HIGH =>
                    adc_convst_i <= '1';
                    adc_sck_i    <= '0';

                    if conv_counter >= CONV_WAIT_CYCLES - 1 then
                        conv_counter <= 0;
                        adc_convst_i <= '0';
                        state <= ST_CONV_LOW;
                    else
                        conv_counter <= conv_counter + 1;
                    end if;

                ------------------------------------------------------------
                -- Petite marge CONVST bas avant SCK
                ------------------------------------------------------------
                when ST_CONV_LOW =>
                    adc_convst_i <= '0';
                    adc_sck_i    <= '0';

                    if low_counter >= CONV_LOW_WAIT_CYCLES - 1 then
                        low_counter <= 0;
                        sck_counter <= 0;
                        bit_index   <= 0;
                        rx_shift    <= (others => '0');

                        adc_sdi_i <= command_word(5);
                        state <= ST_SCK_LOW;
                    else
                        low_counter <= low_counter + 1;
                    end if;

                ------------------------------------------------------------
                -- Phase SCK bas
                -- Préparation du signal ADC_SDI
                ------------------------------------------------------------
                when ST_SCK_LOW =>
                    adc_sck_i <= '0';

                    if sck_counter >= SCK_DIV_CYCLES - 1 then
                        sck_counter <= 0;
                        adc_sck_i   <= '1';
                        state       <= ST_SCK_HIGH;
                    else
                        sck_counter <= sck_counter + 1;
                    end if;

                ------------------------------------------------------------
                -- Phase SCK haut
                -- Capture ADC_SDO à la fin de la phase haute
                ------------------------------------------------------------
                when ST_SCK_HIGH =>
                    adc_sck_i <= '1';

                    if sck_counter >= SCK_DIV_CYCLES - 1 then
                        sck_counter <= 0;

                        -- Capture plus tardive :
                        -- le signal ADC_SDO a eu le temps de se stabiliser.
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

                ------------------------------------------------------------
                -- Fin d'une trame SPI
                ------------------------------------------------------------
                when ST_FRAME_DONE =>
                    adc_sck_i    <= '0';
                    adc_convst_i <= '0';
                    adc_sdi_i    <= '0';

                    if pass_index = '0' then
                        ----------------------------------------------------
                        -- Première trame :
                        -- commande envoyée, donnée reçue ignorée.
                        ----------------------------------------------------
                        pass_index   <= '1';
                        conv_counter <= 0;
                        low_counter  <= 0;
                        rx_shift     <= (others => '0');

                        adc_convst_i <= '1';
                        state <= ST_CONV_HIGH;

                    else
                        ----------------------------------------------------
                        -- Deuxième trame :
                        -- donnée du canal demandé.
                        ----------------------------------------------------
                        data_reg <= rx_shift;
                        channel_data(to_integer(requested_channel)) <= rx_shift;

                        busy_reg <= '0';
                        done_reg <= '1';

                        state <= ST_IDLE;
                    end if;

            end case;
        end if;
    end process;

end architecture rtl;