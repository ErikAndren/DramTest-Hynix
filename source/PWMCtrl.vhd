-- This function implements a simple P controller, trying to send pulses to
-- always keep the object tracked focused in the middle
-- Copyright 2014 erik@zachrisson.info

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;
use work.VgaPack.all;
use work.ServoPack.all;

entity PWMCtrl is
  port (
    Clk64kHz    : in  bit1;
    RstN64kHz   : in  bit1;
    --
    TopLeft     : in  Cord;
    BottomRight : in  Cord;
    --
    YawPos      : out word(ServoResW-1 downto 0);
    PitchPos    : out word(ServoResW-1 downto 0)
    );
end entity;

architecture rtl of PWMCtrl is
  signal BoxMiddle                    : Cord;
  signal CalcMiddle                   : Cord;
  --
  signal CurYawPos_N, CurYawPos_D     : word(ServoResW-1 downto 0);
  signal CurPitchPos_N, CurPitchPos_D : word(ServoResW-1 downto 0);
  signal BoxDelta                     : Cord;

  signal Cnt_N, Cnt_D : word(bits(64000)-1 downto 0);

  constant X_Thres        : natural := 1;
  constant Y_Thres        : natural := 1;
  constant BoxHeightThres : natural := 20;
  constant BoxWidthThres  : natural := 20;
  
begin
  -- Calculate middle by adding half the delta 

  BoxDelta.X  <= BottomRight.X - TopLeft.X;
  BoxDelta.Y  <= BottomRight.Y - TopLeft.Y;
  --
  BoxMiddle.X <= TopLeft.X + Quotient(BoxDelta.X, 2);
  BoxMiddle.Y <= TopLeft.Y + Quotient(BoxDelta.Y, 2);
  --

  CalcDelta : process (BoxMiddle, CurYawPos_D, CurPitchPos_D, Cnt_D, BoxDelta)
  begin
    CurYawPos_N   <= CurYawPos_D;
    CurPitchPos_N <= CurPitchPos_D;

    if BoxDelta.X > BoxWidthThres then
      -- Box is on right side of screen, must move camera to the left
      if BoxMiddle.X(VgaWidthW-1 downto X_Thres) > MiddleOfScreen.X(VgaWidthW-1 downto X_Thres) then
        -- DeltaToMiddle.X := BoxMiddle.X - MiddleXOfScreen;
        -- Delta must be adjusted to available pwm resolution
        -- Add adjusted delta to yaw pos
        -- CurYawPos_N     <= CurYawPos_D + Quotient(DeltaToMiddle.X, TileXRes);
        CurYawPos_N <= CurYawPos_D + 1;
        -- Protect against overflow
        if CurYawPos_D + 1 > ServoYawMax then
          CurYawPos_N <= conv_word(ServoYawMax, CurYawPos_N'length);
        end if;
        
      elsif BoxMiddle.X(VgaWidthW-1 downto X_Thres) < MiddleOfScreen.X(VgaWidthW-1 downto X_Thres) then
        -- Deltatomiddle.X := MiddleXOfScreen - BoxMiddle.X;
        --CurYawPos_N     <= CurYawPos_D - Quotient(DeltaToMiddle.X, TileXRes);
        CurYawPos_N <= CurYawPos_D - 1;
        -- Protect against underflow
        if (CurYawPos_D - 1 < ServoYawMin) then
          CurYawPos_N <= conv_word(ServoYawMin, CurYawPos_N'length);
        end if;
      end if;
    end if;

    if BoxDelta.Y > BoxHeightThres then
      -- Lower half of screen, must lower camera
      if BoxMiddle.Y(VgaHeightW-1 downto Y_Thres) > MiddleOfScreen.Y(VgaHeightW-1 downto Y_Thres) then
        --DeltaToMiddle.Y := BoxMiddle.Y - MiddleYOfScreen;
        --CurPitchPos_N   <= CurPitchPos_D - Quotient(DeltaToMiddle.Y, TileYRes);
        CurPitchPos_N   <= CurPitchPos_D + 1;
        -- Protect against underflow
        if CurPitchPos_D + 1 > ServoPitchMax then
          CurPitchPos_N <= conv_word(ServoPitchMax, CurPitchPos_N'length);
        end if;
      elsif BoxMiddle.Y(VgaHeightW-1 downto Y_Thres) < MiddleOfScreen.Y(VgaHeightW-1 downto Y_Thres) then
        -- DeltaToMiddle.Y := MiddleYOfScreen - BoxMiddle.Y;
        --CurPitchPos_N   <= CurPitchPos_D + Quotient(DeltaToMiddle.Y, TileYRes);
        CurPitchPos_N   <= CurPitchPos_D - 1;
        if CurPitchPos_D - 1 < ServoPitchMin then
          CurPitchPos_N <= conv_word(ServoPitchMin, CurPitchPos_D'length);
        end if;
      end if;
    end if;

    -- Limit the servo update rate to 20 Hz for now, otherwise the servos go bonkers
    Cnt_N <= Cnt_D + 1;
    if (Cnt_D = 3200) then
      Cnt_N <= (others => '0');
    else
      CurPitchPos_N <= CurPitchPos_D;
      CurYawPos_N   <= CurYawPos_D;
    end if;
  end process;

  SyncProc : process (Clk64Khz, RstN64kHz)
  begin
    if RstN64kHz = '0' then
      CurYawPos_D   <= conv_word(ServoYawStart, CurYawPos_D'length);
      CurPitchPos_D <= conv_word(ServoPitchStart, CurPitchPos_D'length);
      Cnt_D <= (others => '0');
    elsif rising_edge(Clk64Khz) then
      Cnt_D <= Cnt_N;
      CurYawPos_D   <= CurYawPos_N;
      CurPitchPos_D <= CurPitchPos_N;
    end if;
  end process;
  
  YawPossAssign  : YawPos   <= CurYawPos_D;
  PitchPosAssign : PitchPos <= CurPitchPos_D;
end architecture rtl;
