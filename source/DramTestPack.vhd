library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;

package DramTestPack is
  constant ASIZE     : integer := 23;
  constant DSIZE     : integer := 16;
  constant ROWSIZE   : integer := 12;
  constant COLSIZE   : integer := 9;
  constant BANKSIZE  : integer := 2;
  constant ROWSTART  : integer := 9;
  constant COLSTART  : integer := 0;
  constant BANKSTART : integer := 20;

  constant BurstLen : natural := 8;

  constant CmdW           : positive              := 3;
  constant DRAM_NOP       : word(CmdW-1 downto 0) := "000";
  constant DRAM_READA     : word(CmdW-1 downto 0) := "001";
  constant DRAM_WRITEA    : word(CmdW-1 downto 0) := "010";
  constant DRAM_REFRESH   : word(CmdW-1 downto 0) := "011";
  constant DRAM_PRECHARGE : word(CmdW-1 downto 0) := "100";
  constant DRAM_LOAD_MODE : word(CmdW-1 downto 0) := "101";
  constant DRAM_LOAD_REG1 : word(CmdW-1 downto 0) := "110";
  constant DRAM_LOAD_REG2 : word(CmdW-1 downto 0) := "111";
  
  type DramRequest is record
    Val  : word1;
    Data : word(DSIZE*BurstLen-1 downto 0);
    Cmd  : word(CmdW-1 downto 0);
    Addr : word(ASIZE-1 downto 0);
  end record;

  constant Z_DramRequest : DramRequest :=
    (Val  => (others => '0'),
     Data => (others => 'X'),
     Cmd  => (others => 'X'),
     Addr => (others => 'X'));
  -- 1 + 128 + 3 + 23 = 155
  constant DramRequestW : positive := Z_DramRequest.Val'length + Z_DramRequest.Data'length + Z_DramRequest.Cmd'length + Z_DramRequest.Addr'length;

  function DramRequestToWord(Rec : DramRequest) return word;
  function WordToDramRequest(W : word) return DramRequest;

end package;

package body DramTestPack is
  function DramRequestToWord(Rec : DramRequest) return word is
    variable res : word(DramRequestW-1 downto 0);
  begin
    res := Rec.Addr &
           Rec.Cmd &
           Rec.Data &
           Rec.Val;
    return res;
  end function;

  function WordToDramRequest(W : word) return DramRequest is
    variable R    : DramRequest;
    variable i, j : natural;
  begin
    i := W'length-1;
    j := i - R.Addr'length; R.Addr := W(i downto j); i := j;
    j := i - R.Cmd'length; R.Cmd := W(i downto j); i := j;
    j := i - R.Data'length; R.Data := W(i downto j); i := j;
    j := i - R.Val'length; R.Val := W(i downto j); i := j;
    assert i = 0 report "Word to record mismatch" severity failure;
    return R;
  end function;
end package body;
