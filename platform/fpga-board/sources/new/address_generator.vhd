----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/19/2026 12:13:36 PM
-- Design Name: 
-- Module Name: address_generator - Behavioral
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

entity address_generator is
    Port ( clk : in STD_LOGIC;
           rst: in STD_LOGIC;
           can_go : in STD_LOGIC;
           addr : out STD_LOGIC_VECTOR (27 downto 0);
           over : out STD_LOGIC);
end address_generator;

architecture Behavioral of address_generator is

component row_counter is
      PORT (
    CLK : IN STD_LOGIC;
    CE : IN STD_LOGIC;
    SCLR : IN STD_LOGIC;
    THRESH0 : OUT STD_LOGIC;
    Q : OUT STD_LOGIC_VECTOR(14 DOWNTO 0)
  );
end component row_counter;

component column_counter is
      PORT (
    CLK : IN STD_LOGIC;
    CE : IN STD_LOGIC;
    SCLR : IN STD_LOGIC;
    THRESH0 : OUT STD_LOGIC;
    Q : OUT STD_LOGIC_VECTOR(9 DOWNTO 0)
  );
end component column_counter;

-- enables clock on the column counter
signal col_ce: std_logic;
-- enables clock on the row counter
signal row_ce: std_logic;
-- over signals from counters
signal row_over: std_logic;
signal col_over: std_logic;
-- signal used to remember that all rows have been emitted
-- used to do one last round of column counter before exiting
signal rows_done: std_logic := '0';
-- to compose the final addreess
signal col_addr: std_logic_vector(9 downto 0);
signal row_addr: std_logic_vector(14 downto 0);

begin
-- you maybe wondering why there are two counters here instead of just a big one.
-- i was wondering the same when i finished writing this component.
-- the answer is that i don't know, but it was good practice since i never wrote vhdl.

-- declare column counter and row counter
col_counter_i: column_counter port map(
    CLK => clk,
    CE => col_ce,
    SCLR => rst,
    THRESH0 => col_over,
    Q => col_addr
);

row_counter_i: row_counter port map(
    CLK => clk,
    CE => row_ce,
    SCLR => rst,
    THRESH0 => row_over,
    Q => row_addr
);

-- for now hardcode bank to be 0
addr <= "000" & row_addr & col_addr;

-- column is enabled when app_rdy is high, which is connected to the can_go input
-- and keeps going for all rows + 1 extra cycle after rows done is asserted
col_ce <= can_go and not (rows_done and col_over) ;
-- row counter is enabled when app_rdy is high and column counter reaches the end
-- but it is not asserted when all rows are done
row_ce <= can_go and col_over and not rows_done;

over_flag: process(clk)
begin
if rising_edge(clk) then
    if rst = '1' then
        rows_done <= '0';
        over <= '0';
    else
        -- assign over signal
        if rows_done = '1' and col_over = '1' then
            over <= '1'; -- signal the end of address generation when all rows are done
        else
            over <= '0';
        end if;
        -- assign rows_done signal
        if row_over = '1' then
            rows_done <= '1';
        end if;   
    end if;
end if;
end process;

end Behavioral;
