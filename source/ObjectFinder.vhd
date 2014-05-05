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
  signal PixelCnt_N, PixelCnt_D         : word(VgaWidthW-1 downto 0);
  signal LineCnt_N, LineCnt_D           : word(VgaHeightW-1 downto 0);
  --
  signal PixelOut_N, PixelOut_D         : word(DataW-1 downto 0);
  --
  -- Set low threshold for now
  constant Threshold                    : natural := 32;
  --
  signal TopLeftFound_N, TopLeftFound_D : bit1;
             
begin
  SyncProc : process (Clk, RstN)
  begin
    if RstN = '0' then
      TopLeft_D         <= Z_Cord;
      BottomRight_D     <= Z_Cord;
      NextTopLeft_D     <= Z_Cord;
      NextBottomRight_D <= Z_Cord;
      --
      TopLeftFound_D    <= '0';
      --
      PixelCnt_D        <= (others => '0');
      LineCnt_D         <= (others => '0');
    elsif rising_edge(Clk) then
      NextTopLeft_D     <= NextTopLeft_N;
      NextBottomRight_D <= NextBottomRight_N;
      TopLeft_D         <= TopLeft_N;
      BottomRight_D     <= BottomRight_N;
      --
      PixelCnt_D        <= PixelCnt_N;
      LineCnt_D         <= LineCnt_N;
      --
      TopLeftFound_D    <= TopLeftFound_N;


      if Vsync = '1' then
        NextTopLeft_D     <= Z_Cord;
        NextBottomRight_D <= Z_Cord;
        TopLeft_D         <= NextTopLeft_D;
        BottomRight_D     <= NextBottomRight_D;
        --
        TopLeftFound_D <= '0';
        PixelCnt_D     <= (others => '0');
        LineCnt_D      <= (others => '0');
      end if;
    end if;
  end process;
  
  AsyncProc : process (TopLeft_D, BottomRight_D, PixelIn, PixelInVal, PixelCnt_D, LineCnt_D, TopLeftFound_D, NextTopLeft_D, NextBottomRight_D)
  begin
    TopLeft_N         <= TopLeft_D;
    BottomRight_N     <= BottomRight_D;
    NextTopLeft_N     <= NextTopLeft_D;
    NextBottomRight_N <= NextBottomRight_D;
    
    PixelCnt_N    <= PixelCnt_D;
    LineCnt_N     <= LineCnt_D;
    TopLeftFound_N <= TopLeftFound_D;

    if PixelInVal = '1' then
      -- Pixel counting
      PixelCnt_N <= PixelCnt_D + 1;
      if PixelCnt_D + 1 = VgaWidth then
        -- End of line
        PixelCnt_N <= (others => '0');
        LineCnt_N <= LineCnt_D + 1;
        if LineCnt_D + 1 = VgaHeight then
          LineCnt_N <= (others => '0');
          -- End of frame
        end if;
      end if;

      if PixelIn >= Threshold then
        if TopLeftFound_D = '0' then
          NextTopLeft_N.X <= PixelCnt_D;
          NextTopLeft_N.Y <= LineCnt_D;
          TopLeftFound_N <= '1';
        end if;

        if NextBottomRight_D.X < PixelCnt_D then
          NextBottomRight_N.X <= PixelCnt_D;
        end if;

        if NextBottomRight_D.Y < LineCnt_D then
          NextBottomRight_N.Y <= LineCnt_D;
        end if;
      end if;      
    end if;
  end process;

  RectAct <= '1' when ((LineCnt_D = TopLeft_D.Y) and ((PixelCnt_D >= TopLeft_D.X) and (PixelCnt_D <= BottomRight_D.X))) or 
                      ((LineCnt_D = BottomRight_D.Y) and ((PixelCnt_D >= TopLeft_D.X) and (PixelCnt_D <= BottomRight_D.X))) or
                      ((PixelCnt_D = TopLeft_D.X) and ((LineCnt_D >= TopLeft_D.Y) and (LineCnt_D <= BottomRight_D.Y))) or
                      ((PixelCnt_D = BottomRight_D.X) and ((LineCnt_D >= TopLeft_D.Y) and (LineCnt_D <= BottomRight_D.Y))) else '0';  

  TopLeftAssign     : TopLeft     <= TopLeft_D;
  BottomRightAssign : BottomRight <= BottomRight_D;
  PixelOutAssign    : PixelOut    <= PixelIn;
  PixelOutValAssign : PixelOutVal <= PixelInVal;
end architecture rtl;
