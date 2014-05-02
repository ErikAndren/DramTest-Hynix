-- Implements a temporal averaging filter
-- This implementation first reads out a pixel from sram and waits for the
-- incoming pixel. Performs the calculation and finally writes back the new value
-- Copyright Erik Zachrisson 2014

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.SramPack.all;
use work.DramTestPack.all;

entity TemporalAverager is
  generic (
    DataW : positive
    );
  port (
    RstN          : in  bit1;
    Clk           : in  bit1;
    --
    Vsync         : in  bit1;
    --
    PixelInVal    : in  bit1;
    PixelIn       : in  word(DataW-1 downto 0);
    --
    SramReadAddr  : out word(SramAddrW-1 downto 0);
    SramRe        : out bit1;
    SramRd        : in  word(DataW-1 downto 0);
    --
    SramWriteAddr : out word(SramAddrW-1 downto 0);
    SramWd        : out word(DataW-1 downto 0);
    SramWe        : out bit1;
    --
    PopWrite      : in  bit1;
    PopRead       : in  bit1
    );
end entity;

architecture rtl of TemporalAverager is
  signal LineCnt_N, LineCnt_D                   : word(VgaHeightW-1 downto 0);
  signal PixelCnt_N, PixelCnt_D                 : word(VgaWidthW-1 downto 0);
  signal SramRdVal_N, SramRdVal_D               : bit1;
  signal SramRd_N, SramRd_D                     : word(DataW-1 downto 0);
  signal SramWd_N, SramWd_D                     : word(DataW-1 downto 0);
  signal SramWe_N, SramWe_D, SramRe_N, SramRe_D : bit1;
  signal PopRead_D                              : bit1;

  function CalcReadAddr(LineCnt : word; PixCnt : word) return word is
    variable NewLineCnt : word(LineCnt'length-1 downto 0);
    variable NewPixCnt  : word(PixCnt'length-1 downto 0);
  begin
    NewPixCnt  := PixCnt - 1;
    NewLineCnt := LineCnt;
    --
    if PixCnt = 0 then
      NewPixCnt := conv_word(VgaWidth-1, NewPixCnt'length);
      if LineCnt = 0 then
        NewLineCnt := conv_word(VgaHeight-1, NewPixCnt'length);
      end if;
    end if;
    return xt0(NewLineCnt & NewPixCnt, SramAddrW);
  end function;
  
begin
  SyncProc : process (Clk, RstN)
  begin
    if RstN = '0' then
      LineCnt_D   <= (others => '0');
      PixelCnt_D  <= (others => '0');
      SramRd_D    <= (others => '0');
      SramRdVal_D <= '0';
      SramWd_D    <= (others => '0');
      SramWe_D    <= '0';
      SramRe_D    <= '0';
      PopRead_D   <= '0';
    elsif rising_edge(Clk) then
      LineCnt_D   <= LineCnt_N;
      PixelCnt_D  <= PixelCnt_N;
      SramRd_D    <= SramRd_N;
      SramRdVal_D <= SramRdVal_D;
      SramWd_D    <= SramWd_N;
      SramWe_D    <= SramWe_N;
      SramRe_D    <= SramRe_N;
      PopRead_D   <= PopRead;

      if Vsync = '1' then
        LineCnt_D          <= (others => '0');
        PixelCnt_D         <= (others => '0');
        SramRd_D    <= (others => '0');
        SramRdVal_D <= '0';
        SramWd_D      <= (others => '0');
        SramRe_D           <= '0';
        SramWe_D           <= '0';
      end if;
    end if;
  end process;
  
  ASyncProc : process (LineCnt_D, PixelCnt_D, PixelInVal, SramRe_D, SramWe_D, PixelIn, SramRd, PopRead_D, SramRd_D, SramRdVal_D)
    variable Avg : word(DataW downto 0);
  begin
    LineCnt_N       <= LineCnt_D;
    PixelCnt_N      <= PixelCnt_D;
    SramRe_N        <= SramRe_D;
    SramWe_N        <= SramWe_D;
    SramWd_N   <= SramWd_D;
    SramRd_N <= SramRd_D;

    if SramRdVal_D = '0' then
      SramRe_N <= '1';
      --
      PixelCnt_N <= PixelCnt_D + 1;
      if PixelCnt_D + 1 = VgaWidth then
        PixelCnt_N <= (others => '0');
        LineCnt_N <= LineCnt_D + 1;
        if LineCnt_D + 1 = VgaHeight then
          LineCnt_N <= (others => '0');
        end if;
      end if;
    end if;

    if PopRead_D = '1' then
      SramRe_N           <= '0';
      SramRd_N    <= SramRd;
      SramRdVal_N <= '1';
    end if;

    if PopWrite = '1' then
      SramWe_N <= '0';
    end if;

    if PixelInVal = '1' then
      -- Perform delta calculation
      --  newAvg = oldAvg - oldAvg>>2 + newColor>>2.
      Avg         := (SramRd_D - SramRd_D(SramRd'high downto 2)) + PixelIn(PixelIn'high downto 2);
      SramWd_N    <= Avg(SramWd'high downto 0);
      SramWe_N    <= '1';
      SramRdVal_N <= '0';
    end if;
  end process;

  SramWd        <= SramWd_D;
  SramWriteAddr <= xt0(LineCnt_D & PixelCnt_D, SramAddrW);
  SramWe        <= SramWe_D;
  --
  SramRe        <= SramRe_D;
  SramReadAddr  <= CalcReadAddr(LineCnt_D, PixelCnt_D);

end architecture rtl;
