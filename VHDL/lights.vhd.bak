LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;

ENTITY lights IS
PORT (
    CLOCK_50 : IN    STD_LOGIC;
    KEY      : IN    STD_LOGIC_VECTOR (0 DOWNTO 0);
    SW       : IN    STD_LOGIC_VECTOR (7 DOWNTO 0);
    LED      : OUT   STD_LOGIC_VECTOR (7 DOWNTO 0);

    -- SDRAM pins (noms typiques dans le QSF Terasic)
    DRAM_CLK   : OUT   STD_LOGIC;
    DRAM_CKE   : OUT   STD_LOGIC;
    DRAM_ADDR  : OUT   STD_LOGIC_VECTOR(12 DOWNTO 0);
    DRAM_BA    : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);
    DRAM_CS_N  : OUT   STD_LOGIC;
    DRAM_CAS_N : OUT   STD_LOGIC;
    DRAM_RAS_N : OUT   STD_LOGIC;
    DRAM_WE_N  : OUT   STD_LOGIC;
    DRAM_DQ    : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    DRAM_DQM   : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0)
);
END lights;

ARCHITECTURE lights_rtl OF lights IS

    COMPONENT system
    PORT (
        clk_clk         : IN  STD_LOGIC;
        reset_reset_n   : IN  STD_LOGIC;

        sdram_clk_clk   : OUT STD_LOGIC;

        leds_export     : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        switches_export : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);

        sdram_wire_addr  : OUT   STD_LOGIC_VECTOR(12 DOWNTO 0);
        sdram_wire_ba    : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);
        sdram_wire_cas_n : OUT   STD_LOGIC;
        sdram_wire_cke   : OUT   STD_LOGIC;
        sdram_wire_cs_n  : OUT   STD_LOGIC;
        sdram_wire_dq    : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        sdram_wire_dqm   : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);
        sdram_wire_ras_n : OUT   STD_LOGIC;
        sdram_wire_we_n  : OUT   STD_LOGIC
    );
    END COMPONENT;

BEGIN

    NiosII : system
    PORT MAP(
        clk_clk         => CLOCK_50,
        reset_reset_n   => KEY(0),

        sdram_clk_clk   => DRAM_CLK,

        switches_export => SW,
        leds_export     => LED,

        sdram_wire_addr  => DRAM_ADDR,
        sdram_wire_ba    => DRAM_BA,
        sdram_wire_cas_n => DRAM_CAS_N,
        sdram_wire_cke   => DRAM_CKE,
        sdram_wire_cs_n  => DRAM_CS_N,
        sdram_wire_dq    => DRAM_DQ,
        sdram_wire_dqm   => DRAM_DQM,
        sdram_wire_ras_n => DRAM_RAS_N,
        sdram_wire_we_n  => DRAM_WE_N
    );

END lights_rtl;
