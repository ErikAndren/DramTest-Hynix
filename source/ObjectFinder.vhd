-- Find a object in the middle and try to track it
-- Erik Zachrisson - erik@zachrisson.info, copyright 2014

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;
use work.VgaPack.all;

entity ObjectFinder is
  generic (
    DataW : positive
    );
  port (
    RstN        : in  bit1;
    Clk         : in  bit1;
    --
    Vsync       : in  bit1;
    --
    PixelIn     : in  word(DataW-1 downto 0);
    PixelInVal  : in  bit1;
    -- Vga if
    PixelOut    : out word(DataW-1 downto 0);
    PixelOutVal : out bit1;
    RectAct     : out bit1;
    -- Box if
    TopLeft     : out Cord;
    BottomRight : out Cord
    );
end entity;

architecture rtl of ObjectFinder is
  signal TopLeft_N, TopLeft_D                 : Cord;
  signal BottomRight_N, BottomRight_D         : Cord;
  signal NextTopLeft_N, NextTopLeft_D         : Cord;
  signal NextBottomRight_N, NextBottomRight_D : Cord;
  --
  signal PixelCnt_N, PixelCnt_D               : word(VgaWidthW-1 downto 0);
  signal LineCnt_N, LineCnt_D                 : word(VgaHeightW-1 downto 0);
  --
  signal PixelOut_N, PixelOut_D               : word(DataW-1 downto 0);
  --
  -- Set low threshold for now
  constant Threshold                          : natural := 32;
  --
  signal NewVsync_D                           : bit1;
  --
  signal RectAct_i                            : bit1;

  signal DrawTop, DrawLeft, DrawRight, DrawBottom : bit1;
  
begin
  SyncNoRstProcProc : process (Clk)
  begin
    if rising_edge(Clk) then
      NextTopLeft_D     <= NextTopLeft_N;
      NextBottomRight_D <= NextBottomRight_N;
      TopLeft_D         <= TopLeft_N;
      BottomRight_D     <= BottomRight_N;
      --
      PixelCnt_D        <= PixelCnt_N;
      LineCnt_D         <= LineCnt_N;
      --
      NewVsync_D        <= Vsync;

      -- Latch in coordinates to draw for the next frame
      if Vsync = '0' and NewVSync_D = '1' then
        NextTopLeft_D     <= M_Cord;
        NextBottomRight_D <= Z_Cord;
        --
        TopLeft_D         <= NextTopLeft_N;
        BottomRight_D     <= NextBottomRight_N;
        --
        PixelCnt_D     <= (others => '0');
        LineCnt_D      <= (others => '0');
      end if;
    end if;
  end process;

  AsyncProc : process (TopLeft_D, BottomRight_D, PixelIn, PixelInVal, PixelCnt_D, LineCnt_D, NextTopLeft_D, NextBottomRight_D)
  begin
    TopLeft_N         <= TopLeft_D;
    BottomRight_N     <= BottomRight_D;
    NextTopLeft_N     <= NextTopLeft_D;
    NextBottomRight_N <= NextBottomRight_D;
    --
    PixelCnt_N     <= PixelCnt_D;
    LineCnt_N      <= LineCnt_D;

    if PixelInVal = '1' then
      -- Pixel counting
      PixelCnt_N <= PixelCnt_D + 1;
      if PixelCnt_D + 1 = VgaWidth then
        -- End of line
        PixelCnt_N <= (others => '0');
        LineCnt_N <= LineCnt_D + 1;
        if LineCnt_D + 1 = VgaHeight then
          LineCnt_N <= (others => '0');
        end if;
      end if;

      if PixelIn >= Threshold then
        if LineCnt_D < NextTopLeft_D.Y then
          NextTopLeft_N.Y <= LineCnt_D;
        end if;

        if LineCnt_D > NextBottomRight_D.Y then
          NextBottomRight_N.Y <= LineCnt_D;
        end if;

        if PixelCnt_D < NextTopLeft_D.X  then
          NextTopLeft_N.X <= PixelCnt_D;
        end if;

        if PixelCnt_D > NextBottomRight_D.X then
          NextBottomRight_N.X <= PixelCnt_D;
        end if;
      end if;
    end if;
  end process;

  DrawTop    <= '1' when ((LineCnt_D = TopLeft_D.Y) and ((PixelCnt_D >= TopLeft_D.X) and (PixelCnt_D <= BottomRight_D.X)))     else '0';
  DrawBottom <= '1' when ((LineCnt_D = BottomRight_D.Y) and ((PixelCnt_D >= TopLeft_D.X) and (PixelCnt_D <= BottomRight_D.X))) else '0';
  DrawLeft   <= '1' when ((PixelCnt_D = TopLeft_D.X) and ((LineCnt_D >= TopLeft_D.Y) and (LineCnt_D <= BottomRight_D.Y)))      else '0';
  DrawRight  <= '1' when ((PixelCnt_D = BottomRight_D.X) and ((LineCnt_D >= TopLeft_D.Y) and (LineCnt_D <= BottomRight_D.Y)))  else '0';
  RectAct_i  <= '1' when ((DrawTop = '1') or (DrawLeft = '1') or (DrawRight = '1') or (DrawBottom = '1'))                      else '0';

  TopLeftAssign     : TopLeft     <= TopLeft_D;
  BottomRightAssign : BottomRight <= BottomRight_D;

  -- Create grey scale image
  RedPixelOutAssign   : PixelOut(RedHigh downto RedLow)     <= PixelIn(8-1 downto 5);
  GreenPixelOutAssign : PixelOut(GreenHigh downto GreenLow) <= (others => '1') when RectAct_i = '1' else PixelIn(8-1 downto 5);
  BluePixelOutAssign  : PixelOut(BlueHigh downto BlueLow)   <= PixelIn(8-1 downto 6);
  
  PixelOutValAssign : PixelOutVal <= PixelInVal;
  RectActAssign     : RectAct     <= RectAct_i;
end architecture rtl;
