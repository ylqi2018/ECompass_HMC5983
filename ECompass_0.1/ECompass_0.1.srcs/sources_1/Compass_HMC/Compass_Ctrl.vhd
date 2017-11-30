

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.ALL;         
USE IEEE.std_logic_arith.ALL;     
use IEEE.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Compass_Ctrl is
	Port (
		clk			:	in	STD_LOGIC;
		rst			:	in	STD_LOGIC;
	-- ##### Ports for SPI of HM5983 #####
		sdo_in		:	in	STD_LOGIC;	
		sclk_out	:	out	STD_LOGIC;
		cs_spi		:	out	STD_LOGIC;
		sdi_out		:	out	STD_LOGIC;
	-- #####
		set_point	:	in	STD_LOGIC_VECTOR(17 downto 0);	-- fix_0_11_7
		pos_val		:	out	STD_LOGIC;
		neg_val		:	out	STD_LOGIC;
		cur_degres	:	out	STD_LOGIC_VECTOR(17 downto 0)
	);
end Compass_Ctrl;

architecture Behavioral of Compass_Ctrl is

-- ##### Component Compass_REC #####
component Compass_REC is
	port (
		clk			:	IN	STD_LOGIC;
		rst			:	IN	STD_LOGIC;
		cs_spi		:	OUT	STD_LOGIC;	-- Compass_REC work as master for SPI
		sclk_out	:	OUT	STD_LOGIC;
		sdo_in		:	IN	STD_LOGIC;	-- SDO of ECompass, i.e. the input of Compass_REC
		sdi_out		:	OUT	STD_LOGIC;	-- SDI of ECompass, i.e. the output of Compass_REC
		phase_out	:	OUT	STD_LOGIC_VECTOR(15 DOWNTO 0);
		act_data_en	:	OUT	STD_LOGIC
	);
end component;


signal	phase_out_temp	:	STD_LOGIC_VECTOR(15 DOWNTO 0);   
signal	phase_out		:	STD_LOGIC_VECTOR(15 DOWNTO 0);
signal	act_data_en		:	STD_LOGIC;                 

signal con_180          :	STD_LOGIC_VECTOR(15 DOWNTO 0); 
signal adjust_d         :	STD_LOGIC_VECTOR(15 DOWNTO 0); 

signal con_360          :	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7  
signal adjust_dw        :	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7  		     
signal err_set1         :	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7  
signal err_set2         :	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7  
signal err_set3         :	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7 
signal err_set1_abs     :	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7  
signal err_set2_abs     :	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7  
signal err_set3_abs     :	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7 
                         	
signal err_out1         :	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7 
signal err_out1_abs     :	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7	                  
signal err_out2         :	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7 

signal   cnt_sig    :   std_logic_vector(17 downto 0);
signal   pwm_sig    :   std_logic;
signal   pwm_bias   :   std_logic_vector(17 downto 0);
constant PMW_HT      :  integer := 2000;	
constant PMW_LT      :  integer := 200;
signal lastE,lastE_reg  :  std_logic_vector(17 DOWNTO 0);--fix_1_10_7
signal lastW,lastW_reg  :  std_logic_vector(17 DOWNTO 0);--fix_1_10_7
signal Out_sig,Out_sig_reg  :  std_logic_vector(17 DOWNTO 0);--fix_1_10_7

signal temp_E,temp_W  :  std_logic_vector(17 DOWNTO 0);--fix_1_10_7
signal err_out2_abs     :  std_logic_vector(17 DOWNTO 0);--fix_0_11_7	
signal speed_st         :  std_logic;	
signal pos_sig          :  std_logic;  
signal neg_sig          :  std_logic;



begin

--inst_Compass_REC: Compass_REC
--	port map(
--		clk			=> clk,							--:	IN	STD_LOGIC;
--		rst			=> rst,							--:	IN	STD_LOGIC;
--		cs_spi		=> cs_spi,						--:	OUT	STD_LOGIC;	-- Compass_REC work as master for SPI
--		sclk_out	=> sclk_out,					--:	OUT	STD_LOGIC;
--		sdo_in		=> sdo_in,						--:	IN	STD_LOGIC;	-- SDO of ECompass, i.e. the input of Compass_REC
--		sdi_out		=> sdi_out,						--:	OUT	STD_LOGIC;	-- SDI of ECompass, i.e. the output of Compass_REC
--		phase_out	=> phase_out_temp,				--:	OUT	STD_LOGIC_VECTOR(15 DOWNTO 0);
--		act_data_en	=> act_data_en					--:	OUT	STD_LOGIC_VECTOR
--	);

-- ############################################################### --
	process(clk, rst)
	begin
		if(rst = '1') then
			con_360          <= (others => '0');		--:	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7  
			adjust_dw        <= (others => '0');		--:	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7  		     
			err_set1         <= (others => '0');		--:	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7  
			err_set2         <= (others => '0');		--:	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7  
			err_set3         <= (others => '0');		--:	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7 
			err_set1_abs     <= (others => '0');		--:	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7  
			err_set2_abs     <= (others => '0');		--:	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7  
			err_set3_abs     <= (others => '0');		--:	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7 
			err_out1         <= (others => '0');		--:	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7 
			err_out1_abs     <= (others => '0');		--:	STD_LOGIC_VECTOR(17 DOWNTO 0);--fix_1_10_7	                  
			err_out2         <= (others => '0');		--:
		elsif(clk'event and clk='1') then
			phase_out	<= phase_out_temp;
			con_180		<= "0101101000000000";	-- 180, fix_1_8_7
			adjust_d	<= con_180 + phase_out;
			
			con_360		<= "001011010000000000"; --fix_1_10_7
			adjust_dw	<= "00" & adjust_d; -- 16-bits to 18-bits
			
			err_set1	<= set_point - adjust_dw;
			err_set2	<= err_set1 + con_360;
			err_set3	<= err_set1 - con_360;
			
			if(err_set1(17) = '0') then
				err_set1_abs <= err_set1;
			else
				err_set1_abs <= not(err_set1) + 1;
			end if;	
				
			if(err_set2(17) = '0') then
				err_set2_abs <= err_set2;
			else
				err_set2_abs <= not(err_set2) + 1;
			end if;	
				
			if(err_set3(17) = '0') then
				err_set3_abs <= err_set3;
			else
				err_set3_abs <= not(err_set3) + 1;
			end if;	
				
			if(err_set1_abs <= err_set2_abs) then
				err_out1 <= err_set1;
			else
				err_out1 <= err_set1;
			end if;
				
			if(err_out1(17)='0') then
				err_out1_abs <= err_out1;
			else
				err_out1_abs <= not(err_out1) + 1;
			end if;
				
			if(err_out1_abs <= err_set3_abs) then
				err_out2 <= err_out1;
			else
				err_out2 <= err_set3;
			end if;
		end if;	
	end process;

cur_degres <= adjust_dw;

	process(rst, clk)
	begin
		if(rst = '1') then
			cnt_sig <= (others=>'0');
		elsif(clk'event and clk='1') then
		    if cnt_sig <= pwm_bias then
				pwm_sig <= '1'; 
		       	cnt_sig <= cnt_sig + 1; 
		    elsif cnt_sig < PMW_HT then
		       	pwm_sig <= '0';
		       	cnt_sig <= cnt_sig + 1; 
		    elsif cnt_sig >= PMW_HT then
		       	pwm_sig <= '0';
		       	cnt_sig <=(others=>'0');
		    else
		       	cnt_sig <= cnt_sig + 1;    
		    end if;			
		end if;	
	end process;

temp_E 	<= (lastW_reg + (err_out2 - lastE_reg));
lastE 	<= "000000" & temp_E(17 downto 6);
temp_W 	<= (Out_sig_reg + (err_out2 - lastE_reg));
lastW 	<= "000000" & temp_W(17 downto 6);
	
	process(clk,rst)
	begin
		if rst = '1' then
			lastW_reg <= (others=>'0');
			lastE_reg <= (others=>'0'); 
			Out_sig_reg <= (others=>'0'); 
		elsif clk'event and clk='1' then
			lastW_reg <= lastW;
			lastE_reg <= lastE;
			Out_sig_reg <= Out_sig;
			
			if  Out_sig(17) = '0' then
				err_out2_abs <= Out_sig;
			else
				err_out2_abs  <=  not(Out_sig) + 1;
			end if;
				
			if err_out2_abs < PMW_LT  then
				pwm_bias <=  "000000000000000000";
			elsif err_out2_abs > PMW_HT then
				pwm_bias <=  conv_std_logic_vector(PMW_HT - 1,18);
			else
				pwm_bias <=  err_out2_abs;
			end if;
		end if;
	end process;	

Out_sig <= err_out2;

speed_st <= '1'         when pwm_bias > PMW_HT else
            '0'         when pwm_bias < PMW_LT else
           pwm_sig;
	       
pos_sig	 <= speed_st when Out_sig(17) = '0' else '0';
neg_sig  <= speed_st when Out_sig(17) = '1' else '0';	
      
pos_val <= pos_sig; 
neg_val <= neg_sig; 

end Behavioral;
