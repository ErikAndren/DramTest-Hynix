-- Extract the different types of signals in the incoming data stream.
-- Current implementation extracts the luminance from the incoming YUV encoded
-- signal.
-- Copyright Erik Zachrisson, erik@zachrisson.info 2014

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;

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
    ColorOut        : out word(DataOutW-1 downto 0);
    ColorOutVal     : out bit1
    );
end entity;

architecture rtl of PixelAligner is
  signal Cnt_N, Cnt_D                     : word(2-1 downto 0);
  signal Y_N, Y_D, Cb_N, Cb_D, Cr_N, Cr_D : word(DataInW-1 downto 0);
  signal GrayScaleVal_N, GrayScaleVal_D   : bit1;
  signal ColorVal_N, ColorVal_D           : bit1;
  signal R, G, B                          : word(DataInW-1 downto 0);
  signal AdjY, AdjCr, AdjCb               : word(DataInW-1 downto 0);
begin
  SyncNoRstProc : process (Clk)
  begin
    if rising_edge(Clk) then
      Cnt_D          <= Cnt_N;
      Y_D            <= Y_N;
      Cb_D           <= Cb_N;
      Cr_D           <= Cr_N;
      GrayScaleVal_D <= GrayScaleVal_N;
      ColorVal_D     <= ColorVal_N;
    end if;
  end process;

  AsyncProc : process (Cnt_D, Vsync, PixelInVal, Y_D, Cb_D, Cr_D,  PixelIn)
  begin
    Cnt_N          <= Cnt_D;
    GrayScaleVal_N <= '0';
    Y_N            <= Y_D;
    Cb_N           <= Cb_D;
    Cr_N           <= Cr_D;
    ColorVal_N     <= '0';

    if PixelInVal = '1' then
      Cnt_N <= Cnt_D + 1;

      -- YUV sample black and white on second cycle
      if (Cnt_D(0) = '0') then
        Y_N            <= PixelIn;
        GrayScaleVal_N <= '1';
        ColorVal_N     <= '1';
      end if;

      if Cnt_D = "10" then
        Cb_N <= PixelIn;
      end if;

      if Cnt_D = "11" then
        Cr_N       <= PixelIn;
      end if;
    end if;

    if Vsync = '1' then
      Cnt_N <= (others => '0');
    end if;
  end process;

  --AdjY  <= Y_D - 16   when Y_D - 16 = 0   else (others => '0');
  --AdjCr <= Cr_D - 128 when Cr_D - 128 = 0 else (others => '0');
  --AdjCb <= Cb_D - 128 when Cb_D - 128 = 0 else (others => '0');
  --RGBConv : process (AdjY, AdjCb, AdjCr)
  --  variable B_T : word(B'length downto 0);
  --begin
    
  --  -- Cb_D = U, Cr_D = V
  --  -- B = 1.164(Y - 16)                   + 2.018(U - 128)
  --  -- G = 1.164(Y - 16) - 0.813(V - 128) - 0.391(U - 128)
  --  -- R = 1.164(Y - 16) + 1.596(V - 128)
  --  -- 
  --  B_T := (('0' & AdjY + '0' & SHR(AdjY, "11")) + SHL(('0' & AdjCb) + '0' & SHR(AdjCb, conv_word(6, bits(6))), "1"));
  --  B   <= minval(B_T, xt1(8));
  --  -- FIXME: Add G, R
  --end process;

  GrayScaleOutValFeed : GrayScaleOutVal <= GrayScaleVal_D;
  GrayScaleOutFeed    : GrayScaleOut    <= Y_D;
--  ColorOutValFeed     : ColorOutVal     <= ColorVal_D;
  -- FIXME
--  ColorOut <= (others => '0');
  
end architecture rtl;
