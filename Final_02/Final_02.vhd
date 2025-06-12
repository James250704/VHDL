library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity Final_02 is
    port (
        clk        : in STD_LOGIC;                     -- 50 MHz system clock
        ps2_clk    : in STD_LOGIC;                     -- PS/2 clock line
        ps2_data   : in STD_LOGIC;                     -- PS/2 data line
        LEDG       : out STD_LOGIC_VECTOR(9 downto 0); -- LEDs (not used here)
        LEDR       : out STD_LOGIC_VECTOR(17 downto 0); -- 8x8 LED matrix (using 64 LEDs)
        HEX3, HEX2 : out STD_LOGIC_VECTOR(6 downto 0)  -- 7-segment displays (not used here)
    );
end entity;

architecture Behavioral of Final_02 is
    signal ascii_new  : STD_LOGIC;
    signal ascii_code : STD_LOGIC_VECTOR(6 downto 0);
    signal led_state  : STD_LOGIC_VECTOR(63 downto 0) := (others => '0'); -- 8x8 LED matrix (64 bits)
    signal step       : integer range 0 to 63 := 0; -- Animation step (0 to 63 for 8x8 grid)
    signal direction  : integer range 0 to 1 := 0;  -- 0 for lighting up, 1 for turning off
    signal pause      : STD_LOGIC := '0';           -- Pause state
    signal counter    : integer range 0 to 99_999_999 := 0; -- Counter for 4-second cycle
    constant CYCLE_TIME : integer := 50_000_000 * 4 / 64; -- Approx 4 seconds / 64 steps

    -- PS/2 to ASCII component instantiation
    component ps2_keyboard_to_ascii is
        generic (
            clk_freq                  : integer := 50_000_000;
            ps2_debounce_counter_size : integer := 8
        );
        port (
            clk        : in  STD_LOGIC;
            ps2_clk    : in  STD_LOGIC;
            ps2_data   : in  STD_LOGIC;
            ascii_new  : out STD_LOGIC;
            ascii_code : out STD_LOGIC_VECTOR(6 downto 0)
        );
    end component;

begin
    -- Instantiate PS/2 to ASCII converter
    ps2_to_ascii_inst : ps2_keyboard_to_ascii
        generic map (
            clk_freq => 50_000_000,
            ps2_debounce_counter_size => 8
        )
        port map (
            clk => clk,
            ps2_clk => ps2_clk,
            ps2_data => ps2_data,
            ascii_new => ascii_new,
            ascii_code => ascii_code
        );

    -- Animation and control process
    process(clk)
    begin
        if rising_edge(clk) then
            if counter = CYCLE_TIME - 1 then
                counter <= 0;
                if not pause then
                    if direction = 0 then -- Lighting up sequence
                        if step < 63 then
                            step <= step + 1;
                            led_state(step + 1) <= '1';
                        else
                            direction <= 1; -- Switch to turning off
                            step <= 62;    -- Start from last lit LED
                        end if;
                    else -- Turning off sequence
                        if step >= 0 then
                            led_state(step + 1) <= '0';
                            step <= step - 1;
                        else
                            direction <= 0; -- Switch back to lighting up
                            step <= 0;     -- Reset to start
                        end if;
                    end if;
                end if;
            else
                counter <= counter + 1;
            end if;

            -- Handle PS/2 input
            if ascii_new = '1' then
                if ascii_code = "0100000" then -- ASCII ' ' (space) to pause/resume
                    pause <= not pause;
                elsif ascii_code = "0011000" then -- ASCII '0' to reset
                    led_state <= (others => '0');
                    step <= 0;
                    direction <= 0;
                    pause <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Assign LED states to LEDR (assuming 64 LEDs mapped sequentially)
    LEDR(7 downto 0)   <= led_state(7 downto 0);   -- Row A
    LEDR(15 downto 8)  <= led_state(15 downto 8);  -- Row B
    LEDR(23 downto 16) <= led_state(23 downto 16); -- Row C
    LEDR(31 downto 24) <= led_state(31 downto 24); -- Row D
    LEDR(39 downto 32) <= led_state(39 downto 32); -- Row E
    LEDR(47 downto 40) <= led_state(47 downto 40); -- Row F
    LEDR(55 downto 48) <= led_state(55 downto 48); -- Row G
    LEDR(63 downto 56) <= led_state(63 downto 56); -- Row H

    -- Unused outputs
    LEDG <= (others => '0');
    HEX3 <= (others => '1');
    HEX2 <= (others => '1');
end architecture;