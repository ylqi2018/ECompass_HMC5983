
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
USE IEEE.std_logic_arith.ALL;     
use IEEE.std_logic_unsigned.all;  

entity Compass_REC is
	port (
		clk			:	IN	STD_LOGIC;
		rst			:	IN	STD_LOGIC;
	-- ##### port of SPI #####
		cs_spi		:	OUT	STD_LOGIC;	-- Compass_REC work as master for SPI
		sclk_out	:	OUT	STD_LOGIC;
		sdo_in		:	IN	STD_LOGIC;	-- SDO of ECompass, i.e. the input of Compass_REC
		sdi_out		:	OUT	STD_LOGIC--;	-- SDI of ECompass, i.e. the output of Compass_REC
--		phase_out	:	OUT	STD_LOGIC_VECTOR(15 DOWNTO 0);
--		act_data_en	:	OUT	STD_LOGIC
	);
end Compass_REC;


architecture Behavioral of Compass_REC is

-- ##### Cordic, Arc tan,
component actan_cal
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_cartesian_tvalid : IN STD_LOGIC;
    s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END component;

component mult_gen_0
  PORT (
    CLK : IN STD_LOGIC;
    A : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    P : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END component;

component ila_ECompass IS
    PORT (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        probe1 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        probe2 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe4 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        probe5 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe7 : IN STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END component;
	
signal	clk_d        : STD_LOGIC;
signal	clk_d_cnt    : STD_LOGIC_VECTOR(7 downto 0);

-- ##### Used to configure register to set the compass #####
signal	data_word_1  : std_logic_vector(15 downto 0); 	
signal	data_word_2  : std_logic_vector(15 downto 0);
signal	data_word_3  : std_logic_vector(15 downto 0);
      	
signal	cnt_mode     : std_logic_vector(3 downto 0);
signal	cnt_word     : std_logic_vector(7 downto 0);
signal	cs_en        : std_logic;			
signal	sdi_out_b    : std_logic;

signal	data_X_sig   : std_logic_vector(15 DOWNTO 0);                   
signal	data_Y_sig   : std_logic_vector(15 DOWNTO 0);
signal	data_Z_sig   : std_logic_vector(15 DOWNTO 0);
	  	
signal	data_X_sig_r2: std_logic_vector(15 DOWNTO 0);
signal	data_Y_sig_r2: std_logic_vector(15 DOWNTO 0);
signal	data_Z_sig_r2: std_logic_vector(15 DOWNTO 0);  
	  	
signal	act_sig_en   : std_logic;
signal	act_data_out : std_logic_vector(15 DOWNTO 0);
signal  act_data_en  : std_logic;

signal	cs_spi_obuf  : std_logic;
signal	sclk_out_obuf: std_logic;
signal	sdi_out_obuf : std_logic;
		
signal	phase_out_reg: std_logic_vector(15 DOWNTO 0);	
signal  act_sig_in   : std_logic_vector(31 DOWNTO 0);

signal  phase_out	:   STD_LOGIC_VECTOR(15 DOWNTO 0);


begin

-- data_word_1(15) = '0' => Write
-- data_word_1(14) = '0' => MS bit, When 0 do not increment address.
-- data_word_1(13 downto 8) = "00000"(0X00), configuration register A
-- data_word_1(7) = '0', TS bit, disable temperature sensor
-- data_word_1(6 downto 5) = "00" => Select number of samples averaged (1 to 8) per measurement output.
-- data_word_1(4 downto 2) = "110" => Data Output Rate Bits. These bits set the rate at which data is written to all three data output registers.
-- data_word_1(1 downto 0) = "00" => Normal measurement configuration.
data_word_1  <= "0000000000011000";

-- data_word_2(15) = '0' => Write
-- data_word_2(14) = '0' => MS bit, When 0 do not increment address.
-- data_word_2(13 downto 8) = "00010"(0X02), Mode Register
-- data_word_2(2) = '0' => 4-wire SPI interface
-- data_word_2(1 downto 0) => "00", set operating mode as Continuous-Measurement Mode
data_word_2  <= "0000001000000000";

-- data_word_3(15) = '1' => Read
-- data_word_3(14) = '1' => MS bit, When 1, the address will be auto incremented in multiple read/write commands
-- data_word_3(13 downto 8) = "000011"(0X03), Data Output X MSB Register
data_word_3  <= "1100001100000000";


fre_div: process(clk, rst)
	begin
		if(rst = '1') then
			clk_d <= '0';
			clk_d_cnt <= (others => '0');
		elsif(clk'event and clk='1') then
			if(clk_d_cnt = 7) then
				clk_d <= not clk_d;
				clk_d_cnt <= (others => '0');
			else
				clk_d_cnt <= clk_d_cnt + 1;
			end if;
		end if;
	end process fre_div;
	
R_W_proc: process(clk_d, rst)
		variable wr_i	: integer range 0 to 16 := 0;
		variable rd_i	: integer range 0 to 64 := 0;
	begin
		if(rst = '1') then
			cnt_mode 	<= (others => '0');
			cnt_word 	<= (others => '0');
			cs_en 		<= '0';
			sdi_out_b 	<= '0';
			act_sig_en	<= '0';
		elsif(clk_d'event and clk_d = '1') then
			if(cnt_mode = 0) then 
				if(cnt_word <= 15) then
					cnt_word 	<= cnt_word + 1;
					cs_en 		<= '1';		-- cs_spi = '0'
					wr_i 		:= conv_integer(cnt_word);
					sdi_out_b 	<= data_word_1(15 - wr_i);
				else
					cnt_word	<= (others => '0');
					cnt_mode	<= "0001";
					cs_en		<= '0';		-- cs_spi = '0'
					sdi_out_b	<= '0';
				end if;
					
			elsif(cnt_mode = 1) then
				if(cnt_word <= 15) then
					cnt_word	<= cnt_word + 1;
					cs_en		<= '1';
					wr_i		:= conv_integer(cnt_word);
					sdi_out_b	<= data_word_2(15 - wr_i);
				else
					cnt_word	<= (others => '0');
					cnt_mode	<= "0010";
					cs_en		<= '0';
					sdi_out_b	<= '0';
				end if;
				
			else
				if(cnt_word <= 7) then
					cnt_word	<= cnt_word + 1;
					cs_en		<= '1';
					wr_i		:= conv_integer(cnt_word);
					sdi_out_b	<= data_word_3(15 - wr_i);
--					act_sig_en	<= '0';
				elsif(cnt_word <= 23) then
					cnt_word	<= cnt_word + 1;
					cs_en		<= '1';
					sdi_out_b	<= '0';
					rd_i		:= conv_integer(cnt_word) - 8;
					data_X_sig(15 - rd_i) <= sdo_in;
--					act_sig_en	<= '0';
				elsif(cnt_word <= 39) then
					cnt_word	<= cnt_word + 1;
					cs_en		<= '1';
					sdi_out_b	<= '0';
					rd_i		:= conv_integer(cnt_word) - 24;
					data_Y_sig(15 - rd_i) <= sdo_in;
--					act_sig_en	<= '0';					
				elsif(cnt_word <= 55) then
					cnt_word	<= cnt_word + 1;
					cs_en		<= '1';
					sdi_out_b	<= '0';
					rd_i		:= conv_integer(cnt_word) - 40;
					data_Z_sig(15 - rd_i) <= sdo_in;
--					act_sig_en	<= '0';
				else
					cnt_mode	<= "0000";
					cnt_word	<= (others => '0');
					cs_en		<= '0';		-- cs_spi = '1'
					sdi_out_b	<= '0';
					data_X_sig_r2 <= data_X_sig;
					data_Y_sig_r2 <= data_Y_sig;
					data_Z_sig_r2 <= data_Z_sig;
					act_sig_en	<= '1';
				end if;
			end if;
		end if;
	end process R_W_proc;

cs_spi_obuf   <=  not cs_en;
sclk_out_obuf <=  clk_d;
sdi_out_obuf  <=  sdi_out_b;

cs_spi    <= cs_spi_obuf   ;				 	
sclk_out  <= sclk_out_obuf ;
sdi_out   <= sdi_out_obuf  ;
-- The range of data_X_sig_r2 and data_Z_sig_r2
-- should in 0xF800 to 0x07FF, 16-bit value in 2's complement form
--act_sig_in	<= data_X_sig_r2 & data_Z_sig_r2;
act_sig_in	<= data_X_sig_r2 & data_Y_sig_r2;
--act_sig_in	<= data_Y_sig_r2 & data_X_sig_r2;

inst_actan_cal: actan_cal
    PORT map(
        aclk                    => clk_d,       --: IN STD_LOGIC;
        s_axis_cartesian_tvalid => act_sig_en, --: IN STD_LOGIC;
        s_axis_cartesian_tdata  => act_sig_in,  --: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axis_dout_tvalid      => act_data_en,	--: OUT STD_LOGIC;
        m_axis_dout_tdata 		=> act_data_out	--: OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );

inst_mult_gen_0: mult_gen_0
    PORT map(
        CLK => clk_d,			--: IN STD_LOGIC;
        A 	=> act_data_out,	--: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        P 	=> phase_out_reg	--: OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );

phase_out <= phase_out_reg;

inst_ila_ECompass: ila_ECompass
    PORT map(
        clk     => clk, --: IN STD_LOGIC;
        probe0  => data_X_sig,   --: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        probe1  => data_Y_sig,   --: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        probe2  => data_Z_sig,   --: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        probe3(0)  => sdi_out_b,     --: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe4  => act_data_out,	    --: IN STD_LOGIC_VECTOR(15 DOWNTO 0)
        probe5  => phase_out_reg,    --: IN STD_LOGIC_VECTOR(15 DOWNTO 0)
        probe6(0) => clk_d,      --: IN STD_LOGIC_VECTOR(0 DOWNTO 0)
        probe7 => cnt_mode      --: IN STD_LOGIC_VECTOR(3 DOWNTO 0)
    );

end Behavioral;
