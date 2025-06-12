library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- For arithmetic operations and type conversions

entity Lab12_1 is -- Renamed to reflect its role as a full VGA driver
    port (
        -- Clock and Reset Inputs
        CLOCK_50 : in STD_LOGIC; -- From pin_assignment: PIN_G21
        RESET_N  : in STD_LOGIC; -- Example: KEY[0] from pin_assignment: PIN_H2

        -- VGA Outputs (directly map to pins)
        VGA_HS : out STD_LOGIC;                    -- From pin_assignment: PIN_L21
        VGA_VS : out STD_LOGIC;                    -- From pin_assignment: PIN_L22
        VGA_R  : out STD_LOGIC_VECTOR(3 downto 0); -- From pin_assignment
        VGA_G  : out STD_LOGIC_VECTOR(3 downto 0); -- From pin_assignment
        VGA_B  : out STD_LOGIC_VECTOR(3 downto 0)  -- From pin_assignment
    );
end entity Lab12_1;

architecture Behavioral of Lab12_1 is

    -- VGA Timing Constants for 640x480 @ 60Hz (using 25MHz pixel clock)
    -- Horizontal Timing (pixels)
    constant H_DISPLAY_AREA : INTEGER := 640;                                                          -- Active display width
    constant H_FRONT_PORCH  : INTEGER := 16;                                                           -- Pixels after active display before sync
    constant H_SYNC_PULSE   : INTEGER := 96;                                                           -- Sync pulse width
    constant H_BACK_PORCH   : INTEGER := 48;                                                           -- Pixels after sync pulse before active display
    constant H_TOTAL_PERIOD : INTEGER := H_DISPLAY_AREA + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH; -- 800 total pixels

    -- Vertical Timing (lines)
    constant V_DISPLAY_AREA : INTEGER := 480;                                                          -- Active display height
    constant V_FRONT_PORCH  : INTEGER := 10;                                                           -- Lines after active display before sync
    constant V_SYNC_PULSE   : INTEGER := 2;                                                            -- Sync pulse width
    constant V_BACK_PORCH   : INTEGER := 33;                                                           -- Lines after sync pulse before active display
    constant V_TOTAL_PERIOD : INTEGER := V_DISPLAY_AREA + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH; -- 525 total lines

    -- Signals for VGA timing generation
    signal pixel_clk_enable : STD_LOGIC            := '0'; -- To create 25MHz from 50MHz
    signal pixel_clk_count  : INTEGER range 0 to 1 := 0;

    signal h_counter : INTEGER range 0 to H_TOTAL_PERIOD - 1 := 0;
    signal v_counter : INTEGER range 0 to V_TOTAL_PERIOD - 1 := 0;

    signal internal_video_on  : STD_LOGIC;
    signal internal_pixel_row : INTEGER range 0 to V_DISPLAY_AREA - 1; -- For Kirby logic, relative to display area
    signal internal_pixel_col : INTEGER range 0 to H_DISPLAY_AREA - 1; -- For Kirby logic, relative to display area

    -- Internal 12-bit RGB signal for Kirby image
    signal kirby_rgb_data : STD_LOGIC_VECTOR(11 downto 0);

    -- Kirby bitmap definition
    type BITMAP is array(0 to 15) of STD_LOGIC_VECTOR(0 to 31);
    constant kirby : BITMAP := (
        "00000000000001010101010000000000",
        "00000000010110111111100101000000",
        "00000001101111111111111110010000",
        "00000110111111111111111111010000",
        "00000111111111111111111111100100",
        "00011111111111111101110111100100",
        "01101111111111111101110111111101",
        "01111111111111111101110111111101",
        "01111111111110101111111110101101",
        "01101111101111111111111111101101",
        "00011011011111111111011111011000",
        "00000101101111111111111110010100",
        "00000001011010111111111001010000",
        "00000110100101010101010110100100",
        "00011010101010010101011010101001",
        "00000101010101010000000101010100"
    );

    -- Color definitions
    constant WHITE     : STD_LOGIC_VECTOR(11 downto 0) := x"FFF";
    constant BLACK     : STD_LOGIC_VECTOR(11 downto 0) := x"000";
    constant MOMO_PINK : STD_LOGIC_VECTOR(11 downto 0) := x"F69";
    constant PINK      : STD_LOGIC_VECTOR(11 downto 0) := x"F9B";
    constant BG_COLOR  : STD_LOGIC_VECTOR(11 downto 0) := x"000"; -- Background for areas outside Kirby

    -- Kirby Image scaling and positioning parameters
    constant BITMAP_ORIGINAL_ROWS : INTEGER := 16;
    constant BITMAP_ORIGINAL_COLS : INTEGER := 16;
    constant SCALE_FACTOR         : INTEGER := 20;
    constant IMAGE_DISPLAY_WIDTH  : INTEGER := BITMAP_ORIGINAL_COLS * SCALE_FACTOR; -- 320
    constant IMAGE_DISPLAY_HEIGHT : INTEGER := BITMAP_ORIGINAL_ROWS * SCALE_FACTOR; -- 320

    -- Top-left corner of the 320x320 Kirby image on the VGA screen (640x480)
    constant IMG_START_COL : INTEGER := (H_DISPLAY_AREA - IMAGE_DISPLAY_WIDTH) / 2;  -- (640-320)/2 = 160
    constant IMG_START_ROW : INTEGER := (V_DISPLAY_AREA - IMAGE_DISPLAY_HEIGHT) / 2; -- (480-320)/2 = 80
    constant IMG_END_COL   : INTEGER := IMG_START_COL + IMAGE_DISPLAY_WIDTH - 1;     -- 160 + 320 - 1 = 479
    constant IMG_END_ROW   : INTEGER := IMG_START_ROW + IMAGE_DISPLAY_HEIGHT - 1;    -- 80 + 320 - 1 = 399

begin

    -- Process to generate 25MHz pixel clock enable from 50MHz CLOCK_50
    pixel_clk_generator : process (CLOCK_50, RESET_N)
    begin
        if RESET_N = '0' then
            pixel_clk_count  <= 0;
            pixel_clk_enable <= '0';
        elsif rising_edge(CLOCK_50) then
            if pixel_clk_count = 0 then
                pixel_clk_enable <= '1';
                pixel_clk_count  <= 1;
            else
                pixel_clk_enable <= '0';
                pixel_clk_count  <= 0;
            end if;
        end if;
    end process pixel_clk_generator;

    -- VGA Timing Generation Process (runs on 50MHz, but counters advance on pixel_clk_enable)
    vga_timing_logic : process (CLOCK_50, RESET_N)
    begin
        if RESET_N = '0' then
            h_counter          <= 0;
            v_counter          <= 0;
            VGA_HS             <= '1'; -- Typically active low, so initialize to inactive (high)
            VGA_VS             <= '1'; -- Typically active low, so initialize to inactive (high)
            internal_video_on  <= '0';
            internal_pixel_col <= 0;
            internal_pixel_row <= 0;
        elsif rising_edge(CLOCK_50) then
            if pixel_clk_enable = '1' then -- Only update counters on the 25MHz effective clock
                -- Horizontal Counter
                if h_counter < H_TOTAL_PERIOD - 1 then
                    h_counter <= h_counter + 1;
                else
                    h_counter <= 0;
                    -- Vertical Counter (increments at the end of each horizontal line)
                    if v_counter < V_TOTAL_PERIOD - 1 then
                        v_counter <= v_counter + 1;
                    else
                        v_counter <= 0;
                    end if;
                end if;

                -- Horizontal Sync (VGA_HS) Generation (active low)
                if h_counter >= H_DISPLAY_AREA + H_FRONT_PORCH and
                    h_counter < H_DISPLAY_AREA + H_FRONT_PORCH + H_SYNC_PULSE then
                    VGA_HS <= '0';
                else
                    VGA_HS <= '1';
                end if;

                -- Vertical Sync (VGA_VS) Generation (active low)
                if v_counter >= V_DISPLAY_AREA + V_FRONT_PORCH and
                    v_counter < V_DISPLAY_AREA + V_FRONT_PORCH + V_SYNC_PULSE then
                    VGA_VS <= '0';
                else
                    VGA_VS <= '1';
                end if;

                -- Video On (Active Display Area) Generation
                if (h_counter < H_DISPLAY_AREA) and (v_counter < V_DISPLAY_AREA) then
                    internal_video_on  <= '1';
                    internal_pixel_col <= h_counter; -- Current column in active display
                    internal_pixel_row <= v_counter; -- Current row in active display
                else
                    internal_video_on  <= '0';
                    internal_pixel_col <= 0; -- Or any value, not used when video_on is '0'
                    internal_pixel_row <= 0; -- Or any value
                end if;
            end if; -- end pixel_clk_enable check
        end if; -- end clock edge check
    end process vga_timing_logic;

    kirby_image_processor : process (internal_video_on, internal_pixel_row, internal_pixel_col)
        variable original_bitmap_row_idx : INTEGER range 0 to BITMAP_ORIGINAL_ROWS - 1;
        variable original_bitmap_col_idx : INTEGER range 0 to BITMAP_ORIGINAL_COLS - 1;
        variable kirby_pixel_data_row    : STD_LOGIC_VECTOR(0 to BITMAP_ORIGINAL_COLS * 2 - 1);
        variable color_code_2bit         : STD_LOGIC_VECTOR(1 downto 0);
    begin
        if internal_video_on = '0' then
            kirby_rgb_data <= BG_COLOR; -- Output background during blanking
        else
            -- Check if the current VGA pixel (internal_pixel_row, internal_pixel_col)
            -- is within the scaled Kirby image display area
            if (internal_pixel_row >= IMG_START_ROW and internal_pixel_row <= IMG_END_ROW and
                internal_pixel_col >= IMG_START_COL and internal_pixel_col     <= IMG_END_COL) then

                original_bitmap_row_idx := (internal_pixel_row - IMG_START_ROW) / SCALE_FACTOR;
                original_bitmap_col_idx := (internal_pixel_col - IMG_START_COL) / SCALE_FACTOR;

                kirby_pixel_data_row := kirby(original_bitmap_row_idx);

                color_code_2bit(1) := kirby_pixel_data_row(original_bitmap_col_idx * 2);
                color_code_2bit(0) := kirby_pixel_data_row(original_bitmap_col_idx * 2 + 1);

                case color_code_2bit is
                    when "00"   => kirby_rgb_data   <= WHITE;
                    when "01"   => kirby_rgb_data   <= BLACK;
                    when "10"   => kirby_rgb_data   <= MOMO_PIN