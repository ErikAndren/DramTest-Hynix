library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

entity SdramArbiter is
  port (
    Clk         : in  bit1;
    Rst_N       : in  bit1;
    --
    WriteReq    : in  DramRequest;
    WriteReqAck : out bit1;
    --
    ReadReq     : in  DramRequest;
    ReadReqAck  : out bit1;
    --
    ArbDecReq   : out DramRequest;
    ArbDecVal   : out bit1
    );
end entity;

architecture rtl of SdramArbiter is
begin
  ArbAsyn : process (ReadReq, WriteReq)
  begin
    WriteReqAck <= '0';
    ReadReqAck  <= '0';
    ArbDecVal   <= '0';
    ArbDecReq   <= Z_DramRequest;

    if ReadReq.Val = "1" then
      ReadReqAck <= '1';
      ArbDecVal  <= '1';
      ArbDecReq  <= ReadReq;
    end if;

    if WriteReq.Val = "1" then
      WriteReqAck <= '1';
      ReadReqAck  <= '0';
      ArbDecVal   <= '1';
      ArbDecReq   <= WriteReq;
    end if;
  end process;
end architecture rtl;
