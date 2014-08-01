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
use work.SerialPack.all;

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
    RegAccessIn     : in  RegAccessRec;
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
  signal AdjY, AdjCr, AdjCb               : word(DataInW   downto 0);
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
  signal R_DitheredVal                    : bit1;
  signal G_Dithered                       : word(3-1 downto 0);
  signal G_DitheredVal                    : bit1;
  signal B_Dithered                       : word(2-1 downto 0);
  signal B_DitheredVal                    : bit1;
  --
  signal SampleOrder_N, SampleOrder_D     : bit1;
  signal GreenOffset_N, GreenOffset_D     : integer;
  signal RedOffset_N, RedOffset_D         : integer;
  signal BlueOffset_N, BlueOffset_D       : integer;
  
begin
  SyncRstProc : process (Clk, RstN)
  begin
    if RstN = '0' then
      GrayScaleVal_D <= '0';
      SampleOrder_D  <= '0';
      GreenOffset_D  <= 0;
      BlueOffset_D   <= 0;
      RedOffset_D    <= 0;
      
    elsif rising_edge(Clk) then
      GrayScaleVal_D <= GrayScaleVal_N;
      SampleOrder_D  <= SampleOrder_N;
      GreenOffset_D  <= GreenOffset_N;
      BlueOffset_D   <= BlueOffset_N;
      RedOffset_D    <= RedOffset_N;
      
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

  AsyncProc : process (Cnt_D, Vsync, PixelInVal, Y_D, Cb_D, Cr_D, PixelIn, SampleOrder_D, RegAccessIn, GreenOffset_D, RedOffset_D, BlueOffset_D)
  begin
    Cnt_N          <= Cnt_D;
    GrayScaleVal_N <= '0';
    Y_N            <= Y_D;
    Cb_N           <= Cb_D;
    Cr_N           <= Cr_D;
    SampleOrder_N  <= SampleOrder_D;
    GreenOffset_N  <= GreenOffset_D;
    BlueOffset_N   <= BlueOffset_D;
    RedOffset_N    <= RedOffset_D;

    if RegAccessIn.Val = "1" then
      if RegAccessIn.Addr = PixelSampleOrderReg then
        SampleOrder_N <= RegAccessIn.Data(PixelSampleOrder);
      elsif RegAccessIn.Addr = GreenOffsetReg then
        GreenOffset_N <= conv_integer(RegAccessIn.Data);
      elsif RegAccessIn.Addr = BlueOffsetReg then
        BlueOffset_N <= conv_integer(RegAccessIn.Data);
      elsif RegAccessIn.Addr = RedOffsetReg then
        RedOffset_N <= conv_integer(RegAccessIn.Data);
      end if;
    end if;

    if PixelInVal = '1' then
      Cnt_N <= Cnt_D + 1;

      if SampleOrder_D = '0' then
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
      else
        if (Cnt_D(0) = '0') then
          Y_N            <= PixelIn;
          GrayScaleVal_N <= '1';
        end if;

        if Cnt_D = "01" then
          Cb_N <= PixelIn;
        end if;

        if Cnt_D = "11" then
          Cr_N <= PixelIn;
        end if;        
      end if;
    end if;

    if Vsync = '1' then
      Cnt_N <= (others => '0');
    end if;
  end process;

  AdjY  <= '0' & Y_D - 16;
  AdjCr <= '0' & Cr_D - 128;
  AdjCb <= '0' & Cb_D - 128;

  RGBConv : process (AdjY, AdjCb, AdjCr)
    variable ValRed, ValBlue, ValGreen : integer;
    variable ValRedWord, ValBlueWord, ValGreenWord : word(32-1 downto 0);
  begin
    ValRed   := (conv_integer(AdjY) * 1220542) + (conv_integer(AdjCr) * 1673527);
    ValBlue  := (conv_integer(AdjY) * 1220542) + (conv_integer(AdjCb) * 2114978);
    ValGreen := (conv_integer(AdjY) * 1220542) - (conv_integer(AdjCr) * 852492) - (conv_integer(AdjCb) * 411042);
    --
    ValRedWord   := conv_word(ValRed, 32);
    ValBlueWord  := conv_word(ValBlue, 32);
    ValGreenWord := conv_word(ValGreen, 32);
    --
    ValRedWord   := SHR(ValRedWord, conv_word(20, bits(20)));
    ValBlueWord  := SHR(ValBlueWord, conv_word(20, bits(20)));
    ValGreenWord := SHR(ValGreenWord, conv_word(20, bits(20)));
    --
    

    if ValRedWord < 0 then
      R <= (others => '0');
    elsif ValRedWord > 255 then
      R <= (others => '1');
    else
      R <= ValRedWord(8-1 downto 0);
    end if;

    if ValGreenWord < 0 then
      G <= (others => '0');
    elsif ValGreenWord > 255 then
      G <= (others => '1');
    else
      G <= ValGreenWord(8-1 downto 0);
    end if;
    
    if ValBlueWord < 0 then
      B <= (others => '0');
    elsif ValBlueWord > 255 then
      B <= (others => '1');
    else
      B <= ValBlueWord(8-1 downto 0);
    end if;
  end process;

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
      PixelOutVal => G_DitheredVal
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
  
    --GreenFeed    : Color(GreenHigh downto GreenLow) <= G(G'high downto 5);
    --RedFeed      : Color(RedHigh downto RedLow)     <= R(R'high downto 5);
    --BlueFeed     : Color(BlueHigh downto BlueLow)   <= B(B'high downto 6);

    GreenFeed    : Color(GreenHigh downto GreenLow) <= G_Dithered;
    RedFeed      : Color(RedHigh downto RedLow)     <= R_Dithered;
    BlueFeed     : Color(BlueHigh downto BlueLow)   <= B_Dithered;

--    RedFeed      : Color(RedHigh downto RedLow)     <= (others => '0');
--    BlueFeed     : Color(BlueHigh downto BlueLow)   <= (others => '0');
--  ColorValFeed : ColorOutVal                      <= B_DitheredVal;
  
  ColorValFeed        : ColorOutVal     <= G_DitheredVal;
  --
  GrayScaleOutValFeed : GrayScaleOutVal <= GrayScaleVal_D;
  GrayScaleOutFeed    : GrayScaleOut    <= Y_D;

  
end architecture rtl;
