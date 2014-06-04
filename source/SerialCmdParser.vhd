library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

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
  constant NewLine                : word(8-1 downto 0) := x"0A";
  constant WriteCmd               : word(8-1 downto 0) := x"56";
  constant ReadCmd                : word(8-1 downto 0) := x"52";
  constant SpaceChar              : word(8-1 downto 0) := x"20";
  --
  constant NbrArgs                : positive           := 3;
  constant OpLen                  : positive           := 1;
  --
  constant BufLen                 : positive           := OpLen + NbrArgs + AddrLen + DataLen;
  constant BufLenW                : positive           := bits(BufLen);
  --
  constant OpStartOffs            : positive           := BufLen-1;
  constant OpEndOffs              : positive           := OpStartOffs;
  --
  constant AddrStartOffs          : positive           := OpEndOffs - 2;
  constant AddrEndOffs            : positive           := AddrStartOffs - AddrLen;
  --
  constant DataStartOffs          : positive           := AddrEndOffs - 2;
  constant DataEndOffs            : positive           := DataStartOffs - DataLen;
  --
  signal IncBuf_N, IncBuf_D       : word(BufLen*ByteW-1 downto 0);
  signal OutBuf_N, OutBuf_D       : word(BufLen*ByteW-1 downto 0);
  signal OutBufLen_N, OutBufLen_D : word(BufLenW-1 downto 0);
  signal OutBufVal_N, OutBufVal_D : bit1;
  signal ShiftBuf                 : word(BufLen*ByteW-1 downto 0);
  signal CurBufLen_N, CurBufLen_D : word(BufLenW-1 downto 0);
  signal DecodeCmd                : bit1;

  function AscToHex(StartOffs : natural; EndOffs : natural; Inc : word) return word is
    variable j : integer;
    variable B : word(ByteW-1 downto 0);
    variable RetVal : word((Inc'length/Byte)*Nibble-1 downto 0);
  begin
    RetVal := (others => '0');
    -- Convert address from ascii to binary representation
    -- ascii is in 8 bits, binary is 4
    for i in StartOffs downto EndOffs loop
      j := i - EndOffs;
      B := Inc((i+1)*Byte-1 downto i*Byte);
      -- hex
      if B >= x"41" then
        B := B - x"41";
      else
        B := B - x"30";
      end if;

      RetVal((j+1)*Nibble-1 downto j*Nibble) := B(Nibble-1 downto 0);
    end loop;
    return RetVal;
  end function;

  function HexToAsc(StartOffs : natural; EndOffs : natural; Inc : word) return word is
    variable j                : integer;
    variable ByteChunk        : word(ByteW-1 downto 0);
    variable UpperNibbleChunk : word(Nibble-1 downto 0);
    variable LowerNibbleChunk : word(Nibble-1 downto 0);
    variable RetVal           : word((Inc'length/Nibble)*Byte-1 downto 0);
  begin
    RetVal := (others => '0');
    -- Convert address from binary to ascii representation
    -- Each nibble gets its own charachter
    for i in StartOffs downto EndOffs loop
      j         := i - AddrEndOffs;
      ByteChunk := Inc((j+1)*Byte-1 downto j*Byte);

      LowerNibbleChunk := ExtractSlice(ByteChunk, Nibble, 0);
      UpperNibbleChunk := ExtractSlice(ByteChunk, Nibble, 1);
      
      -- Check if hex
      if LowerNibbleChunk < 10 then
        RetVal((i+1)*Byte-Nibble-1 downto i*Byte) := LowerNibbleChunk + x"30";        
      else
        RetVal((i+1)*Byte-Nibble-1 downto i*Byte) := LowerNibbleChunk + x"41";
      end if;        

      if UpperNibbleChunk < 10 then
        RetVal((i+1)*Byte-1 downto i*Byte+Nibble) := UpperNibbleChunk + x"30";        
      else
        RetVal((i+1)*Byte-1 downto i*Byte+Nibble) := UpperNibbleChunk + x"41";
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
      IncBuf_D    <= (others => '0');
      CurBufLen_D <= (others => '0');
    end if;
  end process;
  
  IncCharAddAsync : process (IncSerChar, IncSerCharVal, IncBuf_D, CurBufLen_D)
    variable IncBuf_T : word(IncBuf_D'range);
  begin
    IncBuf_T    := IncBuf_D;
    DecodeCmd   <= '0';
    CurBufLen_N <= CurBufLen_D;
    ShiftBuf    <= SHL(IncBuf_D, conv_word((BufLen - conv_integer(CurBufLen_D)) * ByteW, bits(BufLen * ByteW)));
    
    if IncSerCharVal = '1' then
      IncBuf_T := IncBuf_D((IncBuf_D'length-2)*ByteW downto 1*ByteW) & IncSerChar;
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
    variable BufLen : integer;
    
  begin
    BufLen       := conv_integer(CurBufLen_D);
    RegAccessOut <= Z_RegAccessRec;
    
    if DecodeCmd = '1' then
      if ShiftBuf((OpStartOffs+1)*ByteW-1 downto OpEndOffs*ByteW) = WriteCmd then
        RegAccessOut.Val <= "1";
        RegAccessOut.Cmd <= REG_WRITE;

        -- Convert address from ascii to binary representation
        -- ascii is in 8 bits, binary is 4
        RegAccessOut.Addr <= AscToHex(AddrStartOffs, AddrEndOffs, ShiftBuf);
        RegAccessOut.Data <= AscToHex(DataStartOffs, DataEndOffs, ShiftBuf);
        
      elsif ShiftBuf((OpStartOffs+1)*ByteW-1 downto OpEndOffs*ByteW) = ReadCmd then
        RegAccessOut.Val  <= "1";
        RegAccessOut.Cmd  <= REG_READ;
        RegAccessOut.Addr <= AscToHex(AddrStartOffs, AddrEndOffs, ShiftBuf);
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

  DecodeResponse : process (RegAccessIn, OutBuf_D, OutBufLen_D, OutBufVal_D)
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

      if RegAccessIn.Cmd = REG_READ then
        OutBuf((OpStartOffs+1)*ByteW-1 downto OpEndOffs*ByteW) := ReadCmd;
      else
        OutBuf((OpStartOffs+1)*ByteW-1 downto OpEndOffs*ByteW) := WriteCmd;
      end if;

      -- Must add d'48 to all numbers to align to ascii, hex numbers need
      -- special treatment.
      -- Each nibble of the data and address must be converted.
      OutBuf((AddrStartOffs+1)*Byte-1 downto AddrEndOffs*Byte) := HexToAsc(AddrStartOffs, AddrEndOffs, RegAccessIn.Addr);
      OutBuf((DataStartOffs+1)*ByteW-1 downto DataEndOffs*ByteW) := HexToAsc(DataStartOffs, DataEndOffs, RegAccessIn.Data);

      OutBufLen_N <= conv_word(BufLen-1, BufLenW);
      OutBufVal_N <= '1';
      OutBuf_N    <= OutBuf;
    end if;

    if OutBufVal_D = '0' and OutSerCharBusy = '0' then
      OutSerCharVal <= '1';
      OutBufLen_N <= OutBufLen_D - 1;
      if OutBufLen_D - 1 = 0 then
        OutBufVal_N <= '0';
      end if;
    end if;
  end process;

  OutSerChar <= OutBuf_D((conv_integer(OutBufLen_D)+1)*ByteW-1 downto conv_integer(OutBufLen_D)*ByteW);

end architecture rtl;
