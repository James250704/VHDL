library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity Lab11_1 is
    port (
        clk        : in STD_LOGIC;                     -- 50 MHz 系統時脈
        KEY        : in STD_LOGIC_VECTOR (1 to 1);     -- KEY(1)，active-low
        ps2_clk    : in STD_LOGIC;                     -- PS/2 時脈線
        ps2_data   : in STD_LOGIC;                     -- PS/2 資料線
        LEDG       : out STD_LOGIC_VECTOR(9 downto 0); -- LEDG0..LEDG9
        HEX3, HEX2 : out STD_LOGIC_VECTOR(6 downto 0)  -- 7 段顯示器
    );
end entity;

architecture rtl of Lab11_1 is

    -- 來自 ASCII 轉換器
    signal ascii_new  : STD_LOGIC;
    signal ascii_code : STD_LOGIC_VECTOR(6 downto 0);
    signal ascii_ext  : STD_LOGIC_VECTOR(7 downto 0);

    -- 拆成高／低 nibble，並且只有在 ascii_new 時才更新，reset 時清 0
    signal hi_nibble, lo_nibble : STD_LOGIC_VECTOR(4 downto 0);

begin

    ----------------------------------------------------------------------------
    -- 1) PS/2 → ASCII
    ----------------------------------------------------------------------------
    ps2_to_ascii_inst : entity work.ps2_keyboard_to_ascii
        generic map(
            clk_freq                  => 50_000_000,
            ps2_debounce_counter_size => 8
        )
        port map(
            clk        => clk,
            ps2_clk    => ps2_clk,
            ps2_data   => ps2_data,
            ascii_new  => ascii_new,
            ascii_code => ascii_code
        );

    ascii_ext <= '0' & ascii_code;

    ----------------------------------------------------------------------------
    -- 2) nibble 更新邏輯
    ----------------------------------------------------------------------------
    process (clk, KEY)
    begin
        if KEY(1) = '0' then
            hi_nibble <= (others => '0');
            lo_nibble <= (others => '0');
        elsif rising_edge(clk) then
            if ascii_new = '1' then
                hi_nibble <= '0' & ascii_ext(7 downto 4);
                lo_nibble <= '0' & ascii_ext(3 downto 0);
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- 3) LEDG 顯示 0~9
    ----------------------------------------------------------------------------
    process (clk, KEY)
    begin
        if KEY(1) = '0' then
            LEDG <= (others => '0');
        elsif rising_edge(clk) then
            if ascii_new = '1' then
                -- 先把 ascii_code 轉 unsigned，再跟常數比較
                if unsigned(ascii_code) >= to_unsigned(48, 7)       -- ASCII '0' = 48
                    and unsigned(ascii_code) <= to_unsigned(57, 7) then -- ASCII '9' = 57

                    LEDG <= (others => '0');
                    -- 低 4 bit 直接轉成 index
                    LEDG(to_integer(unsigned(ascii_code(3 downto 0)))) <= '1';

                else
                    LEDG <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- 4) 7-segment 解碼：用你提供的 decoder
    ----------------------------------------------------------------------------
    hex3_dec : entity work.decoder
        port map(
            digit => hi_nibble,
            seg   => HEX3
        );

    hex2_dec : entity work.decoder
        port map(
            digit => lo_nibble,
            seg   => HEX2
        );

end architecture;
