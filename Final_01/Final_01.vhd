library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity Final_01 is
    port (
        SW   : in STD_LOGIC_VECTOR(9 downto 0);
        LEDG : out STD_LOGIC_VECTOR(9 downto 0);
        HEX3, HEX2, HEX1, HEX0 : out STD_LOGIC_VECTOR(6 downto 0);
        LCD_DATA : out STD_LOGIC_VECTOR(7 downto 0);
        LCD_EN, LCD_RS, LCD_RW : out STD_LOGIC
    );
end entity;

architecture Behavioral of Final_01 is
    signal cat_votes, dog_votes : integer range 0 to 99 := 0;
    signal hex_display : STD_LOGIC_VECTOR(6 downto 0);
begin
    process(SW)
    begin
        if rising_edge(SW(0)) then  -- Assuming SW(0) as clock or reset trigger
            if SW(1) = '1' then     -- Vote for cat
                if cat_votes < 99 then cat_votes <= cat_votes + 1; end if;
            elsif SW(2) = '1' then  -- Vote for dog
                if dog_votes < 99 then dog_votes <= dog_votes + 1; end if;
            elsif SW(3) = '1' then  -- Reset votes
                cat_votes <= 0;
                dog_votes <= 0;
            end if;
        end if;
    end process;

    -- Display on HEX
    with to_unsigned(cat_votes, 8)(7 downto 4) select HEX3 <= 
        "1000000" when x"0",  -- 0
        "1111001" when x"1",  -- 1
        "0100100" when x"2",  -- 2
        "0110000" when x"3",  -- 3
        "0011001" when x"4",  -- 4
        "0010010" when x"5",  -- 5
        "0000010" when x"6",  -- 6
        "1111000" when x"7",  -- 7
        "0000000" when x"8",  -- 8
        "0010000" when x"9",  -- 9
        "1111111" when others;

    with to_unsigned(cat_votes, 8)(3 downto 0) select HEX2 <= 
        "1000000" when x"0",  -- 0
        "1111001" when x"1",  -- 1
        "0100100" when x"2",  -- 2
        "0110000" when x"3",  -- 3
        "0011001" when x"4",  -- 4
        "0010010" when x"5",  -- 5
        "0000010" when x"6",  -- 6
        "1111000" when x"7",  -- 7
        "0000000" when x"8",  -- 8
        "0010000" when x"9",  -- 9
        "1111111" when others;

    with to_unsigned(dog_votes, 8)(7 downto 4) select HEX1 <= 
        "1000000" when x"0",  -- 0
        "1111001" when x"1",  -- 1
        "0100100" when x"2",  -- 2
        "0110000" when x"3",  -- 3
        "0011001" when x"4",  -- 4
        "0010010" when x"5",  -- 5
        "0000010" when x"6",  -- 6
        "1111000" when x"7",  -- 7
        "0000000" when x"8",  -- 8
        "0010000" when x"9",  -- 9
        "1111111" when others;

    with to_unsigned(dog_votes, 8)(3 downto 0) select HEX0 <= 
        "1000000" when x"0",  -- 0
        "1111001" when x"1",  -- 1
        "0100100" when x"2",  -- 2
        "0110000" when x"3",  -- 3
        "0011001" when x"4",  -- 4
        "0010010" when x"5",  -- 5
        "0000010" when x"6",  -- 6
        "1111000" when x"7",  -- 7
        "0000000" when x"8",  -- 8
        "0010000" when x"9",  -- 9
        "1111111" when others;

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

    LEDG <= (others => '0');  -- LEDs not used here
end architecture;