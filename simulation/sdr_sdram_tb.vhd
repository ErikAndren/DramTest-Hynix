--###############################################################################
--
--  LOGIC CORE:          SDR SDRAM Controller test bench							
--  MODULE NAME:         sdr_sdram_tb()
--  COMPANY:             Altera Corporation
--                       www.altera.com	
--
--  REVISION HISTORY:  
--
--    Revision 1.0  06/06/2000	Description: Initial Release.
--    Revision 1.1  07/12/2000  Modified to support burst terminate and precharge
--                              during full page accesses.
--
--  FUNCTIONAL DESCRIPTION:
--
--  This module is the test bench for the SDR SDRAM controller.
--
--  Copyright (C) 1991-2000 Altera Corporation
--
--##############################################################################
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

--library arithmetic;
--use arithmetic.std_logic_arith.all;


entity sdr_sdram_tb is
    generic (
         ASIZE          : integer := 23;
         DSIZE          : integer := 32;
         ROWSIZE        : integer := 12;
         COLSIZE        : integer := 9;
         BANKSIZE       : integer := 2;
         ROWSTART       : integer := 9;
         COLSTART       : integer := 0;
         BANKSTART      : integer := 20
    );
end sdr_sdram_tb;

architecture rtl of sdr_sdram_tb is

component sdr_sdram
	port (
         CLK            : in      std_logic;                                   --System Clock
         RESET_N        : in      std_logic;                                   --System Reset
         ADDR           : in      std_logic_vector(ASIZE-1 downto 0);          --Address for controller requests
         CMD            : in      std_logic_vector(2 downto 0);                --Controller command 
         CMDACK         : out     std_logic;                                   --Controller command acknowledgement
         DATAIN         : in      std_logic_vector(DSIZE-1 downto 0);          --Data input
         DATAOUT        : out     std_logic_vector(DSIZE-1 downto 0);          --Data output
         DM             : in      std_logic_vector(DSIZE/8-1 downto 0);        --Data mask input
         SA             : out     std_logic_vector(11 downto 0);               --SDRAM address output
         BA             : out     std_logic_vector(1 downto 0);                --SDRAM bank address
         CS_N           : out     std_logic_vector(1 downto 0);                --SDRAM Chip Selects
         CKE            : out     std_logic;                                   --SDRAM clock enable
         RAS_N          : out     std_logic;                                   --SDRAM Row address Strobe
         CAS_N          : out     std_logic;                                   --SDRAM Column address Strobe
         WE_N           : out     std_logic;                                   --SDRAM write enable
         DQ             : inout   std_logic_vector(DSIZE-1 downto 0);          --SDRAM data bus
         DQM            : out     std_logic_vector(DSIZE/8-1 downto 0)         --SDRAM data mask lines
  	);
end component;

component mt48lc8m16a2
   PORT (
        Dq    : INOUT STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => 'Z');
        Addr  : IN    STD_LOGIC_VECTOR (11 DOWNTO 0) := (OTHERS => '0');
        Ba    : IN    STD_LOGIC_VECTOR := "00";
        Clk   : IN    STD_LOGIC := '0';
        Cke   : IN    STD_LOGIC := '0';
        Cs_n  : IN    STD_LOGIC := '1';
        Ras_n : IN    STD_LOGIC := '0';
        Cas_n : IN    STD_LOGIC := '0';
        We_n  : IN    STD_LOGIC := '0';
        Dqm   : IN    STD_LOGIC_VECTOR (1 DOWNTO 0) := (OTHERS => '0')
    );
END component;


signal   clk            : std_logic := '0';
signal   clk2           : std_logic := '0';
signal   reset_n        : std_logic;
signal   sa             : std_logic_vector(11 downto 0);
signal   ba             : std_logic_vector(1 downto 0);
signal   cs_n           : std_logic_vector(1 downto 0);
signal   cke            : std_logic;
signal   ras_n          : std_logic;
signal   cas_n          : std_logic;
signal   we_n           : std_logic;
signal   cmd            : std_logic_vector(2 downto 0);
signal   cmdack         : std_logic;
signal   addr           : std_logic_vector(ASIZE-1 downto 0);
signal   datain         : std_logic_vector(DSIZE-1 downto 0);
signal   dataout        : std_logic_vector(DSIZE-1 downto 0);
signal   dm             : std_logic_vector(DSIZE/8-1 downto 0);
signal   dq             : std_logic_vector(DSIZE-1 downto 0);
signal   dqm            : std_logic_vector(DSIZE/8-1 downto 0);

signal   test_addr      : std_logic_vector(ASIZE-1 downto 0);
signal   test_data      : std_logic_vector(DSIZE-1 downto 0);
signal   y              : std_logic_vector(2 downto 0);
signal   z              : std_logic_vector(1 downto 0);




--       write_burst(start_data, start_addr, bl, rcd, mask, addr, dataout, dqm, cmdack, cmd)
--
--       This task performs a write access of size BL 
--       at SDRAM address to the SDRAM controller
--
--       start_data     :    Starting value for the burst write sequence.  The write burst procedure
--                           simply increments the data values from the start_data value.   
--       start_addr     : 	Address in SDRAM to start the burst access
--       bl             :    bl is the burst length the sdram devices have been configured for.
--       rcd            :    rcd value that was set during configuration
--       mask           :    Byte data mask for all cycles in the burst.
--       addr           :    Address output
--       dataout        :    Data output
--       dqm            :    data mask output
--       cmdack         :    Command ack input
--       cmd            :    Command output

  procedure burst_write (
                         start_data: std_logic_vector(DSIZE-1 downto 0);
                         start_addr: std_logic_vector(ASIZE-1 downto 0);
                         bl : integer;
                         rcd : integer;
                         mask : std_logic_vector(DSIZE/8-1 downto 0);
                         signal addr: out std_logic_vector(ASIZE-1 downto 0);
                         signal dataout: out std_logic_vector(DSIZE-1 downto 0);
                         signal dqm: out std_logic_vector(DSIZE/8-1 downto 0);
                         signal cmdack: std_logic;
                         signal cmd: out std_logic_vector(2 downto 0)) is
                         
    variable i : integer;
    
    begin
			wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              cmd <= "010";                                                    -- issued a WRITEA command
              addr <= start_addr; 
              dataout <= start_data;                                           -- issue the first data value                    
              dqm <= mask;
              wait until (cmdack = '1');                                       -- wait for a ack from the controller
			wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              cmd <= "000";                                                    -- NOP the commmand input
             
              for i in 1 to rcd-2 loop                                         -- wait for RAS to CAS to expire
			     wait until (CLK'event and CLK = '1');
                   wait for 1 ns;
              end loop;
              
              for  i in 1 to bl loop                                            -- loop from 1 to bl
                   dataout <= start_data + i;                                   -- clock the data into the controller
			     wait until (CLK'event and CLK = '1');
                   wait for 1 ns;
              end loop;
                            
              dqm <= "0000";
  end burst_write;




--       burst_read(address, start_value, CL, RCD, BL)
--
--       This task performs a read access of size BL 
--       at SDRAM address to the SDRAM controller
--
--       start_data     :    Starting value for the burst read sequence.  The read burst task
--                           simply increments and compares the data values from the start_value.    
--       start_addr     :    Address in SDRAM to start the burst access.
--       bl             :    bl is the burst length the sdram devices have been configured for.
--       cl             :    CAS latency the sdram devices have been configured for.
--       rcd            :    rcd value the controller has been configured for.
--       addr           :    Address output
--       datain         :    Data input
--       cmdack         :    Command ack input
--       cmd            :    Command output
                             

   procedure burst_read (
                         start_data: std_logic_vector(DSIZE-1 downto 0);
                         start_addr: std_logic_vector(ASIZE-1 downto 0);
                         bl : integer;
                         cl : integer;
                         rcd : integer;
                         signal addr: out std_logic_vector(ASIZE-1 downto 0);
                         signal datain: std_logic_vector(DSIZE-1 downto 0);
                         signal cmdack: std_logic;
                         signal cmd: out std_logic_vector(2 downto 0)) is
    
    variable i: std_logic_vector(3 downto 0) := "0000";
    
    begin
			wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              cmd <= "001";                                                    -- issue a READA command
              addr <= start_addr;                     
              wait until (cmdack = '1');                                       -- wait for command ack
			wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              cmd <= "000";                                                    -- NOP the command input
 
              for i in 1 to (cl+rcd+1) loop                                    -- wait for RAS to CAS and cl to expire
			     wait until (CLK'event and CLK = '1');
              end loop;
              
              for i in 1 to bl loop                                            -- loop from 1 to burst length(BL), 
                wait until (CLK'event and CLK = '1');                          -- collecting and comparing the data
 --               wait for 3 ns;
                        if (datain /= start_data + i - 1 ) then
                            assert false
                            REPORT "read data mis-match"
                            SEVERITY FAILURE;
                        end if;
              end loop;	
         
    
  end burst_read;



--       page_write_burst(address, start_value, data_mask, RCD, len, dataout, addr, dqm, cmd, cmdack)
--       
--       This task performs a page write burst access of size length 
--       at SDRAM address to the SDRAM controller
--
--       address        : 	Address in SDRAM to start the burst access
--       start_value    :    Starting value for the burst write sequence.  The write burst task
--                             simply increments the data values from the start_value.
--       data_mask      :    Byte data mask for all cycles in the burst.
--       rcd            :    RCD value that was set during configuration
--       len            :    burst length of the access.
--       dataout        :    data output
--       addr           :    address output
--       dqm            :    data mask output
--       cmd            :    command output
--       cmdack         :    comand ack input   


  procedure   page_write_burst(
	               address             : std_logic_vector(ASIZE-1 downto 0);
                   start_value         : std_logic_vector(DSIZE-1  downto 0);
                   data_mask           : std_logic_vector(DSIZE/8-1 downto 0);
                   rcd                 : integer;
                   len                 : integer;
                   signal dataout      : out std_logic_vector(DSIZE-1 downto 0);
                   signal addr         : out std_logic_vector(ASIZE-1 downto 0);
                   signal dqm          : out std_logic_vector(DSIZE/8-1 downto 0);
                   signal cmd          : out std_logic_vector(2 downto 0);
                   signal cmdack       : std_logic
              ) is

         variable i : integer;

         begin
              wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              addr <= address;
              cmd  <= "010";
              dataout <= start_value;
              dqm     <= data_mask;
              wait until (cmdack = '1');                                       -- wait for command ack
			wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              cmd  <= "000";
                
              for i in 1 to rcd-2 loop                                         -- wait for rcd to pass 
			     wait until (CLK'event and CLK = '1');
              end loop;
              wait for 1 ns;

              for i in 1 to len-3 loop                                         -- burst out len data cycles 
                   dataout <= start_value + i;
			     wait until (CLK'event and CLK = '1');
                   wait for 1 ns;
              end loop;
              dataout <= start_value + len-2;                                  --keep incrementing the data value
              cmd <= "100";                                                    -- issue a terminate command to terminate the page burst                         
			wait until (CLK'event and CLK = '1');
              wait for 1 ns;

              dataout <= start_value + len-1;                                  --increment the data one more
                   
              wait until (cmdack = '1');                                       -- Wait for the controller to ack the command   
			wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              cmd <= "000";                                                    -- Clear the command by issuing a NOP
                
              dqm <= "0000";	
              
              wait for 200 ns;
              cmd <= "100";                                     -- close the bank with a precharge
              wait until (cmdack = '1');
              wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              cmd <= "000"; 
                                     
              
              
  end page_write_burst;





--       page_read_burst(address, start_value, cl, rcd, len, addr, datain, cmd, cmdack)
--
--       This task performs a page read access of size length 
--       at SDRAM address to the SDRAM controller
--
--       address        :         Address in SDRAM to start the burst access
--       start_value    :         Starting value for the burst read sequence.  The read burst task
--                                     simply increments and compares the data values from the start_value.
--       cl             :         CAS latency the sdram devices have been configured for.
--       rcd            :         rcd value the controller has been configured for.
--       len            :         burst length of the access.
--       addr           :         address output.
--       datain         :         data input;
--       cmd            :         command output;
--       cmdack         :         command ack;



procedure    page_read_burst(
	                         address   : std_logic_vector(ASIZE-1 downto 0);
                             start_value : std_logic_vector(DSIZE-1 downto 0);
                             cl   : integer;
                             rcd : integer;
                             len : integer;
                             signal addr : out std_logic_vector(ASIZE-1 downto 0);
                             signal datain : std_logic_vector(DSIZE-1 downto 0);
                             signal cmd    : out std_logic_vector(2 downto 0);
                             signal cmdack : std_logic
                             ) is
                           
        variable i : integer;
        
        begin
              wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              addr  <= address;
              cmd   <= "001";                                   -- issue a read command to the controller
              wait until (cmdack = '1');                        -- wait for the controller to ack
			wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              cmd <= "000";                                     -- NOP on the command input
              
              for i in 1 to (CL+RCD) loop                     -- Wait for activate and cas latency delays
			     wait until (CLK'event and CLK = '1');
              end loop;
              
              for i in 1 to len loop                            -- loop and collect the data
                   wait until (CLK'event and CLK = '1');
                   wait for 3 ns;
                   
                        if (i = (len-cl-5)) then
                              cmd <= "100";                     -- Terminate the page burst
                        end if;
                         
                        if (cmdack = '1') then
                             cmd<="000";                        -- end the precharge command once the controller has ack'd
                        end if;
                        
                        if (datain /= start_value + i - 1 ) then
                            assert false
                            REPORT "read data mis-match"
                            SEVERITY FAILURE;
                        end if;
              end loop;	

              wait for 200 ns;
              
              cmd <= "100";                                     -- close the bank with a precharge
              wait until (cmdack = '1');
              wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              
              cmd <= "000";                        
end page_read_burst;






--      config(cl, rc, bl, pm, ref)
--
--      This task cofigures the SDRAM devices and the controller 
--
--      cl         :       Cas latency, 2 or 3
--      rc         :       Ras to Cas delay.
--      bl         :       Burst length 1,2,4, or 8
--      pm         :       page mode setting
--      ref        :       refresh period setting

   procedure config (    cl: std_logic_vector(2 downto 0);
                         rc: std_logic_vector(1 downto 0);
                         bl: integer;
                         pm: std_logic;
                         ref: std_logic_vector(15 downto 0);
                         signal addr: out std_logic_vector(ASIZE-1 downto 0);
                         signal cmdack: std_logic;
                         signal cmd: out std_logic_vector(2 downto 0)) is
 
    
    begin
              addr <= (others => '0');
			wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              
              cmd <= "100";                         
              wait until (cmdack = '1');
              wait until (CLK'event and CLK = '1');        -- Wait for the controller to ack the command   
              wait for 1 ns;
              cmd <= "000";                                -- Clear the command by issuing a NOP

              if (bl = 1) then
                      addr(2 downto 0) <= "000";           -- Set the Burst length portion of the mode data
              elsif (bl = 2) then
                      addr(2 downto 0) <= "001";
              elsif (bl = 4) then
                      addr(2 downto 0) <= "010";
              elsif (bl = 8) then
                      addr(2 downto 0) <= "011";
              elsif (bl = 0) then
                      addr(2 downto 0) <= "111";           -- full page burst configuration value for bl
              end if;
                        
              addr(6 downto 4) <= cl;
               
              cmd <= "101";
              wait until (cmdack = '1');                   -- Wait for the controller to ack the command
			wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              cmd <= "000";                                -- Clear the command by issuing a NOP

			wait until (CLK'event and CLK = '1');
			wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              addr(15 downto 0) <= ref;
              cmd  <= "111";                               -- load refresh counter
              wait until (cmdack = '1');                   -- Wait for the controller to ack the command
			wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              cmd <= "000";                                -- Clear the command by issuing a NOP
 
 
              addr(1 downto 0) <= cl(1 downto 0);          -- load contorller reg1
              addr(3 downto 2) <= rc;
              addr(8) <= pm;
              if (bl = 1) then
                      addr(12 downto 9) <= "0001";         -- Set the Burst length portion of the mode data
              elsif (bl = 2) then
                      addr(12 downto 9) <= "0010";
              elsif (bl = 4) then
                      addr(12 downto 9) <= "0100";
              elsif (bl = 8) then
                      addr(12 downto 9) <= "1000";
              elsif (bl = 0) then
                      addr(12 downto 9) <= "1000";         -- full page burst configuration value for bl
              end if;

              cmd  <= "110";
              wait until (cmdack = '1');                   -- Wait for the controller to ack the command
			wait until (CLK'event and CLK = '1');
              wait for 1 ns;
              cmd <= "000";                                -- Clear the command by issuing a NOP
 
         
    
  end config;

begin

	-- The SDRAM Controller
	
    sdr: sdr_sdram 
         port map (

              CLK       =>   clk,   
              RESET_N   =>   reset_n, 
              ADDR      =>   addr,    
              CMD       =>   cmd,  
              CMDACK    =>   cmdack,  
              DATAIN    =>   datain, 
              DATAOUT   =>   dataout, 
              DM        =>   dm,      
              SA        =>   sa,      
              BA        =>   ba,      
              CS_N      =>   cs_n,    
              CKE       =>   cke,     
              RAS_N     =>   ras_n,  
              CAS_N     =>   cas_n,   
              WE_N      =>   we_n,    
              DQ        =>   dq,      
              DQM       =>   dqm     
 		);

	-- The SDRAMs

	B00: mt48lc8m16a2
		port map(
			Dq        =>   dq(15 downto 0),
			Addr      =>   sa(11 downto 0),
			Ba        =>   ba,
			CLK       =>   clk2,
			Cke       =>   cke,
			Cs_n      =>   cs_n(0),
			Cas_n     =>   cas_n,
			Ras_n     =>   ras_n,
			We_n      =>   we_n,
			Dqm       =>   dqm(1 downto 0)
		);

	B01: mt48lc8m16a2
		port map(
			Dq        =>   dq(31 downto 16),
			Addr      =>   sa(11 downto 0),
			Ba        =>   ba,
			CLK       =>   clk2,
			Cke       =>   cke,
			Cs_n      =>   cs_n(0),
			Cas_n     =>   cas_n,
			Ras_n     =>   ras_n,
			We_n	     =>	we_n,
			Dqm		=>   dqm(3 downto 2)
		);

	B10: mt48lc8m16a2
		port map(
			Dq        =>   dq(15 downto 0),
			Addr      =>   sa(11 downto 0),
			Ba        =>   ba,
			CLK       =>   clk2,
			Cke       =>   cke,
			Cs_n      =>   cs_n(1),
			Cas_n     =>   cas_n,
			Ras_n     =>   ras_n,
			We_n      =>   we_n,
			Dqm       =>   dqm(1 downto 0)
		);

	B11: mt48lc8m16a2
		port map(
			Dq        =>   dq(31 downto 16),
			Addr      =>   sa(11 downto 0),
			Ba        =>   ba,
			CLK       =>   clk2,
			Cke       =>   cke,
			Cs_n      =>   cs_n(1),
			Cas_n     =>   cas_n,
			Ras_n     =>   ras_n,
			We_n	     =>	we_n,
			Dqm		=>   dqm(3 downto 2)
		);



	-- Generate the clocks
-- clocks for 133mhz operation
	process
		begin
			clk <= '0';
 			wait for 3750 ps;
  			clk <= '1';
			wait for 3750 ps;
	end process;

 process
    begin
   
         clk2 <= '0';
         wait for 2750 ps;
         clk2 <= '1';
         wait for 3750 ps;
         clk2 <= '0';
         wait for 1000 ps;
 end process;
	
 -- clocks for 100mhz operations
--	process
--		begin
--			clk <= '0';
-- 			wait for 5000 ps;
--  			clk <= '1';
--			wait for 5000 ps;
--	end process;

-- process
--    begin
   
--         clk2 <= '0';
--         wait for 4000 ps;
--         clk2 <= '1';
--         wait for 5000 ps;
--         clk2 <= '0';
--         wait for 1000 ps;
-- end process;
process
    
 variable x         : integer := 0;
 variable j         : integer := 0;
 variable yi        : integer := 0;
 variable bl        : integer := 0;
 variable zi        : integer := 0;
    
    
  begin
  reset_n <= '0';
  wait for 100 ns;
  reset_n <= '1';
    
  wait for 200 ns;
 
  report "Testing page burst accesses";
  config("011", "11", 0, '1', x"05F6", addr, cmdack, cmd);
  wait for 1000 ns;

  report "Writing a ramp value from 0-29 out to sdram at address 0x0";
  page_write_burst("00000000000000000000000", x"00000000", x"0", 3, 30, datain, addr, dm, cmd, cmdack);
  wait for 1000 ns;

  report "Reading the ramp value from sdram at address 0x0";
  page_read_burst("00000000000000000000000", x"00000000", 3, 3, 30, addr, dataout, cmd, cmdack);
  wait for 1000 ns;


  report "Testing data mask inputs";
  config("011", "11", 8, '0', x"05F6", addr, cmdack, cmd);
  wait for 1000 ns;
  
  report "writing pattern 0,1,2,3,4,5,6,7 to sdram at address 0x0";
  burst_write(x"00000000", "00000000000000000000000", 8, 3, x"0", addr, datain, dm, cmdack, cmd);
  wait for 1000 ns;
    
  report "Reading and verifing the pattern 0,1,2,3,4,5,6,7 at sdram address 0x0";
  burst_read(x"00000000", "00000000000000000000000", 8, 3, 3, addr, dataout, cmdack, cmd);
  wait for 1000 ns;
  
  report "Writing pattern 0xfffffff0, 0xfffffff1, 0xfffffff2, 0xfffffff3, 0xfffffff4, 0xfffffff5, 0xfffffff6, 0xfffffff7";
  report "with DM set to 0xf";
  burst_write(x"FFFFFFF0", "00000000000000000000000", 8, 3, x"f", addr, datain, dm, cmdack, cmd);
  wait for 1000 ns;
  
  report "Reading and verifing that the pattern at sdram address 0x0 is";
  report "still 0,1,2,3,4,5,6,7";
  burst_read(x"00000000", "00000000000000000000000", 8, 3, 3, addr, dataout, cmdack, cmd);
  wait for 1000 ns;
  
  report "End of data mask test";
  
  
  report "running data pattern tests";
  bl := 1;
  for x in 1 to 4 loop                           -- step through the four burst lengths 1,2,4,8
  y <= "011";
  z <= "11";
    for yi in 3 to 3 loop                         -- at 133mhz cl must be 3,  if 100mhz cl can be 2
      for zi in 3 to 3 loop                       -- at 133mhz rc must be 3, if 100mhz rc can be 2
         config(y, z, bl, '0', x"05F6", addr, cmdack, cmd);
                

-- perform 1024 burst writes to the first chip select, writing a ramp pattern
        report "Peforming burst write to first sdram bank";
        test_data <= (others => '0');
        test_addr <= (others => '0');
        for j in 0 to 1024 loop
        
                burst_write(test_data, test_addr, bl, zi, x"0", addr, datain, dm, cmdack, cmd);
                test_data <= test_data + bl;
                test_addr <= test_addr + bl;
                wait for 100 ns;
        end loop;
        

-- perform 1024 burst reads to the first chip select, verifing the ramp pattern
        report "Performing burst read, verify ramp values in first sdram bank";
        test_data <= (others => '0');
        test_addr <= (others => '0');
        for j in 0 to 1024 loop
                burst_read(test_data, test_addr, bl, yi, zi, addr, dataout, cmdack, cmd);
                test_data <= test_data + bl;
                test_addr <= test_addr + bl;
        end loop;
        
        wait for 500 ns;

-- perform 1024 burst writes to the second chip select, writing a ramp pattern
        report "Peforming burst write to second sdram bank";
        test_data <= x"00400000";
        test_addr <= "10000000000000000000000";
        for j in 0 to 1024 loop
                burst_write(test_data, test_addr, bl, zi, x"0", addr, datain, dm, cmdack, cmd);
                test_data <= test_data + bl;
                test_addr <= test_addr + bl;
                wait for 100 ns;
        end loop;
        
-- perform 1024 burst reads to the second chip select, verifing the ramp pattern
        report "Performing burst read, verify ramp values in second sdram bank";
        test_data <= x"00400000";
        test_addr <= "10000000000000000000000";
        for j in 0 to 1024 loop
                burst_read(test_data, test_addr, bl, yi, zi, addr, dataout, cmdack, cmd);
                test_data <= test_data + bl;
                test_addr <= test_addr + bl;
        end loop;
        
        wait for 500 ns;

        report "Test complete";
        z <= z+1;
      end loop;
    y<=y+1;
    end loop;
    bl := bl * 2;
	
  end loop;	
assert false report "all tests complete" severity failure;

  
  
         

    end process;
    
    
         

end rtl;

