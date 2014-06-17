library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.VgaPack.all;

package DramTestPack is
  constant Byte               : positive              := 8;
  constant Nibble             : positive              := 4;
  --
  constant PixelW             : positive              := 8;
  --
  constant ColResW            : positive              := 3;
  --
  constant VgaPixels          : positive              := VgaRes * PixelW;
  --  
  --
  constant ASIZE              : integer               := 24;
  constant DSIZE              : integer               := 16;
  --
  constant COLSIZE            : integer               := 9;
  constant COLSTART           : integer               := 0;
  --
  constant ROWSIZE            : integer               := 12;
  constant ROWSTART           : integer               := COLSIZE;
  --
  constant BANKSIZE           : integer               := 2;
  constant BANKSTART          : integer               := COLSIZE + ROWSIZE;
  --
  constant VgaPixelsPerDword  : positive              := VgaPixels / DSIZE;
  constant VgaPixelsPerDwordW : positive              := bits(VgaPixelsPerDword);
  --
  constant Frames             : positive              := 3;
  constant FramesW            : positive              := bits(Frames);
  --
  constant BurstLen           : natural               := 8;
  constant BurstLenW          : positive              := bits(BurstLen);
  -- 8 * 16 = 128
  constant BurstSz            : natural               := BurstLen * DSIZE;
  -- 128 / 8 = 16
  constant PixelsPerBurst     : positive              := BurstSz / PixelW;
  -- 4
  constant PixelsPerBurstW    : positive              := bits(PixelsPerBurst);
  --
  type PixVec is array (3-1 downto 0) of word(PixelW-1 downto 0);
  type PixVec2D is array (natural range <>) of PixVec;
  --
  constant CmdW               : positive              := 3;
  constant DRAM_NOP           : word(CmdW-1 downto 0) := "000";
  constant DRAM_READA         : word(CmdW-1 downto 0) := "001";
  constant DRAM_WRITEA        : word(CmdW-1 downto 0) := "010";
  constant DRAM_REFRESH       : word(CmdW-1 downto 0) := "011";
  constant DRAM_PRECHARGE     : word(CmdW-1 downto 0) := "100";
  constant DRAM_LOAD_MODE     : word(CmdW-1 downto 0) := "101";
  constant DRAM_LOAD_REG1     : word(CmdW-1 downto 0) := "110";
  constant DRAM_LOAD_REG2     : word(CmdW-1 downto 0) := "111";

  constant tRCD     : positive := 2;
  constant tCL      : positive := 3;

  -- Best
  constant tRdDel   : positive := 2; -- Empirically derived

  constant NONE_MODE   : natural := 0;
  constant DITHER_MODE : natural := 1;
  constant SOBEL_MODE  : natural := 2;
  constant MEDIAN_MODE : natural := 3;
  constant MODES       : natural := MEDIAN_MODE + 1;
  constant MODESW      : natural := bits(MODES);
  
  constant RedHigh   : natural := 2;
  constant RedLow    : natural := 0;
  constant GreenHigh : natural := 5;
  constant GreenLow  : natural := 3;
  constant BlueHigh  : natural := 7;
  constant BlueLow   : natural := 6;
  
  type DramRequest is record
    Val  : word1;
    Data : word(DSIZE*BurstLen-1 downto 0);
    Cmd  : word(CmdW-1 downto 0);
    Addr : word(ASIZE-1 downto 0);
  end record;

  constant Z_DramRequest : DramRequest :=
    (Val  => (others => '0'),
     Data => (others => 'X'),
     Cmd  => DRAM_NOP,
     Addr => (others => 'X'));
  -- 1 + 128 + 3 + 24 = 156
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
    i := W'length;
    j := i - R.Addr'length; R.Addr := W(i-1 downto j); i := j;
    j := i - R.Cmd'length; R.Cmd := W(i-1 downto j); i := j;
    j := i - R.Data'length; R.Data := W(i-1 downto j); i := j;
    j := i - R.Val'length; R.Val := W(i-1 downto j); i := j;
    assert i = 0 report "Word to record mismatch" severity failure;
    return R;
  end function;
end package body;
