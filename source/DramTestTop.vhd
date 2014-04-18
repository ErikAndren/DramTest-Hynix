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

  signal SdramAddr     : word(ASIZE-1 downto 0);
  signal SdramCmd      : word(3-1 downto 0);
  signal SdramCmdAck   : bit1;
  --
  signal SdramDataIn   : word(DSIZE-1 downto 0);
  signal SdramDataOut  : word(DSIZE-1 downto 0);
  --
  signal SdramDataMask : word(DSIZE/8-1 downto 0);  

  signal SdramCS_N_i : word(2-1 downto 0);
  
begin
  -- Reset synchronizer
  RstSync100Mhz : entity work.ResetSync
    port map (
      AsyncRst => AsyncRst,
      Clk      => Clk100MHz,
      --
      Rst_N    => RstN100MHz
      );

  -- Pll
  Pll100MHz : entity work.PLL
    port map (
      AReset => AsyncRst,
      inclk0 => Clk,
      c0     => Clk100MHz
      );

  -- Dram data generator and consumer

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
