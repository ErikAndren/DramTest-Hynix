-- Table that defines what register and data pairs to write to the OV7660 via
-- SCCB after startup. A delay is needed before writing the actual data
-- Also perform a register reset first of all in order to ensure that we know
-- what state we are writing. A simple FPGA flash might not reset the OV7660 firmware.
-- Copyright Erik Zachrisson - erik@zachrisson.info

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;

entity OV7660Init is
  port (
    Clk      : in  bit1;
    Rst_N    : in  bit1;
    --
    NextInst : in  bit1;
    --
    We       : out bit1;
    Start    : out bit1;
    AddrData : out word(16-1 downto 0);
    --
    InstPtr  : out word(4-1 downto 0)
    );
end entity;

architecture fpga of OV7660Init is
  constant BLUE  : word(8-1 downto 0) := x"01";
  constant RED   : word(8-1 downto 0) := x"02";  
  constant COM2  : word(8-1 downto 0) := x"09";
  constant AECH  : word(8-1 downto 0) := x"10";
  constant CLKRC : word(8-1 downto 0) := x"11";
  constant COM7  : word(8-1 downto 0) := x"12";
  constant COM8  : word(8-1 downto 0) := x"13";
  constant COM9  : word(8-1 downto 0) := x"14";
  constant COM10 : word(8-1 downto 0) := x"15";
  constant MVFP  : word(8-1 downto 0) := x"1e";
  constant TSLB  : word(8-1 downto 0) := x"3a";
  constant COM15 : word(8-1 downto 0) := x"40";
  -- Comment stolen from ov7660.c
  -- v-red, v-green, v-blue, u-red, u-green, u-blue
  -- They are nine-bit signed quantities, with the sign bit
  -- stored in 0x58.  Sign for v-red is bit 0, and up from there.
  
  constant MTX1  : word(8-1 downto 0) := x"4F";
  constant MTX2  : word(8-1 downto 0) := x"50";
  constant MTX3  : word(8-1 downto 0) := x"51";
  constant MTX4  : word(8-1 downto 0) := x"52";
  constant MTX5  : word(8-1 downto 0) := x"53";
  constant MTX6  : word(8-1 downto 0) := x"54";
  constant MTX7  : word(8-1 downto 0) := x"55";
  constant MTX8  : word(8-1 downto 0) := x"56";
  constant MTX9  : word(8-1 downto 0) := x"57";
  constant MTXS  : word(8-1 downto 0) := x"58";
  --
  constant MANU  : word(8-1 downto 0) := x"67";
  constant MANV  : word(8-1 downto 0) := x"68";

  constant NbrOfInst : positive := 1;

  signal InstPtr_N, InstPtr_D : word(4-1 downto 0);
  -- FIXME: Potentially listen for a number of vsync pulses instead. This would
  -- save a number of flops
  -- wait for 2**16 cycles * 40 ns = ~2 ms
  signal Delay_N, Delay_D     : word(16-1 downto 0);
begin
  SyncProc : process (Clk, Rst_N)
  begin
    if Rst_N = '0' then
      InstPtr_D <= (others => '0');

      if Simulation then
        Delay_D <= "1111111111111100";
      end if;

      if Synthesis then
        Delay_D <= (others => '0');
      end if;
    elsif rising_edge(Clk) then
      InstPtr_D <= InstPtr_N;
      Delay_D   <= Delay_N;
    end if;
  end process;

  ASyncProc : process (InstPtr_D, NextInst, Delay_D)
    variable InstPtr_T : word(4-1 downto 0);
  begin
    InstPtr_T := InstPtr_D;
    AddrData  <= (others => '0');
    We        <= '1';
    Start     <= '1';
    --
    Delay_N   <= Delay_D + 1;
    if (RedAnd(Delay_D) = '1') then
      Delay_N <= Delay_D;

      if (NextInst = '1') then
        InstPtr_T := InstPtr_D + 1;
      end if;

      case InstPtr_D is
        when "0000" =>
          AddrData <= COM7 & x"80";     -- SCCB Register reset

        when "0001" =>
          AddrData <= COM7 & x"80";     -- SCCB Register reset

        when "0010" =>
          AddrData <= COM7 & x"00";     -- SCCB Register reset

        when "0011" =>
          AddrData <= COM2 & x"00";     -- Enable 4x drive
 
        when "0100" =>
          AddrData <= MVFP & x"10";     -- Flip image to it mount

        when "0101" =>
          AddrData <= MTXS & x"0F";

        when "0110" =>
          -- Red?
          AddrData <= MTX1 & x"58";

        when "0111" =>
          -- Green, should decrease as coefficient sign is negative
          AddrData <= MTX2 & x"48";
          
        when "1000" =>
          -- Blue? Add blueness
          AddrData <= MTX3 & x"10";
                      
        when "1001" =>
          AddrData <= MTX4 & x"28";

        when "1010" =>
          -- Decrease green
          AddrData <= MTX5 & x"48";

        when "1011" =>
          AddrData <= MTX6 & x"70";

        when "1100" =>
          AddrData <= MTX7 & x"40";

        when "1101" =>
          AddrData <= MTX8 & x"40";

        when "1110" =>
          AddrData <= MTX9 & x"40";

        --when "0101" =>
        --  AddrData <= COM7 & x"04";     -- Enable RGB

        --when "0110" =>
        --  AddrData <= COM15 & x"F0";    -- Enable RGB555

        --when "1100" =>
        --  AddrData <= TSLB & x"04";          
          
        when others =>
          We        <= '0';
          Start     <= '0';
          --
          InstPtr_T := (others => '1');
          Start     <= '0';
          
      end case;
    end if;

    InstPtr_N <= InstPtr_T;
  end process;

  InstPtr <= InstPtr_D;
end architecture;
