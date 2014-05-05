library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;

package ServoPack is

  constant ServoResW       : positive := 8;
  constant ServoRes        : positive := 2**ServoResW;
  constant MiddleServoPos  : positive := ServoRes / 2;
  --
  constant ServoPitchMin   : natural  := 20;
  constant ServoPitchMax   : positive := 120;
  constant ServoPitchStart : positive := 80;
  constant ServoPitchRange : positive := ServoPitchMax - ServoPitchMin;
  --
--  constant ServoYawMin     : natural  := 30;
    constant ServoYawMin     : natural  := 40;
  constant ServoYawMax     : positive := 80;
--  constant ServoYawMax     : positive := 120;
  constant ServoYawStart   : positive := 50;
  constant ServoYawRange   : positive := ServoYawMax - ServoYawMin;
  
end package;

package body ServoPack is

end package body;
