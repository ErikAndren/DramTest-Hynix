-- This block manages feeds the vga generator

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

entity RespHandler is
  generic (
    PixelW : positive := 8
    );
  port (
    WrRst_N     : in  bit1;
    WrClk       : in  bit1;
    --
    RespData    : in  word(DSIZE-1 downto 0);
    RespDataVal : in  bit1;
    --
    -- interface to sram arbiter
    RdRst_N     : in  bit1;
    RdClk       : in  bit1;
    --
    ReadReq     : out DramRequest;
    ReadReqAck  : in  bit1;
    -- Vga interface
    InView      : in  bit1;
    PixelToDisp : out word(PixelW-1 downto 0)
    );
end entity;

architecture rtl of RespHandler is
  signal DataToVga : word(DSIZE-1 downto 0);
  signal FifoEmpty, ReadFifo, FifoFull : bit1;
  signal FillLvl : word(5-1 downto 0);

  constant PixelsPerWord  : positive := DSIZE / PixelW;
  constant PixelsPerWordW : positive := bits(PixelsPerWord);
  
  signal WordCnt_N, WordCnt_D : word(PixelsPerWordW-1 downto 0);

  signal Frame_N, Frame_D : word(FramesW-1 downto 0);
  signal Addr_N, Addr_D   : word(VgaPixelsPerDwordW-1 downto 0);
begin
  
  RespFifo : entity work.RespFIFO
    port map (
      WrClk   => WrClk,
      WrReq   => RespDataVal,
      Data    => RespData,
      --
      RdClk   => RdClk,
      RdReq   => ReadFifo,
      Q       => DataToVga,
      RdEmpty => FifoEmpty,
      RdUsedW => FillLvl,
      wrFull  => FifoFull
      );

  assert not (RespDataVal = '1' and FifoFull = '1') report "Overflowing response fifo" severity failure;
  SyncProc : process (RdClk, RdRst_N)
  begin
    if RdRst_N = '0' then
      Frame_D   <= (others => '0');
      Addr_D    <= (others => '0');
      WordCnt_D <= (others => '0');
    elsif rising_edge(RdClk) then
      Frame_D   <= Frame_N;
      WordCnt_D <= WordCnt_N;
      Addr_D    <= Addr_N;
    end if;
  end process;

  VgaFiller : process (WordCnt_D, DataToVga, FifoEmpty, InView)
  begin
    -- Display black as default
    PixelToDisp <= (others => '0');
    WordCnt_N   <= WordCnt_D;
    ReadFifo    <= '0';

    -- Try to read out data when there is something to send
    if FifoEmpty = '0' and WordCnt_D = 0 then
      ReadFifo  <= '1';
      WordCnt_N <= conv_word(1, WordCnt_N'length);
    end if;

    if InView = '1' then
      PixelToDisp <= ExtractSlice(DataToVga, PixelW, conv_integer(WordCnt_D));

      WordCnt_N <= WordCnt_D - 1;
      if WordCnt_D = 0 then
        WordCnt_N   <= (others => '0');
        PixelToDisp <= (others => '0');
      end if;
    end if;
  end process;

  ReadReqProc : process (Addr_D, Frame_D, FillLvl, ReadReqAck)
  begin
    ReadReq <= Z_DramRequest;
    Addr_N  <= Addr_D;
    Frame_N <= Frame_D;
    --
    -- Generate read request as long as fifo is less than half full
    if FillLvl(FillLvl'high) = '0' then
      ReadReq.Val  <= "1";
      ReadReq.Cmd  <= DRAM_READA;
      ReadReq.Addr <= xt0(Frame_D & Addr_D, ReadReq.Addr'length);
    end if;

    if ReadReqAck = '1' then
      Addr_N <= Addr_D + BurstLen;
      if (Addr_D + BurstLen > VgaPixelsPerDwordW) then
        Addr_N  <= (others => '0');
        Frame_N <= Frame_D + 1;
        if Frame_D + 1 >= Frames then
          Frame_N <= (others => '0');
        end if;
      end if;
    end if;
  end process;
  
end architecture rtl;
