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
    WrRst_N       : in  bit1;
    WrClk         : in  bit1;
    --
    FirstFrameVal : in  bit1;
    LastFrameComp : in  word(FramesW-1 downto 0);
    --
    RespData      : in  word(DSIZE-1 downto 0);
    RespDataVal   : in  bit1;
    --
    -- interface to sram arbiter
    RdRst_N       : in  bit1;
    RdClk         : in  bit1;
    --
    ReadReq       : out DramRequest;
    ReadReqAck    : in  bit1;
    -- Vga interface
    VgaVSync      : in  bit1;
    InView        : in  bit1;
    PixelToDisp   : out word(PixelW-1 downto 0)
    );
end entity;

architecture rtl of RespHandler is
  signal DataToVga : word(DSIZE-1 downto 0);
  signal FifoEmpty, ReadFifo, FifoFull : bit1;

  -- FIXME: This can probably be lowered to 16
  constant FifoSize  : positive := 32;
  constant FifoSizeW : positive := bits(FifoSize);
  signal FillLvl     : word(FifoSizeW-1 downto 0);

  -- Must be less than 16
  constant ReadReqThrottle            : positive := 15;
  constant ReadReqThrottleW           : positive := bits(ReadReqThrottle);
  signal ReqThrottle_N, ReqThrottle_D : word(ReadReqThrottleW downto 0);

  constant FillLevelThres : positive := 16;
  
  constant PixelsPerWord  : positive := DSIZE / PixelW;
  constant PixelsPerWordW : positive := bits(PixelsPerWord);
  
  signal WordCnt_N, WordCnt_D : word(PixelsPerWordW-1 downto 0);

  signal Frame_N, Frame_D : word(FramesW-1 downto 0);
  signal Addr_N, Addr_D   : word(VgaPixelsPerDwordW-1 downto 0);
begin
  
  ReadReqProc : process (Addr_D, Frame_D, FillLvl, ReadReqAck, ReqThrottle_D, LastFrameComp, FirstFrameVal, VgaVSync)
  begin
    ReadReq <= Z_DramRequest;
    Addr_N  <= Addr_D;
    Frame_N <= Frame_D;
    --
    ReqThrottle_N <= ReqThrottle_D - 1;
    if ReqThrottle_D = 0 then
      ReqThrottle_N <= (others => '0');
    end if;

    -- Generate read requests when:
    -- 1. Fifo is less than half full
    -- 2. No throttling is occurring
    -- 3. A full, valid frame has been generated
    -- 4. The VGA is not syncing, if so we must load the next frame
    if (conv_integer(FillLvl) < FillLevelThres) and (ReqThrottle_D = 0) and (FirstFrameVal = '1') and (VgaVSync = '0') then
      ReadReq.Val   <= "1";
      ReadReq.Cmd   <= DRAM_READA;
      ReadReq.Addr  <= xt0(Frame_D & Addr_D, ReadReq.Addr'length);
    end if;

    if ReadReqAck = '1' then
      Addr_N        <= Addr_D + BurstLen;

      -- Throttle the time to the next read request to avoid burstiness
      ReqThrottle_N <= conv_word(ReadReqThrottle, ReqThrottle_N'length);

      -- Wrap address upon frame completion
      -- Should not be needed as the vga vsync will ensure the address pointer
      -- is reset
      if conv_integer(Addr_D + BurstLen) = VgaPixelsPerDword then
        Addr_N  <= (others => '0');
      end if;
    end if;

    -- Reset address pointer as the next frame must be loaded upon vga vsync release
    if VgaVSync = '1' then
      Addr_N <= (others => '0');

      -- Update to latest frame
      if ((LastFrameComp > Frame_D) or (LastFrameComp = 0)) then
        Frame_N <= LastFrameComp;
      end if;
    end if;
  end process;

  RespFifo : entity work.RespFIFO
    port map (
      WrClk   => WrClk,
      WrReq   => RespDataVal,
      Data    => RespData,
      wrFull  => FifoFull,
      --
      -- Clear fifo between each frame
      aclr    => VgaVsync,
      RdClk   => RdClk,
      RdReq   => ReadFifo,
      Q       => DataToVga,
      RdEmpty => FifoEmpty,
      RdUsedW => FillLvl
      );

  assert not (RespDataVal = '1' and FifoFull = '1') report "Overflowing response fifo" severity failure;
  
  SyncProc : process (RdClk, RdRst_N)
  begin
    if RdRst_N = '0' then
      Frame_D       <= (others => '0');
      Addr_D        <= (others => '0');
      WordCnt_D     <= (others => '0');
      ReqThrottle_D <= (others => '0');
    elsif rising_edge(RdClk) then
      Frame_D       <= Frame_N;
      WordCnt_D     <= WordCnt_N;
      Addr_D        <= Addr_N;
      ReqThrottle_D <= ReqThrottle_N;
    end if;
  end process;

  VgaFiller : process (WordCnt_D, DataToVga, FifoEmpty, InView, VgaVsync)
  begin
    -- Display black as default
    PixelToDisp <= (others => '0');
    WordCnt_N   <= WordCnt_D;
    ReadFifo    <= '0';

    if InView = '1' then
      -- Read out lowest pixel first
      PixelToDisp <= ExtractSlice(DataToVga, PixelW, (PixelsPerWord-1) - conv_integer(WordCnt_D));
      WordCnt_N   <= WordCnt_D - 1;
    end if;

    -- Try to read out data when there is something to send
    if (FifoEmpty = '0' and WordCnt_D = 0) then
      ReadFifo  <= '1';
      WordCnt_N <= conv_word(PixelsPerWord-1, WordCnt_N'length);
    end if;

    if VgaVsync = '1' then
      ReadFifo  <= '0';
      WordCnt_N <= (others => '0');
    end if;
  end process;
end architecture rtl;
