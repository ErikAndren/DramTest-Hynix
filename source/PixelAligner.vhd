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
  signal Cnt_N, Cnt_D                     : word(2-1 downto 0);
  signal Y_N, Y_D, Cb_N, Cb_D, Cr_N, Cr_D : word(DataInW-1 downto 0);
  signal GrayScaleVal_N, GrayScaleVal_D   : bit1;
  signal R, G, B                          : word(DataInW-1 downto 0);
  signal AdjY, AdjCr, AdjCb               : word(DataInW-1 downto 0);
  signal AdjY_0_125                       : word(DataInW-1 downto 0);
  signal AdjY_1_125                       : word(DataInW downto 0);
  --
  signal AdjCr_0_5                        : word(DataInW-1 downto 0);
  signal AdjCr_0_25                       : word(DataInW-1 downto 0);
  signal AdjCr_0_125                      : word(DataInW-1 downto 0);
  signal AdjCr_0_0625                     : word(DataInW-1 downto 0);
  signal AdjCr_0_03125                    : word(DataInW-1 downto 0);
  --
  signal AdjCr_0_8125                     : word(DataInW-1 downto 0);
  signal AdjCr_1_59375                    : word(DataInW downto 0);
  signal AdjCr_1_375                      : word(DataInW downto 0);
  --
  signal AdjCb_0_5                        : word(DataInW-1 downto 0);
  signal AdjCb_0_25                       : word(DataInW-1 downto 0);
  signal AdjCb_0_125                      : word(DataInW-1 downto 0);
  signal AdjCb_0_0625                     : word(DataInW-1 downto 0);
  signal AdjCb_0_03125                    : word(DataInW-1 downto 0);
  signal AdjCb_0_015625                   : word(DataInW-1 downto 0);
  --
  signal AdjCb_0_3906                     : word(DataInW-1 downto 0);
  signal AdjCb_1_772                      : word(DataInW downto 0);
  --
  signal R_Dithered                       : word(3-1 downto 0);
  signal G_Dithered                       : word(3-1 downto 0);
  signal B_Dithered                       : word(2-1 downto 0);
  signal R_DitheredVal                    : bit1;
  signal B_DitheredVal                    : bit1;

  
begin
  SyncRstProc : process (Clk, RstN)
  begin
    if RstN = '0' then
      GrayScaleVal_D <= '0';
    elsif rising_edge(Clk) then
      GrayScaleVal_D <= GrayScaleVal_N;
    end if;
  end process;
  
  SyncNoRstProc : process (Clk)
  begin
    if rising_edge(Clk) then
      Cnt_D          <= Cnt_N;
      Y_D            <= Y_N;
      Cb_D           <= Cb_N;
      Cr_D           <= Cr_N;
    end if;
  end process;

  AsyncProc : process (Cnt_D, Vsync, PixelInVal, Y_D, Cb_D, Cr_D,  PixelIn)
  begin
    Cnt_N          <= Cnt_D;
    GrayScaleVal_N <= '0';
    Y_N            <= Y_D;
    Cb_N           <= Cb_D;
    Cr_N           <= Cr_D;

    if PixelInVal = '1' then
      Cnt_N <= Cnt_D + 1;

      if (Cnt_D(0) = '1') then
        Y_N            <= PixelIn;
        GrayScaleVal_N <= '1';
      end if;

      if Cnt_D = "00" then
        Cb_N <= PixelIn;
      end if;

      if Cnt_D = "10" then
        Cr_N <= PixelIn;
      end if;
    end if;

    if Vsync = '1' then
      Cnt_N <= (others => '0');
    end if;
  end process;

  AdjY       <= Y_D - 16   when Y_D - 16 > 0   else (others => '0');
  --
  AdjCr      <= Cr_D - 128 when Cr_D - 128 > 0 else (others => '0');
  AdjCb      <= Cb_D - 128 when Cb_D - 128 > 0 else (others => '0');
    
  RGBConv : process (AdjY, AdjCb, AdjCr)
    variable C_298 : integer;
    variable E_208 : integer;
    variable E_409 : integer;
    variable D_100 : integer;
    variable D_516 : integer;
    variable R_T, G_T, B_T : integer;
    
  begin
    C_298 := conv_integer(AdjY) * 298;
    E_409 := conv_integer(AdjCr) * 409;
    E_208 := conv_integer(AdjCr) * 208;
    D_100 := conv_integer(AdjCb) * 100;
    D_516 := conv_integer(AdjCb) * 516;
    --
    R_T := (C_298 + E_409 + 128) / 2**8;
    if R_T > 255 then
      R <= (others => '1');
    else
      R <= conv_word(R_T, R'length);
    end if;

    G_T := (C_298 - D_100 - E_208 + 128) / 2**8;
    if G_T > 255 then
      G <= (others => '1');
    else
      G <= conv_word(G_T, G'length);
    end if;

    B_T := (C_298 + D_516 + 128) / 2**8;
    if B_T > 255 then
      B <= (others => '1');
    else
      B <= conv_word(B_T, B'length);
    end if;
  end process;

  GrayScaleOutValFeed : GrayScaleOutVal <= GrayScaleVal_D;
  GrayScaleOutFeed    : GrayScaleOut    <= Y_D;

  RedDither : entity work.DitherFloydSteinberg
    generic map (
      DataW     => 8,
      CompDataW => 3
      )
    port map (
      RstN        => RstN,
      Clk         => Clk,
      --
      Vsync       => Vsync,
      --
      PixelIn     => R,
      PixelInVal  => GrayScaleVal_D,
      --
      PixelOut    => R_Dithered,
      PixelOutVal => R_DitheredVal
      );
  
  GreenDither : entity work.DitherFloydSteinberg
    generic map (
      DataW     => 8,
      CompDataW => 3
      )
    port map (
      RstN        => RstN,
      Clk         => Clk,
      --
      Vsync       => Vsync,
      --
      PixelIn     => G,
      PixelInVal  => GrayScaleVal_D,
      --
      PixelOut    => G_Dithered,
      PixelOutVal => open
      );

  BlueDither : entity work.DitherFloydSteinberg
    generic map (
      DataW     => 8,
      CompDataW => 2
      )
    port map (
      RstN        => RstN,
      Clk         => Clk,
      --
      Vsync       => Vsync,
      --
      PixelIn     => B,
      PixelInVal  => GrayScaleVal_D,
      --
      PixelOut    => B_Dithered,
      PixelOutVal => B_DitheredVal
      );
  
  RedFeed   : Color(RedHigh downto RedLow)     <= R_Dithered;
  GreenFeed : Color(GreenHigh downto GreenLow) <= G_Dithered;
  BlueFeed  : Color(BlueHigh downto BlueLow)   <= B_Dithered;

  ColorValFeed     : ColorOutVal     <= B_DitheredVal;
  
end architecture rtl;
