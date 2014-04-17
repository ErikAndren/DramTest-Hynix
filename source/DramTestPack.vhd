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

end package;

package body DramTestPack is

end package body;
