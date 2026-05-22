library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hammer_device_slave_lite_v0_1_S00_AXI is
	generic (
		-- Users to add parameters here

		-- User parameters ends
		-- Do not modify the parameters beyond this line

		-- Width of S_AXI data bus
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		-- Width of S_AXI address bus
		C_S_AXI_ADDR_WIDTH	: integer	:= 6
	);
	port (
		-- Users to add ports here
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
      	sys_rst_n     : in    std_logic;
		-- User ports ends
		-- Do not modify the ports beyond this line

		-- Global Clock Signal
		S_AXI_ACLK	: in std_logic;
		-- Global Reset Signal. This Signal is Active LOW
		S_AXI_ARESETN	: in std_logic;
		-- Write address (issued by master, acceped by Slave)
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		-- Write channel Protection type. This signal indicates the
    		-- privilege and security level of the transaction, and whether
    		-- the transaction is a data access or an instruction access.
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		-- Write address valid. This signal indicates that the master signaling
    		-- valid write address and control information.
		S_AXI_AWVALID	: in std_logic;
		-- Write address ready. This signal indicates that the slave is ready
    		-- to accept an address and associated control signals.
		S_AXI_AWREADY	: out std_logic;
		-- Write data (issued by master, acceped by Slave) 
		S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		-- Write strobes. This signal indicates which byte lanes hold
    		-- valid data. There is one write strobe bit for each eight
    		-- bits of the write data bus.    
		S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		-- Write valid. This signal indicates that valid write
    		-- data and strobes are available.
		S_AXI_WVALID	: in std_logic;
		-- Write ready. This signal indicates that the slave
    		-- can accept the write data.
		S_AXI_WREADY	: out std_logic;
		-- Write response. This signal indicates the status
    		-- of the write transaction.
		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
		-- Write response valid. This signal indicates that the channel
    		-- is signaling a valid write response.
		S_AXI_BVALID	: out std_logic;
		-- Response ready. This signal indicates that the master
    		-- can accept a write response.
		S_AXI_BREADY	: in std_logic;
		-- Read address (issued by master, acceped by Slave)
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		-- Protection type. This signal indicates the privilege
    		-- and security level of the transaction, and whether the
    		-- transaction is a data access or an instruction access.
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		-- Read address valid. This signal indicates that the channel
    		-- is signaling valid read address and control information.
		S_AXI_ARVALID	: in std_logic;
		-- Read address ready. This signal indicates that the slave is
    		-- ready to accept an address and associated control signals.
		S_AXI_ARREADY	: out std_logic;
		-- Read data (issued by slave)
		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		-- Read response. This signal indicates the status of the
    		-- read transfer.
		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
		-- Read valid. This signal indicates that the channel is
    		-- signaling the required read data.
		S_AXI_RVALID	: out std_logic;
		-- Read ready. This signal indicates that the master can
    		-- accept the read data and response information.
		S_AXI_RREADY	: in std_logic
	);
end hammer_device_slave_lite_v0_1_S00_AXI;

architecture arch_imp of hammer_device_slave_lite_v0_1_S00_AXI is

	-- AXI4LITE signals
	signal axi_awaddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_awready	: std_logic;
	signal axi_wready	: std_logic;
	signal axi_bresp	: std_logic_vector(1 downto 0);
	signal axi_bvalid	: std_logic;
	signal axi_araddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_arready	: std_logic;
	signal axi_rresp	: std_logic_vector(1 downto 0);
	signal axi_rvalid	: std_logic;

	-- Example-specific design signals
	-- local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	-- ADDR_LSB is used for addressing 32/64 bit registers/memories
	-- ADDR_LSB = 2 for 32 bits (n downto 2)
	-- ADDR_LSB = 3 for 64 bits (n downto 3)
	constant ADDR_LSB  : integer := (C_S_AXI_DATA_WIDTH/32)+ 1;
	constant OPT_MEM_ADDR_BITS : integer := 3;
	------------------------------------------------
	---- Signals for user logic register space example
	--------------------------------------------------
	---- Number of Slave Registers 12
	signal slv_reg0	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg1	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg2	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg3	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg4	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg5	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg6	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg7	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg8	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg9	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg10	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg11	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal byte_index	: integer;

	 signal mem_logic  : std_logic_vector(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);

	 --State machine local parameters
	constant Idle : std_logic_vector(1 downto 0) := "00";
	constant Raddr: std_logic_vector(1 downto 0) := "10";
	constant Rdata: std_logic_vector(1 downto 0) := "11";
	constant Waddr: std_logic_vector(1 downto 0) := "10";
	constant Wdata: std_logic_vector(1 downto 0) := "11";
	 --State machine variables
	signal state_read : std_logic_vector(1 downto 0);
	signal state_write: std_logic_vector(1 downto 0); 

	-----------------------------
	----- user component and signals
	-----------------------------

	-- debugging step - add ila
	component ila_1 is
	PORT (
		clk     : IN STD_LOGIC;
		probe0  : IN STD_LOGIC_VECTOR(17 DOWNTO 0)
	);
	end component ila_1;

	signal probe0 : STD_LOGIC_VECTOR(17 downto 0);

	component controller_top is
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
		sys_rst_n       : in    std_logic; -- active low reset
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
		data_pattern: in std_logic_vector(2 downto 0)	 -- data pattern to write to the dram
		);
	end component controller_top;

	-- clock in sync with ui
	signal out_clk : std_logic;
	-- control signals
	signal data_ack: std_logic;                         -- set by processor and cleared by peripheral
	signal dev_rst : std_logic;							-- set by processor when config registers are ready	
	-- configuration
	signal ag1 :STD_LOGIC_VECTOR (14 downto 0);         -- first aggressor
	signal ag2 :STD_LOGIC_VECTOR (14 downto 0);         -- second aggressor
	signal victim :STD_LOGIC_VECTOR (14 downto 0);      -- victim, must adjacent to an aggressor
	signal n_act :STD_LOGIC_VECTOR (31 downto 0);       -- number of activations for hammering
	-- output data from memory
	signal data_read: std_logic_vector (127 downto 0);  -- last data that was read
	signal data_read_valid: std_logic;                  -- data present isn data_read is valid
	-- status of the state machine and internal control signals
	signal status_reg: std_logic_vector (15 downto 0);  -- give feedback on the status of the operations in the controller
	signal curr_addr: std_logic_vector(28 downto 0);    -- see address fed to the mig
	signal data_pattern: std_logic_vector(2 downto 0);  -- data pattern to use

begin
	-- I/O Connections assignments

	S_AXI_AWREADY	<= axi_awready;
	S_AXI_WREADY	<= axi_wready;
	S_AXI_BRESP	<= axi_bresp;
	S_AXI_BVALID	<= axi_bvalid;
	S_AXI_ARREADY	<= axi_arready;
	S_AXI_RRESP	<= axi_rresp;
	S_AXI_RVALID	<= axi_rvalid;
	    mem_logic     <= S_AXI_AWADDR(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB) when (S_AXI_AWVALID = '1') else axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);

	-- Implement Write state machine
	-- Outstanding write transactions are not supported by the slave i.e., master should assert bready to receive response on or before it starts sending the new transaction
	 process (S_AXI_ACLK)                                       
	   begin                                       
	     if rising_edge(S_AXI_ACLK) then                                       
	        if S_AXI_ARESETN = '0' then                                       
	          --asserting initial values to all 0's during reset                                       
	          axi_awready <= '0';                                       
	          axi_wready <= '0';                                       
	          axi_bvalid <= '0';                                       
	          axi_bresp <= (others => '0');                                       
	          state_write <= Idle;                                       
	        else                                       
	          case (state_write) is                                       
	             when Idle =>		--Initial state inidicating reset is done and ready to receive read/write transactions                                       
	               if (S_AXI_ARESETN = '1') then                                       
	                 axi_awready <= '1';                                       
	                 axi_wready <= '1';                                       
	                 state_write <= Waddr;                                       
	               else state_write <= state_write;                                       
	               end if;                                       
	             when Waddr =>		--At this state, slave is ready to receive address along with corresponding control signals and first data packet. Response valid is also handled at this state                                       
	               if (S_AXI_AWVALID = '1' and axi_awready = '1') then                                       
	                 axi_awaddr <= S_AXI_AWADDR;                                       
	                 if (S_AXI_WVALID = '1') then                                       
	                   axi_awready <= '1';                                       
	                   state_write <= Waddr;                                       
	                   axi_bvalid <= '1';                                       
	                 else                                       
	                   axi_awready <= '0';                                       
	                   state_write <= Wdata;                                       
	                   if (S_AXI_BREADY = '1' and axi_bvalid = '1') then                                       
	                     axi_bvalid <= '0';                                       
	                   end if;                                       
	                 end if;                                       
	               else                                        
	                 state_write <= state_write;                                       
	                 if (S_AXI_BREADY = '1' and axi_bvalid = '1') then                                       
	                   axi_bvalid <= '0';                                       
	                 end if;                                       
	               end if;                                       
	             when Wdata =>		--At this state, slave is ready to receive the data packets until the number of transfers is equal to burst length                                       
	               if (S_AXI_WVALID = '1') then                                       
	                 state_write <= Waddr;                                       
	                 axi_bvalid <= '1';                                       
	                 axi_awready <= '1';                                       
	               else                                       
	                 state_write <= state_write;                                       
	                 if (S_AXI_BREADY ='1' and axi_bvalid = '1') then                                       
	                   axi_bvalid <= '0';                                       
	                 end if;                                       
	               end if;                                       
	             when others =>      --reserved                                       
	               axi_awready <= '0';                                       
	               axi_wready <= '0';                                       
	               axi_bvalid <= '0';                                       
	           end case;                                       
	        end if;                                       
	      end if;                                                
	 end process;                                       
	-- Implement memory mapped register select and write logic generation
	-- The write data is accepted and written to memory mapped registers when
	-- axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	-- select byte enables of slave registers while writing.
	-- These registers are cleared when reset (active low) is applied.
	-- Slave register write enable is asserted when valid address and data are available
	-- and the slave is ready to accept the write address and write data.
	

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
		  -- data in from microcontroller
	      slv_reg0 <= (others => '0');	-- ag1
	      slv_reg1 <= (others => '0');	-- ag2
	      slv_reg2 <= (others => '0');	-- victim
	      slv_reg3 <= (others => '0');	-- n_act
	      slv_reg4 <= (others => '0');	-- control register (pattern, rst, data_ack)
		  -- data out from module (commented to avoid multiple driver issues)
	      -- slv_reg5 <= (others => '0');	-- data_read(127 downto 96)
	      -- slv_reg6 <= (others => '0');	-- data_read(95 downto 64)
	      -- slv_reg7 <= (others => '0');	-- data_read(63 downto 32)
	      -- slv_reg8 <= (others => '0');	-- data_read(31 downto 0)
	      -- slv_reg9 <= (others => '0');	-- data valid flag
	      -- slv_reg10 <= (others => '0');	-- status register
	      -- slv_reg11 <= (others => '0');	-- addr out
	    else
	      if (S_AXI_WVALID = '1') then
	          case (mem_logic) is
	          when b"0000" =>
	            for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
	              if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 0
	                slv_reg0(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0001" =>
	            for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
	              if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 1
	                slv_reg1(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0010" =>
	            for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
	              if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 2
	                slv_reg2(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0011" =>
	            for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
	              if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 3
	                slv_reg3(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0100" =>
	            for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
	              if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 4
	                slv_reg4(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	        --   when b"0101" =>
	            -- for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
	            --   if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- -- Respective byte enables are asserted as per write strobes                   
	                -- -- slave registor 5
	                -- slv_reg5(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	            --   end if;
	            -- end loop;
	        --   when b"0110" =>
	            -- for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
	            --   if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- -- Respective byte enables are asserted as per write strobes                   
	                -- -- slave registor 6
	                -- slv_reg6(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	            --   end if;
	            -- end loop;
	        --   when b"0111" =>
	            -- for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
	            --   if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- -- Respective byte enables are asserted as per write strobes                   
	                -- -- slave registor 7
	                -- slv_reg7(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	            --   end if;
	            -- end loop;
	        --   when b"1000" =>
	            -- for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
	            --   if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- -- Respective byte enables are asserted as per write strobes                   
	                -- -- slave registor 8
	                -- slv_reg8(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	            --   end if;
	            -- end loop;
	        --   when b"1001" =>
	            -- for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
	            --   if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- -- Respective byte enables are asserted as per write strobes                   
	                -- -- slave registor 9
	                -- slv_reg9(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	            --   end if;
	            -- end loop;
	        --   when b"1010" =>
	            -- for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
	            --   if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- -- Respective byte enables are asserted as per write strobes                   
	                -- -- slave registor 10
	                -- slv_reg10(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	            --   end if;
	            -- end loop;
	        --   when b"1011" =>
	            -- for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
	            --   if ( S_AXI_WSTRB(byte_index) = '1' ) then
	                -- -- Respective byte enables are asserted as per write strobes                   
	                -- -- slave registor 11
	                -- slv_reg11(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	            --   end if;
	            -- end loop;
	          when others =>
	            slv_reg0 <= slv_reg0;
	            slv_reg1 <= slv_reg1;
	            slv_reg2 <= slv_reg2;
	            slv_reg3 <= slv_reg3;
	            slv_reg4 <= slv_reg4;
	            -- slv_reg5 <= slv_reg5;
	            -- slv_reg6 <= slv_reg6;
	            -- slv_reg7 <= slv_reg7;
	            -- slv_reg8 <= slv_reg8;
	            -- slv_reg9 <= slv_reg9;
	            -- slv_reg10 <= slv_reg10;
	            -- slv_reg11 <= slv_reg11;
	        end case;
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement read state machine
	 process (S_AXI_ACLK)                                          
	   begin                                          
	     if rising_edge(S_AXI_ACLK) then                                           
	        if S_AXI_ARESETN = '0' then                                          
	          --asserting initial values to all 0's during reset                                          
	          axi_arready <= '0';                                          
	          axi_rvalid <= '0';                                          
	          axi_rresp <= (others => '0');                                          
	          state_read <= Idle;                                          
	        else                                          
	          case (state_read) is                                          
	            when Idle =>		--Initial state inidicating reset is done and ready to receive read/write transactions                                          
	                if (S_AXI_ARESETN = '1') then                                          
	                  axi_arready <= '1';                                          
	                  state_read <= Raddr;                                          
	                else state_read <= state_read;                                          
	                end if;                                          
	            when Raddr =>		--At this state, slave is ready to receive address along with corresponding control signals                                          
	                if (S_AXI_ARVALID = '1' and axi_arready = '1') then                                          
	                  state_read <= Rdata;                                          
	                  axi_rvalid <= '1';                                          
	                  axi_arready <= '0';                                          
	                  axi_araddr <= S_AXI_ARADDR;                                          
	                else                                          
	                  state_read <= state_read;                                          
	                end if;                                          
	            when Rdata =>		--At this state, slave is ready to send the data packets until the number of transfers is equal to burst length                                          
	                if (axi_rvalid = '1' and S_AXI_RREADY = '1') then                                          
	                  axi_rvalid <= '0';                                          
	                  axi_arready <= '1';                                          
	                  state_read <= Raddr;                                          
	                else                                          
	                  state_read <= state_read;                                          
	                end if;                                          
	            when others =>      --reserved                                          
	                axi_arready <= '0';                                          
	                axi_rvalid <= '0';                                          
	           end case;                                          
	         end if;                                          
	       end if;                                                   
	  end process;                                          
	-- Implement memory mapped register select and read logic generation
	 S_AXI_RDATA <= slv_reg0 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "0000" ) else 
	 slv_reg1 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "0001" ) else 
	 slv_reg2 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "0010" ) else 
	 slv_reg3 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "0011" ) else 
	 slv_reg4 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "0100" ) else 
	 slv_reg5 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "0101" ) else 
	 slv_reg6 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "0110" ) else 
	 slv_reg7 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "0111" ) else 
	 slv_reg8 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "1000" ) else 
	 slv_reg9 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "1001" ) else 
	 slv_reg10 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "1010" ) else 
	 slv_reg11 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "1011" ) else 
	 (others => '0');

	-- Add user logic here

	-------------------------------------
	---- component instantiation
	-------------------------------------

	ila_1_i: ila_1
	port map (
		clk => out_clk,
		probe0 => probe0
	);

	controller_i: controller_top
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
	      init_calib_complete => open,
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

	-------------------------------------
	---- logic
	-------------------------------------

	-- copy config from registers
	ag1 <= slv_reg0(14 downto 0);
	ag2 <= slv_reg1(14 downto 0);
	victim <= slv_reg2(14 downto 0);
	n_act <= slv_reg3;
	-- active high reset, keep peripheral in reset state until config is done
	-- does not reset the memory controller
	-- when microcontroller writes 1 the device is started
	dev_rst <= not slv_reg4(1);
	data_pattern <= slv_reg4(4 downto 2);
	
	-- assert data_ack for 1ck when signaled by microncontroller
	DATA_ACK_1CK: process(out_clk)
	variable ack_done : BOOLEAN := false;
	begin
		if rising_edge(out_clk) then
			if sys_rst_n = '0' then
				data_ack <= '0';
				ack_done := false;
			elsif slv_reg4(0) = '1' and not ack_done then
				-- when cpu sets value, raise data_ack for 1 ck
				-- then don't set it until reg4(0) is set again to 1
				-- this needs to be done by the cpu otherwise i get 
				-- multiple driver issues during implementation
				data_ack <= '1';
				ack_done := true;
			else
				if slv_reg4(0) = '0' then
					ack_done := false;
				end if;
				data_ack <= '0';
			end if;
		end if;
	end process;
	

	-- write outputs of module to axi registers
	OUT_PROC : process( S_AXI_ACLK ) is
	begin
		if rising_edge(S_AXI_ACLK) then
			slv_reg5 <= data_read( 127 downto 96 );
			slv_reg6 <= data_read(  95 downto 64 );
			slv_reg7 <= data_read(  63 downto 32 );
			slv_reg8 <= data_read(  31 downto  0 );
			slv_reg9(31 downto 2) <= (others => '0');
			slv_reg9(1) <= status_reg(2); -- bit corresponds to 1 when is waiting for read
			slv_reg9(0) <= data_read_valid;
			slv_reg10(31 downto 16) <= (16 => sys_rst_n, others => '0');
			slv_reg10(15 downto 0) <= status_reg;
			slv_reg11(31 downto 29) <= (others => '0');
			slv_reg11(28 downto 0) <= curr_addr;
		end if;
	end process OUT_PROC;

	-- debugging step - add ila
	probe0 <= status_reg(13 downto 0) & 
			data_read_valid & 
			slv_reg4(0) &
			slv_reg9(1 downto 0);

	-- User logic ends

end arch_imp;
