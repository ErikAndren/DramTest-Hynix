library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;
use work.SramPack.all;

entity tb is 
end entity;

architecture rtl of tb is
  signal RstN         : bit1;
  signal Clk50MHz     : bit1;
  signal CamClk       : bit1;
  --
  signal SIO_D        : bit1;
  --
  signal CamVSync     : bit1;
  signal CamHRef      : bit1;
  signal CamD         : word(8-1 downto 0);
  --
  signal SdramSA      : word(12-1 downto 0);
  signal SdramBA      : word(2-1 downto 0);
  signal SdramCS_N    : word(1-1 downto 0);
  signal SdramCs_NBit : bit1;
  signal SdramCKE     : bit1;
  signal SdramRAS_N   : bit1;
  signal SdramCAS_N   : bit1;
  signal SdramWE_N    : bit1;
  signal SdramDQ      : word(DSIZE-1 downto 0);
  signal SdramDQM     : word(DSIZE/8-1 downto 0);
  signal SdramClk     : bit1;
  signal SdramClk_Del : bit1;
  --
  signal SramD        : word(SramDataW-1 downto 0);
  signal SramCeN      : bit1;
  signal SramOeN      : bit1;
  signal SramWeN      : bit1;  
  signal SramCnt      : word(SramDataW-1 downto 0);

begin
  RstN <= '0', '1' after 100 ns;

  SdramDQ <= (others => 'Z');

  SdramClk_Del <= transport SdramClk after 5 ns;  
  
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
      VgaVSync   => open,
      --
      SIO_C      => open,
      SIO_D      => SIO_D,
      --
      CamClk     => CamClk,
      CamHref    => CamHref,
      CamVSync   => CamVSync,
      CamD       => CamD,
      --
      Button1   => '1',
      Button2   => '1',
      Button3   => '1',      
      --
      SramD      => SramD,
      SramAddr   => open,
      SramCeN    => SramCeN,
      SramOeN    => SramOeN,
      SramWeN    => SramWeN,
      SramUbN    => open,
      SramLbN    => open
      );

  SramCntProc : process (RstN, SramCeN)
  begin
    if RstN = '0' then
      SramCnt <= (others => '0');
    elsif falling_edge(SramCeN) then
      if SramWeN = '1' then
        SramCnt <= SramCnt + 1;
      end if;
    end if;
  end process;
 
  SramD <= SramCnt when SramOeN = '1' else (others => 'Z');

  FakeCam : entity work.FakeVgaCam
    port map (
      RstN  => RstN,
      Clk   => CamClk,
      --
      VSync => CamVSync,
      HRef  => CamHref,
      D     => CamD
      );
  
  SdramCs_NBit <= SdramCS_N(0);

  sdram : entity work.H57V2562GTR
    generic map (
      addr_bits => 12
      )
    port map (
      Dq    => SdramDQ,
      Addr  => SdramSa,
      Ba    => SdramBA,
      Clk   => SdramClk_Del,
      Cke   => SdramCKE,
      Cs_n  => SdramCS_NBit,
      Ras_N => SdramRAS_N,
      Cas_N => SdramCAS_N,
      We_N  => SdramWE_N,
      DQM   => SdramDQM
      );
  
end architecture rtl;
