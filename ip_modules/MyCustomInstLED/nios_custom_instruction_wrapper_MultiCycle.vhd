library ieee;
use ieee.std_logic_1164.all;

entity nios_custom_instruction_wrapper_MultiCycle is
    port (
        clk      : in  std_logic;                    -- Horloge Nios II
        clk_en   : in  std_logic;                    -- Activation Nios II
        --start    : in  std_logic;                    -- Début Nios II
        --done     : out std_logic;                    -- Fin Nios II
        dataa    : in  std_logic_vector(31 downto 0); -- Opérande A Nios II
        --datab    : in  std_logic_vector(31 downto 0); -- Opérande B Nios II
        n        : in  std_logic_vector(7 downto 0);  -- Sélecteur Nios II
        result   : out std_logic_vector(31 downto 0);  -- Résultat Nios II
        Qexport  : out std_logic_vector(7 downto 0)  -- Résultat Nios II
    
	 );
end entity nios_custom_instruction_wrapper_MultiCycle;

architecture structural of nios_custom_instruction_wrapper_MultiCycle is
    -- Déclaration du composant interne
    component custom_logic_core_led is
        port (
            core_clk    : in  std_logic;
            core_en     : in  std_logic;
            --core_start  : in  std_logic;
            --core_done   : out std_logic;
            core_dataa  : in  std_logic_vector(31 downto 0);
            --core_datab  : in  std_logic_vector(31 downto 0);
            core_n      : in  std_logic_vector(7 downto 0);
            core_result : out std_logic_vector(31 downto 0);
				core_export : out std_logic_vector(7 downto 0)
        );
    end component;

begin
    -- Instanciation du composant interne
    core_inst : custom_logic_core_led
    port map (
        core_clk    => clk,      -- Connexion directe à l’horloge Nios II
        core_en     => clk_en,   -- Connexion directe à l’activation Nios II
        --core_start  => start,    -- Connexion directe au signal de début
        --core_done   => done,     -- Connexion directe au signal de fin
        core_dataa  => dataa,    -- Connexion directe à l’opérande A
        --core_datab  => datab,    -- Connexion directe à l’opérande B
        core_n      => n,        -- Connexion directe au sélecteur
        core_result => result,    -- Connexion directe au résultat
		  core_export => Qexport
    );
end architecture structural;