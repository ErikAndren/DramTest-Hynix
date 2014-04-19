library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

entity DramTestTop is
  port (
    AsyncRst   : in    bit1;
    Clk        : in    bit1;
   -- Here goes dram interface
    SdramSA    : out   word(12-1 downto 0);
    SdramBA    : out   word(2-1 downto 0);
    SdramCS_N  : out   word(1-1 downto 0);
    SdramCKE   : out   bit1;
    SdramRAS_N : out   bit1;
    SdramCAS_N : out   bit1;
    SdramWE_N  : out   bit1;
    SdramDQ    : inout word(DSIZE-1 downto 0);
    SdramDQM   : out   word(DSIZE/8-1 downto 0)
    );
end entity;

architecture rtl of DramTestTop is
  signal Clk100MHz  : bit1;
  signal RstN100MHz : bit1;
  --
  signal Clk50MHz    : bit1;
  signal RstN50MHz   : bit1;

  signal SdramAddr     : word(ASIZE-1 downto 0);
  signal SdramCmd      : word(3-1 downto 0);
  signal SdramCmdAck   : bit1;
  --
  signal SdramDataIn   : word(DSIZE-1 downto 0);
  signal SdramDataOut  : word(DSIZE-1 downto 0);
  --
  signal SdramDataMask : word(DSIZE/8-1 downto 0);  

  signal SdramCS_N_i : word(2-1 downto 0);

  signal ReqFromArb              : DramRequest;
  signal ReqFromArbWe            : bit1;
  --
  signal ReqToCont               : DramRequest;
  signal ContCmdAck              : bit1;
  --
  signal WriteReqFromPatGen      : DramRequest;
  signal WriteReqFromPatGenAck   : bit1;
  --
  signal ReadReqFromRespHdler    : DramRequest;
  signal ReadReqFromRespHdlerAck : bit1;
  
begin
  -- Pll
  Pll100MHz : entity work.PLL
    port map (
      AReset => AsyncRst,
      inclk0 => Clk,
      c0     => Clk100MHz
      );

  ClkDiv : entity work.ClkDiv
    generic map (
      SourceFreq => 100,
      SinkFreq   => 50
      )
    port map (
      Clk => Clk100MHz,
      RstN => RstN100MHz,
      --
      Clk_out => Clk50MHz
      );

  -- Reset synchronizer
  RstSync100Mhz : entity work.ResetSync
    port map (
      AsyncRst => AsyncRst,
      Clk      => Clk100MHz,
      --
      Rst_N    => RstN100MHz
      );

  RstSync50Mhz : entity work.ResetSync
    port map (
      AsyncRst => AsyncRst,
      Clk      => Clk50MHz,
      --
      Rst_N    => RstN50MHz
      );

  -- Write data generator, will later be camera

  -- Response handler
  
  SdramArb : entity work.SdramArbiter
    port map (
      Clk         => Clk50MHz,
      Rst_N       => RstN50MHz,
      --
      WriteReq    => WriteReqFromPatGen,
      WriteReqAck => WriteReqFromPatGenAck,
      --
      ReadReq     => ReadReqFromRespHdler,
      ReadReqAck  => ReadReqFromRespHdlerAck,
      --
      ArbDecReq   => ReqFromArb,
      ArbDecVal   => ReqFromArbWe
      );

  -- Dram data generator and consumer
  ReqHdler : entity work.RequestHandler
    port map (
      Rst_N  => RstN100MHz, -- FIXME: Hook this up properly
      --
      WrClk  => Clk50MHz,
      ReqIn  => ReqFromArb,
      We     => ReqFromArbWe,
      --
      RdClk  => Clk100MHz,
      ReqOut => ReqToCont,
      Re     => ContCmdAck
      );

  -- Dram controller
  SdramController : entity work.sdr_sdram
    generic map (
      ASIZE     => ASIZE,
      DSIZE     => DSIZE,
      ROWSIZE   => ROWSIZE,
      COLSIZE   => COLSIZE,
      BANKSIZE  => BANKSIZE,
      ROWSTART  => ROWSTART,
      COLSTART  => COLSTART,
      BANKSTART => BANKSTART
      )
    port map (
      Clk              => Clk100MHz,
      Reset_N          => RstN100MHz,
      --
      ADDR             => SdramAddr,
      CMD              => SdramCmd,
      CMDACK           => SdramCmdAck,
      --
      DATAIN           => SdramDataIn,
      DATAOUT          => SdramDataOut,
      DM               => SdramDataMask,
      --
      SA               => SdramSA,
      BA               => SdramBA,
      CS_N             => SdramCS_N_i,
      CKE              => SdramCKE,
      RAS_N            => SdramRAS_N,
      CAS_N            => SdramCAS_N,
      WE_N             => SdramWE_N,
      DQ               => SdramDQ,
      DQM              => SdramDQM
      );
  SdramCs_N <= SdramCs_N_i(0 downto 0);

  
  
end architecture rtl;
