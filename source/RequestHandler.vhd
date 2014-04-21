library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

entity RequestHandler is
  port (
    WrClk      : in  bit1;
    ReqIn      : in  DramRequest;
    We         : in  bit1;
    --
    RdClk      : in  bit1;
    RdRst_N    : in  bit1;
    ReqOut     : out DramRequest;
    ReqDataOut : out word(DSIZE-1 downto 0);
    CmdAck      : in  bit1
    );
end entity;

architecture rtl of RequestHandler is
  signal ReqInWord, ReqOutWord : word(DramRequestW-1 downto 0);
  signal WrFull_i              : bit1;
  --
  signal WordCnt_N, WordCnt_D  : word(BurstLenW-1 downto 0);

  constant WritePenalty                 : positive := tRCD - 2;
  constant WritePenaltyW                : positive := bits(WritePenalty);
  --
  signal WritePenalty_N, WritePenalty_D : word(WritePenaltyW-1 downto 0);
  signal ReadFifo, FifoEmpty            : bit1;
  signal CmdMask_N, CmdMask_D           : bit1;
  signal ReqOut_i : DramRequest;
  
begin
  ReqInWord <= DramRequestToWord(ReqIn);
  
  RequestFifo : entity work.ReqFifo
    port map (
      Data    => ReqInWord,
      WrClk   => WrClk,
      WrReq   => We,
      --
      RdClk   => RdClk,
      RdReq   => ReadFifo,
      RdEmpty => FifoEmpty,
      Q       => ReqOutWord,
      wrfull  => WrFull_i
    );
  
  assert not (WrFull_i = '1' and We = '1') report "Request fifo overflow" severity failure;

  ReqOut_i <= WordToDramRequest(ReqOutWord);

  -- Must mask dram request out after ack
  ReqOut <= ReqOut_i when CmdMask_D = '0' else Z_DramRequest;

  RdSyncProc : process (RdClk, RdRst_N)
  begin
    if RdRst_N = '0' then
      WordCnt_D      <= (others => '0');
      WritePenalty_D <= (others => '0');
      CmdMask_D      <= '1';
    elsif rising_edge(RdClk) then
      WordCnt_D      <= WordCnt_N;
      WritePenalty_D <= WritePenalty_N;
      CmdMask_D      <= CmdMask_N;
    end if;
  end process;

  ReadFifo <= '1' when WordCnt_D = 0 and FifoEmpty = '0' else '0';
  
  ReadOutProc : process (WordCnt_D, WritePenalty_D, CmdAck, ReadFifo, CmdMask_D, ReqOut_i)
  begin
    WordCnt_N      <= WordCnt_D;
    WritePenalty_N <= WritePenalty_D;
    CmdMask_N      <= CmdMask_D;
	 ReqDataOut     <= (others => 'X');

    if ReadFifo = '1' then
      CmdMask_N <= '0';
    end if;

    if WritePenalty_D > 0 then
      WritePenalty_N <= WritePenalty_D - 1;
    end if;
    --
    -- Split write word into 16 bit chunks
    if (WordCnt_D > 0) and (WritePenalty_D = 0) then
      ReqDataOut <= ExtractSlice(ReqOut_i.Data, DSIZE, WordCnt_D);
      WordCnt_N  <= WordCnt_D - 1;
    end if;
    
    if CmdAck = '1' then
      WordCnt_N      <= conv_word(BurstLen, WordCnt_N'length);
      WritePenalty_N <= conv_word(WritePenalty, WritePenalty_N'length);
      -- Mask command after controller ack
      CmdMask_N      <= '1';
    end if;
  end process;

  
end architecture rtl;
