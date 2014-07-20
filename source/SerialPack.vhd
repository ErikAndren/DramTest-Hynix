library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;


package SerialPack is
  constant NewLine   : word(8-1 downto 0) := x"0A";
  constant WriteCmd  : word(8-1 downto 0) := x"57";
  constant ReadCmd   : word(8-1 downto 0) := x"52";
  constant SpaceChar : word(8-1 downto 0) := x"20";
  --
  constant W         : word(8-1 downto 0) := x"57";
  constant Space     : word(8-1 downto 0) := x"20";
  
  type RegCmd is (REG_READ, REG_WRITE);
  constant AddrW : positive := 32;
  constant DataW : positive := 32;

  constant SccbOffset         : natural  := 16#010000#;
  --
  constant ColorSelectReg     : natural  := 16#00000001#;
  constant ColorToggle        : natural  := 0;
  
  constant TemporalFilterReg   : natural  := 16#00000002#;
  --
  constant ConvFilterThresReg  : natural  := 16#00000010#;
  constant ConvFilterThresW    : positive := 3;
  --
  constant FilterSelectReg     : natural  := 16#00000020#;
  constant NONE_MODE           : natural  := 0;
  constant DITHER_MODE         : natural  := 1;
  constant SOBEL_MODE          : natural  := 2;
  constant MEDIAN_MODE         : natural  := 3;
  constant MODES               : natural  := MEDIAN_MODE + 1;
  constant MODESW              : natural  := bits(MODES);
  --
  constant PixelSampleOrderReg : natural  := 16#00000030#;
  constant PixelSampleOrder    : natural  := 0;
  --
  constant EnableTrackRectReg  : natural  := 16#00000040#;
  constant EnableTrackRect     : natural  := 0;
  
  type RegAccessRec is record
    Val  : word1;
    Cmd  : RegCmd;
    Addr : word(AddrW-1 downto 0);
    Data : word(DataW-1 downto 0);
  end record;

  constant Z_RegAccessRec : RegAccessRec :=
    (Val  => "0",
     Data => (others => '0'),
     Cmd  => REG_READ,
     Addr => (others => '0')
     );  
  
end package;

package body SerialPack is

end package body;
