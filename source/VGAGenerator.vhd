-- Generates the vga signal for a 640x480@60Hz signal
-- Copyright 2014 Erik Zachrisson - erik@zachrisson.info
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.VgaPack.all;
use work.DramTestPack.all;

entity VGAGenerator is
  generic (
    DataW     : positive := 3;
    ColResW   : positive := 3;
    DivideClk : boolean  := true
    );
  port (
    Clk            : in  bit1;
    RstN           : in  bit1;
    --
    PixelToDisplay : in  word(DataW-1 downto 0);
    DrawRect       : in  bit1;
    InView         : out bit1;
    --
    ColorEn        : in  bit1;
    --
    Red            : out word(ColResW-1 downto 0);
    Green          : out word(ColResW-1 downto 0);
    Blue           : out word(ColResW-1 downto 0);
    HSyncN         : out bit1;
    VSyncN         : out bit1
    );
end entity;

architecture rtl of VGAGenerator is
  signal PixelClk : bit1;

  signal hCount     : word(bits(HPixelEnd)-1 downto 0);
  signal vCount     : word(bits(VLineEnd)-1 downto 0);
  signal HCountOvfl : bit1;
  signal VCountOvfl : bit1;
  --
  signal InView_i   : bit1;
  
begin
  DivClkGen : if DivideClk = true generate
    ClkDiv : process (RstN, Clk)
    begin
      if RstN = '0' then
        PixelClk <= '0';
      elsif rising_edge(Clk) then
        PixelClk <= not PixelClk;
      end if;
    end process;
  end generate;

  NoDivClkGen : if DivideClk = false generate
    PixelClk <= Clk;
  end generate;

  HCountOvfl <= '1' when hcount = HPixelEnd else '0';
  HCnt : process (RstN, PixelClk)
  begin
    if RstN = '0' then
      hcount <= (others => '0');
    elsif rising_edge(PixelClk) then
      
      if (HCountOvfl = '1') then
        hcount <= (others => '0');
      else
        hcount <= hcount + 1;
      end if;
    end if;
  end process;

  VCountOvfl <= '1' when vcount = VLineEnd else '0';
  VCnt : process (RstN, PixelClk)
  begin
    if RstN = '0' then
      vcount <= (others => '0');
    elsif rising_edge(PixelClk) then
      if (HCountOvfl = '1') then
        if (VCountOvfl = '1') then
          vcount <= (others => '0');
        else
          vcount <= vcount + 1;
        end if;
      end if;
    end if;
  end process;

  InViewCalc : process (hcount, vcount)
  begin
    InView_i <= '0';

    if ((hcount >= HDatBegin) and (hcount < HDatEnd)) and ((vcount >= VDatBegin) and (vcount < VDatEnd)) then
      InView_i <= '1';
    end if;
  end process;
  
  InView   <= InView_i;
  
  HsyncN <= '1' when hcount > HSyncEnd else '0';
  VsyncN <= '1' when vcount > VSyncEnd else '0';

  DrawColorProc : process (PixelToDisplay, DrawRect, InView_i, ColorEn)
  begin
    Red   <= (others => '0');
    Green <= (others => '0');
    Blue  <= (others => '0');

    if InView_i = '1' then
      if ColorEn = '1' then
        Red   <= PixelToDisplay(RedHigh downto RedLow);
        Green <= PixelToDisplay(GreenHigh downto GreenLow);
        Blue  <= PixelToDisplay(BlueHigh downto BlueLow) & '0';
      else
        Red   <= PixelToDisplay(3-1 downto 0);
        Green <= PixelToDisplay(3-1 downto 0);
        Blue  <= PixelToDisplay(3-1 downto 0);
      end if;

     -- Draw green rectangle overlay
      if DrawRect = '1' then
        Green <= (others => '1');
      end if;
    end if;
  end process;  
end architecture rtl;
