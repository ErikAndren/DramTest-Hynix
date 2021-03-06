-- Samples the line and stores it in 3 rams
-- This is then sent in a 3x3 array to a filter
-- Copyright Erik Zachrisson erik@zachrisson.info

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;
use work.VgaPack.all;

entity LineSampler is
  generic (
    DataW   : positive;
    Buffers : positive;
    OutRes  : positive
    );
  port (
    Clk         : in  bit1;
    RstN        : in  bit1;
    --
    Vsync       : in  bit1;
    RdAddr      : out word(VgaWidthW-1 downto 0);
    --
    PixelIn     : in  word(DataW-1 downto 0);
    PixelInVal  : in  bit1;
    --
    PixelOut    : out PixVec2D(OutRes-1 downto 0);
    PixelOutVal : out bit1
    );
end entity;

architecture rtl of LineSampler is
  signal Addr_N, Addr_D       : word(VgaWidthW-1 downto 0);
  type AddrArr is array (natural range <>) of word(Buffers-1 downto 0);
  signal PixArr_N, PixArr_D   : PixVec2D(OutRes-1 downto 0);

  constant Z_PixArr : PixVec2D(OutRes-1 downto 0) := (others => (others => (others => '0')));

  constant BufW : positive := bits(Buffers);
  
  --
  signal LineCnt_N, LineCnt_D : word(VgaHeightW-1 downto 0);
  signal WrEn                 : word(Buffers-1 downto 0);
  type BuffArr is array (natural range <>) of word(PixelW-1 downto 0);
  signal RamOut               : BuffArr(Buffers-1 downto 0);

  signal PixelVal_D : bit1;
  
  function CalcLine(CurLine : word; Offs : natural) return natural is
  begin
    -- Plus one is to compensate that we are writing into the buffer that is
    -- not being read
    return ((conv_integer(CurLine) + Offs + 1) mod Buffers);
  end function;
begin
  OneHotProc : process (LineCnt_D, PixelInVal)
  begin
    WrEn <= (others => '0');

    if PixelInVal = '1' then
      WrEn(conv_integer(LineCnt_D(BufW-1 downto 0))) <= '1';
    end if;
  end process;

  -- FIXME: The registered output could probably be removed. Timing should be
  -- lax anyway
  Ram : for i in 0 to Buffers-1 generate
    R : entity work.LineSampler1PRAM
      port map (
        Clock   => Clk,
        Data    => PixelIn,
        WrEn    => WrEn(i),
        address => Addr_D,
        --
        q       => RamOut(i)
        );
  end generate;

  SyncRstProc : process (RstN, Clk)
  begin
    if RstN = '0' then
      PixelVal_D <= '0';
    elsif rising_edge(Clk) then
      PixelVal_D <= PixelInVal;
    end if;
  end process;
  
  SyncNoRstProc : process (Clk)
  begin
    if rising_edge(Clk) then
      LineCnt_D <= LineCnt_N;
      Addr_D    <= Addr_N;
      PixArr_D  <= PixArr_N;

      if Vsync = '1' then
        LineCnt_D <= (others => '0');
        Addr_D    <= (others => '0');

        -- Clear pixel array during vsync to avoid frames from contaminating
        -- each other
        PixArr_D  <= Z_PixArr;
      end if;
    end if;
  end process;
  
  AsyncProc : process (LineCnt_D, Addr_D, PixArr_D, PixelInVal, RamOut)
  begin
    LineCnt_N <= LineCnt_D;
    Addr_N    <= Addr_D;
    PixArr_N  <= PixArr_D;

    if PixelInVal = '1' then
      -- Shift all entries one step to the left
      -- Outer loop runs thru the three lines, inner, unrolled loop handles the
      -- rows

      -- Prepare the box for the next pixel
      for i in 0 to OutRes-1 loop
        PixArr_N(i)(0) <= PixArr_D(i)(1);        
        PixArr_N(i)(1) <= PixArr_D(i)(2);
        PixArr_N(i)(2) <= RamOut(CalcLine(LineCnt_D(BufW-1 downto 0), i));

        -- Invalidate the rows which contains data from the bottom of the
        -- previous frame
        if LineCnt_D < 3-i then
          PixArr_N(i)(2) <= (others => '0');
        end if;        
      end loop;

      -- Bump address for the next write
      Addr_N <= Addr_D + 1;

      -- Wrap new line
      if Addr_D + 1 = VgaWidth then
        Addr_N <= (others => '0');

        -- Clear pixel array upon each line change
        PixArr_N <= Z_PixArr;
        
        -- Align to a new buffer
        LineCnt_N <= LineCnt_D + 1;
        if LineCnt_D + 1 = VgaHeight then
          -- Wrap buffer
          LineCnt_N <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  AddrFeed        : RdAddr      <= Addr_D;
  PixelOutValFeed : PixelOutVal <= PixelVal_D;
  PixelOutFeed    : PixelOut    <= PixArr_D;
end architecture rtl;
