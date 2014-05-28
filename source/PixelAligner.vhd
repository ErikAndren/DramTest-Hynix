-- Extract the different types of signals in the incoming data stream.
-- Current implementation extracts the luminance from the incoming YUV encoded
-- signal.
-- Copyright Erik Zachrisson, erik@zachrisson.info 2014

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

entity PixelAligner is
  generic (
    DataInW  : positive := 8;
    DataOutW : positive := 8
    );
  port (
    RstN            : in  bit1;
    Clk             : in  bit1;
    --
    Vsync           : in  bit1;
    PixelInVal      : in  bit1;
    PixelIn         : in  word(DataInW-1 downto 0);
    --
    GrayScaleOutVal : out bit1;
    GrayScaleOut    : out word(DataOutW-1 downto 0);
    --
    Color           : out word(DataOutW-1 downto 0);
    ColorOutVal     : out bit1
    );
end entity;

architecture rtl of PixelAligner is
  signal Cnt_N, Cnt_D                     : word(2-1 downto 0);
  signal Y_N, Y_D, Cb_N, Cb_D, Cr_N, Cr_D : word(DataInW-1 downto 0);
  signal GrayScaleVal_N, GrayScaleVal_D   : bit1;
  signal R, G, B                          : word(DataInW-1 downto 0);
  signal AdjY, AdjCr, AdjCb               : word(DataInW-1 downto 0);
  signal AdjY_0_125                       : word(DataInW-1 downto 0);
  signal AdjY_1_125                       : word(DataInW downto 0);
  --
  signal AdjCr_0_5                        : word(DataInW-1 downto 0);
  signal AdjCr_0_25                       : word(DataInW-1 downto 0);
  signal AdjCr_0_125                      : word(DataInW-1 downto 0);
  signal AdjCr_0_0625                     : word(DataInW-1 downto 0);
  signal AdjCr_0_03125                    : word(DataInW-1 downto 0);
  --
  signal AdjCr_0_8125                     : word(DataInW-1 downto 0);
  signal AdjCr_1_59375                    : word(DataInW downto 0);
  signal AdjCr_1_375                      : word(DataInW downto 0);
  --
  signal AdjCb_0_5                        : word(DataInW-1 downto 0);
  signal AdjCb_0_25                       : word(DataInW-1 downto 0);
  signal AdjCb_0_125                      : word(DataInW-1 downto 0);
  signal AdjCb_0_0625                     : word(DataInW-1 downto 0);
  signal AdjCb_0_03125                    : word(DataInW-1 downto 0);
  signal AdjCb_0_015625                   : word(DataInW-1 downto 0);
  --
  signal AdjCb_0_3906                     : word(DataInW-1 downto 0);
  signal AdjCb_1_772                      : word(DataInW downto 0);
  --
  signal R_Dithered                       : word(3-1 downto 0);
  signal G_Dithered                       : word(3-1 downto 0);
  signal B_Dithered                       : word(2-1 downto 0);
  signal R_DitheredVal                    : bit1;
  signal B_DitheredVal                    : bit1;
begin
  SyncRstProc : process (Clk, RstN)
  begin
    if RstN = '0' then
      GrayScaleVal_D <= '0';
    elsif rising_edge(Clk) then
      GrayScaleVal_D <= GrayScaleVal_N;
    end if;
  end process;
  
  SyncNoRstProc : process (Clk)
  begin
    if rising_edge(Clk) then
      Cnt_D          <= Cnt_N;
      Y_D            <= Y_N;
      Cb_D           <= Cb_N;
      Cr_D           <= Cr_N;
    end if;
  end process;

  AsyncProc : process (Cnt_D, Vsync, PixelInVal, Y_D, Cb_D, Cr_D,  PixelIn)
  begin
    Cnt_N          <= Cnt_D;
    GrayScaleVal_N <= '0';
    Y_N            <= Y_D;
    Cb_N           <= Cb_D;
    Cr_N           <= Cr_D;

    if PixelInVal = '1' then
      Cnt_N <= Cnt_D + 1;

      if (Cnt_D(0) = '1') then
        Y_N            <= PixelIn;
        GrayScaleVal_N <= '1';
      end if;

      if Cnt_D = "00" then
        Cb_N <= PixelIn;
      end if;

      if Cnt_D = "10" then
        Cr_N <= PixelIn;
      end if;
    end if;

    if Vsync = '1' then
      Cnt_N <= (others => '0');
    end if;
  end process;

  AdjY       <= Y_D - 16   when Y_D - 16 > 0   else (others => '0');
  AdjY_0_125   <= SHR(AdjY, "11");
  AdjY_1_125 <= ('0' & AdjY) + ('0' & AdjY_0_125);
  --
  -- AdjCr      <= Cr_D - 128 when Cr_D - 128 > 0 else (others => '0');
  -- AdjCb      <= Cb_D - 128 when Cb_D - 128 > 0 else (others => '0');
  AdjCr      <= Cr_D - 128 when Cr_D - 128 > 0 else (others => '0');
  AdjCb      <= Cb_D - 128 when Cb_D - 128 > 0 else (others => '0');

  AdjCr_0_5     <= SHR(AdjCr, "01");
  AdjCr_0_25    <= SHR(AdjCr, "10");
  AdjCr_0_125   <= SHR(AdjCr, "11");
  AdjCr_0_0625  <= SHR(AdjCr, "100");
  AdjCr_0_03125 <= SHR(AdjCr, "101");
  --
  AdjCr_0_8125  <= AdjCr - AdjCr_0_25 + AdjCr_0_125 - AdjCr_0_0625;
  AdjCr_1_59375 <= ('0' & AdjCr) + ('0' & AdjCr_0_5) + ('0' & AdjCr_0_125) + ('0' & AdjCr_0_03125);
  AdjCr_1_375   <= ('0' & AdjCr) + ('0' & AdjCr_0_5) - ('0' & AdjCr_0_25) + ('0' & AdjCr_0_125);
  
  AdjCb_0_5 <= SHR(AdjCb, "01");
  AdjCb_0_25 <= SHR(AdjCb, "10");
  AdjCb_0_125 <= SHR(AdjCb, "11");
  AdjCb_0_0625 <= SHR(AdjCb, "100");
  AdjCb_0_03125 <= SHR(AdjCb, "101");
  AdjCb_0_015625 <= SHR(AdjCb, "110");
  --
  AdjCb_0_3906 <= AdjCb - AdjCb_0_5 - AdjCb_0_25 + AdjCb_0_125 + AdjCb_0_0625 - AdjCb_0_03125 - AdjCb_0_015625;
  AdjCb_1_772 <= ('0' & AdjCb) + ('0' & AdjCb_0_5) + ('0' & AdjCb_0_25);
  
  
  RGBConv : process (AdjY_1_125, AdjCb, AdjCr_0_8125, AdjCr_1_59375, AdjCb_0_3906, AdjCr_1_375, Y_D, AdjCb_1_772)
    variable B_T : word(B'length+1 downto 0);  
    variable G_T : word(G'length+1 downto 0);
    variable R_T : word(R'length+1 downto 0);
    
  begin
    -- Cb_D = U, Cr_D = V
    -- B = 1.164(Y - 16)                  + 2.018(U - 128)
    -- G = 1.164(Y - 16) - 0.813(V - 128) - 0.391(U - 128)
    -- R = 1.164(Y - 16) + 1.596(V - 128)

    
    --B_T := ('0' & AdjY_1_125) + SHL('0' & AdjCb, "1");
    ---- Check for wrap    
    --if B_T(B_T'high) = '1' then
    --  B <= (others => '1');
    --else
    --  B <= B_T(B'length-1 downto 0);
    --end if;

    --G_T := ('1' & AdjY_1_125) - AdjCr_0_8125 - AdjCb_0_3906;
    ---- Check for negative wrap
    --if G_T(G_T'high) = '0' then
    --  G <= (others => '0');
    ---- Check for positive wrap
    --elsif G_T(G_T'high-1) = '1' then
    --  G <= (others => '1');
    --else
    --  G <= G_T(G'length-1 downto 0);
    --end if;
    
    --R_T := AdjY_1_125 + ('0' & AdjCr_1_59375);
    ---- Check for wrap
    --if R_T(R_T'high) = '1' then
    --  R <= (others => '1');
    --else
    --  R <= R_T(R'length-1 downto 0);
    --end if;

    -- R = Y + 1.402 (Cr-128)
    -- G = Y - 0.34414 * (Cb - 128) - 0.71414 * (Cr - 128)
    -- B = Y + 1.772 * (Cb - 128)

    R_T := ('0' & Y_D) + ('0' & AdjCr_1_375);
    -- Check for wrap
    if R_T(R_T'high) = '1' then
      R <= (others => '1');
    else
      R <= R_T(R'length-1 downto 0);
    end if;

    G_T := ("01" & Y_D) - ('0' & AdjCb_0_3906) - ('0' & AdjCr_0_8125);
    -- Check for negative wrap
    if G_T(G_T'high) = '0' then
      G <= (others => '0');
    -- Check for positive wrap
    elsif G_T(G_T'high-1) = '1' then
      G <= (others => '1');
    else
      G <= G_T(G'length-1 downto 0);
    end if;
    
    B_T := ('0' & Y_D) + ('0' & AdjCb_1_772);
    --Check for wrap    
    if B_T(B_T'high) = '1' then
      B <= (others => '1');
    else
      B <= B_T(B'length-1 downto 0);
    end if;
  end process;

  GrayScaleOutValFeed : GrayScaleOutVal <= GrayScaleVal_D;
  GrayScaleOutFeed    : GrayScaleOut    <= Y_D;
  --

  RedDither : entity work.DitherFloydSteinberg
    generic map (
      DataW     => 8,
      CompDataW => 3
      )
    port map (
      RstN        => RstN,
      Clk         => Clk,
      --
      Vsync       => Vsync,
      --
      PixelIn     => R,
      PixelInVal  => GrayScaleVal_D,
      --
      PixelOut    => R_Dithered,
      PixelOutVal => R_DitheredVal
      );
  
  GreenDither : entity work.DitherFloydSteinberg
    generic map (
      DataW     => 8,
      CompDataW => 3
      )
    port map (
      RstN        => RstN,
      Clk         => Clk,
      --
      Vsync       => Vsync,
      --
      PixelIn     => G,
      PixelInVal  => GrayScaleVal_D,
      --
      PixelOut    => G_Dithered,
      PixelOutVal => open
      );

  BlueDither : entity work.DitherFloydSteinberg
    generic map (
      DataW     => 8,
      CompDataW => 2
      )
    port map (
      RstN        => RstN,
      Clk         => Clk,
      --
      Vsync       => Vsync,
      --
      PixelIn     => B,
      PixelInVal  => GrayScaleVal_D,
      --
      PixelOut    => B_Dithered,
      PixelOutVal => B_DitheredVal
      );
  
  --RedFeed   : Color(RedHigh downto RedLow)     <= R(8-1 downto 5);
  --GreenFeed : Color(GreenHigh downto GreenLow) <= G(8-1 downto 5);
  --BlueFeed  : Color(BlueHigh downto BlueLow)   <= B(8-1 downto 6);

  RedFeed   : Color(RedHigh downto RedLow)     <= R_Dithered;
  GreenFeed : Color(GreenHigh downto GreenLow) <= G_Dithered;
  BlueFeed  : Color(BlueHigh downto BlueLow)   <= B_Dithered;

  ColorValFeed     : ColorOutVal     <= B_DitheredVal;
  
end architecture rtl;
