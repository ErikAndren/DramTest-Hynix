library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

entity tb is 
end entity;

architecture rtl of tb is
  signal RstN : bit1;
  signal Clk50MHz : bit1;

  signal SdramSA    : word(12-1 downto 0);
  signal SdramBA    : word(2-1 downto 0);
  signal SdramCS_N  : word(1-1 downto 0);
  signal SdramCKE   : bit1;
  signal SdramRAS_N : bit1;
  signal SdramCAS_N : bit1;
  signal SdramWE_N  : bit1;
  signal SdramDQ    : word(DSIZE-1 downto 0);
  signal SdramDQM   : word(DSIZE/8-1 downto 0);
  signal SdramClk   : bit1;
  
begin
  RstN <= '0', '1' after 100 ns;

  ClkGen : process
  begin
    while true loop
      Clk50MHz <= '0';
      wait for 10 ns;
      Clk50MHz <= '1';
      wait for 10 ns;
    end loop;
  end process;
  
  dut : entity work.DramTestTop
    port map (
      AsyncRst   => RstN,
      Clk        => Clk50MHz,
      --
      SdramSa    => SdramSa,
      SdramBA    => SdramBA,
      SdramCS_N  => SdramCS_N,
      SdramCKE   => SdramCKE,
      SdramRAS_N => SdramRAS_N,
      SdramCAS_N => SdramCAS_N,
      SdramWE_N  => SdramWE_N,
      SdramDQ    => SdramDQ,
      SdramDQM   => SdramDQM,
      SdramClk   => SdramClk,
      --
      VgaRed     => open,
      VgaGreen   => open,
      VgaBlue    => open,
      VgaHsync   => open,
      VgaVSync   => open
      );

  sdram : entity work.mt48lc16m16a2
    port map (
      Dq    => SdramDQ,
      Addr  => SdramSa,
      Ba    => SdramBA,
      Clk   => SdramClk,
      Cke   => SdramCKE,
      Cs_n  => SdramCS_N,
      Ras_N => SdramRAS_N,
      Cas_N => SdramCAS_N,
      We_N  => SdramWE_N,
      DQM   => SdramDQM
      );
  
end architecture rtl;
