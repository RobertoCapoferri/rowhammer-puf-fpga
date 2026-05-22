----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/20/2026 10:34:01 AM
-- Design Name: 
-- Module Name: hammer_module - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity hammer_module is
    Port ( clk : in STD_LOGIC;
           rst : in STD_LOGIC;
           can_go : in STD_LOGIC;
           ag1 : in STD_LOGIC_VECTOR (14 downto 0);
           ag2 : in STD_LOGIC_VECTOR (14 downto 0);
           n_act : in STD_LOGIC_VECTOR (31 downto 0);
           addr : out STD_LOGIC_VECTOR (27 downto 0);
           over : out STD_LOGIC);
end hammer_module;

architecture Behavioral of hammer_module is

component n_act_counter is
  PORT (
    CLK : IN STD_LOGIC;
    CE : IN STD_LOGIC;
    SCLR : IN STD_LOGIC;
    LOAD : IN STD_LOGIC;
    L : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    THRESH0 : OUT STD_LOGIC;
    Q : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
end component n_act_counter;

-- keep track of the remaining n_act
signal remaining_act: std_logic_vector(31 downto 0);
-- control the counter
signal counter_ce: std_logic;
signal counter_over: std_logic;
-- signals to laod the counter at the beginning
signal load_counter: std_logic;
signal loaded: std_logic := '0';

-- given how this is implemented, all inputs must be valid before
-- asserting can_go
begin

n_act_counter_i: n_act_counter port map(
    CLK => clk,
    CE => counter_ce,
    SCLR => rst,
    LOAD => load_counter,
    L => n_act,
    THRESH0 => counter_over,
    Q => remaining_act
);

-- keep load_counter high for one clock cycle in order to load initial value
-- also handles reset
load: process(clk)
begin
if rising_edge(clk) then
    if rst = '1' then
        load_counter <= '1';
        loaded <= '0';
    else
        if loaded = '0' then
            -- only load when also can_go is high, otherwise counter misses it
            if can_go = '1' then
                load_counter <= '1';
                loaded <= '1';
            end if;
        else
            -- already loaded, deassert flag
            load_counter <= '0';
        end if;
    end if;
end if;
end process;

-- switch between each of the two aggressors every counter pulse
-- need also to take into account if the counter changed, so this
-- also depends on counter_ce
alternate: process(clk)
-- i don't know if this should be a variable or a signal
variable state: std_logic := '1';
begin
if rising_edge(clk) then
    if rst = '1' then
        state := '1';
        addr <= (others => '0');
    else
        -- only switch when the counter is enabled
        if counter_ce = '1' then
            -- alternate between the two aggressors
            if state = '1' then
                addr <= "000" & ag1 & "0000000000";
            else
                addr <= "000" & ag2 & "0000000000";
            end if;
            state := not state;
        end if;
    end if;
end if;
end process;

-- assign the output over flag and handles reset
over_flag: process(clk)
begin
if rising_edge(clk) then
    if rst = '1' then
        over <= '0';
    else
        if counter_over = '1' then
            over <= '1';
        end if;
    end if;
end if;
end process;

-- combinatorial logic for the counter_ce signal, only
-- go when can_go is asserted and over is not asserted
counter_ce <= can_go and not counter_over;

end Behavioral;
