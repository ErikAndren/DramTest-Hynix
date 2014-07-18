-- Wrapper file to include the full pipe line
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;
use work.VgaPack.all;
use work.SerialPack.all;

entity FilterChain is
  generic (
    DataW     : positive;
    CompDataW : positive
    );
  port (
    Clk         : in  bit1;
    RstN        : in  bit1;
    --
    Vsync       : in  bit1;
    --
    ToggleMode  : in  bit1;
    --
    RegAccessIn : in RegAccessRec;
    --
    PixelIn     : in  word(DataW-1 downto 0);
    PixelInVal  : in  bit1;
    --
    PixelOut    : out word(CompDataW-1 downto 0);
    PixelOutVal : out bit1
    );
end entity;

architecture rtl of FilterChain is
  constant Res                                    : positive := 3;
  signal PixelArray, PixelArrayToConvFilter       : PixVec2D(Res-1 downto 0);
  signal PixelArrayVal, PixelArrayToConvFilterVal : bit1;
  signal PixelFromSobel                           : word(CompDataW-1 downto 0);
  signal PixelFromSobelVal                        : bit1;
  signal PixelFromDither                          : word(CompDataW-1 downto 0);
  signal PixelFromDitherVal                       : bit1;
  signal PixelFromMedian                          : word(DataW-1 downto 0);
  signal PixelFromMedianVal                       : bit1;
  signal RdAddr                                   : word(VgaWidthW-1 downto 0);
  --
  signal FilterSel_N, FilterSel_D                 : word(MODESW-1 downto 0);
begin
  MedianFilterB : block
  begin
    LS : entity work.LineSampler
      generic map (
        DataW   => DataW,
        Buffers => 4,
        OutRes  => Res
        )
      port map (
        Clk         => Clk,
        RstN        => RstN,
        --
        Vsync       => Vsync,
        --
        PixelIn     => PixelIn,
        PixelInVal  => PixelInVal,
        --
        PixelOut    => PixelArray,
        PixelOutVal => PixelArrayVal
        );

    MF : entity work.MedianFilter
      generic map (
        DataW => DataW,
        Res   => Res
        )
      port map (
        Clk         => Clk,
        RstN        => RstN,
        --
        PixelIn     => PixelArray,
        PixelInVal  => PixelArrayVal,
        --
        PixelOut    => PixelFromMedian,
        PixelOutVal => PixelFromMedianVal
        );
  end block;
  
  LS_Conv : entity work.LineSampler
    generic map (
      DataW   => DataW,
      Buffers => 4,
      OutRes  => Res
      )
    port map (
      Clk         => Clk,
      RstN        => RstN,
      --
      Vsync       => Vsync,
      RdAddr      => RdAddr,
      --
      PixelIn     => PixelFromMedian,
      PixelInVal  => PixelFromMedianVal,
      --
      PixelOut    => PixelArrayToConvFilter,
      PixelOutVal => PixelArrayToConvFilterVal
    );

  CF : entity work.ConvFilter
    generic map (
      DataW     => DataW,
      CompDataW => CompDataW,
      Res       => Res
    )
    port map (
      Clk          => Clk,
      RstN         => RstN,
      --
      Vsync        => Vsync,
      --
      RegAccessIn  => RegAccessIn,
      --
      RdAddr       => RdAddr,
      FilterSel    => FilterSel_D,
      --
      PixelIn      => PixelArrayToConvFilter,
      PixelInVal   => PixelArrayToConvFilterVal,
      --
      PixelOut     => PixelFromSobel,
      PixelOutVal  => PixelFromSobelVal
      );

  VideoCompFloydSteinberg : entity work.DitherFloydSteinberg
    generic map (
      DataW     => DataW,
      CompDataW => 3
      )
    port map (
      Clk         => Clk,
      RstN        => RstN,
      --
      Vsync       => Vsync,
      --
      PixelIn     => PixelIn,
      PixelInVal  => PixelInVal,
      --
      PixelOut    => PixelFromDither(DataW-1 downto DataW-3),
      PixelOutVal => PixelFromDitherVal
      );
  PixelFromDither(5-1 downto 0) <= (others => '0');

  FilterSync : process (Clk, RstN)
  begin
    if RstN = '0' then
      FilterSel_D <= conv_word(DITHER_MODE, FilterSel_D'length);
    elsif rising_edge(Clk) then
      FilterSel_D <= FilterSel_N;
    end if;
  end process;

  FilterAsync : process (FilterSel_D, ToggleMode)
  begin
    FilterSel_N <= FilterSel_D;
    if ToggleMode = '1' then
      FilterSel_N <= FilterSel_D + 1;
      if FilterSel_D + 1 = MODES then
        FilterSel_N <= conv_word(NONE_MODE, FilterSel_N'length);
      end if;
    end if;
  end process;

  FilterMux : process (FilterSel_D, PixelFromSobel, PixelFromSobelVal, PixelFromDither, PixelFromDitherVal, PixelIn, PixelInVal, PixelFromMedian, PixelFromMedianVal)
  begin
    if FilterSel_D = SOBEL_MODE then
      PixelOutVal <= PixelFromSobelVal;
      PixelOut    <= PixelFromSobel;
    elsif FilterSel_D = DITHER_MODE then
      PixelOutVal <= PixelFromDitherVal;
      PixelOut    <= PixelFromDither;
    elsif FilterSel_D = MEDIAN_MODE then
      PixelOutVal <= PixelFromMedianVal;
      PixelOut <= PixelFromMedian(PixelIn'length-1 downto PixelIn'length-PixelOut'length);
    else
      PixelOutVal <= PixelInVal;
      PixelOut    <= PixelIn(PixelIn'length-1 downto PixelIn'length-PixelOut'length);
    end if;
  end process;
end architecture rtl;
