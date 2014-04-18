library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

entity RequestHandler is
  port (
    Rst_N  : in  bit1;
    --
    WrClk  : in  bit1;
    ReqIn  : in  DramRequest;
    We     : in  bit1;
    --
    RdClk  : in  bit1;
    ReqOut : out DramRequest;
    Re     : in  bit1
    );
end entity;

architecture rtl of RequestHandler is
  signal ReqInWord, ReqOutWord : word(DramRequestW-1 downto 0);
  signal WrFull_i : bit1;
begin
  ReqInWord <= DramRequestToWord(ReqIn);
  
  RequestFifo : entity work.ReqFifo
    port map (
      Data   => ReqInWord,
      WrClk  => WrClk,
      WrReq  => We,
      --
      RdClk  => RdClk,
      RdReq  => Re,
      Q      => ReqOutWord,
      wrfull => WrFull_i
    );

    assert not (WrFull_i = '1' and We = '1') report "Request fifo overflow" severity failure;

  ReqOut <= WordToDramRequest(ReqOutWord);

  -- FIXME: Must handle NOP insertion upon ack
  -- FIXME: Must split write word into 16 bit chunks
  
end architecture rtl;
