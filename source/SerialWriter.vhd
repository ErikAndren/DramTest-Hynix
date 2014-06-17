library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;

entity SerialWriter is
  generic (
    DataW   : positive := 8;
    ClkFreq : positive := 50000000
    );
  port (
    Clk       : in  bit1;
    Rst_N     : in  bit1;
    --
    Baud      : in  word(3-1 downto 0);
    --
    We        : in  bit1;
    WData     : in  word(DataW-1 downto 0);
    --
    Busy      : out bit1;
    SerialOut : out bit1
    );
end entity;

architecture fpga of SerialWriter is
  -- Data plus start and stop bits
  constant Payload            : positive := DataW + 2;
  constant PayLoadW           : positive := bits(Payload);
  --
  signal Divisor              : integer;
  --
  signal Cnt_N, Cnt_D         : word(bits(ClkFreq / 1200)-1 downto 0);
  --
  signal CharCnt_D, CharCnt_N : word(PayloadW-1 downto 0);
  signal Str_D, Str_N         : word(DataW-1 downto 0);

  constant Baud_115200 : word(3-1 downto 0) := "000";
  constant Baud_57600  : word(3-1 downto 0) := "001";
  constant Baud_38400  : word(3-1 downto 0) := "010";
  constant Baud_19200  : word(3-1 downto 0) := "011";
  constant Baud_9600   : word(3-1 downto 0) := "100";
  constant Baud_4800   : word(3-1 downto 0) := "101";
  constant Baud_2400   : word(3-1 downto 0) := "110";
  constant Baud_1200   : word(3-1 downto 0) := "111";
  
begin
  BusyAssign : Busy <= '1' when CharCnt_D < Payload else '0';

  BaudRateSel : process (Rst_N, Clk)
  begin
    if Rst_N = '0' then
      Divisor <= 0;
    elsif rising_edge(Clk) then
      case Baud is
        when Baud_115200 =>
          Divisor <= ClkFreq / 115200;
        when Baud_57600 =>
          Divisor <= ClkFreq / 57600;
        when Baud_38400 =>
          Divisor <= ClkFreq / 38400;
        when Baud_19200 =>
          Divisor <= ClkFreq / 19200;
        when Baud_9600 =>
          Divisor <= ClkFreq / 9600;
        when Baud_4800 =>
          Divisor <= ClkFreq / 4800;
        when Baud_2400 =>
          Divisor <= ClkFreq / 2400;
        when Baud_1200 =>
          Divisor <= ClkFreq / 1200;
        when others =>
          Divisor <= ClkFreq / 115200;
      end case;
    end if;
  end process;

  CntSync : process (Clk, Rst_N)
  begin
    if (Rst_N = '0') then
      Cnt_D     <= (others => '0');
      Str_D     <= (others => '0');
      CharCnt_D <= (others => '1');
    elsif rising_edge(Clk) then
      Cnt_D     <= Cnt_N;
      Str_D     <= Str_N;
      CharCnt_D <= CharCnt_N;
    end if;
  end process;

  CntAsync : process (Cnt_D, CharCnt_D, Str_D, WData, We, Divisor)
    variable IsCtrlBit : boolean;
  begin
    IsCtrlBit := false;
    Cnt_N     <= Cnt_D + 1;
    CharCnt_N <= CharCnt_D;
    Str_N     <= Str_D;
    SerialOut <= '1';

    if CharCnt_D = 0 then
      -- Send start bit
      SerialOut <= '0';
      IsCtrlBit := true;
    elsif conv_integer(CharCnt_D) = Payload-1 then
      -- Send stop bit
      SerialOut <= '1';
      IsCtrlBit := true;
    elsif conv_integer(CharCnt_D) < PayLoad-1 then
      -- Send LSB first
      SerialOut <= Str_D(0);
    end if;
    
    if (Cnt_D = Divisor-1) and CharCnt_D < PayLoad then
      Cnt_N <= (others => '0');
      -- Rotate value right one step
      if (IsCtrlBit = false) then
        Str_N <= '0' & Str_D(Str_D'high downto 1);
      end if;

      CharCnt_N <= CharCnt_D + 1;
    end if;

    if (We = '1') and (CharCnt_D >= PayLoad) then
      Str_N     <= WData;
      CharCnt_N <= (others => '0');
      Cnt_N     <= (others => '0');
    end if;
  end process;
end architecture;
