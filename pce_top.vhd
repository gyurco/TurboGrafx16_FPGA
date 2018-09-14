library STD;
use STD.TEXTIO.ALL;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
-- use IEEE.STD_LOGIC_ARITH.ALL;
-- use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;
use IEEE.NUMERIC_STD.ALL;

entity pce_top is
	port(
		RESET			: in  std_logic;
		CLK 			: in  std_logic;

		ROM_REQ		: out std_logic;
		ROM_ACK		: in  std_logic;
		ROM_A 		: out std_logic_vector(21 downto 0);
		ROM_DO 		: in  std_logic_vector(7 downto 0);
		ROM_SZ 		: in  std_logic_vector(7 downto 0);

		BRM_A 		: out std_logic_vector(10 downto 0);
		BRM_DI 		: out std_logic_vector(7 downto 0);
		BRM_DO 		: in  std_logic_vector(7 downto 0);
		BRM_WE 		: out std_logic;

		AUD_LDATA	: out std_logic_vector(23 downto 0);
		AUD_RDATA	: out std_logic_vector(23 downto 0);

		SGX			: in  std_logic;
		TURBOTAP    : in  std_logic;
		SIXBUTTON   : in  std_logic;
		JOY1 		   : in  std_logic_vector(15 downto 0);
		JOY2 		   : in  std_logic_vector(15 downto 0);

		VIDEO_R		: out std_logic_vector(2 downto 0);
		VIDEO_G		: out std_logic_vector(2 downto 0);
		VIDEO_B		: out std_logic_vector(2 downto 0);
		VIDEO_CE		: out std_logic;
		VIDEO_VS		: out std_logic;
		VIDEO_HS		: out std_logic;
		VIDEO_HBL	: out std_logic;
		VIDEO_VBL	: out std_logic
	);
end pce_top;

architecture rtl of pce_top is

signal RESET_N			: std_logic := '0';

-- CPU signals
signal CPU_RD_N		: std_logic;
signal CPU_WR_N		: std_logic;
signal CPU_DI			: std_logic_vector(7 downto 0);
signal CPU_DO			: std_logic_vector(7 downto 0);
signal CPU_A			: std_logic_vector(20 downto 0);
signal CPU_CLKEN		: std_logic;
signal CPU_VCE_SEL_N	: std_logic;
signal CPU_VDC_SEL_N	: std_logic;
signal CPU_RAM_SEL_N	: std_logic;
signal CPU_BRM_SEL_N	: std_logic;
signal CPU_IO_DI		: std_logic_vector(7 downto 0);
signal CPU_IO_DO		: std_logic_vector(7 downto 0);

signal CPU_VDC0_SEL_N: std_logic;
signal CPU_VDC1_SEL_N: std_logic;
signal CPU_VPC_SEL_N	: std_logic;

-- RAM signals
signal RAM_DO			: std_logic_vector(7 downto 0);
signal RAM_A			: std_logic_vector(14 downto 0);

-- VCE signals
signal VCE_DO			: std_logic_vector(7 downto 0);
signal DOTCLOCK		: std_logic_vector(1 downto 0);

-- VDC signals
signal VDC0_DO			: std_logic_vector(7 downto 0);
signal VDC0_BUSY_N	: std_logic;
signal VDC0_IRQ_N		: std_logic;
signal VDC0_COLNO		: std_logic_vector(8 downto 0);
signal VDC1_DO			: std_logic_vector(7 downto 0);
signal VDC1_BUSY_N	: std_logic;
signal VDC1_IRQ_N		: std_logic;
signal VDC1_COLNO		: std_logic_vector(8 downto 0);
signal VDC_CLKEN		: std_logic;
signal VPC_DO			: std_logic_vector(7 downto 0);
signal VDCNUM    		: std_logic;
signal VDC_COLNO		: std_logic_vector(8 downto 0);

-- NTSC/RGB Video Output
signal VS_N				: std_logic;
signal HS_N				: std_logic;

signal ROM_RDREQ		: std_logic;

signal gamepad_out	: std_logic_vector(1 downto 0);
signal gamepad_port	: unsigned(2 downto 0);
signal gamepad_nibble: std_logic;

begin

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

CPU : entity work.huc6280
port map(
	CLK 		=> CLK,
	RESET_N	=> RESET_N,
	
	IRQ1_N	=> VDC0_IRQ_N and VDC1_IRQ_N,

	DI			=> CPU_DI,
	DO 		=> CPU_DO,
	
	A 			=> CPU_A,
	WR_N 		=> CPU_WR_N,
	RD_N		=> CPU_RD_N,
	
	CLKEN		=> CPU_CLKEN,
	RDY		=> VDC0_BUSY_N and VDC1_BUSY_N and not(ROM_RDREQ xor ROM_ACK),
	
	CEK_N		=> CPU_VCE_SEL_N,
	CE7_N		=> CPU_VDC_SEL_N,
	CER_N		=> CPU_RAM_SEL_N,
	CEB_N		=> CPU_BRM_SEL_N,
	VDCNUM   => VDCNUM,

	K			=> CPU_IO_DI,
	O			=> CPU_IO_DO,
	
	AUD_LDATA=> AUD_LDATA,
	AUD_RDATA=> AUD_RDATA
);

VIDEO_CE <= VDC_CLKEN;
VIDEO_VS <= not VS_N;
VIDEO_HS <= not HS_N;

VCE : entity work.huc6260
port map(
	CLK 		=> CLK,
	RESET_N	=> RESET_N,
	DOTCLOCK_O => DOTCLOCK,

	-- CPU Interface
	A			=> CPU_A(2 downto 0),
	CE_N		=> CPU_VCE_SEL_N,
	WR_N		=> CPU_WR_N,
	RD_N		=> CPU_RD_N,
	DI			=> CPU_DO,
	DO 		=> VCE_DO,
		
	-- VDC Interface
	COLNO		=> VDC_COLNO,
	CLKEN		=> VDC_CLKEN,
		
	-- NTSC/RGB Video Output
	R			=> VIDEO_R,
	G			=> VIDEO_G,
	B			=> VIDEO_B,
	VS_N		=> VS_N,
	HS_N		=> HS_N,
	HBL		=> VIDEO_HBL,
	VBL		=> VIDEO_VBL
);

VDC0 : entity work.huc6270
port map(
	CLK 		=> CLK,
	RESET_N	=> RESET_N,
	DOTCLOCK => DOTCLOCK,

	-- CPU Interface
	A			=> CPU_A(1 downto 0),
	CE_N		=> CPU_VDC0_SEL_N,
	WR_N		=> CPU_WR_N,
	RD_N		=> CPU_RD_N,
	DI			=> CPU_DO,
	DO 		=> VDC0_DO,
	BUSY_N	=> VDC0_BUSY_N,
	IRQ_N		=> VDC0_IRQ_N,
	
	-- VCE Interface
	COLNO		=> VDC0_COLNO,
	CLKEN		=> VDC_CLKEN,
	HS_N		=> HS_N,
	VS_N		=> VS_N
);

VDC1 : entity work.huc6270
port map(
	CLK 		=> CLK,
	RESET_N	=> RESET_N,
	DOTCLOCK => DOTCLOCK,

	-- CPU Interface
	A			=> CPU_A(1 downto 0),
	CE_N		=> CPU_VDC1_SEL_N,
	WR_N		=> CPU_WR_N,
	RD_N		=> CPU_RD_N,
	DI			=> CPU_DO,
	DO 		=> VDC1_DO,
	BUSY_N	=> VDC1_BUSY_N,
	IRQ_N		=> VDC1_IRQ_N,
	
	-- VCE Interface
	COLNO		=> VDC1_COLNO,
	CLKEN		=> VDC_CLKEN,
	HS_N		=> HS_N,
	VS_N		=> VS_N
);

VPC : entity work.huc6202
port map(
	CLK 		=> CLK,
	CLKEN		=> VDC_CLKEN,
	RESET_N	=> RESET_N,

	-- CPU Interface
	A			=> CPU_A(2 downto 0),
	CE_N		=> CPU_VPC_SEL_N,
	WR_N		=> CPU_WR_N,
	RD_N		=> CPU_RD_N,
	DI			=> CPU_DO,
	DO 		=> VPC_DO,
	
	HS_N		=> HS_N,
	VDC0_IN  => VDC0_COLNO,
	VDC1_IN  => VDC1_COLNO,
	VDC_OUT  => VDC_COLNO,

	VDCNUM   => VDCNUM
);

CPU_VDC0_SEL_N <= CPU_VDC_SEL_N or     CPU_A(3) or     CPU_A(4) when SGX = '1' else CPU_VDC_SEL_N;
CPU_VDC1_SEL_N <= CPU_VDC_SEL_N or     CPU_A(3) or not CPU_A(4) when SGX = '1' else '1';
CPU_VPC_SEL_N  <= CPU_VDC_SEL_N or not CPU_A(3) or     CPU_A(4) when SGX = '1' else '1';

-- CPU data bus
CPU_DI <= RAM_DO  when CPU_RD_N = '0' and CPU_RAM_SEL_N = '0' 
	  else BRM_DO  when CPU_RD_N = '0' and CPU_BRM_SEL_N = '0' 
	  else ROM_DO  when CPU_RD_N = '0' and CPU_A(20) = '0'
	  else VCE_DO  when CPU_RD_N = '0' and CPU_VCE_SEL_N = '0'
	  else VDC0_DO when CPU_RD_N = '0' and CPU_VDC0_SEL_N = '0'
	  else VDC1_DO when CPU_RD_N = '0' and CPU_VDC1_SEL_N = '0'
	  else VPC_DO  when CPU_RD_N = '0' and CPU_VPC_SEL_N = '0'
	  else X"FF";

ROM_REQ <= ROM_RDREQ;

process( CLK )
	variable rombank : std_logic_vector(1 downto 0);
begin
	if rising_edge( CLK ) then
		if RESET = '1' then
			RESET_N <= '0';
			rombank := "00";
		elsif CPU_CLKEN = '1' then

			RESET_N <= '1';

			-- CPU_A(12 downto 2) = X"7FC" means CPU_A & 0x1FFC = 0x1FF0
			if CPU_A(20) = '0' and ('0' & CPU_A(12 downto 2)) = X"7FC" and CPU_WR_N = '0' then
				rombank := CPU_A(1 downto 0);
			end if;

			if CPU_RD_N = '0' and CPU_A(20) = '0' then
				ROM_RDREQ <= not ROM_ACK;
				ROM_A <= '0'&CPU_A;

				-- Perform address mangling to mimic HuCard chip mapping.
				-- Straight mapping
				-- 384K ROM, split in 3, mapped ABABCCCC
				-- Are these needed? or correct?
				-- 768K ROM, split in 6, mapped ABCDEFEF
				-- 512K ROM,             mapped ABCDABCD
				-- 256K ROM,             mapped ABABABAB
				-- 128K ROM,             mapped AAAAAAAA
				--2560K ROM, ABCDEFGH, ABCDIJKL, ABCDMNOP, ABCDQRST = SF2

				if ROM_SZ = X"06" then                    -- bits 19 downto 16
					-- 00000 -> 20000  => 00000 -> 20000		0000 -> 0000
					-- 20000 -> 40000  => 20000 -> 40000		0010 -> 0010
					-- 40000 -> 60000  => 00000 -> 20000		0100 -> 0000
					-- 60000 -> 80000  => 20000 -> 40000		0110 -> 0010
					-- 80000 -> A0000  => 40000 -> 60000		1000 -> 0100
					-- A0000 -> C0000  => 40000 -> 60000		1010 -> 0100
					-- C0000 -> E0000  => 40000 -> 60000		1100 -> 0100
					-- E0000 ->100000  => 40000 -> 60000		1110 -> 0100
					ROM_A(19)<='0';
					ROM_A(18)<=CPU_A(19);
					ROM_A(17)<=CPU_A(17) and not CPU_A(19);
				elsif ROM_SZ = X"0C" then                    -- bits 19 downto 16
					-- 00000 -> 20000  => 00000 -> 20000		0000 -> 0000
					-- 20000 -> 40000  => 20000 -> 40000		0010 -> 0010
					-- 40000 -> 60000  => 40000 -> 60000		0100 -> 0100
					-- 60000 -> 80000  => 60000 -> 80000		0110 -> 0110
					-- 80000 -> A0000  => 80000 -> A0000		1000 -> 1000
					-- A0000 -> C0000  => A0000 -> C0000		1010 -> 1010
					-- C0000 -> E0000  => 80000 -> A0000		1100 -> 1000
					-- E0000 ->100000  => A0000 -> C0000		1110 -> 1010
					ROM_A(18)<=CPU_A(18) and not CPU_A(19);
				elsif ROM_SZ = X"08" then                    -- bits 19 downto 16
				-- Some documentation suggests this...not sure if this is correct...
					-- 00000 -> 20000  => 00000 -> 20000		0000 -> 0000
					-- 20000 -> 40000  => 20000 -> 40000		0010 -> 0010
					-- 40000 -> 60000  => 40000 -> 60000		0100 -> 0100
					-- 60000 -> 80000  => 60000 -> 80000		0110 -> 0110
					-- 80000 -> A0000  => 40000 -> 60000		1000 -> 0100
					-- A0000 -> C0000  => 60000 -> 80000		1010 -> 0110
					-- C0000 -> E0000  => 40000 -> 60000		1100 -> 0100
					-- E0000 ->100000  => 60000 -> 80000		1110 -> 0110
					ROM_A(19)<='0';
					--Use this if above is correct.
					--ROM_A(18)<=CPU_A(18) or CPU_A(19);
				elsif ROM_SZ = X"04" then                    -- bits 19 downto 16
					ROM_A(19)<='0';
					ROM_A(18)<='0';
				elsif ROM_SZ = X"02" then                    -- bits 19 downto 16
					ROM_A(19)<='0';
					ROM_A(18)<='0';
					ROM_A(17)<='0';
				elsif ROM_SZ = X"28" then                    -- bits 21 downto 19
					-- 00000 -> 80000 XX => 00000 -> 80000		0 XX -> 000
					-- 80000 ->100000 00 => 80000 ->100000		1 00 -> 001
					-- 80000 ->100000 01 =>100000 ->180000		1 01 -> 010
					-- 80000 ->100000 10 =>180000 ->200000		1 10 -> 011
					-- 80000 ->100000 11 =>200000 ->280000		1 11 -> 100
					ROM_A(21)<=CPU_A(19) and (rombank(0) and rombank(1));
					ROM_A(20)<=CPU_A(19) and (rombank(0) xor rombank(1));
					ROM_A(19)<=CPU_A(19) and not rombank(0);
				end if;
			end if;
		end if;
	end if;
end process;


RAM : entity work.dpram generic map (15,8)
port map (
	clock		=> CLK,
	address_a=> RAM_A,
	data_a	=> CPU_DO,
	wren_a	=> CPU_CLKEN and not CPU_RAM_SEL_N and not CPU_WR_N,
	q_a		=> RAM_DO
);

RAM_A(12 downto 0)  <= CPU_A(12 downto 0);
RAM_A(14 downto 13) <= CPU_A(14 downto 13) when SGX = '1' else "00";

-- Backup RAM
BRM_A <= CPU_A(10 downto 0);
BRM_DI <= CPU_DO;
BRM_WE <= CPU_CLKEN and not CPU_BRM_SEL_N and not CPU_WR_N;

-- I/O Port
CPU_IO_DI(7 downto 4) <= "1011"; -- No CD-Rom unit, TGFX-16
CPU_IO_DI(3 downto 0) <= 
	     "0000"            when CPU_IO_DO(1) = '1' or  (CPU_IO_DO(0) = '1'  and gamepad_nibble = '1')
	else joy1( 7 downto 4) when CPU_IO_DO(0) = '0' and gamepad_port = "000" and gamepad_nibble = '0'
	else joy1( 3 downto 0) when CPU_IO_DO(0) = '1' and gamepad_port = "000" and gamepad_nibble = '0'
	else joy1(11 downto 8) when CPU_IO_DO(0) = '0' and gamepad_port = "000" and gamepad_nibble = '1'
	else joy2( 7 downto 4) when CPU_IO_DO(0) = '0' and gamepad_port = "001" and gamepad_nibble = '0'
	else joy2( 3 downto 0) when CPU_IO_DO(0) = '1' and gamepad_port = "001" and gamepad_nibble = '0'
	else joy2(11 downto 8) when CPU_IO_DO(0) = '0' and gamepad_port = "001" and gamepad_nibble = '1'
	else "1111";

process(clk)
begin
	if rising_edge(clk) then
		gamepad_out<=CPU_IO_DO(1 downto 0);
		if CPU_IO_DO(1)='1' then -- reset pad
			gamepad_port<="000";
			if(gamepad_out(1) = '0') then
				gamepad_nibble <= sixbutton and not gamepad_nibble;
			end if;
		elsif gamepad_out(0)='0' and CPU_IO_DO(0)='1' and turbotap='1' then -- Rising edge of select bit
			gamepad_port<=gamepad_port+1;
		end if;
	end if;
end process;

end rtl;
