----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/20/2026 01:22:50 PM
-- Design Name: 
-- Module Name: dram_control - Behavioral
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

-- this entity will interface with the controller
-- TODO: add a status output that will be mapped to a register so that
--      the processor can know what's going on
-- TODO: make data pattern configurable
-- TODO: read all memory to check for faults (later)
entity dram_control is
    port ( 
           -- signals to and from memory controller 
           ui_clk : in STD_LOGIC;
           ui_rst : in STD_LOGIC;
           init_calib_complete : in STD_LOGIC;
           app_wdf_rdy : in STD_LOGIC;
           app_rdy : in STD_LOGIC;
           app_rd_data : in STD_LOGIC_VECTOR (127 downto 0);
           app_rd_data_end : in STD_LOGIC;
           app_rd_data_valid : in STD_LOGIC;
           app_en : out STD_LOGIC;
           app_cmd : out STD_LOGIC_VECTOR (2 downto 0);
           app_addr : out STD_LOGIC_VECTOR (28 downto 0);
           app_wdf_data : out STD_LOGIC_VECTOR (127 downto 0);
           app_wdf_mask : out STD_LOGIC_VECTOR (15 downto 0);
           app_wdf_end : out STD_LOGIC;
           app_wdf_wren : out STD_LOGIC;
           -- signals from outside, will come from/go to registers in the axi
           ag1 : in STD_LOGIC_VECTOR (14 downto 0);         -- first aggressor
           ag2 : in STD_LOGIC_VECTOR (14 downto 0);         -- second aggressor
           victim : in STD_LOGIC_VECTOR (14 downto 0);      -- victim, must adjacent to an aggressor
           n_act : in STD_LOGIC_VECTOR (31 downto 0);       -- number of activations for hammering
           data_read: out std_logic_vector (127 downto 0);  -- last data that was read
           data_read_valid: out std_logic;                  -- data present isn data_read is valid
           data_ack: in std_logic;                          -- set by processor and cleared by peripheral
           status_reg: out std_logic_vector (15 downto 0);  -- give feedback on the status of the operations in the controller
           dev_rst: in std_logic;                           -- flag set when inputs are ready and procedure can start
		   data_pattern: in std_logic_vector(2 downto 0)	-- data pattern to write to the dram
           );
           
end dram_control;

architecture Behavioral of dram_control is

--------------------------------------------------------
---- component declarations -------
--------------------------------------------------------


component address_generator is
    Port ( clk : in STD_LOGIC;
           rst: in STD_LOGIC;
           can_go : in STD_LOGIC;
           addr : out STD_LOGIC_VECTOR (27 downto 0);
           over : out STD_LOGIC);
end component;

component hammer_module is
    Port ( clk : in STD_LOGIC;
           rst : in STD_LOGIC;
           can_go : in STD_LOGIC;
           ag1 : in STD_LOGIC_VECTOR (14 downto 0);
           ag2 : in STD_LOGIC_VECTOR (14 downto 0);
           n_act : in STD_LOGIC_VECTOR (31 downto 0);
           addr : out STD_LOGIC_VECTOR (27 downto 0);
           over : out STD_LOGIC);
end component hammer_module;

component column_counter is
      PORT (
    CLK : IN STD_LOGIC;
    CE : IN STD_LOGIC;
    SCLR : IN STD_LOGIC;
    THRESH0 : OUT STD_LOGIC;
    Q : OUT STD_LOGIC_VECTOR(9 DOWNTO 0)
  );
end component column_counter;

component delay is
  PORT (
    CLK : IN STD_LOGIC;
    CE : IN STD_LOGIC;
    SCLR : IN STD_LOGIC;
    THRESH0 : OUT STD_LOGIC;
    Q : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
  );
  end component delay;

-- debugging step - add ila
component ila_0 is
PORT (
  clk     : IN STD_LOGIC;
  probe0  : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
  probe1  : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
  probe2  : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
  probe3  : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
  probe4  : IN STD_LOGIC_VECTOR(28 DOWNTO 0)
);
end component ila_0;
--------------------------------------------------------
---- constant declarations -------
--------------------------------------------------------

constant RD_CMD: std_logic_vector (2 downto 0) := "001";
constant WR_CMD: std_logic_vector (2 downto 0) := "000";
constant RST_STATE: std_logic_vector (3 downto 0) := "0000"; -- 0x0
constant IDL_STATE: std_logic_vector (3 downto 0) := "0001"; -- 0x1
constant WRP_STATE: std_logic_vector (3 downto 0) := "0010"; -- 0x2
constant HAM_STATE: std_logic_vector (3 downto 0) := "0011"; -- 0x3
constant RDM_STATE: std_logic_vector (3 downto 0) := "0100"; -- 0x4
constant DON_STATE: std_logic_vector (3 downto 0) := "0101"; -- 0x5

--------------------------------------------------------
---- signal declarations -------
--------------------------------------------------------

-- signals to enable the various components
signal addr_gen_en_s: std_logic;
signal hammer_en_s: std_logic;
signal delay_en_s: std_logic;
-- over signals from the components
signal addr_gen_over_s: std_logic;
signal hammer_over_s: std_logic;
signal delay_over_s: std_logic;
-- address to be extended with rank (0 & part_addr)
-- will selecte between the two with a multiplexer
signal partial_addr_from_gen_s: std_logic_vector (27 downto 0);
signal partial_addr_from_hammer_s: std_logic_vector (27 downto 0);
-- signals used for reading the victim row after hammering
signal col_en_s: std_logic;
signal col_addr_s: std_logic_vector (9 downto 0);
signal read_over_s: std_logic;
-- signal for status register
-- i could probably use the state itself
signal state_tracker_s: std_logic_vector (3 downto 0);
-- internal signals
signal cmd_o_s: std_logic_vector (2 downto 0);
signal last_col_s: std_logic := '0';
signal need_invert: std_logic; -- chk and ros need to be inverted at each row
signal base_pattern: std_logic_vector(127 downto 0);
-- global reset signal to correctly reset all components
-- it's the or of ui_rst and dev_rst
signal global_reset: std_logic;
-- debugging step - ensure all signals are assigned once in process
signal app_en_s : std_logic;
signal app_addr_s : std_logic_vector(28 downto 0);
signal app_wdf_data_s: std_logic_vector(127 downto 0);
signal app_wdf_wren_s : std_logic;
signal app_wdf_end_s : std_logic;
signal data_read_valid_s: std_logic := '0';
-- debugging step - add ila
signal probe0 : STD_LOGIC_VECTOR(15 DOWNTO 0);
signal probe1 : STD_LOGIC_VECTOR(7 DOWNTO 0);
signal probe2 : STD_LOGIC_VECTOR(3 DOWNTO 0);
signal probe3 : STD_LOGIC_VECTOR(127 DOWNTO 0);
signal probe4 : STD_LOGIC_VECTOR(28 DOWNTO 0);

--------------------------------------------------------
---- state declaration -------
--------------------------------------------------------

type state_t is (idle, write_pattern, wp1, wp2, hammer, h1, wait_delay, read_flips, r1, r2, r3, done);
signal state_s: state_t;

begin

--------------------------------------------------------
---- component instantiation -------
--------------------------------------------------------

address_generator_i: address_generator port map (
    clk => ui_clk,
    rst => global_reset,
    can_go => addr_gen_en_s,
    addr => partial_addr_from_gen_s,
    over => addr_gen_over_s
);

hammer_module_i: hammer_module port map (
    clk => ui_clk,
    rst => global_reset,
    can_go => hammer_en_s,
    ag1 => ag1,
    ag2 => ag2,
    n_act => n_act,
    addr => partial_addr_from_hammer_s,
    over => hammer_over_s
);

col_counter_i: column_counter port map(
    CLK => ui_clk,
    CE => col_en_s,
    SCLR => global_reset,
    THRESH0 => read_over_s,
    Q => col_addr_s
);

delay_i: delay port map(
    CLK => ui_clk,
    CE => delay_en_s,
    SCLR => global_reset,
    THRESH0 => delay_over_s,
    Q => open
);

-- debugging step - add ila
ila_i: ila_0 port map (
  clk => ui_clk,
  probe0 => probe0, -- 16 bits - status reg
  probe1 => probe1, -- 8 bits - controls signals mig
  probe2 => probe2, -- 4 bits - state
  probe3 => probe3, -- 128 bits - read or write data
  probe4 => probe4  -- 29 bits - address sent to dram
);

--------------------------------------------------------
---- processes -------
--------------------------------------------------------

-- this is still very 
-- after all the inputs are set by the CPU in the appropriate
-- registers, this component will do the following
-- 1) write the data pattern to the selected bank
--    states wp1 and wp2 are used to perform the write
-- 2) do the hammering on the selected row pair
-- 3) read back the data 128 bits at a time to allow
--    the cpu to check for differences
state_machine: process(ui_clk)
-- debugging step - ensure all signals are assigned once inside process
-- this is achieved by using variables
-- in theory it should not matter but you never know
variable addr_gen_en_v: std_logic;
variable hammer_en_v: std_logic;
variable col_en_v: std_logic;
variable delay_en_v: std_logic;
variable state_tracker_v: std_logic_vector (3 downto 0);
variable cmd_o_v: std_logic_vector (2 downto 0);
variable last_col_v: std_logic := '0';
variable state_v: state_t;
variable invert_v: boolean := false;
-- these go directly to output so map them to new signals
variable app_en_v: std_logic;
variable app_addr_v : std_logic_vector(28 downto 0);
variable app_wdf_data_v: std_logic_vector(127 downto 0);
variable app_wdf_wren_v: std_logic;
variable app_wdf_end_v: std_logic;
variable data_read_valid_v: std_logic;
begin
if rising_edge(ui_clk) then
    if global_reset = '1' then
        -- reset state machine, disable commands
        state_v := idle;
        app_en_v := '0';
        cmd_o_v := RD_CMD;
        last_col_v := '0';
        invert_v := false;
        app_addr_v := (others => '0');
        -- disable all other components
        addr_gen_en_v := '0';
        hammer_en_v := '0';
        col_en_v := '0';
        delay_en_v := '0';
        -- zero data out and valid bit
        data_read <= (others => '0');
        data_read_valid_v := '0';
        -- disable writes
        app_wdf_end_v := '0';
        app_wdf_wren_v := '0';
        app_wdf_data_v := (others => '0');
        -- track status
        state_tracker_v := RST_STATE;
    else
        -- default assignments
        -- stop commands
        app_en_v := '0';
        app_wdf_wren_v := '0';
        app_wdf_end_v := '0';
        -- pause state (last_col not set intentionally)
        addr_gen_en_v := '0';
        hammer_en_v := '0';
        col_en_v := '0';
        delay_en_v := '0';
        data_read_valid_v := '0';
        -- now set signals according to state
        case state_s is
            when idle =>
                state_tracker_v := IDL_STATE;
                -- remain here until calibration completes
                if init_calib_complete = '0' then
                    state_v := idle;
                    -- set it just in case we somehow end up here
                    last_col_v := '0';
                else
                    state_v := write_pattern;
                end if;
            when write_pattern =>
                state_tracker_v := WRP_STATE;
                -- when the addr_gen component emits the over signal proceed
                if addr_gen_over_s = '1' then
                    hammer_en_v := '1';
                    state_v := hammer;
                -- write data to the controller ui
                elsif app_wdf_rdy = '1' then
                    -- generate the next address so that it will be ready
                    -- in the next state
                    addr_gen_en_v := '1';
                    -- set app_wdf_data to the correct data pattern for this row
                    -- for some patterns i need to invert when changing row, but the address
                    -- will be ready after i already wrote the data, so i need to check whether
                    -- the next address would be a new row
                    if need_invert = '1' then
                        if partial_addr_from_gen_s(9 downto 0) = "0000000000" then
                            if invert_v then
                                app_wdf_data_v := not base_pattern;
                            else
                                app_wdf_data_v := base_pattern;
                            end if;
                            invert_v := not invert_v;
                        end if;
                    else
                        app_wdf_data_v := base_pattern;
                    end if;

                    -- write data to controller ui
                    app_wdf_wren_v := '1';
                    app_wdf_end_v := '1';
                    state_v := wp1;
                else
                    -- wait for ui to be ready
                    addr_gen_en_v := '0';
                    app_wdf_wren_v := '0';
                    app_wdf_end_v := '0';
                    state_v := write_pattern;
                end if;
            -- TODO: i think this next state can possibly be optimized out since
            -- i can do these operations when app_wdf_ready = 1 in the previous
            -- state, saving time during writing
            when wp1 => 
                -- here i written data to the ui, need to assert the command
                app_addr_v := '0' & partial_addr_from_gen_s;
                app_en_v := '1';
                cmd_o_v := WR_CMD;
                state_v := wp2;
            when wp2 =>
                -- need to keep command asserted until app_rdy is high
                if app_rdy = '1' then
                    state_v := write_pattern;
                else
                    app_en_v := '1';
                    cmd_o_v := WR_CMD;
                    state_v := wp2;
                end if;
            when hammer =>
                state_tracker_v := HAM_STATE;
                if hammer_over_s = '1' then
                    -- when the hammer component emits the over signal proceed
                    state_v := wait_delay;
                    delay_en_v := '1';
                    app_en_v := '0';
                else
                    -- enable hammer component and assert command
                    app_addr_v := '0' & partial_addr_from_hammer_s;
                    hammer_en_v := '1';
                    app_en_v := '1';
                    cmd_o_v := RD_CMD;
                    state_v := h1;
                end if;
            when h1 =>
                -- keep read asserted until app_rdy is asserted
                -- we don't care about the read output
                if app_rdy = '1' then
                    state_v := hammer;
                else
                    app_en_v := '1';
                    cmd_o_v := RD_CMD;
                    state_v := h1;
                end if;
            when wait_delay =>
                -- the purpose of this state is to wait for the read commands
                -- sent by the hammering to output data so that the read logic 
                -- does not overlap with it
                if delay_over_s = '0' then
                    delay_en_v := '1';
                    state_v := wait_delay;
                else
                    state_v := read_flips;
                end if;
            when read_flips =>
                -- read data from the victim row and write it out
                -- one burst at a time
                -- before reading the next burst wait for external ack
                state_tracker_v := RDM_STATE;
                if last_col_v = '1' then
                    -- check if we need to exit
                    state_v := done;
                    app_en_v := '0';
                else
                    -- if i am here it's either the first read or data_ack has been
                    -- asserted in r3
                    -- compose the address and assert command
                    app_addr_v := '0' & "000" & victim & col_addr_s;
                    app_en_v := '1';
                    cmd_o_v := RD_CMD;
                    state_v := r1;
                end if;
                -- if this is the last column, set flag to exit
                if read_over_s = '1' then
                    last_col_v := '1';
                end if;
            when r1 =>
                -- keep command asserted until it is accepted
                if app_rdy = '0' then
                    app_addr_v := '0' & "000" & victim & col_addr_s;
                    app_en_v := '1';
                    cmd_o_v := RD_CMD;
                    state_v := r1;
                else
                    -- prepare next column
                    -- this is done here so that during r2 (which lasts at minimum 1ck)
                    -- the CE is asserted for column counter, which guarantees that the
                    -- next address is ready when we go back to read_flips
                    col_en_v := '1';
                    state_v := r2;
                end if;
            when r2 =>
                -- wait until data valid, then copy to output
                -- and signal that it is ready
                -- this is not efficient but timing is not critical here
                if app_rd_data_valid = '1' then
                    data_read <= app_rd_data;
                    data_read_valid_v := '1';
                    state_v := r3;
                else
                    state_v := r2;
                end if;
            when r3 =>
                -- keep data_read_valid up until an ack is received
                if data_ack = '0' then
                    data_read_valid_v := '1';
                    state_v := r3;
                else
                    state_v := read_flips;
                end if;
            when done =>
                -- nothing to do
                state_tracker_v := DON_STATE;
                state_v := done;
            when others =>
                state_v := idle;
        end case;
    end if;
end if;
addr_gen_en_s <= addr_gen_en_v;
hammer_en_s <= hammer_en_v; 
col_en_s <= col_en_v; 
delay_en_s <= delay_en_v;
state_tracker_s <= state_tracker_v; 
cmd_o_s <= cmd_o_v; 
last_col_s <= last_col_v; 
state_s <= state_v;
app_en_s <= app_en_v;
app_addr_s <= app_addr_v;
app_wdf_data_s <= app_wdf_data_v;
app_wdf_wren_s <= app_wdf_wren_v;
app_wdf_end_s <= app_wdf_end_v;
data_read_valid_s <= data_read_valid_v;
end process;


--------------------------------------------------------
---- combinatorial logic -------
--------------------------------------------------------

-- reset signal
global_reset <= ui_rst or dev_rst;

-- write signals
need_invert <= data_pattern(1);
base_pattern <= (others => '0') when data_pattern = "000" else -- sol0
                (others => '1') when data_pattern = "001" else -- sol1
                "10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010" when data_pattern = "010" else -- chk, at each row logic will invert it
                (others => '1') when data_pattern = "011" else -- ros, at each row logic will invert it
                (others => '1'); -- default
app_wdf_data <= app_wdf_data_s;
app_wdf_mask <= (others => '0'); -- no masking
-- output cmd
app_cmd <= cmd_o_s;

-- debugging step - ensure all signals are assigned once inside process
app_en <= app_en_s;
app_addr <= app_addr_s;
app_wdf_wren <= app_wdf_wren_s;
app_wdf_end <= app_wdf_end_s;
data_read_valid <= data_read_valid_s;

-- status register with information on the internal process
status_reg(15 downto 0) <= hammer_en_s & addr_gen_en_s & hammer_over_s & addr_gen_over_s & dev_rst & ui_rst & init_calib_complete & app_wdf_rdy & app_rdy & cmd_o_s & state_tracker_s;

-- debugging step - add ila
probe0 <= hammer_en_s & -- almost mirror status_reg to check if it is correct
        addr_gen_en_s &
        col_en_s & 
        hammer_over_s & 
        addr_gen_over_s & 
        dev_rst & 
        ui_rst & 
        init_calib_complete & 
        app_wdf_rdy & 
        app_rdy &
        data_ack &
        data_read_valid_s & 
        state_tracker_s;
probe1 <= cmd_o_s(0) & -- control signals to and from the mig
        app_en_s &
        app_rdy &
        app_wdf_rdy &
        app_wdf_wren_s &
        app_wdf_end_s &
        app_rd_data_valid &
        app_rd_data_end;
probe2 <= X"0" when state_s = idle else  -- current state
        X"1" when state_s = write_pattern else
        X"2" when state_s = wp1 else
        X"3" when state_s = wp2 else
        X"4" when state_s = hammer else
        X"5" when state_s = h1 else
        X"6" when state_s = wait_delay else
        X"7" when state_s = read_flips else
        X"8" when state_s = r1 else
        X"9" when state_s = r2 else
        X"A" when state_s = r3 else
        X"B" when state_s = done else
        X"F";

probe3 <= app_wdf_data_s when state_s = write_pattern or state_s = wp1 or state_s = wp2 else
        app_rd_data;

probe4 <= app_addr_s;

end Behavioral;
