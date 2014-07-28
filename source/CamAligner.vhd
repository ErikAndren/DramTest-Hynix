-- Keeps track and generates frames to be written to the DRAM.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

entity CamAligner is
  port (
    Rst_N       : in  bit1;
    Clk         : in  bit1;
    --
    Vsync         : in  bit1;
    Href          : in  bit1;
    D             : in  word(PixelW-1 downto 0);
    --
    WriteReq      : out DramRequest;
    WriteReqAck   : in  bit1;
    --
    FirstFrameVal : out bit1;
    LastFrameComp : out word(FramesW-1 downto 0)
    );
end entity;

architecture rtl of CamAligner is
  signal Frame_N, Frame_D                 : word(FramesW-1 downto 0);
  signal Addr_N, Addr_D                   : word(VgaPixelsPerDwordW-1 downto 0);
  --
  signal WordCnt_N, WordCnt_D             : word(PixelsPerBurstW-1 downto 0);
  signal WrData_N, WrData_D               : word(BurstSz-1 downto 0);
  --
  signal DramRequest_i                    : DramRequest;
  signal FifoWe_N, FifoWe_D               : bit1;
  signal ArbAck_N, ArbAck_D               : bit1;
  signal FirstFrameVal_N, FirstFrameVal_D : bit1;
  
  function CalcLastFrameComp(CurFrame : word) return word is
    variable res : word(CurFrame'length-1 downto 0);
  begin
    if CurFrame = 0 then
      res := conv_word(Frames-1, CurFrame'length);
    else
      res := CurFrame - 1;
    end if;
    return res;
  end function;
  
begin
  SyncProc : process (Clk, Rst_N)
  begin
    if Rst_N = '0' then
      Frame_D         <= (others => '0');
      Addr_D          <= (others => '0');
      WordCnt_D       <= (others => '0');
      FifoWe_D        <= '0';
      FirstFrameVal_D <= '0';
      ArbAck_D        <= '1';
    elsif rising_edge(Clk) then
      ArbAck_D        <= ArbAck_N;
      Frame_D         <= Frame_N;
      WordCnt_D       <= WordCnt_N;
      Addr_D          <= Addr_N;
      FifoWe_D        <= FifoWe_N;
      FirstFrameVal_D <= FirstFrameVal_N;
    end if;
  end process;

  WrSyncNoRstProc : process (Clk)
  begin
    if rising_edge(Clk) then
      WrData_D <= WrData_N;
    end if;
  end process;

  LastFrameAssign  : LastFrameComp <= CalcLastFrameComp(Frame_D);
  FirstFrameAssign : FirstFrameVal <= FirstFrameVal_D;
  
  WrAsyncProc : process (WordCnt_D, WrData_D, Vsync, Href, D, FifoWe_D)
  begin
    WordCnt_N       <= WordCnt_D;
    WrData_N        <= WrData_D;
    FifoWe_N        <= '0';

    if Href = '1' then
      WrData_N  <= D & WrData_D(WrData_D'length-1 downto PixelW);

      --WrData_N  <= ModifySlice(WrData_D, PixelW, WordCnt_D, D);
      WordCnt_N <= WordCnt_D + 1;

      if RedAnd(WordCnt_D) = '1' then
        FifoWe_N  <= '1';
        WordCnt_N <= (others => '0');
      end if;
    end if;

    if Vsync = '1' then
      WordCnt_N  <= (others => '0');
    end if;
  end process;

  AddrStep : process (Frame_D, Addr_D, FirstFrameVal_D, Vsync, WriteReqAck)
  begin
    Frame_N         <= Frame_D;
    Addr_N          <= Addr_D;
    FirstFrameVal_N <= FirstFrameVal_D;

    if WriteReqAck = '1' then
      -- Increase address after the last entry was written
      Addr_N    <= Addr_D + BurstLen;

      if conv_integer(Addr_D + BurstLen) = VgaPixelsPerDword then
        -- Send signal to read path that the first frame is complete
        FirstFrameVal_N <= '1';
        Addr_N          <= (others => '0');
        Frame_N         <= Frame_D + 1;

        -- Wrap frame counter
        if Frame_D + 1 = Frames then
          Frame_N <= (others => '0');
        end if;
      end if;
    end if;
    
    if Vsync = '1' then
      Addr_N     <= (others => '0');
    end if;
  end process;

  DramRequest_i.Val  <= Bit1ToWord1(FifoWe_D);
  DramRequest_i.Data <= WrData_D;
  DramRequest_i.Cmd  <= DRAM_WRITEA;
  DramRequest_i.Addr <= xt0(Frame_D & Addr_D, ASIZE);
  WriteReq           <= DramRequest_i when ArbAck_D = '0' else Z_DramRequest;

  RdAsyncProc : process (WriteReqAck, ArbAck_D, FifoWe_D)
  begin
    ArbAck_N <= ArbAck_D;

    -- Arbiter has acked request, proceed to mask the output
    if WriteReqAck = '1' then
      ArbAck_N <= '1';
    end if;

    -- New request
    if FifoWe_D = '1' then
      ArbAck_N <= '0';
    end if;
  end process;  
end architecture rtl;
