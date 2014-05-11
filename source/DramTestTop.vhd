library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.DramTestPack.all;
use work.SramPack.all;
use work.VgaPack.all;
use work.ServoPack.all;

entity DramTestTop is
  port (
    AsyncRst   : in    bit1;
    Clk        : in    bit1;
    -- Sdram interface
    SdramSA    : out   word(12-1 downto 0);
    SdramBA    : out   word(2-1 downto 0);
    SdramCS_N  : out   word(1-1 downto 0);
    SdramCKE   : out   bit1;
    SdramRAS_N : out   bit1;
    SdramCAS_N : out   bit1;
    SdramWE_N  : out   bit1;
    SdramDQ    : inout word(DSIZE-1 downto 0);
    SdramDQM   : out   word(DSIZE/8-1 downto 0);
    ClkToSdram : out   bit1;
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
    CamD       : in    word(8-1 downto 0);
    -- Button interface
    Button1    : in    bit1;
    Button2    : in    bit1;
    Button3    : in    bit1;
    -- Sram interface
    SramD      : inout word(SramDataW-1 downto 0);
    SramAddr   : out   word(SramAddrW-1 downto 0);
    SramCeN    : out   bit1;
    SramOeN    : out   bit1;
    SramWeN    : out   bit1;
    SramUbN    : out   bit1;
    SramLbN    : out   bit1;
    -- Servo interface
    PitchServo : out   bit1;
    YawServo   : out   bit1
    );
end entity;

architecture rtl of DramTestTop is
  signal Clk100MHz                       : bit1;
  signal RstN100MHz                      : bit1;
  --
  signal Clk25MHz                        : bit1;
  signal RstN25MHz                       : bit1;
  --
  signal Clk64kHz                        : bit1;
  signal RstN64kHz                       : bit1;
  --
  signal SdramAddr                       : word(ASIZE-1 downto 0);
  signal SdramCmd                        : word(3-1 downto 0);
  signal SdramCmdAck                     : bit1;
  --
  signal SdramDataIn                     : word(DSIZE-1 downto 0);
  signal SdramDataOut                    : word(DSIZE-1 downto 0);
  --
  signal SdramDataVal                    : bit1;
  signal VgaInView                       : bit1;
  signal VgaPixelToDisp                  : word(PixelW-1 downto 0);
  --
  signal SdramDataMask                   : word(DSIZE/8-1 downto 0);
  --
  signal SdramCS_N_i                     : word(2-1 downto 0);
  --
  signal ShaperBp                        : bit1;
  --
  signal ReqFromArb                      : DramRequest;
  signal ReqFromArbWe                    : bit1;
  --
  signal ReqToCont                       : DramRequest;
  signal ContCmdAck                      : bit1;
  --
  signal WriteReqFromPatGen              : DramRequest;
  signal WriteReqFromPatGenAck           : bit1;
  --
  signal ReadReqFromRespHdler            : DramRequest;
  signal ReadReqFromRespHdlerAck         : bit1;
  --
  signal PixelVal                        : bit1;
  signal PixelData                       : word(8-1 downto 0);
  signal AlignedPixDataVal               : bit1;
  signal AlignedPixData                  : word(8-1 downto 0);
  --
  signal VSync_i                         : bit1;
  --
  signal LastFrameComp                   : word(FramesW-1 downto 0);
  signal FirstFrameVal                   : bit1;
  --
  signal VgaVsync_i                      : bit1;
  signal VgaVSyncN, VgaHSyncN            : bit1;
  --
  signal SramContAddr                    : word(SramAddrW-1 downto 0);
  signal SramContWd                      : word(SramDataW-1 downto 0);
  signal SramContRd                      : word(SramDataW-1 downto 0);
  signal SramContWe                      : bit1;
  signal SramContRe                      : bit1;
  --
  signal SramReadAddr                    : word(SramAddrW-1 downto 0);
  signal SramRe                          : bit1;
  signal SramPopRead                     : bit1;
  signal SramWriteAddr                   : word(SramAddrW-1 downto 0);
  signal SramWe                          : bit1;
  signal SramPopWrite                    : bit1;
  --
  signal TempPixelOut                    : word(PixelW-1 downto 0);
  signal TempPixelOutVal                 : bit1;
  --
  signal PixelPostFilter                 : word(PixelW-1 downto 0);
  signal PixelPostFilterVal              : bit1;
  --
  signal ObjFindPixel                    : word(PixelW-1 downto 0);
  signal ObjFindPixelVal                 : bit1;
  --
  signal Btn1Pulse, Btn2Pulse, Btn3Pulse : bit1;
  --
  signal DrawRect                        : bit1;
  --
  signal ObjTopLeft, ObjBottomRight      : Cord;
  signal YawPos, PitchPos                : word(ServoResW-1 downto 0);
  --
  
begin
  -- Pll
  Pll100MHz : entity work.PLL
    port map (
      inclk0 => Clk,
      c0     => Clk100MHz,
      c1     => ClkToSdram,
      c2     => Clk25MHz
      );

  Clk64kHzGen : entity work.ClkDiv
    generic map (
      SourceFreq => 25000000,
      SinkFreq => 64000
    )
    port map (
      Clk     => Clk25MHz,
      RstN    => RstN25MHz,
      Clk_out => Clk64kHz
      );
  
  CamClkFeed : CamClk <= Clk25MHz;

  -- Reset synchronizer
  RstSync100Mhz : entity work.ResetSync
    port map (
      AsyncRst => AsyncRst,
      Clk      => Clk100MHz,
      --
      Rst_N    => RstN100MHz
      );

  RstSync25Mhz : entity work.ResetSync
    port map (
      AsyncRst => AsyncRst,
      Clk      => Clk25MHz,
      --
      Rst_N    => RstN25MHz
      );

  RstSync64kHz : entity work.ResetSync
    port map (
      AsyncRst => AsyncRst,
      Clk      => Clk64kHz,
      --
      Rst_N    => RstN64kHz
      );
  
  DebBtn1 : entity work.ButtonPulse
    port map (
      Clk         => Clk25MHz,
      RstN        => RstN25MHz,
      --
      Button      => Button1,
      ButtonPulse => Btn1Pulse
      );

  DebBtn2 : entity work.ButtonPulse
    port map (
      Clk         => Clk25MHz,
      RstN        => RstN25MHz,
      --
      Button      => Button2,
      ButtonPulse => Btn2Pulse
      );

  DebBtn3 : entity work.ButtonPulse
    port map (
      Clk         => Clk25MHz,
      RstN        => RstN25MHz,
      --
      Button      => Button3,
      ButtonPulse => Btn3Pulse
      );
  
  SccbM : entity work.SccbMaster
    port map (
      Clk          => Clk25MHz,
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

  PixAlign : entity work.PixelAligner
    port map (
      RstN            => RstN25MHz,
      Clk             => Clk25MHz,
      --
      Vsync           => Vsync_i,
      PixelInVal      => PixelVal,
      PixelIn         => PixelData,
      --
      GrayScaleOut    => AlignedPixData,
      GrayScaleOutVal => AlignedPixDataVal
      );

  FChain : entity work.FilterChain
    generic map (
      DataW     => PixelW,
      CompDataW => PixelW
      )
    port map (
      Clk          => Clk25MHz,
      RstN         => RstN25MHz,
      --
      Vsync        => Vsync_i,
      ToggleMode   => Btn3Pulse,
      IncThreshold => Btn2Pulse,
      DecThreshold => Btn1Pulse,
      --
      --PixelIn      => AlignedPixData,
      --PixelInVal   => AlignedPixDataVal,
      PixelIn      => TempPixelOut,
      PixelInVal   => TempPixelOutVal,
      --
      PixelOut     => PixelPostFilter,
      PixelOutVal  => PixelPostFilterVal
      );
  
  -- 262144 16 bit words available
  -- Need 640x480 / 2 words = 153600 words
  TempAvg : entity work.TemporalAverager
    generic map (
      DataW => PixelW
      )
    port map (
      RstN          => RstN25MHz,
      Clk           => Clk25MHz,
      --
      Vsync         => Vsync_i,
      --
      PixelInVal    => AlignedPixDataVal,
      PixelIn       => AlignedPixData,
      --PixelInVal    => PixelPostFilterVal,
      --PixelIn       => PixelPostFilter,
      --
      SramReadAddr  => SramReadAddr,
      SramRe        => SramRe,
      SramRd        => SramContRd,
      PopRead       => SramPopRead,
      --
      SramWriteAddr => SramWriteAddr,
      SramWd        => SramContWd,
      SramWe        => SramWe,
      PopWrite      => SramPopWrite,
      --
      PixelOut      => TempPixelOut,
      PixelOutVal   => TempPixelOutVal
      );

  Sram : block
  begin
    SramArb : entity work.SramArbiter
      port map (
        RstN      => RstN25MHz,
        Clk       => Clk25MHz,
        --
        WriteReq  => SramWe,
        WriteAddr => SramWriteAddr,
        PopWrite  => SramPopWrite,
        --
        ReadReq   => SramRe,
        ReadAddr  => SramReadAddr,
        PopRead   => SramPopRead,
        --
        SramAddr  => SramContAddr,
        SramWe    => SramContWe,
        SramRe    => SramContRe
        );

    SramCon : entity work.SramController
      port map (
        Clk     => Clk25MHz,
        RstN    => RstN25MHz,
        --
        AddrIn  => SramContAddr,
        WrData  => SramContWd,
        RdData  => SramContRd,
        We      => SramContWe,
        Re      => SramContRe,
        --
        D       => SramD,
        AddrOut => SramAddr,
        CeN     => SramCeN,
        OeN     => SramOeN,
        WeN     => SramWeN,
        UbN     => SramUbN,
        LbN     => SramLbN
        );
  end block;

  ObjFin : entity work.ObjectFinder
    generic map (
      DataW => PixelW
      )
    port map (
      RstN        => RstN25MHz,
      Clk         => Clk25MHz,
      --
      Vsync       => Vsync_i,
      --
      PixelIn     => PixelPostFilter,
      PixelInVal  => PixelPostFilterVal,
      --
      PixelOut    => ObjFindPixel,
      PixelOutVal => ObjFindPixelVal,
      RectAct     => open,
      --
      TopLeft     => ObjTopLeft,
      BottomRight => ObjBottomRight
      );

  Servo : block
  begin
    PWMC : entity work.PWMCtrl
      port map (
        Clk64kHz    => Clk64kHz,
        RstN64kHz   => RstN64kHz,
        --
        TopLeft     => ObjTopLeft,
        BottomRight => ObjBottomRight,
        --
        YawPos      => YawPos,
        PitchPos    => PitchPos
        );

    YawServoDriver : entity work.ServoPwm
      generic map (
        ResW => ServoResW
        )
      port map (
        Clk   => Clk64Khz,
        RstN  => RstN25MHz,
        --
        Pos   => YawPos,
        --
        Servo => YawServo
        );

    PitchServoDriver : entity work.ServoPwm
      generic map (
        ResW => ServoResW
        )
      port map (
        Clk   => Clk64Khz,
        RstN  => RstN25MHz,
        --
        Pos   => PitchPos,
        --
        Servo => PitchServo
        );
  end block;

  CamAlign : entity work.CamAligner
    port map (
      WrRst_N       => RstN25MHz,
      WrClk         => Clk25MHz,
      --
      Vsync         => Vsync_i,
      --Href          => AlignedPixDataVal,
      --D             => AlignedPixData,
--      Href          => TempPixelOutVal,
--      D             => TempPixelOut,
      --Href          => PixelPostFilterVal,
      --D             => PixelPostFilter,
      Href          => ObjFindPixelVal,
      D             => ObjFindPixel,
      --
      RdClk         => Clk25MHz,
      RdRst_N       => RstN25MHz,
      --
      WriteReq      => WriteReqFromPatGen,
      WriteReqAck   => WriteReqFromPatGenAck,
      --
      FirstFrameVal => FirstFrameVal,
      LastFrameComp => LastFrameComp
      );

  SdramArb : entity work.SdramArbiter
    port map (
      Clk         => Clk25MHz,
      Rst_N       => RstN25MHz,
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
      WrClk      => Clk25MHz,
      WrRstN     => RstN25MHz,
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
  SdramCs_N     <= SdramCs_N_i(0 downto 0);

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
      Clk     => Clk100MHz,
      Reset_N => RstN100MHz,
      --
      ADDR    => SdramAddr,
      CMD     => SdramCmd,
      CMDACK  => SdramCmdAck,
      --
      DATAIN  => SdramDataIn,
      DATAOUT => SdramDataOut,
      DM      => SdramDataMask,
      --
      SA      => SdramSA,
      BA      => SdramBA,
      CS_N    => SdramCS_N_i,
      CKE     => SdramCKE,
      RAS_N   => SdramRAS_N,
      CAS_N   => SdramCAS_N,
      WE_N    => SdramWE_N,
      DQ      => SdramDQ,
      DQM     => SdramDQM
      );

  RespHdler : entity work.RespHandler
    port map (
      WrRst_N       => RstN100MHz,
      WrClk         => Clk100MHz,
      --
      RespData      => SdramDataOut,
      RespDataVal   => SdramDataVal,
      FirstFrameVal => FirstFrameVal,
      LastFrameComp => LastFrameComp,
      --
      RdRst_N       => RstN25MHz,
      RdClk         => Clk25MHz,
      --
      ReadReq       => ReadReqFromRespHdler,
      ReadReqAck    => ReadReqFromRespHdlerAck,
      -- Vga interface
      VgaVsync      => VgaVsync_i,
      InView        => VgaInView,
      PixelToDisp   => VgaPixelToDisp
      );

  DrawRect <= VgaPixelToDisp(0);
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
      DrawRect       => DrawRect,
      InView         => VgaInView,
      --
      Red            => VgaRed,
      Green          => VgaGreen,
      Blue           => VgaBlue,
      HsyncN         => VgaHsyncN,
      VSyncN         => VgaVsyncN
      );
  VgaVsync_i <= not VgaVSyncN;
  VgaVSync   <= VgaVSyncN;
  VgaHSync   <= VgaHSyncN;
  
end architecture rtl;
