LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY nios_system;

ENTITY DE1_top IS
PORT (
    CLOCK_50 : IN STD_LOGIC;

    KEY : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    SW  : IN STD_LOGIC_VECTOR(9 DOWNTO 0);

    LEDG : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    LEDR : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);

    HEX0 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
    HEX1 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
    HEX2 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
    HEX3 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);

    SRAM_DQ   : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    SRAM_ADDR : OUT   STD_LOGIC_VECTOR(17 DOWNTO 0);
    SRAM_LB_N : OUT   STD_LOGIC;
    SRAM_UB_N : OUT   STD_LOGIC;
    SRAM_CE_N : OUT   STD_LOGIC;
    SRAM_OE_N : OUT   STD_LOGIC;
    SRAM_WE_N : OUT   STD_LOGIC;

    DRAM_ADDR  : OUT   STD_LOGIC_VECTOR(11 DOWNTO 0);
    DRAM_BA    : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);
    DRAM_CAS_N : OUT   STD_LOGIC;
    DRAM_CKE   : OUT   STD_LOGIC;
    DRAM_CS_N  : OUT   STD_LOGIC;
    DRAM_DQ    : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    DRAM_DQM   : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);
    DRAM_RAS_N : OUT   STD_LOGIC;
    DRAM_WE_N  : OUT   STD_LOGIC;

    GPIO_0 : INOUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    GPIO_1 : INOUT STD_LOGIC_VECTOR(31 DOWNTO 0);

    UART_RXD : IN  STD_LOGIC;
    UART_TXD : OUT STD_LOGIC
);
END DE1_top;

ARCHITECTURE Structure OF DE1_top IS

SIGNAL to_hex : STD_LOGIC_VECTOR(15 DOWNTO 0);

BEGIN

u0 : ENTITY nios_system.nios_system
PORT MAP (
    SRAM_DQ_to_and_from_the_SRAM         => SRAM_DQ,
    SRAM_ADDR_from_the_SRAM              => SRAM_ADDR,
    SRAM_LB_N_from_the_SRAM              => SRAM_LB_N,
    SRAM_UB_N_from_the_SRAM              => SRAM_UB_N,
    SRAM_CE_N_from_the_SRAM              => SRAM_CE_N,
    SRAM_OE_N_from_the_SRAM              => SRAM_OE_N,
    SRAM_WE_N_from_the_SRAM              => SRAM_WE_N,

    resetn_reset_n                       => KEY(0),

    GPIO_0_to_and_from_the_Expansion_JP1 => GPIO_0,
    LEDG_from_the_Green_LEDs             => LEDG,

    zs_addr_from_the_sdram               => DRAM_ADDR,
    zs_ba_from_the_sdram                 => DRAM_BA,
    zs_cas_n_from_the_sdram              => DRAM_CAS_N,
    zs_cke_from_the_sdram                => DRAM_CKE,
    zs_cs_n_from_the_sdram               => DRAM_CS_N,
    zs_dq_to_and_from_the_sdram          => DRAM_DQ,
    zs_dqm_from_the_sdram                => DRAM_DQM,
    zs_ras_n_from_the_sdram              => DRAM_RAS_N,
    zs_we_n_from_the_sdram               => DRAM_WE_N,

    GPIO_1_to_and_from_the_Expansion_JP2 => GPIO_1,

    UART_RXD_to_the_Serial_port          => UART_RXD,
    UART_TXD_from_the_Serial_port        => UART_TXD,

    KEY_to_the_Pushbuttons               => KEY,
    SW_to_the_Slider_switches            => SW,
    LEDR_from_the_Red_LEDs               => LEDR,

    HEX0_from_the_HEX3_HEX0              => OPEN,
    HEX1_from_the_HEX3_HEX0              => OPEN,
    HEX2_from_the_HEX3_HEX0              => OPEN,
    HEX3_from_the_HEX3_HEX0              => OPEN,

    clk_clk                              => CLOCK_50,
    to_hex_export                        => to_hex
);

h0 : ENTITY work.hex7seg
PORT MAP (
    hex     => to_hex(3 DOWNTO 0),
    display => HEX0
);

h1 : ENTITY work.hex7seg
PORT MAP (
    hex     => to_hex(7 DOWNTO 4),
    display => HEX1
);

h2 : ENTITY work.hex7seg
PORT MAP (
    hex     => to_hex(11 DOWNTO 8),
    display => HEX2
);

h3 : ENTITY work.hex7seg
PORT MAP (
    hex     => to_hex(15 DOWNTO 12),
    display => HEX3
);

END Structure;