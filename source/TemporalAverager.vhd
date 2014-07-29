-- Implements a temporal averaging filter
-- This implementation first reads out a pixel from sram and waits for the
-- incoming pixel. Performs the calculation and finally writes back the new value
-- Copyright Erik Zachrisson 2014

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.VgaPack.all;
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
    SramRd        : in  word(SramDataW-1 downto 0);
    PopRead       : in  bit1;
    --
    SramWriteAddr : out word(SramAddrW-1 downto 0);
    SramWd        : out word(SramDataW-1 downto 0);
    SramWe        : out bit1;
    PopWrite      : in  bit1;
    --
    PixelOut      : out word(DataW-1 downto 0);
    PixelOutVal   : out bit1
    );
end entity;

architecture rtl of TemporalAverager is
  signal LineCnt_N, LineCnt_D                   : word(VgaHeightW-1 downto 0);
  signal PixelCnt_N, PixelCnt_D                 : word(VgaWidthW-1 downto 0);
  signal SramRdVal_N, SramRdVal_D               : bit1;
  signal SramRd_N, SramRd_D                     : word(SramDataW-1 downto 0);
  signal SramWd_N, SramWd_D                     : word(SramDataW-1 downto 0);
  signal SramWe_N, SramWe_D, SramRe_N, SramRe_D : bit1;
  signal PopRead_D                              : bit1;
  signal WordCnt_N, WordCnt_D                   : word(1-1 downto 0);
  signal SramReadAddr_i                         : word(SramAddrW-1 downto 0);

  constant Threshold : natural := 32;
  
  function CalcOldAddr(LineCnt : word; PixCnt : word) return word is
    variable NewLineCnt : word(LineCnt'length-1 downto 0);
    variable NewPixCnt  : word(PixCnt'length-1 downto 0);
  begin
    NewPixCnt  := PixCnt - 1;
    NewLineCnt := LineCnt;
    --
    if PixCnt = 0 then
      NewPixCnt := conv_word(VgaWidth-1, NewPixCnt'length);
      if LineCnt = 0 then
        NewLineCnt := conv_word(VgaHeight-1, NewLineCnt'length);
      end if;
    end if;
    -- Every address entry is shared by two pixels
    return xt0(NewLineCnt & NewPixCnt(NewPixCnt'length-1 downto 1), SramAddrW);
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
      WordCnt_D   <= (others => '0');
    elsif rising_edge(Clk) then
      LineCnt_D   <= LineCnt_N;
      PixelCnt_D  <= PixelCnt_N;
      SramRd_D    <= SramRd_N;
      SramRdVal_D <= SramRdVal_N;
      SramWd_D    <= SramWd_N;
      SramWe_D    <= SramWe_N;
      SramRe_D    <= SramRe_N;
      PopRead_D   <= PopRead;
      WordCnt_D   <= WordCnt_N;

      if Vsync = '1' then
        LineCnt_D   <= (others => '0');
        PixelCnt_D  <= (others => '0');
        SramRd_D    <= (others => '0');
        SramRdVal_D <= '0';
        SramWd_D    <= (others => '0');
        SramRe_D    <= '0';
        SramWe_D    <= '0';
        WordCnt_D   <= (others => '0');
      end if;
    end if;
  end process;
  
  ASyncProc : process (SramWd_D, PopWrite, LineCnt_D, PixelCnt_D, PixelInVal, SramRe_D, SramWe_D, PixelIn, SramRd, PopRead_D, SramRd_D, SramRdVal_D, PopRead, WordCnt_D)
    variable Avg         : word(DataW-1 downto 0);
    variable Diff        : word(DataW-1 downto 0);
    variable SramRdSlice : word(DataW-1 downto 0);
    variable SramRdSlice_i : integer;
  begin
    WordCnt_N   <= WordCnt_D;
    LineCnt_N   <= LineCnt_D;
    PixelCnt_N  <= PixelCnt_D;
    SramRe_N    <= SramRe_D;
    SramWe_N    <= SramWe_D;
    SramWd_N    <= SramWd_D;
    SramRd_N    <= SramRd_D;
    PixelOut    <= (others => '0');
    SramRdVal_N <= SramRdVal_D;

    if SramRdVal_D = '0' and PopRead_D = '0' and SramRe_D = '0' then
      SramRe_N <= '1';
    end if;

    if PopRead = '1' then
      SramRe_N <= '0';
    end if;

    if PopRead_D = '1' then
      SramRd_N    <= SramRd;
      SramRdVal_N <= '1';
    end if;

    if PopWrite = '1' then
      SramWe_N <= '0';
    end if;

    if PixelInVal = '1' then
      WordCnt_N <= WordCnt_D + 1;
      if conv_integer(WordCnt_D + 1) = 2 then
        WordCnt_N <= (others => '0');
      end if;

      PixelCnt_N <= PixelCnt_D + 1;
      if PixelCnt_D + 1 = VgaWidth then
        PixelCnt_N <= (others => '0');
        LineCnt_N <= LineCnt_D + 1;
        if LineCnt_D + 1 = VgaHeight then
          LineCnt_N <= (others => '0');
        end if;
      end if;
      
      -- Perform delta calculation
      SramRdSlice   := ExtractSlice(SramRd_D, DataW, conv_integer(WordCnt_D));
      SramRdSlice_i := conv_integer(SramRdSlice);
      --
      Avg           := conv_word((7*SramRdSlice_i + conv_integer(PixelIn)) / 8, DataW);

      if Avg > PixelIn then
        Diff := (Avg - PixelIn);
      else
        Diff := (PixelIn - Avg);
      end if;

      if Diff >= Threshold then
        PixelOut <= PixelIn;
      end if;
      
      SramWd_N    <= ModifySlice(SramWd_D, DataW, conv_integer(WordCnt_D), Avg);
      SramWe_N    <= WordCnt_D(0);
      SramRdVal_N <= WordCnt_D(0);
    end if;
  end process;

  SramWd         <= SramWd_D;
  -- Each word is 16 bit and is shared by two pixels
  SramWriteAddr  <= CalcOldAddr(LineCnt_D, PixelCnt_D);
  SramWe         <= SramWe_D;
  --
  SramRe         <= SramRe_D;
  SramReadAddr_i <= xt0(LineCnt_N & PixelCnt_N(PixelCnt_D'length-1 downto 1), SramAddrW);
  SramReadAddr   <= SramReadAddr_i;

  PixelOutVal <= PixelInVal;

end architecture rtl;
