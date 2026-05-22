----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/20/2026 04:09:29 PM
-- Design Name: 
-- Module Name: controller - Behavioral
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity controller is
    port (
        -- to memory
      ddr3_dq       : inout std_logic_vector(15 downto 0);
      ddr3_dqs_p    : inout std_logic_vector(1 downto 0);
      ddr3_dqs_n    : inout std_logic_vector(1 downto 0);

      ddr3_addr     : out   std_logic_vector(14 downto 0);
      ddr3_ba       : out   std_logic_vector(2 downto 0);
      ddr3_ras_n    : out   std_logic;
      ddr3_cas_n    : out   std_logic;
      ddr3_we_n     : out   std_logic;
      ddr3_reset_n  : out   std_logic;
      ddr3_ck_p     : out   std_logic_vector(0 downto 0);
      ddr3_ck_n     : out   std_logic_vector(0 downto 0);
      ddr3_cke      : out   std_logic_vector(0 downto 0);
      ddr3_dm       : out   std_logic_vector(1 downto 0);
      ddr3_odt      : out   std_logic_vector(0 downto 0);
      -- clock and reset
      sys_clk     : in    std_logic;
      sys_rst_n       : in    std_logic;
      init_calib_complete : out std_logic;
      -- output clock from ui to sync external operations
      out_clk : out std_logic;
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
      curr_addr: out std_logic_vector(28 downto 0);    -- address currently fed to the mig
	  data_pattern: in std_logic_vector(2 downto 0)	   -- data pattern to write to the dram
    );
end controller;

architecture Behavioral of controller is
--------------------------------------------------------
---- component declarations -------
--------------------------------------------------------

component mig_7series_0
    port(
      ddr3_dq       : inout std_logic_vector(15 downto 0);
      ddr3_dqs_p    : inout std_logic_vector(1 downto 0);
      ddr3_dqs_n    : inout std_logic_vector(1 downto 0);

      ddr3_addr     : out   std_logic_vector(14 downto 0);
      ddr3_ba       : out   std_logic_vector(2 downto 0);
      ddr3_ras_n    : out   std_logic;
      ddr3_cas_n    : out   std_logic;
      ddr3_we_n     : out   std_logic;
      ddr3_reset_n  : out   std_logic;
      ddr3_ck_p     : out   std_logic_vector(0 downto 0);
      ddr3_ck_n     : out   std_logic_vector(0 downto 0);
      ddr3_cke      : out   std_logic_vector(0 downto 0);
      ddr3_dm       : out   std_logic_vector(1 downto 0);
      ddr3_odt      : out   std_logic_vector(0 downto 0);
      app_addr                  : in    std_logic_vector(28 downto 0);
      app_cmd                   : in    std_logic_vector(2 downto 0);
      app_en                    : in    std_logic;
      app_wdf_data              : in    std_logic_vector(127 downto 0);
      app_wdf_end               : in    std_logic;
      app_wdf_mask         : in    std_logic_vector(15 downto 0);
      app_wdf_wren              : in    std_logic;
      app_rd_data               : out   std_logic_vector(127 downto 0);
      app_rd_data_end           : out   std_logic;
      app_rd_data_valid         : out   std_logic;
      app_rdy                   : out   std_logic;
      app_wdf_rdy               : out   std_logic;
      app_sr_req                : in    std_logic;
      app_ref_req               : in    std_logic;
      app_zq_req                : in    std_logic;
      app_sr_active             : out   std_logic;
      app_ref_ack               : out   std_logic;
      app_zq_ack                : out   std_logic;
      ui_clk                    : out   std_logic;
      ui_clk_sync_rst           : out   std_logic;
      init_calib_complete       : out   std_logic;
      -- System Clock Ports
      sys_clk_i                      : in    std_logic;
      device_temp                      : out std_logic_vector(11 downto 0);
      sys_rst             : in std_logic
      );
end component mig_7series_0;

component dram_control is
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
end component dram_control;

--------------------------------------------------------
---- signal declarations -------
--------------------------------------------------------

-- clock and rst from ui to dram_control, reset active high
signal ui_clk: std_logic;
signal ui_rst: std_logic;
-- signals to check status
signal calib_complete: std_logic;
signal app_rdy: std_logic;
signal app_wdf_rdy: std_logic;
-- write signals
signal app_wdf_data : STD_LOGIC_VECTOR (127 downto 0);
signal app_wdf_mask : STD_LOGIC_VECTOR (15 downto 0);
signal app_wdf_end : STD_LOGIC;
signal app_wdf_wren : STD_LOGIC;
-- read signals
signal app_rd_data : STD_LOGIC_VECTOR (127 downto 0);
signal app_rd_data_end : STD_LOGIC;
signal app_rd_data_valid : STD_LOGIC;
-- addressing and command
signal app_cmd: std_logic_vector (2 downto 0);
signal app_en: std_logic;
signal app_addr: std_logic_vector (28 downto 0);
-- managing refresh
signal app_ref_req: std_logic;
signal app_ref_ack: std_logic;
signal status_reg_s: std_logic_vector(15 downto 0);

--------------------------------------------------------
---- state declaration -------
--------------------------------------------------------



begin

--------------------------------------------------------
---- component instantiation -------
--------------------------------------------------------

mig_7series_0_mig_i : mig_7series_0
    port map (
       -- Memory interface ports
       ddr3_addr                      => ddr3_addr,
       ddr3_ba                        => ddr3_ba,
       ddr3_cas_n                     => ddr3_cas_n,
       ddr3_ck_n                      => ddr3_ck_n,
       ddr3_ck_p                      => ddr3_ck_p,
       ddr3_cke                       => ddr3_cke,
       ddr3_ras_n                     => ddr3_ras_n,
       ddr3_reset_n                   => ddr3_reset_n,
       ddr3_we_n                      => ddr3_we_n,
       ddr3_dq                        => ddr3_dq,
       ddr3_dqs_n                     => ddr3_dqs_n,
       ddr3_dqs_p                     => ddr3_dqs_p,
       init_calib_complete            => calib_complete,
       ddr3_dm                        => ddr3_dm,
       ddr3_odt                       => ddr3_odt,
       -- Application interface ports
       app_addr                       => app_addr,
       app_cmd                        => app_cmd,
       app_en                         => app_en,
       app_wdf_data                   => app_wdf_data,
       app_wdf_end                    => app_wdf_end,
       app_wdf_wren                   => app_wdf_wren,
       app_rd_data                    => app_rd_data,
       app_rd_data_end                => app_rd_data_end,
       app_rd_data_valid              => app_rd_data_valid,
       app_rdy                        => app_rdy,
       app_wdf_rdy                    => app_wdf_rdy,
       app_sr_req                     => '0', -- reserved
       app_ref_req                    => app_ref_req,
       app_zq_req                     => '0', -- unused
       app_sr_active                  => open, -- reserved
       app_ref_ack                    => app_ref_ack,
       app_zq_ack                     => open, -- unused
       ui_clk                         => ui_clk,
       ui_clk_sync_rst                => ui_rst,
       app_wdf_mask                   => app_wdf_mask,
       -- System Clock Ports
       sys_clk_i                       => sys_clk,
	   device_temp                      => open, -- unused
       -- it's called sys_rst but can be configured either high or low and i set low in the options
       sys_rst                        => sys_rst_n
    );
    
dram_control_i : dram_control
    port map ( 
           -- signals to and from memory controller 
           ui_clk => ui_clk,
           ui_rst => ui_rst,
           init_calib_complete => calib_complete,
           app_wdf_rdy => app_wdf_rdy,
           app_rdy => app_rdy,
           app_rd_data => app_rd_data,
           app_rd_data_end => app_rd_data_end,
           app_rd_data_valid => app_rd_data_valid,
           app_en => app_en,
           app_cmd => app_cmd,
           app_addr => app_addr,
           app_wdf_data => app_wdf_data, 
           app_wdf_mask => app_wdf_mask,
           app_wdf_end => app_wdf_end,
           app_wdf_wren => app_wdf_wren,
           -- signals from outside, will come from register in the axi
           ag1 => ag1,
           ag2 => ag2,
           victim => victim,
           n_act => n_act,
           data_read => data_read,
           data_read_valid => data_read_valid,
           data_ack => data_ack,
           status_reg => status_reg_s,
           dev_rst => dev_rst,
           data_pattern => data_pattern
           );

--------------------------------------------------------
---- processes -------
--------------------------------------------------------

-- handle user refreshes
-- refreshes are disabled during the hammer phase
refresh_handler: process(ui_clk)
variable refresh_sent: boolean := false;
variable ack_received: boolean := true;
variable counter: std_logic_vector(9 downto 0) := (others => '0');
begin
    if sys_rst_n = '0' or calib_complete = '0' then
        -- do not send refreshes if reset or calib not done
        app_ref_req <= '0';
        counter := (others => '0');
        -- reset state also
        refresh_sent := false;
        ack_received := true;
    elsif rising_edge(ui_clk) then
        -- refresh logic
        if status_reg_s(3 downto 0) = "0011" then
            -- do not send refreshes when hammering
            app_ref_req <= '0';
        elsif not refresh_sent then
            -- if last refresh was acknoledged, send refresh
            if ack_received then
                app_ref_req <= '1';
                refresh_sent := true;
                -- reset ack flag for this ref
                ack_received := false;
            else
                app_ref_req <= '0';
            end if;
        else
            -- i don't send refresh request
            app_ref_req <= '0';
            -- increment counter up to 759
            -- since the maximum time between refresh requests is given by
            -- (tREFI - (tRCD + (CL+4)tCK) + tRP)N_bank_machines) = 7590ns
            counter := counter + "000000001";
            if counter = "1011110111" then
                -- at 759, enable ref again and restart
                refresh_sent := false;
                counter := (others => '0');
            end if;
        end if;
        -- ack logic
        if app_ref_ack = '1' then
            ack_received := true;
        end if;
    end if;
end process;

--------------------------------------------------------
---- combinatorial logic -------
--------------------------------------------------------
init_calib_complete <= calib_complete;
out_clk <= ui_clk;
curr_addr <= app_addr;
status_reg <= status_reg_s;

end Behavioral;
