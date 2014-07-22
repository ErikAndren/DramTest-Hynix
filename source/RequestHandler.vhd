library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;
use work.SerialPack.all;

entity RequestHandler is
  port (
    WrClk       : in  bit1;
    WrRstN      : in  bit1;
    --
    ReqIn       : in  DramRequest;
    We          : in  bit1;
    ShapBp      : out bit1;
    --
    RegAccessIn : in  RegAccessRec;
    --
    RdClk       : in  bit1;
    RdRst_N     : in  bit1;
    ReqOut      : out DramRequest;
    ReqDataOut  : out word(DSIZE-1 downto 0);
    CmdAck      : in  bit1;
    --
    RespVal     : out bit1
    );
end entity;

architecture rtl of RequestHandler is
  signal ReqInWord, ReqOutWord                : word(DramRequestW-1 downto 0);
  signal WrFull_i                             : bit1;
  --
  signal ReadFifo, FifoEmpty                  : bit1;
  signal CmdMask_N, CmdMask_D                 : bit1;
  signal ReqIn_i, ReqOut_i                    : DramRequest;
  --
  constant tReadWait                          : positive := tRCD + tCL + tRdDel;
  constant tPostWait                          : natural  := 0;
  constant tReadWaitAndBurst                  : positive := tReadWait + BurstLen + tPostWait;
  constant ReadPenalty                        : positive := tReadWaitAndBurst;
  constant ReadPenaltyW                       : positive := bits(ReadPenalty);
  --
  constant WritePenalty                       : positive := BurstLen + 2;
  --
  constant WritePenaltyW                      : positive := bits(WritePenalty);
  signal WritePenaltySet_N, WritePenaltySet_D : word(WritePenaltyW-1 downto 0);
  --
  signal WritePenalty_N, WritePenalty_D       : word(WritePenaltyW-1 downto 0);
  --
  signal ReadPenalty_N, ReadPenalty_D         : word(ReadPenaltyW-1 downto 0);
  signal ReadPenaltySet_N, ReadPenaltySet_D   : word(ReadPenaltyW-1 downto 0);
  --
  signal RegAccessIn_D                        : RegAccessRec;
  
  type DramInitStates is (INIT, DO_PRECHARGE, DO_LOAD_MODE, DO_LOAD_REG2, DO_LOAD_REG1, DONE);
  
  signal InitFSM_N, InitFSM_D : DramInitStates;
  signal InitReq              : DramRequest;
  signal We_i                 : bit1;
begin
  WrSyncProc : process (WrClk, WrRstN)
  begin
    if WrRstN = '0' then
      InitFsm_D <= INIT;
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
        InitReq.Val  <= "1";
        InitReq.Addr <= (others => '0');
        InitReq.Cmd  <= DRAM_PRECHARGE;
        InitFsm_N    <= DO_LOAD_MODE;
        
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

        -- RCD 2
        InitReq.Addr(3 downto 2) <= "10";

        -- RRD 2
        InitReq.Addr(7 downto 4) <= "0010";

        -- Page mode normal
        InitReq.Addr(8) <= '0';

        -- Burst length 8
        InitReq.Addr(12 downto 9) <= "1000";
        
        InitFsm_N <= DONE;
        
      when others =>
        null;
    end case;
  end process;

  We_i <= InitReq.Val(0) or We;

  ReqMux  : ReqIn_i   <= InitReq when InitReq.Val = "1" else ReqIn;
  ReqConv : ReqInWord <= DramRequestToWord(ReqIn_i);

  ShapBp <= InitReq.Val(0) or WrFull_i;

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
      CmdMask_D         <= '1';
      ReadPenalty_D     <= (others => '0');
      WritePenalty_D    <= (others => '0');
      WritePenaltySet_D <= conv_word(WritePenalty, WritePenaltyW);
      ReadPenaltySet_D  <= conv_word(ReadPenalty, ReadPenaltyW);
    elsif rising_edge(RdClk) then
      CmdMask_D         <= CmdMask_N;
      ReadPenalty_D     <= ReadPenalty_N;
      WritePenalty_D    <= WritePenalty_N;
      WritePenaltySet_D <= WritePenaltySet_N;
      ReadPenaltySet_D  <= ReadPenaltySet_N;
    end if;
  end process;

  ReadFifoProc : process (FifoEmpty, ReqOut_i, ReadPenalty_D, CmdAck, CmdMask_D, WritePenalty_D)
  begin
    ReadFifo          <= '0';

    if FifoEmpty = '0' then
      if ReqOut_i.Cmd = DRAM_WRITEA and CmdMask_D = '1' then
        if WritePenalty_D = 0 then
          ReadFifo <= '1';
        end if;
      elsif ReqOut_i.Cmd = DRAM_READA and CmdMask_D = '1' then
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

  RegAccessClkTran : block
    signal RegAccessInWord    : word(RegAccessRecW downto 0);
    signal ReadRegFifo        : bit1;
    signal RegAccessFifoEmpty : bit1;
    signal RegAccessIn_RdClk  : word(RegAccessRecW downto 0);
  begin
    RegAccessInWord <= '0' & RegAccessRecToWord(RegAccessIn);
    -- 2 port fifo for reg access
    RegAccessF : entity work.RegAccessFifo
      port map (
        data    => RegAccessInWord,
        wrclk   => WrClk,
        wrreq   => RegAccessIn.Val(0),
        --
        rdclk   => RdClk,
        rdreq   => ReadRegFifo,
        q       => RegAccessIn_RdClk,
        rdempty => RegAccessFifoEmpty,
        wrfull  => open
        );
    
    ReadRegFifo   <= not RegAccessFifoEmpty;
    RegAccessIn_D <= WordToRegAccessRec(RegAccessIn_RdClk(66-1 downto 0));
  end block;

  ReadOutProc : process (CmdAck, CmdMask_D, ReqOut_i, ReadPenalty_D, FifoEmpty, ReadFifo, WritePenalty_D, WritePenaltySet_D, ReadPenaltySet_D, RegAccessIn_D)
  begin
    WritePenaltySet_N <= WritePenaltySet_D;
    ReadPenaltySet_N  <= ReadPenaltySet_D;
    CmdMask_N         <= CmdMask_D;
    ReqDataOut        <= (others => 'X');
    ReadPenalty_N     <= ReadPenalty_D;
    WritePenalty_N    <= WritePenalty_D;
    RespVal           <= '0';

    if RegAccessIn_D.Val = "1" then
      if RegAccessIn_D.Addr = ReqHandlerWrPenReg then
        WritePenaltySet_N <= RegAccessIn_D.Data(WritePenaltyW-1 downto 0);
      elsif RegAccessIn_D.Addr = ReqHandlerRdPenReg then
        ReadPenaltySet_N <= RegAccessIn_D.Data(ReadPenaltyW-1 downto 0);
      end if; 
    end if;
    
    -- Clear mask upon reading new entry
    If ReadFifo = '1' then
      CmdMask_N <= '0';
    end if;

    if (WritePenalty_D > 0) then
      WritePenalty_N <= WritePenalty_D - 1;
    end if;

    if ReadPenalty_D > 0 then
      ReadPenalty_N <= ReadPenalty_D - 1;

      -- Signal to response chain to sample responses
      if (ReadPenalty_D <= BurstLen + tPostWait) and (ReadPenalty_D > tPostWait) then
        RespVal <= '1';
      end if;
    end if;

    -- Split write word into 16 bit chunks
    if (conv_integer(WritePenalty_D) > (WritePenalty - BurstLen)) then
      -- Send lowest pixel first
      ReqDataOut <= ExtractSlice(ReqOut_i.Data, DSIZE, BurstLen - (conv_integer(WritePenalty_D) - (WritePenalty - BurstLen)));
    end if;
    
    if CmdAck = '1' then
      if ReqOut_i.Cmd = DRAM_WRITEA then
        WritePenalty_N <= WritePenaltySet_D;
      elsif ReqOut_i.Cmd = DRAM_READA then
        ReadPenalty_N <= ReadPenaltySet_D;
      end if;

      -- Mask command after controller ack
      CmdMask_N      <= '1';
    end if;
  end process;
end architecture rtl;
