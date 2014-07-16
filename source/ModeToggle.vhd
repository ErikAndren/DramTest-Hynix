-- Override all filtering if color is selected

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.SerialPack.all;

entity ModeToggle is
  generic (
    DataW : positive
    );
  port (
    Clk                   : in  bit1;
    RstN                  : in  bit1;
    --
    TemporalFiltToggle    : in  bit1;
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
    PixelPostMux          : out word(DataW-1 downto 0);
    --
    RegAccessIn           : in  RegAccessRec
    );
end entity;

architecture rtl of ModeToggle is
  signal TempFilt_N, TempFilt_D   : bit1;
  signal ColSel_N, ColSel_D       : bit1;
  signal Delay_N, Delay_D         : word(20-1 downto 0);
  signal DelayDone_N, DelayDone_D : bit1;
begin
  SyncProc : process (Clk, RstN)
  begin
    if RstN = '0' then
      TempFilt_D  <= '0';
      ColSel_D    <= '0';
      Delay_D     <= (others => '1');
      DelayDone_D <= '0';
    elsif rising_edge(Clk) then
      TempFilt_D  <= TempFilt_N;
      ColSel_D    <= ColSel_N;
      Delay_D     <= Delay_N;
      DelayDone_D <= DelayDone_N;
    end if;
  end process;

  AsyncProc : process (TempFilt_D, TemporalFiltToggle, ColSel_D, Delay_D, DelayDone_D, RegAccessIn)
  begin
    TempFilt_N  <= TempFilt_D;
    ColSel_N    <= ColSel_D;
    DelayDone_N <= DelayDone_D;

    Delay_N <= Delay_D - 1;
    if Delay_D = 0 then
      Delay_N <= (others => '0');
      DelayDone_N <= '1';
    end if;

    -- Protect against initial spikes
    if DelayDone_D = '1' then
      if TemporalFiltToggle = '1' then
        TempFilt_N <= not TempFilt_D;
      end if;

      if RegAccessIn.Val = "1" then
        if RegAccessIn.Cmd = REG_WRITE and (RegAccessIn.Addr = ColorSelectReg) then
          ColSel_N <= RegAccessIn.Data(0);
        end if;
      end if;      
    end if;
  end process;

  -- Select if to enable temporal filtering
  TempFiltValPostMux <= FromTempFiltValPreMux when TempFilt_D = '1' else GrayScaleVal;
  TempFiltPostMux    <= FromTempFiltPreMux    when TempFilt_D = '1' else GrayScaleIn;

  -- Select color or not
  PixelValPostMux    <= ColorVal              when ColSel_D = '1'   else ObjFindPixValPreMux;
  PixelPostMux       <= ColorIn               when ColSel_D = '1'   else ObjFindPixPreMux;

end architecture rtl;
