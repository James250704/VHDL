
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Final_02 is
    port (
        CLOCK_50  : in STD_LOGIC;
        KEY       : in STD_LOGIC_VECTOR(2 downto 0);
        PS2_KBCLK : in STD_LOGIC;
        PS2_KBDAT : in STD_LOGIC;
        GPIO_0    : out STD_LOGIC_VECTOR(21 downto 9);
        GPIO_1    : out STD_LOGIC_VECTOR(21 downto 9)
    );
end entity Final_02;

architecture arch of Final_02 is

    type LED8x8_type is array (1 to 8) of STD_LOGIC_VECTOR(1 to 8);
    type led_pattern_buffer is array (0 to 7) of STD_LOGIC_VECTOR(7 downto 0);

    constant CLK_FREQ            : INTEGER := 50_000_000;
    constant ANIMATION_TIMER_MAX : INTEGER := 1_562_500;
    constant SCAN_CLK_DIVISOR    : INTEGER := 25000;

    signal clk     : STD_LOGIC;
    signal reset_n : STD_LOGIC;

    signal ascii_new         : STD_LOGIC;
    signal ascii_code        : STD_LOGIC_VECTOR(6 downto 0);
    signal key_pressed_pulse : STD_LOGIC;
    signal prev_ascii_new    : STD_LOGIC := '0';

    type animation_state_type is (S_RESET, S_RUN, S_PAUSE, S_DIMMING, S_DONE);
    signal state              : animation_state_type;
    signal state_before_pause : animation_state_type := S_RUN;
    signal animation_timer    : INTEGER range 0 to ANIMATION_TIMER_MAX;
    signal current_row        : INTEGER range 0 to 7;
    signal current_col        : INTEGER range 0 to 7;
    signal led_pattern        : led_pattern_buffer;

    signal scan_clk_counter   : INTEGER range 0 to SCAN_CLK_DIVISOR - 1;
    signal scan_clk           : STD_LOGIC;
    signal scanline           : INTEGER range 0 to 7;
    signal row_out            : STD_LOGIC_VECTOR(1 to 8);
    signal col_out            : STD_LOGIC_VECTOR(1 to 8);
    signal led8x8map_from_fsm : LED8x8_type;

begin

    clk     <= CLOCK_50;
    reset_n <= KEY(0);

    ps2_to_ascii_inst : entity work.ps2_keyboard_to_ascii
        generic map(
            clk_freq                  => CLK_FREQ,
            ps2_debounce_counter_size => 8
        )
        port map(
            clk        => clk,
            ps2_clk    => PS2_KBCLK,
            ps2_data   => PS2_KBDAT,
            ascii_new  => ascii_new,
            ascii_code => ascii_code
        );

    process (clk)
    begin
        if rising_edge(clk) then
            key_pressed_pulse <= '0';
            if ascii_new = '1' and prev_ascii_new = '0' then
                key_pressed_pulse <= '1';
            end if;
            prev_ascii_new <= ascii_new;
        end if;
    end process;

    process (clk, reset_n)
    begin
        if reset_n = '0' then
            state <= S_RESET;
        elsif rising_edge(clk) then
            if key_pressed_pulse = '1' then
                if ascii_code = "0110000" then
                    state <= S_RESET;
                elsif ascii_code = "0100000" then
                    if state = S_RUN or state = S_DIMMING then
                        state_before_pause <= state;
                        state              <= S_PAUSE;
                    elsif state = S_PAUSE then
                        state <= state_before_pause;
                    end if;
                end if;
            end if;

            case state is
                when S_RESET =>
                    animation_timer <= 0;
                    current_row     <= 0;
                    current_col     <= 0;
                    led_pattern     <= (others => (others => '0'));
                    state           <= S_RUN;

                when S_RUN =>
                    if animation_timer < ANIMATION_TIMER_MAX then
                        animation_timer <= animation_timer + 1;
                    else
                        animation_timer                           <= 0;
                        led_pattern(current_row)(7 - current_col) <= '1';

                        if current_row = 7 and current_col = 7 then
                            state       <= S_DIMMING;
                            current_row <= 0;
                            current_col <= 0;
                        else
                            if current_col < 7 then
                                current_col <= current_col + 1;
                            else
                                current_col <= 0;
                                current_row <= current_row + 1;
                            end if;
                        end if;
                    end if;

                when S_DIMMING =>
                    if animation_timer < ANIMATION_TIMER_MAX then
                        animation_timer <= animation_timer + 1;
                    else
                        animation_timer                           <= 0;
                        led_pattern(current_row)(7 - current_col) <= '0';

                        if current_row = 7 and current_col = 7 then
                            state <= S_RESET;
                        else
                            if current_col < 7 then
                                current_col <= current_col + 1;
                            else
                                current_col <= 0;
                                current_row <= current_row + 1;
                            end if;
                        end if;
                    end if;

                when S_PAUSE | S_DONE =>
                    null;
            end case;
        end if;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            if scan_clk_counter < SCAN_CLK_DIVISOR - 1 then
                scan_clk_counter <= scan_clk_counter + 1;
            else
                scan_clk_counter <= 0;
                scan_clk         <= not scan_clk;
            end if;
        end if;
    end process;

    process (scan_clk, reset_n)
    begin
        if reset_n = '0' then
            scanline <= 0;
        elsif rising_edge(scan_clk) then
            if scanline = 7 then
                scanline <= 0;
            else
                scanline <= scanline + 1;
            end if;
        end if;
    end process;

    process (led_pattern)
    begin
        for i in 0 to 7 loop
            for j in 0 to 7 loop
                led8x8map_from_fsm(i + 1)(j + 1) <= led_pattern(i)(7 - j);
            end loop;
        end loop;
    end process;

    process (scanline)
    begin
        case scanline is
            when 0      => row_out      <= "01111111";
            when 1      => row_out      <= "10111111";
            when 2      => row_out      <= "11011111";
            when 3      => row_out      <= "11101111";
            when 4      => row_out      <= "11110111";
            when 5      => row_out      <= "11111011";
            when 6      => row_out      <= "11111101";
            when 7      => row_out      <= "11111110";
            when others => row_out <= "11111111";
        end case;
    end process;

    process (scanline, led8x8map_from_fsm)
    begin
        col_out <= led8x8map_from_fsm(scanline + 1);
    end process;

    GPIO_0(21) <= col_out(8); GPIO_0(19) <= col_out(7); GPIO_0(17) <= row_out(2); GPIO_0(15) <= col_out(1);
    GPIO_0(14) <= row_out(4); GPIO_0(13) <= col_out(6); GPIO_0(11) <= col_out(4); GPIO_0(9) <= row_out(1);

    GPIO_1(21) <= row_out(5); GPIO_1(19) <= row_out(7); GPIO_1(17) <= col_out(2); GPIO_1(15) <= col_out(3);
    GPIO_1(14) <= row_out(8); GPIO_1(13) <= col_out(5); GPIO_1(11) <= row_out(6); GPIO_1(9) <= row_out(3);

end architecture arch;
