----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/02/2026 11:23:19 AM
-- Design Name: 
-- Module Name: controller_top - Behavioral
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

entity controller_top is
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
end controller_top;

architecture Behavioral of controller_top is

component controller is
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
		  data_pattern: in std_logic_vector(2 downto 0)	  -- data pattern to write to the dram
    );
end component controller;


begin

controller_i: controller
port map (
      ddr3_dq       => ddr3_dq,
      ddr3_dqs_p    => ddr3_dqs_p,
      ddr3_dqs_n    => ddr3_dqs_n,

      ddr3_addr     => ddr3_addr,
      ddr3_ba       => ddr3_ba,
      ddr3_ras_n    => ddr3_ras_n,
      ddr3_cas_n    => ddr3_cas_n,
      ddr3_we_n     => ddr3_we_n,
      ddr3_reset_n  => ddr3_reset_n,
      ddr3_ck_p     => ddr3_ck_p,
      ddr3_ck_n     => ddr3_ck_n,
      ddr3_cke      => ddr3_cke,
      ddr3_dm       => ddr3_dm,
      ddr3_odt      => ddr3_odt,
      -- clock and reset
      sys_clk     => sys_clk,
      sys_rst_n     => sys_rst_n,
      init_calib_complete => init_calib_complete,
      out_clk => out_clk,
      -- signals from outside, will come from/go to registers in the axi
      ag1 => ag1,
      ag2 => ag2,
      victim => victim,
      n_act => n_act,
      data_read => data_read,
      data_read_valid => data_read_valid,
      data_ack => data_ack,
      status_reg => status_reg,
      dev_rst => dev_rst,
      curr_addr => curr_addr,
      data_pattern => data_pattern
);
end Behavioral;
