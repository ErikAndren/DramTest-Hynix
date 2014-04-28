library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;

entity DramTestTop is
  port (
    AsyncRst   : in    bit1;
    Clk        : in    bit1;
   -- Here goes dram interface
    SdramSA    : out   word(12-1 downto 0);
    SdramBA    : out   word(2-1 downto 0);
    SdramCS_N  : out   word(1-1 downto 0);
    SdramCKE   : out   bit1;
    SdramRAS_N : out   bit1;
    SdramCAS_N : out   bit1;
    SdramWE_N  : out   bit1;
    SdramDQ    : inout word(DSIZE-1 downto 0);
    SdramDQM   : out   word(DSIZE/8-1 downto 0);
    SdramClk   : out   bit1;
    -- VGA interface
    VgaRed     : out   word(ColResW-1 downto 0);
    VgaGreen   : out   word(ColResW-1 downto 0);
    VgaBlue    : out   word(ColResW-1 downto 0);
    VgaHsync   : out   bit1;
    VgaVSync   : out   bit1;
    -- Sccb interface
    SIO_C      : out   bit1;
    SIO_D      : inout bit1;
    -- Cam interface
    CamClk     : out   bit1;
    CamHRef    : in    bit1;
    CamVSync   : in    bit1;
    CamD       : in    word(8-1 downto 0)
    );
end entity;

architecture rtl of DramTestTop is
  signal Clk100MHz               : bit1;
  signal RstN100MHz              : bit1;
  --
  signal Clk50MHz                : bit1;
  signal RstN50MHz               : bit1;
  --
  signal Clk25MHz                : bit1;
  signal RstN25MHz               : bit1;
  --
  signal RawClk25MHz             : bit1;
  --
  signal SdramAddr               : word(ASIZE-1 downto 0);
  signal SdramCmd                : word(3-1 downto 0);
  signal SdramCmdAck             : bit1;
  --
  signal SdramDataIn             : word(DSIZE-1 downto 0);
  signal SdramDataOut            : word(DSIZE-1 downto 0);
  --
  signal SdramDataVal            : bit1;
  signal VgaInView               : bit1;
  signal VgaPixelToDisp          : word(PixelW-1 downto 0);
  --
  signal SdramDataMask           : word(DSIZE/8-1 downto 0);
  --
  signal SdramCS_N_i             : word(2-1 downto 0);
  --
  signal ShaperBp                : bit1;
  --
  signal ReqFromArb              : DramRequest;
  signal ReqFromArbWe            : bit1;
  --
  signal ReqToCont               : DramRequest;
  signal ContCmdAck              : bit1;
  --
  signal WriteReqFromPatGen      : DramRequest;
  signal WriteReqFromPatGenAck   : bit1;
  --
  signal ReadReqFromRespHdler    : DramRequest;
  signal ReadReqFromRespHdlerAck : bit1;
  --
  signal PixelVal                : bit1;
  signal PixelData               : word(8-1 downto 0);
  signal VSync_i                 : bit1;
  --
  signal LastFrameComp           : word(FramesW-1 downto 0);

begin
  -- Pll
  Pll100MHz : entity work.PLL
    port map (
      inclk0 => Clk,
      c0     => Clk100MHz,
      c1     => SdramClk
      );

  ClkDivTo50Mhz : entity work.ClkDiv
    generic map (
      SourceFreq => 100,
      SinkFreq   => 50
      )
    port map (
      Clk => Clk100MHz,
      RstN => RstN100MHz,
      --
      Clk_out => Clk50MHz
      );
  
  ClkDivTo25Mhz : entity work.ClkDiv
    generic map (
      SourceFreq => 50,
      SinkFreq   => 25
      )
    port map (
      Clk     => Clk50MHz,
      RstN    => RstN50MHz,
      --
      Clk_out => Clk25MHz
      );

  RawClkDivTo25Mhz : entity work.ClkDiv
    generic map (
      SourceFreq => 50,
      SinkFreq   => 25
      )
    port map (
      Clk     => Clk,
      RstN    => RstN50MHz,
      --
      Clk_out => RawClk25MHz
      );

  -- Use raw, divided clock
  CamClkFeed : CamClk <= RawClk25MHz;
  
  -- Reset synchronizer
  RstSync100Mhz : entity work.ResetSync
    port map (
      AsyncRst => AsyncRst,
      Clk      => Clk100MHz,
      --
      Rst_N    => RstN100MHz
      );

  RstSync50Mhz : entity work.ResetSync
    port map (
      AsyncRst => AsyncRst,
      Clk      => Clk50MHz,
      --
      Rst_N    => RstN50MHz
      );

  RstSync25Mhz : entity work.ResetSync
    port map (
      AsyncRst => AsyncRst,
      Clk      => Clk25MHz,
      --
      Rst_N    => RstN25MHz
      );

  SccbM : entity work.SccbMaster
    port map (
      Clk          => RawClk25MHz,
      Rst_N        => RstN25MHz,
      --
      DataFromSccb => open,
      --
      SIO_C        => SIO_C,
      SIO_D        => SIO_D
      );

  -- This clock is probably invalid for this purpose. Use the raw clk divided
  CaptPixel : entity work.CamCapture
    generic map (
      DataW => 8
      )
    port map (
      RstN      => RstN25MHz,
      Clk       => Clk25MHz,
      --
      PRstN     => RstN25MHz,
      -- HACK: We use the internal raw 25 MHz clock for
      -- now due to the bad quality of the incoming one.      
      PClk      => Clk25MHz,
      --                   
      Vsync     => CamVSYNC,
      HREF      => CamHREF,
      PixelData => CamD,
      --
      PixelOut  => PixelData,
      PixelVal  => PixelVal,      
      --
      Vsync_Clk => Vsync_i
      );
  
  CamAlign : entity work.CamAligner
    port map (
      WrRst_N       => RstN25MHz,
      WrClk         => Clk25MHz,
      --
      Vsync         => Vsync_i,
      Href          => PixelVal,
      D             => PixelData,
      --
      RdClk         => Clk50MHz,
      RdRst_N       => RstN50MHz,
      --
      WriteReq      => WriteReqFromPatGen,
      WriteReqAck   => WriteReqFromPatGenAck,
      --
      LastFrameComp => LastFrameComp
      );      

  SdramArb : entity work.SdramArbiter
    port map (
      Clk         => Clk50MHz,
      Rst_N       => RstN50MHz,
      --
      WriteReq    => WriteReqFromPatGen,
      WriteReqAck => WriteReqFromPatGenAck,
      --
      ReadReq     => ReadReqFromRespHdler,
      ReadReqAck  => ReadReqFromRespHdlerAck,
      --
      ShapBp      => ShaperBp,
      ArbDecReq   => ReqFromArb,
      ArbDecVal   => ReqFromArbWe
      );

  ReqHdler : entity work.RequestHandler
    port map (
      WrClk      => Clk50MHz,
      WrRstN     => RstN50MHz,
      ReqIn      => ReqFromArb,
      We         => ReqFromArbWe,
      ShapBp     => ShaperBp,
      --
      RdClk      => Clk100MHz,
      RdRst_N    => RstN100MHz,
      ReqOut     => ReqToCont,
      ReqDataOut => SdramDataIn,
      CmdAck     => SdramCmdAck,
      --
      RespVal    => SdramDataVal
      );

  SdramAddr     <= ReqToCont.Addr;
  SdramCmd      <= ReqToCont.Cmd;
  SdramDataMask <= (others => '0');

  -- Dram controller
  SdramController : entity work.sdr_sdram
    generic map (
      ASIZE     => ASIZE,
      DSIZE     => DSIZE,
      ROWSIZE   => ROWSIZE,
      COLSIZE   => COLSIZE,
      BANKSIZE  => BANKSIZE,
      ROWSTART  => ROWSTART,
      COLSTART  => COLSTART,
      BANKSTART => BANKSTART
      )
    port map (
      Clk              => Clk100MHz,
      Reset_N          => RstN100MHz,
      --
      ADDR             => SdramAddr,
      CMD              => SdramCmd,
      CMDACK           => SdramCmdAck,
      --
      DATAIN           => SdramDataIn,
      DATAOUT          => SdramDataOut,
      DM               => SdramDataMask,
      --
      SA               => SdramSA,
      BA               => SdramBA,
      CS_N             => SdramCS_N_i,
      CKE              => SdramCKE,
      RAS_N            => SdramRAS_N,
      CAS_N            => SdramCAS_N,
      WE_N             => SdramWE_N,
      DQ               => SdramDQ,
      DQM              => SdramDQM
      );
  SdramCs_N <= SdramCs_N_i(0 downto 0);

  RespHdler : entity work.RespHandler
    port map (
      WrRst_N       => RstN100MHz,
      WrClk         => Clk100MHz,
      --
      RespData      => SdramDataOut,
      RespDataVal   => SdramDataVal,
      LastFrameComp => LastFrameComp,
      --
      RdRst_N       => RstN25MHz,
      RdClk         => Clk25MHz,
      --
      ReadReq       => ReadReqFromRespHdler,
      ReadReqAck    => ReadReqFromRespHdlerAck,
      --
      InView        => VgaInView,
      PixelToDisp   => VgaPixelToDisp
      );

  VGAGen : entity work.VGAGenerator
    generic map (
      DataW     => PixelW,
      DivideClk => false
      )
    port map (
      Clk            => Clk25MHz,
      RstN           => RstN25MHz,
      --
      PixelToDisplay => VgaPixelToDisp,
      DrawRect       => '0',
      InView         => VgaInView,
      --
      Red            => VgaRed,
      Green          => VgaGreen,
      Blue           => VgaBlue,
      Hsync          => VgaHsync,
      VSync          => VgaVsync
      );
      
end architecture rtl;
