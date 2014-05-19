-- Extract the different types of signals in the incoming data stream.
-- Current implementation extracts the luminance from the incoming YUV encoded
-- signal.
-- Copyright Erik Zachrisson, erik@zachrisson.info 2014

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

entity PixelAligner is
  generic (
    DataInW  : positive := 8;
    DataOutW : positive := 8
    );
  port (
    RstN            : in  bit1;
    Clk             : in  bit1;
    --
    Vsync           : in  bit1;
    PixelInVal      : in  bit1;
    PixelIn         : in  word(DataInW-1 downto 0);
    --
    GrayScaleOutVal : out bit1;
    GrayScaleOut    : out word(DataOutW-1 downto 0);
    --
    Color           : out word(DataOutW-1 downto 0);
    ColorOutVal     : out bit1
    );
end entity;

architecture rtl of PixelAligner is
  signal Cnt_N, Cnt_D                   : word(1-1 downto 0);
  signal GrayScaleVal_N, GrayScaleVal_D : bit1;
  signal ColorVal_N, ColorVal_D         : bit1;
  signal R_N, R_D, B_N, B_D             : word(5-1 downto 0);
  signal G_N, G_D                       : word(6-1 downto 0);
  

begin
  SyncNoRstProc : process (Clk)
  begin
    if rising_edge(Clk) then
      Cnt_D          <= Cnt_N;
      GrayScaleVal_D <= GrayScaleVal_N;
      ColorVal_D     <= ColorVal_N;
      R_D <= R_N;
      B_D <= B_N;
      G_D <= G_N;
      
    end if;
  end process;

  AsyncProc : process (Cnt_D, Vsync, PixelInVal, PixelIn, R_D, B_D, G_D)
  begin
    Cnt_N          <= Cnt_D;
    GrayScaleVal_N <= '0';
    ColorVal_N     <= '0';
    R_N <= R_D;
    B_N <= B_D;
    G_N <= G_D;

    if PixelInVal = '1' then
      Cnt_N <= Cnt_D + 1;

      if Cnt_D = 0 then
        R_N(5-1 downto 0) <= PixelIn(8-1 downto 3);
        G_N(6-1 downto 3) <= PixelIn(3-1 downto 0);
      end if;

      if Cnt_D = 1 then
        G_N(3-1 downto 0) <= PixelIn(8-1 downto 5);
        B_N(5-1 downto 0) <= PixelIn(5-1 downto 0);
        ColorVal_N <= '1';
        GrayScaleVal_N <= '1';
      end if;
    end if;

    if Vsync = '1' then
      Cnt_N <= (others => '0');
    end if;
  end process;
  

  GrayScaleOutValFeed : GrayScaleOutVal <= GrayScaleVal_D;
  -- FIXME: Improve
  GrayScaleOutFeed    : GrayScaleOut    <= conv_word((conv_integer(R_D & '0') + conv_integer(G_D) + conv_integer(B_D & '0') / 3), GrayScaleOut'length);
  --
  ColorOutValFeed     : ColorOutVal     <= ColorVal_D;

  RedFeed   : Color(RedHigh downto RedLow)     <= R_D(R_D'high downto R_D'high-2);
  GreenFeed : Color(GreenHigh downto GreenLow) <= G_D(G_D'high downto G_D'high-2);
  BlueFeed  : Color(BlueHigh downto BlueLow)   <= B_D(B_D'high downto B_D'high-1);
  
--  ColorOutFeed        : ColorOut        <= B_D(B_D'high downto B_D'high-1) & G_D(G_D'high downto G_D'high-2) & R_D(R_D'high downto R_D'high-2);

end architecture rtl;
