library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

entity RequestHandler is
  port (
    WrClk      : in  bit1;
    WrRstN     : in  bit1;
    ReqIn      : in  DramRequest;
    We         : in  bit1;
    ShapBp     : out bit1;
    --
    RdClk      : in  bit1;
    RdRst_N    : in  bit1;
    ReqOut     : out DramRequest;
    ReqDataOut : out word(DSIZE-1 downto 0);
    CmdAck     : in  bit1;
    --
    RespVal    : out bit1
    );
end entity;

architecture rtl of RequestHandler is
  signal ReqInWord, ReqOutWord : word(DramRequestW-1 downto 0);
  signal WrFull_i              : bit1;
  --
  signal WordCnt_N, WordCnt_D  : word(BurstLenW downto 0);
  --
  signal ReadFifo, FifoEmpty            : bit1;
  signal CmdMask_N, CmdMask_D           : bit1;
  signal ReqIn_i, ReqOut_i              : DramRequest;
  --
  constant tReadWait                    : positive := tRCD + tCL + tRdDel;
  constant tReadWaitAndBurst            : positive := tReadWait + BurstLen;
  constant tReadWaitAndBurstW           : positive := bits(tReadWaitAndBurst);
  --
  signal ReadPenalty_N, ReadPenalty_D   : word(tReadWaitAndBurstW downto 0);

  type DramInitStates is (INIT, DO_PRECHARGE, DO_LOAD_MODE, DO_LOAD_REG2, DO_LOAD_REG1, DONE);
  
  signal InitFSM_N, InitFSM_D : DramInitStates;
  signal InitReq : DramRequest;
  signal We_i : bit1;
begin
  WrSyncProc : process (WrClk, WrRstN)
  begin
    if WrRstN = '0' then
      InitFsm_D <= DO_PRECHARGE;
    elsif rising_edge(WrClk) then
      InitFsm_D <= InitFsm_N;
    end if;
  end process;

  WrAsyncProc : process (InitFsm_D)
  begin
    InitReq   <= Z_DramRequest;
    InitFsm_N <= InitFsm_D;

    case InitFsm_D is
      when INIT =>
        InitFsm_N <= DO_PRECHARGE;
        
      when DO_PRECHARGE =>
        InitReq.Val <= "1";
        InitReq.Addr <= (others => '0');
        InitReq.Cmd <= DRAM_PRECHARGE;
        InitFsm_N   <= DO_LOAD_MODE;
        
      when DO_LOAD_MODE =>
        InitReq.Val <= "1";
        InitReq.Cmd <= DRAM_LOAD_MODE;

        InitReq.Addr <= (others => '0');

        -- CAS Latency 3
        InitReq.Addr(6 downto 4) <= "011";

        -- BL = 8
        InitReq.Addr(2 downto 0) <= "011";
        
        InitFsm_N <= DO_LOAD_REG2;
        
      when DO_LOAD_REG2 =>
        InitReq.Val <= "1";
        InitReq.Cmd <= DRAM_LOAD_REG2;

        -- set refresh rate 
        InitReq.Addr <= conv_word(1562, ASIZE);
        
        InitFsm_N <= DO_LOAD_REG1;
        
      when DO_LOAD_REG1 =>
        InitReq.Val <= "1";
        InitReq.Cmd <= DRAM_LOAD_REG1;

        InitReq.Addr <= (others => '0');

        -- CAS 3
        InitReq.Addr(1 downto 0) <= "11";

        -- RCD 3
        InitReq.Addr(3 downto 2) <= "11";

        -- RRD 2
        InitReq.Addr(7 downto 4) <= "0010";

        -- Page mode normal
        InitReq.Addr(8) <= '0';

        -- Burst length 8
        InitReq.Addr(12 downto 9) <= conv_word(8, 4);
        
        InitFsm_N <= DONE;
        
      when others =>
        null;
    end case;
  end process;

  We_i <= InitReq.Val(0) or We;

  ReqMux : ReqIn_i <= InitReq when InitReq.Val = "1" else ReqIn;
  ReqConv : ReqInWord        <= DramRequestToWord(ReqIn_i);

  ShapBp <= InitReq.Val(0);
  
  RequestFifo : entity work.ReqFifo
    port map (
      Data    => ReqInWord,
      WrClk   => WrClk,
      WrReq   => We_i,
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
  -- Must mask request if last entry
  ReqOut <= ReqOut_i when CmdMask_D = '0' else Z_DramRequest;

  RdSyncProc : process (RdClk, RdRst_N)
  begin
    if RdRst_N = '0' then
      WordCnt_D      <= (others => '0');
      CmdMask_D      <= '1';
      ReadPenalty_D  <= (others => '0');
    elsif rising_edge(RdClk) then
      WordCnt_D      <= WordCnt_N;
      CmdMask_D      <= CmdMask_N;
      ReadPenalty_D  <= ReadPenalty_N;
    end if;
  end process;

  ReadFifoProc : process (FifoEmpty, ReqOut_i, ReadPenalty_D, CmdAck, WordCnt_D, CmdMask_D)
  begin
    ReadFifo <= '0';

    if FifoEmpty = '0' then
      if ReqOut_i.Cmd = DRAM_WRITEA then
        if WordCnt_D = 0 then
          ReadFifo <= '1';
        end if;
      elsif ReqOut_i.Cmd = DRAM_READA then
        if ReadPenalty_D = 0 then
          ReadFifo <= '1';
        end if;
      else
        -- Read fifo if previous command was acknowledged
        if CmdMask_D = '1' then
          ReadFifo <= '1';
        end if;

        -- Autoload new value if empty
        if ReqOut_i.Val = "0" then
          ReadFifo <= '1';
        end if;
      end if;
    end if;
  end process;

  ReadOutProc : process (WordCnt_D, CmdAck, ReadFifo, CmdMask_D, ReqOut_i, ReadPenalty_D, FifoEmpty)
  begin
    WordCnt_N      <= WordCnt_D;
    CmdMask_N      <= CmdMask_D;
    ReqDataOut     <= (others => 'X');
    ReadPenalty_N  <= ReadPenalty_D;
    RespVal        <= '0';

    if FifoEmpty = '0' then
      CmdMask_N <= '0';
    end if;

    if ReadPenalty_D > 0 then
      ReadPenalty_N <= ReadPenalty_D - 1;

      -- Signal to response chain to sample responses
      if ReadPenalty_D <= BurstLen then
        RespVal <= '1';
      end if;
    end if;

    -- Split write word into 16 bit chunks
    if (WordCnt_D > 0) then
      -- ReqDataOut <= ExtractSlice(ReqOut_i.Data, DSIZE, WordCnt_D-1);
      -- Send lowest pixel first
      ReqDataOut <= ExtractSlice(ReqOut_i.Data, DSIZE, BurstLen - conv_integer(WordCnt_D));

      WordCnt_N  <= WordCnt_D - 1;
    end if;
    
    if CmdAck = '1' then
      if ReqOut_i.Cmd = DRAM_WRITEA then
        WordCnt_N <= conv_word(BurstLen, WordCnt_N'length);
      elsif ReqOut_i.Cmd = DRAM_READA then
        ReadPenalty_N <= conv_word(tReadWaitAndBurst, ReadPenalty_N'length);
      end if;

      -- Mask command after controller ack
      CmdMask_N      <= '1';
    end if;
  end process;
end architecture rtl;
