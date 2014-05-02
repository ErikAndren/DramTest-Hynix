library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

entity CamAligner is
  port (
    WrRst_N       : in  bit1;
    WrClk         : in  bit1;
    --
    Vsync         : in  bit1;
    Href          : in  bit1;
    D             : in  word(8-1 downto 0);
    --
    RdClk         : in  bit1;
    RdRst_N       : in  bit1;
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
  -- FIXME: Replace with assymetric fifo?
  signal WrData_N, WrData_D               : word(BurstSz-1 downto 0);
  --
  signal DramRequest_i, WriteReq_i        : DramRequest;
  signal DramRequestWord, WriteReqWord    : word(DramRequestW-1 downto 0);
  signal FifoWe_N, FifoWe_D               : bit1;
  signal WasEmpty_D                       : bit1;
  signal ArbAck_N, ArbAck_D               : bit1;
  signal ReadFifo                         : bit1;
  signal FifoEmpty, FifoFull              : bit1;
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
  WrSyncProc : process (WrClk, WrRst_N)
  begin
    if WrRst_N = '0' then
      Frame_D         <= (others => '0');
      Addr_D          <= (others => '0');
      WordCnt_D       <= (others => '0');
      FifoWe_D        <= '0';
      FirstFrameVal_D <= '0';
    elsif rising_edge(WrClk) then
      Frame_D         <= Frame_N;
      WordCnt_D       <= WordCnt_N;
      Addr_D          <= Addr_N;
      FifoWe_D        <= FifoWe_N;
      FirstFrameVal_D <= FirstFrameVal_N;
    end if;
  end process;

  WrSyncNoRstProc : process (WrClk)
  begin
    if rising_edge(WrClk) then
      WrData_D <= WrData_N;
    end if;
  end process;

  LastFrameAssign  : LastFrameComp <= CalcLastFrameComp(Frame_D);
  FirstFrameAssign : FirstFrameVal <= FirstFrameVal_D;
  
  WrAsyncProc : process (WordCnt_D, Frame_D, WrData_D, Vsync, Href, D, Addr_D, FifoWe_D, FirstFrameVal_D)
  begin
    WordCnt_N       <= WordCnt_D;
    Frame_N         <= Frame_D;
    WrData_N        <= WrData_D;
    Addr_N          <= Addr_D;
    FifoWe_N        <= '0';
    FirstFrameVal_N <= FirstFrameVal_D;

    if Href = '1' then
      
      WrData_N  <= ModifySlice(WrData_D, PixelW, WordCnt_D, D);        
      WordCnt_N <= WordCnt_D + 1;

      if WordCnt_D = PixelsPerBurst-1 then
        FifoWe_N  <= '1';
        WordCnt_N <= (others => '0');
      end if;
    end if;

    if FifoWe_D = '1' then
      Addr_N    <= Addr_D + BurstLen;

      if conv_integer(Addr_D + BurstLen) = VgaPixelsPerDword then
        FirstFrameVal_N <= '1';
        Addr_N          <= (others => '0');
        Frame_N         <= Frame_D + 1;
        
        if Frame_D + 1 = Frames then
          Frame_N <= (others => '0');
        end if;
      end if;
    end if;

    if Vsync = '1' then
      WordCnt_N  <= (others => '0');
      Addr_N     <= (others => '0');
    end if;
  end process;

  DramRequest_i.Val  <= Bit1ToWord1(FifoWe_D);
  DramRequest_i.Data <= WrData_D;
  DramRequest_i.Cmd  <= DRAM_WRITEA;
  DramRequest_i.Addr <= xt0(Frame_D & Addr_D, ASIZE);
  DramRequestWord    <= DramRequestToWord(DramRequest_i);

  RFifo : entity work.ReqFifo
    port map (
      WrClk   => WrClk,
      WrReq   => FifoWe_D,
      Data    => DramRequestWord,
      --
      RdClk   => RdClk,
      RdReq   => ReadFifo,
      Q       => WriteReqWord,
      RdEmpty => FifoEmpty,
      WrFull  => FifoFull
      );

  assert not (FifoFull = '1' and FifoWe_D = '1') report "CamAligner fifo overflow" severity failure;
	
  WriteReq_i <= WordToDramRequest(WriteReqWord);
  WriteReq   <= WriteReq_i when ArbAck_D = '0' else Z_DramRequest;
  
  RdSyncProc : process (RdClk, RdRst_N)
  begin
    if RdRst_N = '0' then
      WasEmpty_D <= '0';
      ArbAck_D   <= '0';
    elsif rising_edge(RdClk) then
      WasEmpty_D <= FifoEmpty;
      ArbAck_D   <= ArbAck_N;
    end if;
  end process;

  RdAsyncProc : process (WriteReqAck, WasEmpty_D, FifoEmpty, ArbAck_D)
  begin
    ReadFifo <= '0';
    ArbAck_N <= ArbAck_D;

    if WriteReqAck = '1' then
      ArbAck_N <= '1';
    end if;

    if FifoEmpty = '0' then
      if WriteReqAck = '1' then
        ReadFifo <= '1';
        ArbAck_N <= '0';
      end if;
    end if;

    if WasEmpty_D = '1' and FifoEmpty = '0' then
      ReadFifo <= '1';
      ArbAck_N <= '0';
    end if;      
  end process;  
end architecture rtl;
