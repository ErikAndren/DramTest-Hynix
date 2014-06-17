library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;
use work.SerialPack.all;

entity SerialCmdParser is
  generic (
    -- Nbr of nibbles
    AddrLen : positive := 8;
    DataLen : positive := 8
    );
  port (
    RstN           : in  bit1;
    Clk            : in  bit1;
    --
    IncSerChar     : in  word(Byte-1 downto 0);
    IncSerCharVal  : in  bit1;
    --
    OutSerCharBusy : in  bit1;
    OutSerChar     : out word(Byte-1 downto 0);
    OutSerCharVal  : out bit1;
    --
    RegAccessOut   : out RegAccessRec;
    RegAccessIn    : in  RegAccessRec
    );
end entity;

architecture rtl of SerialCmdParser is
  --
  constant NbrArgs                : positive := 3;
  constant OpLen                  : positive := 1;
  -- 1111111111
  -- 9876543210987654321 0
  -- O AAAAAAAA DDDDDDDD\n
  -- 1 + 3 + 8 + 8 = 20
  constant BufLen                 : positive := OpLen + NbrArgs + AddrLen + DataLen;
  -- 5
  constant BufLenW                : positive := bits(BufLen);
  -- 19
  constant OpStartOffs            : natural  := BufLen-1;
  -- 19
  constant OpEndOffs              : natural  := OpStartOffs;
  -- 19 - 2 = 17
  constant AddrStartOffs          : natural  := OpEndOffs - 2;
  -- 17 - 7 = 10
  constant AddrEndOffs            : natural  := AddrStartOffs - (AddrLen-1);
  -- 10 - 2 = 8
  constant DataStartOffs          : natural  := AddrEndOffs - 2;
  -- 8 - 1 = 1
  constant DataEndOffs            : natural  := DataStartOffs - (DataLen-1);
  --
  signal IncBuf_N, IncBuf_D       : word(BufLen*Byte-1 downto 0);
  signal OutBuf_N, OutBuf_D       : word(BufLen*Byte-1 downto 0);
  signal OutBufLen_N, OutBufLen_D : word(BufLenW-1 downto 0);
  signal OutBufVal_N, OutBufVal_D : bit1;
  signal ShiftBuf                 : word(BufLen*Byte-1 downto 0);
  signal CurBufLen_N, CurBufLen_D : word(BufLenW-1 downto 0);
  signal DecodeCmd                : bit1;

  function AscToHex(StartOffs : natural; EndOffs : natural; Inc : word) return word is
    variable j : integer;
    variable B : word(Byte-1 downto 0);
    variable RetVal : word((Inc'length/Byte)*Nibble-1 downto 0);
    variable Inc_norm : word(Inc'length-1 downto 0);
    
  begin
    Inc_norm := Inc;
    
    RetVal := (others => '0');
    -- Convert address from ascii to binary representation
    -- ascii is in 8 bits, binary is 4
    for i in StartOffs downto EndOffs loop
      j := i - EndOffs;
      B := Inc_norm((j+1)*Byte-1 downto j*Byte);
      -- hex
      if B >= x"41" then
        B := B - x"37";
      else
        B := B - x"30";
      end if;

      RetVal((j+1)*Nibble-1 downto j*Nibble) := B(Nibble-1 downto 0);
    end loop;
    return RetVal;
  end function;

  function HexToAsc(StartOffs : natural; EndOffs : natural; Inc : word) return word is
    variable j           : integer;
    variable NibbleChunk : word(Nibble-1 downto 0);
    variable RetVal      : word((Inc'length/Nibble)*Byte-1 downto 0);
    variable Inc_norm    : word(Inc'length-1 downto 0);
  begin
    Inc_norm := Inc;
    
    RetVal := (others => '0');
    -- Convert address from binary to ascii representation
    -- Each nibble gets its own charachter
    for i in StartOffs downto EndOffs loop
      j           := i - EndOffs;
      NibbleChunk := Inc_norm((j+1)*Nibble-1 downto j*Nibble);
      
      -- Check if hex
      if NibbleChunk < 10 then
        RetVal((i+1)*Byte-1 downto i*Byte) := NibbleChunk + x"30";        
      else
        RetVal((i+1)*Byte-1 downto i*Byte) := NibbleChunk + x"37";
      end if;        
    end loop;
    return RetVal;  
  end function;
  
begin
  IncCharAddSync : process (Clk, RstN)
  begin
    if RstN = '0' then
      IncBuf_D    <= (others => '0');
      CurBufLen_D <= (others => '0');
    elsif rising_edge(Clk) then
      IncBuf_D    <= IncBuf_N;
      CurBufLen_D <= CurBufLen_N;
    end if;
  end process;
  
   IncCharAddAsync : process (IncSerChar, IncSerCharVal, IncBuf_D, CurBufLen_D)
    variable IncBuf_T : word(IncBuf_D'range);
  begin
    IncBuf_T    := IncBuf_D;
    DecodeCmd   <= '0';
    CurBufLen_N <= CurBufLen_D;
    ShiftBuf    <= SHL(IncBuf_D, conv_word((BufLen - conv_integer(CurBufLen_D)) * Byte, bits(BufLen * Byte)));
    
    if IncSerCharVal = '1' then
      IncBuf_T := IncBuf_D((IncBuf_D'length-Byte)-1 downto 0) & IncSerChar;
      CurBufLen_N <= CurBufLen_D + 1;
      if (CurBufLen_D + 1 = BufLen) then
        CurBufLen_N <= CurBufLen_D;
      end if;

      if IncSerChar = NewLine then
        DecodeCmd   <= '1';
        CurBufLen_N <= (others => '0');
      end if;
    end if;

    IncBuf_N <= IncBuf_T;
  end process;

  DecodeCmdProc : process (ShiftBuf, DecodeCmd, CurBufLen_D)
  begin
    RegAccessOut <= Z_RegAccessRec;
    
    if DecodeCmd = '1' then
      if ShiftBuf((OpStartOffs+1)*Byte-1 downto OpEndOffs*Byte) = WriteCmd then
        RegAccessOut.Val <= "1";
        RegAccessOut.Cmd <= REG_WRITE;

        -- Convert address from ascii to binary representation
        -- ascii is in 8 bits, binary is 4
        -- 135 d 80
        RegAccessOut.Addr <= AscToHex(AddrStartOffs, AddrEndOffs, ShiftBuf((AddrStartOffs+1)*Byte-1 downto AddrEndOffs*Byte));
        RegAccessOut.Data <= AscToHex(DataStartOffs, DataEndOffs, ShiftBuf((DataStartOffs+1)*Byte-1 downto DataEndOffs*Byte));
        
      elsif ShiftBuf((OpStartOffs+1)*Byte-1 downto OpEndOffs*Byte) = ReadCmd then
        RegAccessOut.Val  <= "1";
        RegAccessOut.Cmd  <= REG_READ;
        RegAccessOut.Addr <= AscToHex(AddrStartOffs, AddrEndOffs, ShiftBuf((AddrStartOffs+1)*Byte-1 downto AddrEndOffs*Byte));
      end if;
    end if;
  end process;

  --

  ResponseSyncRst : process(Clk, RstN)
  begin
    if RstN = '0' then
      OutBufVal_D <= '0';
    elsif rising_edge(Clk) then
      OutBufVal_D <= OutBufVal_N;
    end if;
  end process;

  ResponseSyncNoRst : process(Clk)
  begin
    if rising_edge(Clk) then
      OutBufLen_D <= (others => '0');
      OutBuf_D    <= OutBuf_N;
      OutBufLen_D <= OutBufLen_N;
    end if;
  end process;

  DecodeResponse : process (RegAccessIn, OutBuf_D, OutBufLen_D, OutBufVal_D, OutSerCharBusy)
    variable OutBuf : word(OutBuf_D'range);
  begin
    OutBuf        := OutBuf_D;
    OutBuf_N      <= OutBuf_D;
    OutBufLen_N   <= OutBufLen_D;
    OutBufVal_N   <= OutBufVal_D;
    OutSerCharVal <= '0';
    
    if RegAccessIn.Val = "1" then
      -- Build the output string
      -- Fill output string with spaces
      OutBuf := ReplicateWord(SpaceChar, BufLen);
      OutBuf(ByteW-1 downto 0) := NewLine;

      if RegAccessIn.Cmd = REG_READ then
        OutBuf((OpStartOffs+1)*Byte-1 downto OpEndOffs*Byte) := ReadCmd;
      else
        OutBuf((OpStartOffs+1)*Byte-1 downto OpEndOffs*Byte) := WriteCmd;
      end if;

      -- Must add d'48 to all numbers to align to ascii, hex numbers need
      -- special treatment.
      -- Each nibble of the data and address must be converted.
      OutBuf((AddrStartOffs+1)*Byte-1 downto AddrEndOffs*Byte) := HexToAsc(RegAccessIn.Addr'length/Nibble-1, 0, RegAccessIn.Addr);
      OutBuf((DataStartOffs+1)*Byte-1 downto DataEndOffs*Byte) := HexToAsc(RegAccessIn.Data'length/Nibble-1, 0, RegAccessIn.Data);

      OutBuf(Byte-1 downto 0) := NewLine;

      OutBufLen_N <= conv_word(BufLen, BufLenW);
      OutBufVal_N <= '1';
      OutBuf_N    <= OutBuf;
    end if;

    if OutBufVal_D = '1' and OutSerCharBusy = '0' then
      OutSerCharVal <= '1';
      OutBufLen_N <= OutBufLen_D - 1;
      if OutBufLen_D - 1 = 0 then
        OutBufVal_N <= '0';
      end if;
    end if;
  end process;
  OutSerChar <= OutBuf_D((conv_integer(OutBufLen_D)+0)*Byte-1 downto (conv_integer(OutBufLen_D)-1)*Byte) when OutBufVal_D = '1' else (others => 'X');
end architecture rtl;
