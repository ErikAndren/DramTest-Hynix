-- Implements median filter
-- Sorts all entries and selects the median value
-- Optimized comparator tree picked from
-- www.ijetae.com ISSN 2250-2459, Vol 2, Issue 8, Aug 2012. Fig 5
--
-- Copyright Erik Zachrisson - erik@zachrisson.info


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

entity Comparator is
  generic (
    DataW : positive
    );
  port (
    X      : in  word(DataW-1 downto 0);
    Y      : in  word(DataW-1 downto 0);
    --
    Higher : out word(DataW-1 downto 0);
    Lower  : out word(DataW-1 downto 0)
    );
end entity;

architecture rtl of Comparator is
begin
  CompProc : process (X, Y) is
  begin
    if X > Y then
      Higher <= X;
      Lower  <= Y;
    else
      Higher <= Y;
      Lower  <= X;
    end if;
  end process;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

entity MedianFilter is
  generic (
    DataW : in positive;
    Res   : in positive
    );
  port (
    Clk         : in  bit1;
    RstN        : in  bit1;
    --
    PixelIn     : in  PixVec2d(Res-1 downto 0);
    PixelInVal  : in  bit1;
    --
    PixelOut    : out word(DataW-1 downto 0);
    PixelOutVal : out bit1
    );
end entity;

architecture rtl of MedianFilter is
  signal PixelOut_N, PixelOut_D       : word(DataW-1 downto 0);
  signal PixelOutVal_N, PixelOutVal_D : bit1;
  signal PixelOutVal_D2 : bit1;

  signal A_H, A_L, B_H, B_L, C_H, C_L, D_H, D_L, E_H, E_L, F_H, F_L : word(PixelW-1 downto 0);
  signal G_H, G_L, H_H, H_L, I_H, I_L, J_L, K_H, K_L, L_H           : word(PixelW-1 downto 0);
  signal M_L, N_H, O_H, Q_L, S_H, S_L, T_H                          : word(PixelW-1 downto 0);
  signal U_L, Median                                                : word(PixelW-1 downto 0);
  --
  signal J_L_D, I_H_D, K_H_D, K_L_D, I_L_D, D_L_D, L_H_D            : word(PixelW-1 downto 0);
  
begin
  A : entity work.Comparator generic map (DataW => DataW) port map (X => PixelIn(0)(0), Y => PixelIn(0)(1), Higher => A_H, Lower => A_L);
  B : entity work.Comparator generic map (DataW => DataW) port map (X => PixelIn(1)(0), Y => PixelIn(1)(1), Higher => B_H, Lower => B_L);
  C : entity work.Comparator generic map (DataW => DataW) port map (X => PixelIn(2)(0), Y => PixelIn(2)(1), Higher => C_H, Lower => C_L);
  --
  D : entity work.Comparator generic map (DataW => DataW) port map (X => PixelIn(0)(2), Y => A_L, Higher => D_H, Lower => D_L);
  E : entity work.Comparator generic map (DataW => DataW) port map (X => PixelIn(1)(2), Y => B_L, Higher => E_H, Lower => E_L);
  F : entity work.Comparator generic map (DataW => DataW) port map (X => PixelIn(2)(2), Y => C_L, Higher => F_H, Lower => F_L);
  --
  G : entity work.Comparator generic map (DataW => DataW) port map (X => A_H, Y => D_H, Higher => G_H, Lower => G_L);
  H : entity work.Comparator generic map (DataW => DataW) port map (X => B_H, Y => E_H, Higher => H_H, Lower => H_L);
  I : entity work.Comparator generic map (DataW => DataW) port map (X => C_H, Y => F_H, Higher => I_H, Lower => I_L);
  --
  J : entity work.Comparator generic map (DataW => DataW) port map (X => G_H, Y => H_H, Higher => open, Lower => J_L);
  K : entity work.Comparator generic map (DataW => DataW) port map (X => G_L, Y => H_L, Higher => K_H, Lower => K_L);
  L : entity work.Comparator generic map (DataW => DataW) port map (X => E_L, Y => F_L, Higher => L_H, Lower => open);
  --
  M : entity work.Comparator generic map (DataW => DataW) port map (X => J_L_D, Y => I_H_D, Higher => open, Lower => M_L);
  N : entity work.Comparator generic map (DataW => DataW) port map (X => K_L_D, Y => I_L_D, Higher => N_H, Lower => open);
  O : entity work.Comparator generic map (DataW => DataW) port map (X => D_L_D, Y => L_H_D, Higher => O_H, Lower => open);
  --
  Q : entity work.Comparator generic map (DataW => DataW) port map (X => K_H_D, Y => N_H, Higher => open, Lower => Q_L);
  S : entity work.Comparator generic map (DataW => DataW) port map (X => M_L, Y => Q_L, Higher => S_H, Lower => S_L);
  T : entity work.Comparator generic map (DataW => DataW) port map (X => S_L, Y => O_H, Higher => T_H, Lower => open);
  --
  U : entity work.Comparator generic map (DataW => DataW) port map (X => S_H, Y => T_H, Higher => open, Lower => U_L);

  MedianAssign : Median <= U_L;
  
  SyncRstProc : process (Clk, RstN)
  begin
    if RstN = '0' then
      PixelOutVal_D  <= '0';
      PixelOutVal_D2 <= '0';
    elsif rising_edge(Clk) then
      PixelOutVal_D  <= PixelOutVal_N;
      PixelOutVal_D2 <= PixelOutVal_D;
    end if;
  end process;

  SyncNoRstProc : process (Clk)
  begin
    if rising_edge(Clk) then
      PixelOut_D <= PixelOut_N;
      J_L_D      <= J_L;
      I_H_D      <= I_H;
      K_H_D      <= K_H;
      K_L_D      <= K_L;
      I_L_D      <= I_L;
      D_L_D      <= D_L;
      L_H_D      <= L_H;
    end if;
  end process;
  
  AsyncProc : process (PixelInVal, Median)
  begin
    PixelOutVal_N <= PixelInVal;
    PixelOut_N    <= Median;
  end process;

  PixelOut    <= PixelOut_D;
  PixelOutVal <= PixelOutVal_D2;
end architecture rtl;
