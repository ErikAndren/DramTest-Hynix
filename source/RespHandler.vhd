-- This block manages feeds the vga generator

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

entity RespHdler is
  generic (
    PixelW : positive := 9
    );
  port (
    WrRst_N     : in  bit1;
    WrClk       : in  bit1;
    --
    RespData    : in  word(DSIZE-1 downto 0);
    RespDataVal : in  bit1;
    --
    -- interface to sram arbiter
    RdRst_N     : in  bit1;
    RdClk       : in  bit1;
    --
    ReadReq     : out DramRequest;
    ReadReqAck  : in  bit1;
    -- Vga interface
    InView      : in  bit1;
    PixelToDisp : out word(PixelW-1 downto 0)
    );
end entity;

architecture rtl of RespHdler is
begin
  
end architecture rtl;
