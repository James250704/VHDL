library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity Final_01 is
    port (
        clk       : in STD_LOGIC;                     -- 50 MHz system clock
        ps2_clk   : in STD_LOGIC;                     -- PS/2 clock line
        ps2_data  : in STD_LOGIC;                     -- PS/2 data line
        LEDG      : out STD_LOGIC_VECTOR(9 downto 0); -- Green LEDs (for debugging)
        HEX3, HEX2, HEX1, HEX0 : out STD_LOGIC_VECTOR(6 downto 0); -- 7-segment displays
        LCD_DATA  : out STD_LOGIC_VECTOR(7 downto 0); -- LCD data
        LCD_EN, LCD_RS, LCD_RW : out STD_LOGIC        -- LCD control signals
    );
end entity;

architecture Behavioral of Final_01 is
    signal ascii_new  : STD_LOGIC;
    signal ascii_code : STD_LOGIC_VECTOR(6 downto 0);
    signal cat_votes, dog_votes : integer range 0 to 99 := 0;
    signal hex_display : STD_LOGIC_VECTOR(6 downto 0);

    -- PS/2 to ASCII component
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

    -- Voting and display update process
    process(clk)
    begin
        if rising_edge(clk) then
            -- Debugging: Toggle LEDG(0) when new ASCII code is detected
            if ascii_new = '1' then
                LEDG(0) <= not LEDG(0); -- Toggle LED to indicate input detection
                case ascii_code is
                    when "0011001" => -- ASCII '1' for cat vote
                        if cat_votes < 99 then cat_votes <= cat_votes + 1; end if;
                    when "0011010" => -- ASCII '2' for dog vote
                        if dog_votes < 99 then dog_votes <= dog_votes + 1; end if;
                    when "0011000" => -- ASCII '0' to reset votes
                        cat_votes <= 0;
                        dog_votes <= 0;
                    when others => null;
                end case;
            end if;
        end if;
    end process;

    -- 7-segment display decoding for cat votes (HEX3-HEX2)
    with to_unsigned(cat_votes, 8)(7 downto 4) select HEX3 <= 
        "1000000" when x"0", "1111001" when x"1", "0100100" when x"2",
        "0110000" when x"3", "0011001" when x"4", "0010010" when x"5",
        "0000010" when x"6", "1111000" when x"7", "0000000" when x"8",
        "0010000" when x"9", "1111111" when others;

    with to_unsigned(cat_votes, 8)(3 downto 0) select HEX2 <= 
        "1000000" when x"0", "1111001" when x"1", "0100100" when x"2",
        "0110000" when x"3", "0011001" when x"4", "0010010" when x"5",
        "0000010" when x"6", "1111000" when x"7", "0000000" when x"8",
        "0010000" when x"9", "1111111" when others;

    -- 7-segment display decoding for dog votes (HEX1-HEX0)
    with to_unsigned(dog_votes, 8)(7 downto 4) select HEX1 <= 
        "1000000" when x"0", "1111001" when x"1", "0100100" when x"2",
        "0110000" when x"3", "0011001" when x"4", "0010010" when x"5",
        "0000010" when x"6", "1111000" when x"7", "0000000" when x"8",
        "0010000" when x"9", "1111111" when others;

    with to_unsigned(dog_votes, 8)(3 downto 0) select HEX0 <= 
        "1000000" when x"0", "1111001" when x"1", "0100100" when x"2",
        "0110000" when x"3", "0011001" when x"4", "0010010" when x"5",
        "0000010" when x"6", "1111000" when x"7", "0000000" when x"8",
        "0010000" when x"9", "1111111" when others;

    -- Simple LCD control (basic implementation)
    process(cat_votes, dog_votes)
    begin
        LCD_RW <= '0';  -- Write mode
        if cat_votes > 0 or dog_votes > 0 then
            LCD_RS <= '1';  -- Data mode
            if cat_votes > 0 then
                LCD_DATA <= STD_LOGIC_VECTOR(to_unsigned(cat_votes, 8));
            elsif dog_votes > 0 then
                LCD_DATA <= STD_LOGIC_VECTOR(to_unsigned(dog_votes, 8));
            end if;
            LCD_EN <= '1';
        else
            LCD_RS <= '0';  -- Command mode
            LCD_DATA <= x"01";  -- Clear display
            LCD_EN <= '1';
        end if;
    end process;

    -- Unused LEDs (except LEDG(0) for debugging)
    LEDG(9 downto 1) <= (others => '0');

end architecture;