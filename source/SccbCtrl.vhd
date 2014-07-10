-- State machine that controls the writing of the sccb bus as defined by omnivision
-- Copyright Erik Zachrisson - erik@zachrisson.info

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;

entity SccbCtrl is
  port (
    clk_i        : in    bit1;
    rst_i        : in    bit1;
    sccb_clk_i   : in    bit1;
    data_pulse_i : in    bit1;
    addr_i       : in    word(8-1 downto 0);
    data_i       : in    word(16-1 downto 0);
    data_o       : out   word(8-1 downto 0);
    rw_i         : in    bit1;
    start_i      : in    bit1;
    ack_error_o  : out   bit1;
    done_o       : out   bit1;
    sioc_o       : out   bit1;
    siod_io      : inout bit1
    );
end entity;

architecture fpga of SccbCtrl is
  signal sccb_stm_clk : bit1;
  signal stm          : word(7-1 downto 0);
  signal bit_out      : bit1;
  signal ack_err      : bit1;

  signal done : bit1;
  
begin
  done_o <= done;

  sioc_o <= sccb_clk_i when start_i = '1' and
((stm >= 5 and stm  <= 12) or stm = 14 or
 (stm >= 16 and stm <= 23) or stm = 25 or
 (stm >= 27 and stm <= 34) or stm = 36 or
 (stm >= 44 and stm <= 51) or stm = 53 or
 (stm >= 55 and stm <= 62) or stm = 64)
            else sccb_stm_clk;
  
  siod_io <= 'Z' when stm <= 62 and
             (stm = 13 or
              stm = 14 or
              stm = 24 or
              stm = 25 or
              stm = 35 or
              stm = 36 or
              stm = 52 or
              stm = 53 or
              stm >= 54)
             else bit_out;
  ack_error_o <= ack_err;

  SyncProc : process (Rst_i, Clk_i)
  begin
    if Rst_i = '0' then
      stm          <= (others => '0');
      sccb_stm_clk <= '1';
      bit_out      <= '1';
      data_o       <= (others => '0');
      done         <= '0';
      ack_err      <= '1';
      
    elsif rising_edge(Clk_i) then
      done <= '0';
      if Data_pulse_i = '1' then
        if (start_i = '0') then
          stm <= (others => '0');
        elsif (rw_i = '0' and stm = 25) then
          stm <= conv_word(37, stm'length);
        elsif (rw_i = '1' and stm = 36) then
          stm <= conv_word(65, stm'length);
        elsif (stm < 68) then
          stm <= stm + 1;
        end if;

        if start_i = '1' then
          case conv_integer(stm) is
            when 0 =>
              bit_out <= '1';
            when 1 =>
              bit_out <= '1';

            -- Start write transaction.
            when 2 =>
              bit_out <= '0';
            when 3 =>
              sccb_stm_clk <= '0';

            -- Write device`s ID address.
            when 4 =>
              bit_out <= addr_i(7);
            when 5 =>
              bit_out <= addr_i(6);
            when 6 =>
              bit_out <= addr_i(5);
            when 7 =>
              bit_out <= addr_i(4);
            when 8 =>
              bit_out <= addr_i(3);
            when 9 =>
              bit_out <= addr_i(2);
            when 10 =>
              bit_out <= addr_i(1);
            when 11 =>
              bit_out <= '0';
            when 12 =>
              bit_out <= '0';
            when 13 =>
              ack_err <= siod_io;
            when 14 =>
              bit_out <= '0';

            -- Write register address.
            when 15 =>
              bit_out <= data_i(15);
            when 16 =>
              bit_out <= data_i(14);
            when 17 =>
              bit_out <= data_i(13);
            when 18 =>
              bit_out <= data_i(12);
            when 19 =>
              bit_out <= data_i(11);
            when 20 =>
              bit_out <= data_i(10);
            when 21 =>
              bit_out <= data_i(9);
            when 22 =>
              bit_out <= data_i(8);
            when 23 =>
              bit_out <= '0';
            when 24 =>
              ack_err <= siod_io;
            when 25 =>
              bit_out <= '0';

            -- Write data. This concludes 3-phase write transaction.
            when 26 =>
              bit_out <= data_i(7);
            when 27 =>
              bit_out <= data_i(6);
            when 28 =>
              bit_out <= data_i(5);
            when 29 =>
              bit_out <= data_i(4);
            when 30 =>
              bit_out <= data_i(3);
            when 31 =>
              bit_out <= data_i(2);
            when 32 =>
              bit_out <= data_i(1);
            when 33 =>
              bit_out <= data_i(0);
            when 34 =>
              bit_out <= '0';
            when 35 =>
              ack_err <= siod_io;
            when 36 =>
              bit_out <= '0';

            -- Stop transaction.
            when 37 =>
              sccb_stm_clk <= '0';
            when 38 =>
              sccb_stm_clk <= '1';
            when 39 =>
              bit_out <= '1';

            -- Start read transaction. At this point register address has been set in prev write transaction.  
            when 40 =>
              sccb_stm_clk <= '1';
            when 41 =>
              bit_out <= '0';
            when 42 =>
              sccb_stm_clk <= '0';

            -- Write device`s ID address.
            when 43 =>
              bit_out <= addr_i(7);
            when 44 =>
              bit_out <= addr_i(6);
            when 45 =>
              bit_out <= addr_i(5);
            when 46 =>
              bit_out <= addr_i(4);
            when 47 =>
              bit_out <= addr_i(3);
            when 48 =>
              bit_out <= addr_i(2);
            when 49 =>
              bit_out <= addr_i(1);
            when 50 =>
              bit_out <= '1';
            when 51 =>
              bit_out <= '0';
            when 52 =>
              ack_err <= siod_io;
            when 53 =>
              bit_out <= '0';

            -- Read register value. This concludes 2-phase read transaction.
            when 54 =>
              bit_out <= '0';
            when 55 =>
              data_o(7) <= siod_io;
            when 56 =>
              data_o(6) <= siod_io;
            when 57 =>
              data_o(5) <= siod_io;
            when 58 =>
              data_o(4) <= siod_io;
            when 59 =>
              data_o(3) <= siod_io;
            when 60 =>
              data_o(2) <= siod_io;
            when 61 =>
              data_o(1) <= siod_io;
            when 62 =>
              data_o(0) <= siod_io;
            when 63 =>
              bit_out <= '1';
            when 64 =>
              bit_out <= '0';
              
            when 65 =>
              sccb_stm_clk <= '0';
            when 66 =>
              sccb_stm_clk <= '1';
            when 67 =>
              bit_out <= '1';
              done    <= '1';
              stm     <= (others => '0');
              
            when others =>
              sccb_stm_clk <= '1';
          end case;
        else
          sccb_stm_clk <= '1';
          bit_out      <= '1';
          done         <= '0';
          ack_err      <= '1';
        end if;
      end if;
    end if;
  end process;
  
end architecture;
