library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;

entity FakeVgaCam is
  port (
    RstN  : in  bit1;
    Clk   : in  bit1;
    --
    VSync : out bit1;
    HRef  : out bit1;
    D     : out word(8-1 downto 0)
    );
end entity;

architecture rtl of FakeVgaCam is
  constant tClk  : positive := 1;
  constant tP    : positive := 2 * tClk;
  constant tLine : positive := tP * 784;

  constant tVsyncPeriod : positive := tLine * 510;
  constant tVsyncHigh   : positive := 4;

  constant tHrefPreamble  : positive := tVsyncHigh + 11;
  constant tHrefPostamble : positive := 15;
  constant noHrefs        : positive := 480;

  constant tHrefHigh   : positive := 640 * tP;
  constant tHrefLow    : positive := 144 * tP;
  constant tHrefPeriod : positive := tHrefHigh + tHrefLow;

  signal clkCnt  : word(bits(tVsyncPeriod)-1 downto 0);
  signal lineCnt : word(bits(tVsyncPeriod / tLine)-1 downto 0);
  signal pixCnt  : word(bits(tLine)-1 downto 0);

  signal D_N, D_D                         : word(8-1 downto 0);
  signal vsync_N, vsync_D, href_N, href_D : bit1;
begin
  Sync : process (Clk, RstN)
  begin
    if RstN = '0' then
      clkCnt  <= (others => '0');
      D_D     <= (others => '0');
      vsync_D <= '0';
      href_D  <= '0';
    elsif rising_edge(Clk) then
      D_D     <= D_N;
      vsync_D <= vsync_N;
      href_D  <= href_N;
      
      clkCnt <= clkCnt + 1;
      if (clkCnt = tVsyncPeriod-1) then
        clkCnt <= (others => '0');
      end if;
    end if;
  end process;

  lineCnt <= conv_word(conv_integer(clkCnt) / tLine, lineCnt'length);
  pixCnt  <= conv_word(conv_integer(clkCnt) mod tLine, pixCnt'length);

  Async : process (lineCnt, pixCnt)
  begin
    vsync_N <= '0';
    href_N  <= '0';
    D_N     <= (others => '0');

    if (lineCnt < tVsyncHigh) then
      vsync_N <= '1';
    end if;
    
    if (conv_integer(lineCnt) >= tHrefPreamble and
        (conv_integer(lineCnt) < (tVsyncPeriod - tHrefPostamble))) then
      if (pixCnt < tHrefHigh) then
        href_N <= '1';
        D_N    <= pixCnt(D'range);
      end if;
    end if;
  end process;

  D     <= D_D;
  
  HRef <= HRef_D;
  vsync <= VSync_D;
end architecture rtl;
