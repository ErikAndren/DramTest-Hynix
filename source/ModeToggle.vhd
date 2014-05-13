-- Override all filtering if color is selected

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;

entity ModeToggle is
  generic (
    DataW : positive
    );
    port (
      Clk                   : in  bit1;
      RstN                  : in  bit1;
      --
      TemporalFiltToggle    : in  bit1;
      ColorToggle           : in  bit1;
      --
      FromTempFiltValPreMux : in  bit1;
      FromTempFiltPreMux    : in  word(DataW-1 downto 0);
      --
      TempFiltValPostMux    : out bit1;
      TempFiltPostMux       : out word(DataW-1 downto 0);
      --
      ObjFindPixPreMux      : in  word(DataW-1 downto 0);
      ObjFindPixValPreMux   : in  bit1;
      --
      GrayScaleIn           : in  word(DataW-1 downto 0);
      GrayScaleVal          : in  bit1;
      --
      ColorIn               : in  word(DataW-1 downto 0);
      ColorVal              : in  bit1;
      --
      PixelValPostMux       : out bit1;
      PixelPostMux          : out word(DataW-1 downto 0)
      );
end entity;

architecture rtl of ModeToggle is
  signal TempFilt_N, TempFilt_D : bit1;
  signal ColSel_N, ColSel_D     : bit1;
begin
  SyncProc : process (Clk, RstN)
  begin
    if RstN = '0' then
      TempFilt_D <= '1';
      ColSel_D   <= '0';
    elsif rising_edge(Clk) then
      TempFilt_D <= TempFilt_N;
      ColSel_D   <= ColSel_N;
    end if;
  end process;

  AsyncProc : process (TempFilt_D, TemporalFiltToggle, ColSel_D)
  begin
    TempFilt_N <= TempFilt_D;
    ColSel_N   <= ColSel_D;
    
    if TemporalFiltToggle = '1' then
      TempFilt_N <= not TempFilt_D;
    end if;

    if ColorToggle = '1' then
      ColSel_N <= not ColSel_D;
    end if;
  end process;

  -- Select if to enable temporal filtering
  TempFiltValPostMux <= FromTempFiltValPreMux when TempFilt_D = '1' else GrayScaleVal;
  TempFiltPostMux    <= FromTempFiltPreMux    when TempFilt_D = '1' else GrayScaleIn;

  -- Select color or not
  PixelValPostMux    <= ColorVal              when ColSel_D = '1'   else ObjFindPixValPreMux;
  PixelPostMux       <= ColorIn               when ColSel_D = '1'   else ObjFindPixPreMux;

end architecture rtl;
