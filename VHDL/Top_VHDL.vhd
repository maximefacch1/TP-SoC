library ieee;
use ieee.std_logic_1164.all;

entity Top_VHDL is
    port (
        CLOCK_50 : in std_logic;

        LED : out std_logic_vector(7 downto 0);
        KEY : in  std_logic_vector(1 downto 0);
        SW  : in  std_logic_vector(3 downto 0);

        DRAM_ADDR  : out   std_logic_vector(12 downto 0);
        DRAM_BA    : out   std_logic_vector(1 downto 0);
        DRAM_CAS_N : out   std_logic;
        DRAM_CKE   : out   std_logic;
        DRAM_CLK   : out   std_logic;
        DRAM_CS_N  : out   std_logic;
        DRAM_DQ    : inout std_logic_vector(15 downto 0);
        DRAM_DQM   : out   std_logic_vector(1 downto 0);
        DRAM_RAS_N : out   std_logic;
        DRAM_WE_N  : out   std_logic;

        GPIO_0_IN : in    std_logic_vector(1 downto 0);
        GPIO_0    : inout std_logic_vector(33 downto 0);

        GPIO_1_IN : in    std_logic_vector(1 downto 0);
        GPIO_1    : inout std_logic_vector(33 downto 0);

        I2C_SCLK      : inout std_logic;
        I2C_SDAT      : inout std_logic;
        G_SENSOR_CS_N : out   std_logic;
        G_SENSOR_INT  : in    std_logic;
        ADC_CS_N      : out   std_logic;
        ADC_SADDR     : out   std_logic;
        ADC_SCLK      : out   std_logic;
        ADC_SDAT      : in    std_logic
    );
end entity Top_VHDL;

architecture rtl of Top_VHDL is

    component system is
        port (
            leds_export     : out std_logic_vector(7 downto 0);
            switches_export : in  std_logic_vector(7 downto 0);

            clk_clk       : in std_logic;
            reset_reset_n : in std_logic;

            sdram_wire_addr  : out   std_logic_vector(12 downto 0);
            sdram_wire_ba    : out   std_logic_vector(1 downto 0);
            sdram_wire_cas_n : out   std_logic;
            sdram_wire_cke   : out   std_logic;
            sdram_wire_cs_n  : out   std_logic;
            sdram_wire_dq    : inout std_logic_vector(15 downto 0);
            sdram_wire_dqm   : out   std_logic_vector(1 downto 0);
            sdram_wire_ras_n : out   std_logic;
            sdram_wire_we_n  : out   std_logic;
            sdram_clk_clk    : out   std_logic;

            pwm_mtrr_p_export      : out std_logic;
            pwm_mtrr_n_export      : out std_logic;
            pwm_mtrl_p_export      : out std_logic;
            pwm_mtrl_n_export      : out std_logic;
            pwm_mtr_sleep_n_export : out std_logic;
            pwm_mtr_fault_n_export : in  std_logic;

            adc_convst_export : out std_logic;
            adc_sck_export    : out std_logic;
            adc_sdo_export    : in  std_logic;
            adc_sdi_export    : out std_logic;
            ir_led_on_export  : out std_logic
        );
    end component;

    signal switches_qsys : std_logic_vector(7 downto 0);
    signal led_qsys      : std_logic_vector(7 downto 0);
    signal ir_led_on_sig : std_logic;

begin

    switches_qsys <= "0000" & SW;

    LED(6 downto 0) <= led_qsys(6 downto 0);
    LED(7)          <= ir_led_on_sig;

    I2C_SCLK <= 'Z';
    I2C_SDAT <= 'Z';

    G_SENSOR_CS_N <= '1';

    ADC_CS_N  <= '1';
    ADC_SADDR <= '0';
    ADC_SCLK  <= '0';

    GPIO_0(0) <= 'Z';
    GPIO_0(1) <= 'Z';

    GPIO_0(12) <= 'Z';
    GPIO_0(13) <= 'Z';
    GPIO_0(14) <= 'Z';
    GPIO_0(15) <= 'Z';
    GPIO_0(16) <= 'Z';
    GPIO_0(17) <= 'Z';
    GPIO_0(18) <= 'Z';
    GPIO_0(19) <= 'Z';
    GPIO_0(20) <= 'Z';
    GPIO_0(21) <= 'Z';
    GPIO_0(22) <= 'Z';
    GPIO_0(23) <= 'Z';
    GPIO_0(24) <= 'Z';
    GPIO_0(25) <= 'Z';
    GPIO_0(26) <= 'Z';
    GPIO_0(27) <= 'Z';
    GPIO_0(28) <= 'Z';
    GPIO_0(29) <= 'Z';
    GPIO_0(30) <= 'Z';
    GPIO_0(31) <= 'Z';

    GPIO_0(33) <= '0';

    GPIO_1 <= (others => 'Z');

    GPIO_0(32) <= ir_led_on_sig;

    u0 : system
        port map (
            leds_export     => led_qsys,
            switches_export => switches_qsys,

            clk_clk       => CLOCK_50,
            reset_reset_n => KEY(0),

            sdram_wire_addr  => DRAM_ADDR,
            sdram_wire_ba    => DRAM_BA,
            sdram_wire_cas_n => DRAM_CAS_N,
            sdram_wire_cke   => DRAM_CKE,
            sdram_wire_cs_n  => DRAM_CS_N,
            sdram_wire_dq    => DRAM_DQ,
            sdram_wire_dqm   => DRAM_DQM,
            sdram_wire_ras_n => DRAM_RAS_N,
            sdram_wire_we_n  => DRAM_WE_N,
            sdram_clk_clk    => DRAM_CLK,

            pwm_mtrr_p_export      => GPIO_0(3),
            pwm_mtrr_n_export      => GPIO_0(2),
            pwm_mtrl_p_export      => GPIO_0(4),
            pwm_mtrl_n_export      => GPIO_0(5),
            pwm_mtr_sleep_n_export => GPIO_0(6),
            pwm_mtr_fault_n_export => GPIO_0(7),

            adc_convst_export => GPIO_0(8),
            adc_sck_export    => GPIO_0(9),
            adc_sdo_export    => GPIO_0(10),
            adc_sdi_export    => GPIO_0(11),
            ir_led_on_export  => ir_led_on_sig
        );

end architecture rtl;