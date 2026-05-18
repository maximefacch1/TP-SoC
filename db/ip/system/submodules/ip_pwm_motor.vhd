library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ip_pwm_motor is
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
        address    : in  std_logic_vector(2 downto 0);
        writedata  : in  std_logic_vector(31 downto 0);
        readdata   : out std_logic_vector(31 downto 0);
        byteenable : in  std_logic_vector(3 downto 0);

        --------------------------------------------------------------------
        -- Conduit moteur CuteCar
        --------------------------------------------------------------------
        mtrr_p      : out std_logic;
        mtrr_n      : out std_logic;
        mtrl_p      : out std_logic;
        mtrl_n      : out std_logic;
        mtr_sleep_n : out std_logic;
        mtr_fault_n : in  std_logic
    );
end entity ip_pwm_motor;

architecture rtl of ip_pwm_motor is

    --------------------------------------------------------------------
    -- Fréquence FPGA : 50 MHz
    -- Fréquence PWM  : environ 16 kHz
    --
    -- PERIODE_PWM = 50 000 000 / 16 000 = 3125 cycles
    --------------------------------------------------------------------
    constant FPGA_FREQ_HZ : integer := 50000000;
    constant PWM_FREQ_HZ  : integer := 16000;
    constant PWM_PERIOD   : unsigned(11 downto 0) :=
        to_unsigned(FPGA_FREQ_HZ / PWM_FREQ_HZ, 12);

    --------------------------------------------------------------------
    -- Mapping registres Avalon-MM
    --
    -- address = 0 : CONTROL
    -- address = 1 : DUTY_LEFT
    -- address = 2 : DUTY_RIGHT
    -- address = 3 : STATUS
    --
    -- CONTROL :
    -- bit 0 : enable moteur global
    -- bit 1 : sleep_n driver moteur
    -- bit 2 : direction gauche  0 = avant, 1 = arrière
    -- bit 3 : direction droite  0 = avant, 1 = arrière
    -- bit 4 : brake             0 = normal, 1 = freinage
    --
    -- DUTY_LEFT :
    -- bits 11 downto 0 : rapport cyclique moteur gauche
    --
    -- DUTY_RIGHT :
    -- bits 11 downto 0 : rapport cyclique moteur droit
    --
    -- STATUS :
    -- bit 0 : mtr_fault_n
    --         1 = pas de défaut
    --         0 = défaut driver moteur
    --------------------------------------------------------------------

    signal control_reg    : std_logic_vector(31 downto 0);
    signal duty_left_reg  : unsigned(11 downto 0);
    signal duty_right_reg : unsigned(11 downto 0);

    signal pwm_counter : unsigned(11 downto 0);
    signal pwm_left    : std_logic;
    signal pwm_right   : std_logic;

    signal enable_motor : std_logic;
    signal sleep_enable : std_logic;
    signal left_dir     : std_logic;
    signal right_dir    : std_logic;
    signal brake_enable : std_logic;

begin

    --------------------------------------------------------------------
    -- Décodage du registre CONTROL
    --------------------------------------------------------------------
    enable_motor <= control_reg(0);
    sleep_enable <= control_reg(1);
    left_dir     <= control_reg(2);
    right_dir    <= control_reg(3);
    brake_enable <= control_reg(4);

    --------------------------------------------------------------------
    -- Sortie sleep du driver moteur
    --------------------------------------------------------------------
    mtr_sleep_n <= sleep_enable;

    --------------------------------------------------------------------
    -- Écriture des registres Avalon-MM
    --------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            control_reg    <= (others => '0');
            duty_left_reg  <= (others => '0');
            duty_right_reg <= (others => '0');

        elsif rising_edge(clk) then
            if chipselect = '1' and write = '1' then

                case address is

                    ----------------------------------------------------------------
                    -- CONTROL
                    ----------------------------------------------------------------
                    when "000" =>
                        if byteenable(0) = '1' then
                            control_reg(7 downto 0) <= writedata(7 downto 0);
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

                    ----------------------------------------------------------------
                    -- DUTY_LEFT
                    ----------------------------------------------------------------
                    when "001" =>
                        if byteenable(0) = '1' then
                            duty_left_reg(7 downto 0) <= unsigned(writedata(7 downto 0));
                        end if;

                        if byteenable(1) = '1' then
                            duty_left_reg(11 downto 8) <= unsigned(writedata(11 downto 8));
                        end if;

                    ----------------------------------------------------------------
                    -- DUTY_RIGHT
                    ----------------------------------------------------------------
                    when "010" =>
                        if byteenable(0) = '1' then
                            duty_right_reg(7 downto 0) <= unsigned(writedata(7 downto 0));
                        end if;

                        if byteenable(1) = '1' then
                            duty_right_reg(11 downto 8) <= unsigned(writedata(11 downto 8));
                        end if;

                    when others =>
                        null;

                end case;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Lecture des registres Avalon-MM
    --------------------------------------------------------------------
    process(address, control_reg, duty_left_reg, duty_right_reg, mtr_fault_n)
    begin
        case address is

            ----------------------------------------------------------------
            -- CONTROL
            ----------------------------------------------------------------
            when "000" =>
                readdata <= control_reg;

            ----------------------------------------------------------------
            -- DUTY_LEFT
            ----------------------------------------------------------------
            when "001" =>
                readdata <= (others => '0');
                readdata(11 downto 0) <= std_logic_vector(duty_left_reg);

            ----------------------------------------------------------------
            -- DUTY_RIGHT
            ----------------------------------------------------------------
            when "010" =>
                readdata <= (others => '0');
                readdata(11 downto 0) <= std_logic_vector(duty_right_reg);

            ----------------------------------------------------------------
            -- STATUS
            ----------------------------------------------------------------
            when "011" =>
                readdata <= (others => '0');
                readdata(0) <= mtr_fault_n;

            ----------------------------------------------------------------
            -- PWM_PERIOD en lecture seule
            ----------------------------------------------------------------
            when "100" =>
                readdata <= (others => '0');
                readdata(11 downto 0) <= std_logic_vector(PWM_PERIOD);

            when others =>
                readdata <= (others => '0');

        end case;
    end process;

    --------------------------------------------------------------------
    -- Compteur PWM
    --------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            pwm_counter <= (others => '0');

        elsif rising_edge(clk) then
            if pwm_counter >= PWM_PERIOD - 1 then
                pwm_counter <= (others => '0');
            else
                pwm_counter <= pwm_counter + 1;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Génération PWM gauche / droite
    --------------------------------------------------------------------
    process(enable_motor, pwm_counter, duty_left_reg, duty_right_reg)
    begin
        if enable_motor = '1' and pwm_counter < duty_left_reg then
            pwm_left <= '1';
        else
            pwm_left <= '0';
        end if;

        if enable_motor = '1' and pwm_counter < duty_right_reg then
            pwm_right <= '1';
        else
            pwm_right <= '0';
        end if;
    end process;

    --------------------------------------------------------------------
    -- Génération des signaux moteur CuteCar
    --
    -- Pont en H :
    -- P = 0, N = 0 : roue libre
    -- P = 1, N = 0 : avant
    -- P = 0, N = 1 : arrière
    -- P = 1, N = 1 : freinage
    --------------------------------------------------------------------
    process(enable_motor, brake_enable, left_dir, right_dir, pwm_left, pwm_right)
    begin
        mtrl_p <= '0';
        mtrl_n <= '0';
        mtrr_p <= '0';
        mtrr_n <= '0';

        if enable_motor = '0' then
            mtrl_p <= '0';
            mtrl_n <= '0';
            mtrr_p <= '0';
            mtrr_n <= '0';

        elsif brake_enable = '1' then
            mtrl_p <= '1';
            mtrl_n <= '1';
            mtrr_p <= '1';
            mtrr_n <= '1';

        else
            ----------------------------------------------------------------
            -- Moteur gauche
            ----------------------------------------------------------------
            if left_dir = '0' then
                mtrl_p <= pwm_left;
                mtrl_n <= '0';
            else
                mtrl_p <= '0';
                mtrl_n <= pwm_left;
            end if;

            ----------------------------------------------------------------
            -- Moteur droit
            ----------------------------------------------------------------
            if right_dir = '0' then
                mtrr_p <= pwm_right;
                mtrr_n <= '0';
            else
                mtrr_p <= '0';
                mtrr_n <= pwm_right;
            end if;
        end if;
    end process;

end architecture rtl;