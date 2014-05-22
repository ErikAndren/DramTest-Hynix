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
  signal G_N, G_D                       : word(5-1 downto 0);
  --
  signal R_Dithered                     : word(3-1 downto 0);
  signal G_Dithered                     : word(3-1 downto 0);
  signal B_Dithered                     : word(2-1 downto 0);
  signal R_DitheredVal                  : bit1;
  signal B_DitheredVal                  : bit1;
  
begin
  SycnRstProc : process (RstN, Clk)
  begin
    if RstN = '0' then
      ColorVal_D     <= '0';
      GrayScaleVal_D <= '0';

    elsif rising_edge(Clk) then
      ColorVal_D     <= ColorVal_N;
      GrayScaleVal_D <= GrayScaleVal_N;

    end if;
  end process;
  
  SyncNoRstProc : process (Clk)
  begin
    if rising_edge(Clk) then
      Cnt_D <= Cnt_N;
      R_D   <= R_N;
      B_D   <= B_N;
      G_D   <= G_N;
    end if;
  end process;

  AsyncProc : process (Cnt_D, Vsync, PixelInVal, PixelIn, R_D, B_D, G_D)
  begin
    Cnt_N          <= Cnt_D;
    GrayScaleVal_N <= '0';
    ColorVal_N     <= '0';
    R_N            <= R_D;
    B_N            <= B_D;
    G_N            <= G_D;

    if PixelInVal = '1' then
      Cnt_N <= Cnt_D + 1;

      if conv_integer(Cnt_D) = 0 then
        R_N(5-1 downto 0) <= PixelIn(8-1 downto 3);
        G_N(5-1 downto 3) <= PixelIn(2-1 downto 0);
      end if;

      if conv_integer(Cnt_D) = 1 then
        G_N(3-1 downto 0) <= PixelIn(8-1 downto 5);
        B_N(5-1 downto 0) <= PixelIn(5-1 downto 0);
        GrayScaleVal_N <= '1';
        ColorVal_N <= '1';
      end if;
    end if;

    if Vsync = '1' then
      Cnt_N <= (others => '0');
    end if;
  end process;

  -- Lightness RGB to grayscale method
  -- (max(R, G, B) + min(R, G, B)) / 2.
  --GrayscaleGen : process (R_D, G_D, B_D)
  --  variable ColMax, ColMin : word(G_D'length-1 downto 0);
  --begin
  --  ColMax       := maxval(R_D & '0', G_D);
  --  ColMax       := maxval(ColMax, B_D & '0');
  --  --
  --  ColMin       := minval(R_D & '0', G_D);
  --  ColMin       := minval(ColMin, B_D & '0');
  --  --
  --  GrayScaleOut <= conv_word((conv_integer(ColMax) + conv_integer(ColMin)) / 2, GrayScaleOut'length);
  --end process; 

  RedDither : entity work.DitherFloydSteinberg
    generic map (
      DataW     => 5,
      CompDataW => 3
      )
    port map (
      RstN        => RstN,
      Clk         => Clk,
      --
      Vsync       => Vsync,
      --
      PixelIn     => R_D,
      PixelInVal  => ColorVal_D,
      --
      PixelOut    => R_Dithered,
      PixelOutVal => R_DitheredVal
      );
  
  GreenDither : entity work.DitherFloydSteinberg
    generic map (
      DataW     => 5,
      CompDataW => 3
      )
    port map (
      RstN        => RstN,
      Clk         => Clk,
      --
      Vsync       => Vsync,
      --
      PixelIn     => G_D,
      PixelInVal  => ColorVal_D,
      --
      PixelOut    => G_Dithered,
      PixelOutVal => open
      );

  BlueDither : entity work.DitherFloydSteinberg
    generic map (
      DataW     => 5,
      CompDataW => 2
      )
    port map (
      RstN        => RstN,
      Clk         => Clk,
      --
      Vsync       => Vsync,
      --
      PixelIn     => B_D,
      PixelInVal  => ColorVal_D,
      --
      PixelOut    => B_Dithered,
      PixelOutVal => B_DitheredVal
      );
  
  RedFeed   : Color(RedHigh downto RedLow)     <= R_Dithered;
  GreenFeed : Color(GreenHigh downto GreenLow) <= G_Dithered;
  BlueFeed  : Color(BlueHigh downto BlueLow)   <= B_Dithered;

  GrayScaleOutValFeed : GrayScaleOutVal <= GrayScaleVal_D;
  --
  ColorOutValFeed     : ColorOutVal     <= B_DitheredVal;
  
end architecture rtl;
