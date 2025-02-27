// Namco mappers

module N163(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [63:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b, // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
	// Special ports
	input [7:0] audio_dout,
	// savestates              
	input       [63:0]  SaveStateBus_Din,
	input       [ 9:0]  SaveStateBus_Adr,
	input               SaveStateBus_wren,
	input               SaveStateBus_rst,
	input               SaveStateBus_load,
	output      [63:0]  SaveStateBus_Dout
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? prg_dout : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? irq : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? audio[15:0] : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
wire irq;
wire [15:0] flags_out = {12'h0, 1'b1, 1'b0, prg_bus_write, 1'b0};
wire prg_bus_write = nesprg_oe;
wire [7:0] prg_dout;
wire [15:0] audio = audio_in;

wire nesprg_oe;
wire [7:0] neschrdout;
wire neschr_oe;
wire wram_oe;
wire wram_we;
wire prgram_we;
wire chrram_oe;
wire prgram_oe;
wire [18:13] ramprgaout;
wire exp6;
reg [7:0] m2;
wire m2_n = 1;//~ce;  //m2_n not used as clk.  Invert m2 (ce).
wire [18:10] chr_aoutm;

wire [3:0] prg_ram_size = flags[29:26];
wire [3:0] prg_nvram_size = flags[34:31];
wire is_nes20 = flags[35];
// Default to having PRG RAM if no NES2.0 header
wire has_prg_ram = |{~is_nes20, prg_ram_size, prg_nvram_size};
// 2KB PRG RAM for mapper 210
wire ram_2k = (prg_ram_size == 4'h5 || prg_nvram_size == 4'h5);

always @(posedge clk) begin
	if (SaveStateBus_load) begin
		m2 <= 8'd0;
	end else begin
		m2[7:1] <= m2[6:0];
		m2[0] <= ce;
	end
end

MAPN163 n163
(
	m2[7], m2_n, clk, ~enable, prg_write, nesprg_oe, 0,
	1, prg_ain, chr_ain, prg_din, 8'b0, prg_dout,
	neschrdout, neschr_oe, chr_allow, chrram_oe, wram_oe, wram_we, prgram_we,
	prgram_oe, chr_aoutm, ramprgaout, irq, vram_ce, exp6,
	0, 7'b1111111, 6'b111111, flags[14], flags[16], flags[15],
	ce, (flags[7:0]==210), flags[24:21], audio_dout,
	// savestates
	SaveStateBus_Din, 
	SaveStateBus_Adr,
	SaveStateBus_wren,
	SaveStateBus_rst,
	SaveStateBus_load,
	SaveStateBus_Dout
);

assign chr_aout[21:18] = {4'b1000};
assign chr_aout[17:10] = chr_aoutm[17:10];
assign chr_aout[9:0] = chr_ain[9:0];
assign vram_a10 = chr_aout[10];

wire [21:13] prg_aout_tmp = {3'b00_0, ramprgaout};
wire [21:13] prg_ram = {9'b11_1100_000};
wire prg_is_ram = (prg_ain[15:13] == 3'b011) & has_prg_ram;

assign prg_aout[21:13] = prg_is_ram ? prg_ram : prg_aout_tmp;
assign prg_aout[12:11] = (prg_is_ram & ram_2k) ? 2'b00 : prg_ain[12:11];
assign prg_aout[10:0] = prg_ain[10:0];
assign prg_allow = (prg_ain[15] && !prg_write) || prg_is_ram;

endmodule


//Taken from Loopy's Power Pak mapper source mapN106.v
//fixme- sound ram is supposed to be readable (does this affect any games?)
module MAPN163(     //signal descriptions in powerpak.v
	input m2,
	input m2_n,
	input clk20,

	input reset,
	input nesprg_we,
	output nesprg_oe,
	input neschr_rd,
	input neschr_wr,
	input [15:0] prgain,
	input [13:0] chrain,
	input [7:0] nesprgdin,
	input [7:0] ramprgdin,
	output reg [7:0] nesprgdout,

	output [7:0] neschrdout,
	output neschr_oe,

	output reg chrram_we,
	output reg chrram_oe,
	output wram_oe,
	output wram_we,
	output prgram_we,
	output prgram_oe,
	output reg [18:10] ramchraout,
	output [18:13] ramprgaout,
	output irq,
	output reg ciram_ce,
	output exp6,

	input cfg_boot,
	input [18:12] cfg_chrmask,
	input [18:13] cfg_prgmask,
	input cfg_vertical,
	input cfg_fourscreen,
	input cfg_chrram,

	input ce,// add
	input mapper210,
	input [3:0] submapper,
	//output [15:0] snd_level,
	input [7:0] audio_dout,
	// savestates              
	input       [63:0]  SaveStateBus_Din,
	input       [ 9:0]  SaveStateBus_Adr,
	input               SaveStateBus_wren,
	input               SaveStateBus_rst,
	input               SaveStateBus_load,
	output      [63:0]  SaveStateBus_Dout
);

assign exp6 = 0;

reg [1:0] chr_en;
reg [5:0] prg89,prgAB,prgCD;
reg [7:0] chr0,chr1,chr2,chr3,chr4,chr5,chr6,chr7,chr10,chr11,chr12,chr13;
reg [1:0] mirror;
wire submapper1 = (submapper == 1);

always@(posedge clk20) begin
	if (reset) begin
		mirror <= cfg_vertical ? 2'b01 : 2'b10;
	end else if (SaveStateBus_load) begin
		chr0   <= SS_MAP1[ 7: 0];
		chr1   <= SS_MAP1[15: 8];
		chr2   <= SS_MAP1[23:16];
		chr3   <= SS_MAP1[31:24];
		chr4   <= SS_MAP1[39:32];
		chr5   <= SS_MAP1[47:40];
		chr6   <= SS_MAP1[55:48];
		chr7   <= SS_MAP1[63:56];
		chr10  <= SS_MAP2[23:16];
		chr11  <= SS_MAP2[31:24];
		chr12  <= SS_MAP2[39:32];
		chr13  <= SS_MAP2[47:40];
		chr_en <= SS_MAP2[49:48];
		prg89  <= SS_MAP2[55:50];
		prgAB  <= SS_MAP2[61:56];
		prgCD  <= SS_MAP3[ 5: 0];
		mirror <= SS_MAP3[ 7: 6];
	end else if(ce && nesprg_we)
		case(prgain[15:11])
			5'b10000: chr0<=nesprgdin;              //8000
			5'b10001: chr1<=nesprgdin;
			5'b10010: chr2<=nesprgdin;              //9000
			5'b10011: chr3<=nesprgdin;
			5'b10100: chr4<=nesprgdin;              //A000
			5'b10101: chr5<=nesprgdin;
			5'b10110: chr6<=nesprgdin;              //B000
			5'b10111: chr7<=nesprgdin;
			5'b11000: chr10<=nesprgdin;             //C000
			5'b11001: chr11<=nesprgdin;
			5'b11010: chr12<=nesprgdin;             //D000
			5'b11011: chr13<=nesprgdin;
			5'b11100: {mirror,prg89}<=nesprgdin;    //E000
			5'b11101: {chr_en,prgAB}<=nesprgdin;    //E800
			5'b11110: prgCD<=nesprgdin[5:0];        //F000
			//5'b11111:                             //F800 (sound)
		endcase
end

//IRQ
reg [15:0] count;
wire [15:0] count_next=count+1'd1;
wire countup=count[15] & ~&count[14:0];
reg timeout;
assign irq = timeout & ~mapper210;
always@(posedge clk20) begin
if (SaveStateBus_load) begin
	count   <= SS_MAP3[23: 8];
	timeout <= SS_MAP3[   24];
end else if (ce) begin
	if(prgain[15:12]==4'b0101)
		timeout<=0;
	else if(count==16'hFFFF)
		timeout<=1;

	if(nesprg_we & prgain[15:11]==5'b01010)
		count[7:0]<=nesprgdin;
	else if(countup)
		count[7:0]<=count_next[7:0];

	if(nesprg_we & prgain[15:11]==5'b01011)
		count[15:8]<=nesprgdin;
	else if(countup)
		count[15:8]<=count_next[15:8];
	end
end

assign SS_MAP1_BACK[ 7: 0] = chr0;
assign SS_MAP1_BACK[15: 8] = chr1;
assign SS_MAP1_BACK[23:16] = chr2;
assign SS_MAP1_BACK[31:24] = chr3;
assign SS_MAP1_BACK[39:32] = chr4;
assign SS_MAP1_BACK[47:40] = chr5;
assign SS_MAP1_BACK[55:48] = chr6;
assign SS_MAP1_BACK[63:56] = chr7;

assign SS_MAP2_BACK[15: 0] = 16'b0; // free to be used
assign SS_MAP2_BACK[23:16] = chr10;
assign SS_MAP2_BACK[31:24] = chr11;
assign SS_MAP2_BACK[39:32] = chr12;
assign SS_MAP2_BACK[47:40] = chr13;
assign SS_MAP2_BACK[49:48] = chr_en;
assign SS_MAP2_BACK[55:50] = prg89;
assign SS_MAP2_BACK[61:56] = prgAB;
assign SS_MAP2_BACK[63:62] = 2'b0; // free to be used

assign SS_MAP3_BACK[ 5: 0] = prgCD;
assign SS_MAP3_BACK[ 7: 6] = mirror;
assign SS_MAP3_BACK[23: 8] = count;
assign SS_MAP3_BACK[   24] = timeout;
assign SS_MAP3_BACK[63:25] = 39'b0; // free to be used

//PRG bank
reg [18:13] prgbankin;
always@* begin
	case(prgain[14:13])
		0:prgbankin=prg89;
		1:prgbankin=prgAB;
		2:prgbankin=prgCD;
		3:prgbankin=6'b111111;
	endcase
end

assign ramprgaout[18:13]=prgbankin[18:13] & cfg_prgmask & {4'b1111,{2{prgain[15]}}};

//CHR control
reg chrram;
reg [17:10] chrbank;
always@* begin
	case(chrain[13:10])
		0:chrbank=chr0;
		1:chrbank=chr1;
		2:chrbank=chr2;
		3:chrbank=chr3;
		4:chrbank=chr4;
		5:chrbank=chr5;
		6:chrbank=chr6;
		7:chrbank=chr7;
		8,12:chrbank=chr10;
		9,13:chrbank=chr11;
		10,14:chrbank=chr12;
		11,15:chrbank=chr13;
	endcase

	chrram=(~(chrain[12]?chr_en[1]:chr_en[0]))&(&chrbank[17:15]);   //ram/rom select

	if(!chrain[13]) begin
		ciram_ce=chrram && ~mapper210;
		chrram_oe=neschr_rd;
		chrram_we=neschr_wr & chrram;
		ramchraout[10]=chrbank[10];
	end else begin
		ciram_ce=(&chrbank[17:15]) | mapper210;
		chrram_oe=~ciram_ce & neschr_rd;
		chrram_we=~ciram_ce & neschr_wr & chrram;
		casez({mapper210,submapper1,mirror,cfg_vertical})
			5'b0?_??_?: ramchraout[10] = chrbank[10];
			//5'b0?_?1_?: ramchraout[10] = chrain[10];
			5'b10_00_?: ramchraout[10] = 1'b0;
			5'b10_01_?: ramchraout[10] = chrain[10];
			5'b10_10_?: ramchraout[10] = chrain[11];
			5'b10_11_?: ramchraout[10] = 1'b1;
			5'b11_??_0: ramchraout[10] = chrain[11];
			5'b11_??_1: ramchraout[10] = chrain[10];
		endcase
	end
	ramchraout[11]=chrbank[11];
	ramchraout[17:12]=chrbank[17:12] & cfg_chrmask[17:12];
	ramchraout[18]=ciram_ce;
end

assign wram_oe=m2_n & ~nesprg_we & prgain[15:13]==3'b011;
assign wram_we=m2_n &  nesprg_we & prgain[15:13]==3'b011;

assign prgram_we=0;
assign prgram_oe= ~cfg_boot & m2_n & ~nesprg_we & prgain[15];

wire config_rd = 0;
//wire [7:0] gg_out;
//gamegenie gg(m2, reset, nesprg_we, prgain, nesprgdin, ramprgdin, gg_out, config_rd);

//PRG data out
// No readable registers on mapper 210
wire mapper_oe = ~mapper210 & m2_n & ~nesprg_we & ((prgain[15:12]=='b0101) || (prgain[15:11]=='b01001));
always @* begin
	case(prgain[15:11])
		5'b01001: nesprgdout=audio_dout;
		5'b01010: nesprgdout=count[7:0];
		5'b01011: nesprgdout=count[15:8];
		default: nesprgdout=nesprgdin;
	endcase
end

assign nesprg_oe=wram_oe | prgram_oe | mapper_oe | config_rd;

assign neschr_oe=0;
assign neschrdout=0;

// savestate
localparam SAVESTATE_MODULES    = 3;
wire [63:0] SaveStateBus_wired_or[0:SAVESTATE_MODULES-1];
wire [63:0] SS_MAP1, SS_MAP2, SS_MAP3;
wire [63:0] SS_MAP1_BACK, SS_MAP2_BACK, SS_MAP3_BACK;	
wire [63:0] SaveStateBus_Dout_active = SaveStateBus_wired_or[0] | SaveStateBus_wired_or[1] | SaveStateBus_wired_or[2];
	
eReg_SavestateV #(SSREG_INDEX_MAP1, 64'h0000000000000000) iREG_SAVESTATE_MAP1 (clk20, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[0], SS_MAP1_BACK, SS_MAP1);  
eReg_SavestateV #(SSREG_INDEX_MAP2, 64'h0000000000000000) iREG_SAVESTATE_MAP2 (clk20, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[1], SS_MAP2_BACK, SS_MAP2);  
eReg_SavestateV #(SSREG_INDEX_MAP3, 64'h0000000000000000) iREG_SAVESTATE_MAP3 (clk20, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[2], SS_MAP3_BACK, SS_MAP3);  

assign SaveStateBus_Dout = ~reset ? SaveStateBus_Dout_active : 64'h0000000000000000;

endmodule

module namco163_mixed (
	input         clk,
	input         ce,
	input   [3:0] submapper,
	input         enable,
	input         wren,
	input  [15:0] addr_in,
	input   [7:0] data_in,
	output  [7:0] data_out,
	input  [15:0] audio_in,
	output [15:0] audio_out,
	// savestates              
	input       [63:0]  SaveStateBus_Din,
	input       [ 9:0]  SaveStateBus_Adr,
	input               SaveStateBus_wren,
	input               SaveStateBus_rst,
	input               SaveStateBus_load,
	output      [63:0]  SaveStateBus_Dout,
	
	input         Savestate_MAPRAMactive,    
	input  [6:0]  Savestate_MAPRAMAddr,     
	input         Savestate_MAPRAMRdEn,    
	input         Savestate_MAPRAMWrEn,    
	input  [7:0]  Savestate_MAPRAMWriteData,
	output [7:0]  Savestate_MAPRAMReadData
);

reg disabled;

always@(posedge clk) begin
if (!enable) begin
	disabled <= 1'b0;
end else if (SaveStateBus_load) begin
	disabled <= SS_MAP1[0];
end else if (ce) begin
	if(wren & addr_in[15:11]==5'b11100)           //E000..E7FF
		disabled<=data_in[6];
	end
end

assign SS_MAP1_BACK[0]    = disabled;
assign SS_MAP1_BACK[63:1] = 63'b0; // free to be used

//sound
wire [10:0] n163_out;

namco163_sound n163
(
	clk, ce, enable, wren, addr_in, data_in, data_out, n163_out,
	// savestates
	SaveStateBus_Din, 
	SaveStateBus_Adr,
	SaveStateBus_wren,
	SaveStateBus_rst,
	SaveStateBus_load,
	SaveStateBus_wired_or[1],
	Savestate_MAPRAMactive,
	Savestate_MAPRAMAddr,     
	Savestate_MAPRAMRdEn,    
	Savestate_MAPRAMWrEn,    
	Savestate_MAPRAMWriteData,
	Savestate_MAPRAMReadData
);

//pdm #(10) pdm_mod(clk20, saturated, exp6);
wire [9:0] saturated=n163_out[9:0] | {10{n163_out[10]}};    //this is still too quiet for the suggested 47k resistor, but more clipping will make some games sound bad
wire [15:0] audio = {1'b0, saturated, 5'b0};
wire [16:0] audio_mix = (!enable | disabled) ? {audio_in, 1'b0} : (submapper==5) ? (audio_in>>>2) + audio : (submapper==4) ? (audio_in>>>1) + audio : audio_in + audio;
assign audio_out = audio_mix[16:1];

// savestates
localparam SAVESTATE_MODULES    = 2;
wire [63:0] SaveStateBus_wired_or[0:SAVESTATE_MODULES-1];
wire [63:0] SS_MAP1;
wire [63:0] SS_MAP1_BACK;	
wire [63:0] SaveStateBus_Dout_active = SaveStateBus_wired_or[0] | SaveStateBus_wired_or[1];
	
eReg_SavestateV #(SSREG_INDEX_SNDMAP5, 64'h0000000000000000) iREG_SAVESTATE_MAP1 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[0], SS_MAP1_BACK, SS_MAP1);  

assign SaveStateBus_Dout = enable ? SaveStateBus_Dout_active : 64'h0000000000000000;

endmodule

module namco163_sound(
	input clk20,
	input m2,
	input enable,
	input wr,
	input [15:0] ain,
	input [7:0] din,
	output [7:0] dout,
	output reg [10:0] out,       //range is 0..0x708
	// savestates              
	input       [63:0]  SaveStateBus_Din,
	input       [ 9:0]  SaveStateBus_Adr,
	input               SaveStateBus_wren,
	input               SaveStateBus_rst,
	input               SaveStateBus_load,
	output      [63:0]  SaveStateBus_Dout,
	
	input         Savestate_MAPRAMactive,    
	input  [6:0]  Savestate_MAPRAMAddr,     
	input         Savestate_MAPRAMRdEn,    
	input         Savestate_MAPRAMWrEn,    
	input  [7:0]  Savestate_MAPRAMWriteData,
	output [7:0]  Savestate_MAPRAMReadData
);

reg carry;
reg autoinc;
reg [6:0] ram_ain;
reg [6:0] ram_aout;
wire [7:0] ram_dout;
reg [2:0] ch;
reg [7:0] cnt_L[7:0];
reg [7:0] cnt_M[7:0];
reg [1:0] cnt_H[7:0];
wire [2:0] sum_H=cnt_H[ch]+ram_dout[1:0]+carry;
reg [4:0] sample_pos[7:0];
reg [2:0] cycle;
reg [3:0] sample;
wire [7:0] chan_out=sample*ram_dout[3:0];   //sample*vol
reg [10:0] out_acc;
wire [10:0] sum=out_acc+chan_out;
reg addr_lsb;
wire [7:0] sample_addr=ram_dout+sample_pos[ch];
reg do_inc;

//ram in
always@(posedge clk20) begin
	if (SaveStateBus_load) begin
		do_inc  <= SS_MAP1[    0];
		ram_ain <= SS_MAP1[ 7: 1];
		autoinc <= SS_MAP1[    8];
	end else if (m2) begin
		do_inc<= 0;
		if (do_inc)
			ram_ain<=ram_ain+1'd1;
		if(wr & ain[15:11]==5'b11111)           //F800..FFFF
			{autoinc,ram_ain}<=din;
		else if(ain[15:11]==5'b01001 & autoinc) //4800..4FFF
			do_inc<=1;
	end
end

//mixer FSM
always @* begin
	case(cycle)
		0: ram_aout={1'b1,ch,3'd0};     //freq[7:0]
		1: ram_aout={1'b1,ch,3'd2};     //freq[15:8]
		2: ram_aout={1'b1,ch,3'd4};     //length, freq[17:16]
		3: ram_aout={1'b1,ch,3'd6};     //address
		4: ram_aout=sample_addr[7:1];   //sample address
		5: ram_aout={1'b1,ch,3'd7};     //volume
		default: ram_aout=7'bXXXXXXX;
	endcase
end

reg [3:0] count45,cnt45;
always@(posedge clk20) begin
	if (SaveStateBus_load) begin
		count45 <= SS_MAP1[12: 9];
	end else if (m2) begin
		count45<=(count45==14)?4'd0:count45+1'd1;
	end
end

always@(posedge clk20) begin
	if (SaveStateBus_load) begin
		cnt45         <= SS_MAP1[16:13];
		cycle         <= SS_MAP1[19:17];
		carry         <= SS_MAP1[   20];
		addr_lsb      <= SS_MAP1[   21];
		sample        <= SS_MAP1[25:22];
		ch            <= SS_MAP1[28:26];
		out_acc       <= SS_MAP1[39:29];
		cnt_L[0]      <= SS_MAP2[ 7: 0];
		cnt_L[1]      <= SS_MAP2[15: 8];
		cnt_L[2]      <= SS_MAP2[23:16];
		cnt_L[3]      <= SS_MAP2[31:24];
		cnt_L[4]      <= SS_MAP2[39:32];
		cnt_L[5]      <= SS_MAP2[47:40];
		cnt_L[6]      <= SS_MAP2[55:48];
		cnt_L[7]      <= SS_MAP2[63:56];
		cnt_M[0]      <= SS_MAP3[ 7: 0];
		cnt_M[1]      <= SS_MAP3[15: 8];
		cnt_M[2]      <= SS_MAP3[23:16];
		cnt_M[3]      <= SS_MAP3[31:24];
		cnt_M[4]      <= SS_MAP3[39:32];
		cnt_M[5]      <= SS_MAP3[47:40];
		cnt_M[6]      <= SS_MAP3[55:48];
		cnt_M[7]      <= SS_MAP3[63:56];
		cnt_H[0]      <= SS_MAP4[ 1: 0];
		cnt_H[1]      <= SS_MAP4[ 3: 2];
		cnt_H[2]      <= SS_MAP4[ 5: 4];
		cnt_H[3]      <= SS_MAP4[ 7: 6];
		cnt_H[4]      <= SS_MAP4[ 9: 8];
		cnt_H[5]      <= SS_MAP4[11:10];
		cnt_H[6]      <= SS_MAP4[13:12];
		cnt_H[7]      <= SS_MAP4[15:14];
		sample_pos[0] <= SS_MAP4[20:16];
		sample_pos[1] <= SS_MAP4[25:21];
		sample_pos[2] <= SS_MAP4[30:26];
		sample_pos[3] <= SS_MAP4[35:31];
		sample_pos[4] <= SS_MAP4[40:36];
		sample_pos[5] <= SS_MAP4[45:41];
		sample_pos[6] <= SS_MAP4[50:46];
		sample_pos[7] <= SS_MAP4[55:51];
	end else begin
		cnt45<=count45;
		if(cnt45[1:0]==0) cycle<=0;             // this gives 45 21.4M clocks per channel
		else if(cycle!=7) cycle<=cycle+1'd1;
		case(cycle)
			1: {carry, cnt_L[ch]}<=cnt_L[ch][7:0]+ram_dout;
			2: {carry, cnt_M[ch]}<=cnt_M[ch][7:0]+ram_dout+carry;
			3: begin
				cnt_H[ch]<=sum_H[1:0];
				if(sum_H[2])
					sample_pos[ch]<=(sample_pos[ch]=={ram_dout[4:2]^3'b111,2'b11})?5'd0:(sample_pos[ch]+1'd1);
			end
			4: addr_lsb<=sample_addr[0];
			5: sample<=addr_lsb?ram_dout[7:4]:ram_dout[3:0];
			6: begin
				if(ch==7) begin
					ch<=~ram_dout[6:4];
					out_acc<=0;
					out<=sum;
				end else begin
					ch<=ch+1'd1;
					out_acc<=sum;
				end
			end
		endcase
	end
end

wire [6:0] ram_addrB = Savestate_MAPRAMactive ? Savestate_MAPRAMAddr : ram_aout;
wire       ram_wrenB = Savestate_MAPRAMactive ? Savestate_MAPRAMWrEn : 1'b0;
wire [7:0] ram_dataB = Savestate_MAPRAMactive ? Savestate_MAPRAMWriteData : 8'b0;

dpram #(.widthad_a(7)) modtable
(
	.clock_a   (clk20),
	.address_a (ram_ain),
	.wren_a    (wr & ain[15:11]==5'b01001),
	.byteena_a (1),
	.data_a    (din),
	.q_a       (dout),

	.clock_b   (clk20),
	.address_b (ram_addrB),
	.wren_b    (ram_wrenB),
	.byteena_b (1),
	.data_b    (ram_dataB),
	.q_b       (ram_dout)
);

// savestate
always@(posedge clk20) begin
	if (enable) begin
		if (Savestate_MAPRAMRdEn) begin
			Savestate_MAPRAMReadData <= ram_dout;
		end
	end else begin
		Savestate_MAPRAMReadData <= 8'd0;
	end
end

assign SS_MAP1_BACK[16:13] = cnt45;
assign SS_MAP1_BACK[19:17] = cycle;
assign SS_MAP1_BACK[   20] = carry;
assign SS_MAP1_BACK[   21] = addr_lsb;
assign SS_MAP1_BACK[25:22] = sample;
assign SS_MAP1_BACK[28:26] = ch;
assign SS_MAP1_BACK[39:29] = out_acc;
assign SS_MAP1_BACK[63:40] = 24'b0; // free to be used

assign SS_MAP2_BACK[ 7: 0] = cnt_L[0];
assign SS_MAP2_BACK[15: 8] = cnt_L[1];
assign SS_MAP2_BACK[23:16] = cnt_L[2];
assign SS_MAP2_BACK[31:24] = cnt_L[3];
assign SS_MAP2_BACK[39:32] = cnt_L[4];
assign SS_MAP2_BACK[47:40] = cnt_L[5];
assign SS_MAP2_BACK[55:48] = cnt_L[6];
assign SS_MAP2_BACK[63:56] = cnt_L[7];
assign SS_MAP3_BACK[ 7: 0] = cnt_M[0];
assign SS_MAP3_BACK[15: 8] = cnt_M[1];
assign SS_MAP3_BACK[23:16] = cnt_M[2];
assign SS_MAP3_BACK[31:24] = cnt_M[3];
assign SS_MAP3_BACK[39:32] = cnt_M[4];
assign SS_MAP3_BACK[47:40] = cnt_M[5];
assign SS_MAP3_BACK[55:48] = cnt_M[6];
assign SS_MAP3_BACK[63:56] = cnt_M[7];
assign SS_MAP4_BACK[ 1: 0] = cnt_H[0];
assign SS_MAP4_BACK[ 3: 2] = cnt_H[1];
assign SS_MAP4_BACK[ 5: 4] = cnt_H[2];
assign SS_MAP4_BACK[ 7: 6] = cnt_H[3];
assign SS_MAP4_BACK[ 9: 8] = cnt_H[4];
assign SS_MAP4_BACK[11:10] = cnt_H[5];
assign SS_MAP4_BACK[13:12] = cnt_H[6];
assign SS_MAP4_BACK[15:14] = cnt_H[7];
assign SS_MAP4_BACK[20:16] = sample_pos[0];
assign SS_MAP4_BACK[25:21] = sample_pos[1];
assign SS_MAP4_BACK[30:26] = sample_pos[2];
assign SS_MAP4_BACK[35:31] = sample_pos[3];
assign SS_MAP4_BACK[40:36] = sample_pos[4];
assign SS_MAP4_BACK[45:41] = sample_pos[5];
assign SS_MAP4_BACK[50:46] = sample_pos[6];
assign SS_MAP4_BACK[55:51] = sample_pos[7];
assign SS_MAP4_BACK[63:56] = 8'b0; // free to be used

localparam SAVESTATE_MODULES    = 4;
wire [63:0] SaveStateBus_wired_or[0:SAVESTATE_MODULES-1];
wire [63:0] SS_MAP1, SS_MAP2, SS_MAP3, SS_MAP4;
wire [63:0] SS_MAP1_BACK, SS_MAP2_BACK, SS_MAP3_BACK, SS_MAP4_BACK;	
wire [63:0] SaveStateBus_Dout_active = SaveStateBus_wired_or[0] | SaveStateBus_wired_or[1] | SaveStateBus_wired_or[2] | SaveStateBus_wired_or[3];
	
eReg_SavestateV #(SSREG_INDEX_SNDMAP1, 64'h0000000000000000) iREG_SAVESTATE_MAP1 (clk20, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[0], SS_MAP1_BACK, SS_MAP1);  
eReg_SavestateV #(SSREG_INDEX_SNDMAP2, 64'h0000000000000000) iREG_SAVESTATE_MAP2 (clk20, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[1], SS_MAP2_BACK, SS_MAP2);  
eReg_SavestateV #(SSREG_INDEX_SNDMAP3, 64'h0000000000000000) iREG_SAVESTATE_MAP3 (clk20, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[2], SS_MAP3_BACK, SS_MAP3);  
eReg_SavestateV #(SSREG_INDEX_SNDMAP4, 64'h0000000000000000) iREG_SAVESTATE_MAP4 (clk20, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[3], SS_MAP4_BACK, SS_MAP4);  

assign SaveStateBus_Dout = enable ? SaveStateBus_Dout_active : 64'h0000000000000000;

endmodule