\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)

   // ==========================================
   // Provides reference solutions
   // without visibility to source code.
   // ==========================================
   
   // ----------------------------------
   // Instructions:
   //    - When stuck on a particular lab, provide the LabId below, and compile/simulate.
   //    - A reference solution will build, but the source code will not be visible.
   //    - You may use waveforms, diagrams, and visualization to understand the proper circuit, but you
   //      will have to come up with the code. Logic expression syntax can be found by hovering over the
   //      signal assignment in the diagram.
   // ----------------------------------
   
   /*
   
   // Provide the Lab ID given at the lower right of the slide.
   var(LabId, DONE)



   // ================================================
   // No need to touch anything below this line.

   // Is this a calculator lab?
   var(CalcLab, m5_if_regex(m5_LabId, ^\(C\)-, (C), 1, 0))
   // ---SETTINGS---
   var(my_design, m5_if(m5_CalcLab, tt_um_calc, tt_um_riscv_cpu)) /// Change to tt_um_<your-github-username>_riscv_cpu. (See Tiny Tapeout repo README.md.)
   var(debounce_inputs, 0)         /// Set to 1 to provide synchronization and debouncing on all input signals.
                                   /// use "m5_neq(m5_MAKERCHIP, 1)" to debounce unless in Makerchip.
   // --------------
   
   // If debouncing, a user's module is within a wrapper, so it has a different name.
   var(user_module_name, m5_if(m5_debounce_inputs, my_design, m5_my_design))
   var(debounce_cnt, m5_if_eq(m5_MAKERCHIP, 1, 8'h03, 8'hff))
   
   */
\SV
   // Include Tiny Tapeout Lab.
   m4_include_lib(['https:/']['/raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/79e40995aab07f65c1616c30c046f26893de3df5/tlv_lib/tiny_tapeout_lib.tlv'])   

   // Strict checking.
   `default_nettype none

   // Default Makerchip TL-Verilog Code Template
   m4_include_makerchip_hidden(['mest_course_solutions.private.tlv'])


// ================================================
// A simple Makerchip Verilog test bench driving random stimulus.
// Modify the module contents to your needs.
// ================================================

// Include the Makerchip module only in Makerchip. (Only because Yosys chokes on $urandom.)
m4_ifelse_block(m5_MAKERCHIP, 1, ['

module top(input logic clk, input logic reset, input logic [31:0] cyc_cnt, output logic passed, output logic failed);
   // Tiny tapeout I/O signals.
   logic [7:0] ui_in, uio_in, uo_out, uio_out, uio_oe;
   assign ui_in = 8'b0;
   assign uio_in = 8'b0;
   logic ena = 1'b0;
   logic rst_n = ! reset;
      
   // Instantiate the Tiny Tapeout module.
   m5_user_module_name tt(.*);
   
   assign passed = uo_out[0];
   assign failed = uo_out[1];
endmodule

'])   /// end Makerchip-only

// Provide a wrapper module to debounce input signals if requested.
m5_if(m5_debounce_inputs, ['m5_tt_top(m5_my_design)'])
// The above macro expands to multiple lines. We enter a new \SV block to reset line tracking.
\SV



// =======================
// The Tiny Tapeout module
// =======================

module m5_user_module_name (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
   logic passed, failed;  // Connected to uo_out[0] and uo_out[1] respectively, which connect to Makerchip passed/failed.

   wire reset = ! rst_n;
   // assign uo_out[0] = 1'b1; // supposedly a hack but didn't work
   
   
///////////////////////////////
// work below
///////////////////////////////
   
// Instruction memory in |cpu at the given stage.
\TLV imem(@_stage)
   // Instruction Memory containing program.
   @_stage
      \SV_plus
         // The program in an instruction memory.
         logic [31:0] instrs [0:m5_NUM_INSTRS-1];
         m5_repeat(m5_NUM_INSTRS, ['assign instrs[m5_LoopCnt] = m5_eval(m5_eval(m5_get(['instr']m5_LoopCnt))); '])
      /m5_IMEM_HIER
         $instr[31:0] = *instrs\[#imem\];
      ?$imem_rd_en
         $imem_rd_data[31:0] = /imem[$imem_rd_addr]$instr;


// A 2-rd 1-wr register file in |cpu that reads and writes in the given stages. If read/write stages are equal, the read values reflect previous writes.
// Reads earlier than writes will require bypass.
\TLV rf(@_rd, @_wr)
   // Reg File
   @_wr
      /xreg[31:0]
         $wr = |cpu$rf_wr_en && (|cpu$rf_wr_index != 5'b0) && (|cpu$rf_wr_index == #xreg);
         $value[31:0] = |cpu$reset ?   #xreg           :
                        $wr        ?   |cpu$rf_wr_data :
                                       $RETAIN;
   @_rd
      ?$rf_rd_en1
         $rf_rd_data1[31:0] = /xreg[$rf_rd_index1]>>m4_stage_eval(@_wr - @_rd + 1)$value;
      ?$rf_rd_en2
         $rf_rd_data2[31:0] = /xreg[$rf_rd_index2]>>m4_stage_eval(@_wr - @_rd + 1)$value;
      `BOGUS_USE($rf_rd_data1 $rf_rd_data2) 


// A data memory in |cpu at the given stage. Reads and writes in the same stage, where reads are of the data written by the previous transaction.
\TLV dmem(@_stage)
   // Data Memory
   @_stage
      /dmem[15:0]
         $wr = |cpu$dmem_wr_en && (|cpu$dmem_addr == #dmem);
         $value[31:0] = |cpu$reset ?   #dmem :
                        $wr        ?   |cpu$dmem_wr_data :
                                       $RETAIN;
                                  
      ?$dmem_rd_en
         $dmem_rd_data[31:0] = /dmem[$dmem_addr]>>1$value;
      `BOGUS_USE($dmem_rd_data)

\TLV myth_fpga(@_stage)
   @_stage

////////////////////////////////////
// VIZ
////////////////////////////////////


\TLV cpu_viz(@_stage)
   m4_ifelse_block(M4_MAKERCHIP, 1, ['
   m4_ifelse_block(m4_sp_graph_dangerous, 1, [''], ['
   |cpu
      // for pulling default viz signals into CPU
      // and then back into viz
      @0
         $ANY = /fpga|cpuviz/defaults<>0$ANY;
         `BOGUS_USE($dummy)
         /xreg[31:0]
            $ANY = /fpga|cpuviz/defaults/xreg<>0$ANY;
         /dmem[15:0]
            $ANY = /fpga|cpuviz/defaults/dmem<>0$ANY;
   // String representations of the instructions for debug.
   \SV_plus
      logic [40*8-1:0] instr_strs [0:m5_NUM_INSTRS];
      // String representations of the instructions for debug.
      m5_repeat(m5_NUM_INSTRS, ['assign instr_strs[m5_LoopCnt] = "m5_eval(['m5_get(['instr_str']m5_LoopCnt)'])"; '])
      assign instr_strs[m5_NUM_INSTRS] = "END                                     ";
   |cpuviz
      @1
         /imem[m5_calc(m5_NUM_INSTRS-1):0]  // TODO: Cleanly report non-integer ranges.
            $instr[31:0] = /fpga|cpu/imem<>0$instr;
            $instr_str[40*8-1:0] = *instr_strs[imem];
            \viz_js
               box: {width: 500, height: 18, strokeWidth: 0},
               onTraceData() {
                  let instr_str = '$instr'.asBinaryStr(NaN) + "    " + '$instr_str'.asString();
                  return {objects: {instr_str: new fabric.Text(instr_str, {
                     top: 0,
                     left: 0,
                     fontSize: 14,
                     fontFamily: "monospace",
                     fill: "white"
                  })}};
               },
               where: {left: -450, top: 0}
             
      @0
         /defaults
            {$is_lui, $is_auipc, $is_jal, $is_jalr, $is_beq, $is_bne, $is_blt, $is_bge, $is_bltu, $is_bgeu, $is_lb, $is_lh, $is_lw, $is_lbu, $is_lhu, $is_sb, $is_sh, $is_sw} = '0;
            {$is_addi, $is_slti, $is_sltiu, $is_xori, $is_ori, $is_andi, $is_slli, $is_srli, $is_srai, $is_add, $is_sub, $is_sll, $is_slt, $is_sltu, $is_xor} = '0;
            {$is_srl, $is_sra, $is_or, $is_and, $is_csrrw, $is_csrrs, $is_csrrc, $is_csrrwi, $is_csrrsi, $is_csrrci} = '0;
            {$is_load, $is_store} = '0;

            $valid               = 1'b1;
            $rd[4:0]             = 5'b0;
            $rs1[4:0]            = 5'b0;
            $rs2[4:0]            = 5'b0;
            $src1_value[31:0]    = 32'b0;
            $src2_value[31:0]    = 32'b0;

            $result[31:0]        = 32'b0;
            $pc[31:0]            = 32'b0;
            $imm[31:0]           = 32'b0;

            $is_s_instr          = 1'b0;

            $rd_valid            = 1'b0;
            $rs1_valid           = 1'b0;
            $rs2_valid           = 1'b0;
            $rf_wr_en            = 1'b0;
            $rf_wr_index[4:0]    = 5'b0;
            $rf_wr_data[31:0]    = 32'b0;
            $rf_rd_en1           = 1'b0;
            $rf_rd_en2           = 1'b0;
            $rf_rd_index1[4:0]   = 5'b0;
            $rf_rd_index2[4:0]   = 5'b0;

            $ld_data[31:0]       = 32'b0;
            $imem_rd_en          = 1'b0;
            $imem_rd_addr[m5_IMEM_INDEX_CNT-1:0] = {m5_IMEM_INDEX_CNT{1'b0}};
            
            /xreg[31:0]
               $value[31:0]      = 32'b0;
               $wr               = 1'b0;
               `BOGUS_USE($value $wr)
               $dummy[0:0]       = 1'b0;
            /dmem[15:0]
               $value[31:0]      = 32'b0;
               $wr               = 1'b0;
               `BOGUS_USE($value $wr) 
               $dummy[0:0]       = 1'b0;
            `BOGUS_USE($is_lui $is_auipc $is_jal $is_jalr $is_beq $is_bne $is_blt $is_bge $is_bltu $is_bgeu $is_lb $is_lh $is_lw $is_lbu $is_lhu $is_sb $is_sh $is_sw)
            `BOGUS_USE($is_addi $is_slti $is_sltiu $is_xori $is_ori $is_andi $is_slli $is_srli $is_srai $is_add $is_sub $is_sll $is_slt $is_sltu $is_xor)
            `BOGUS_USE($is_srl $is_sra $is_or $is_and $is_csrrw $is_csrrs $is_csrrc $is_csrrwi $is_csrrsi $is_csrrci)
            `BOGUS_USE($is_load $is_store)
            `BOGUS_USE($valid $rd $rs1 $rs2 $src1_value $src2_value $result $pc $imm)
            `BOGUS_USE($is_s_instr $rd_valid $rs1_valid $rs2_valid)
            `BOGUS_USE($rf_wr_en $rf_wr_index $rf_wr_data $rf_rd_en1 $rf_rd_en2 $rf_rd_index1 $rf_rd_index2 $ld_data)
            `BOGUS_USE($imem_rd_en $imem_rd_addr)
            
            $dummy[0:0]          = 1'b0;
      @_stage
         $ANY = /fpga|cpu<>0$ANY;
         
         /xreg[31:0]
            $ANY = /fpga|cpu/xreg<>0$ANY;
            `BOGUS_USE($dummy)
         
         /dmem[15:0]
            $ANY = /fpga|cpu/dmem<>0$ANY;
            `BOGUS_USE($dummy)

         // m5_mnemonic_expr is build for WARP-V signal names, which are slightly different. Correct them.
         m4_define(['m4_modified_mnemonic_expr'], ['m4_patsubst(m5_mnemonic_expr, ['_instr'], [''])'])
         $mnemonic[10*8-1:0] = m4_modified_mnemonic_expr $is_load ? "LOAD      " : $is_store ? "STORE     " : "ILLEGAL   ";
         \viz_js
            box: {left: -470, top: -20, width: 1070, height: 1000, strokeWidth: 0},
            render() {
               //
               // PC instr_mem pointer
               //
               let $pc = '$pc';
               let color = !('$valid'.asBool()) ? "red" : "green";
               let pcPointer = new fabric.Text("➥", {
                  top: 18 * ($pc.asInt() / 4) - 6,
                  left: -166,
                  fill: color,
                  fontSize: 24,
                  fontFamily: "monospace"
               });
               //
               //
               // Fetch Instruction
               //
               // TODO: indexing only works in direct lineage.  let fetchInstr = new fabric.Text('|fetch/instr_mem[$Pc]$instr'.asString(), {  // TODO: make indexing recursive.
               //let fetchInstr = new fabric.Text('$raw'.asString("--"), {
               //   top: 50,
               //   left: 90,
               //   fill: color,
               //   fontSize: 14,
               //   fontFamily: "monospace"
               //});
               //
               // Instruction with values.
               //
               let regStr = (valid, regNum, regValue) => {
                  return valid ? `x${regNum} (${regValue})` : `xX`;
               };
               let srcStr = ($src, $valid, $reg, $value) => {
                  return $valid.asBool(false)
                             ? `\n      ${regStr(true, $reg.asInt(NaN), $value.asInt(NaN))}`
                             : "";
               };
               let str = `${regStr('$rd_valid'.asBool(false), '$rd'.asInt(NaN), '$result'.asInt(NaN))}\n` +
                         `  = ${'$mnemonic'.asString()}${srcStr(1, '$rs1_valid', '$rs1', '$src1_value')}${srcStr(2, '$rs2_valid', '$rs2', '$src2_value')}\n` +
                         `      i[${'$imm'.asInt(NaN)}]`;
               let instrWithValues = new fabric.Text(str, {
                  top: 70,
                  left: 140,
                  fill: color,
                  fontSize: 14,
                  fontFamily: "monospace"
               });
               return [pcPointer, instrWithValues];
            }
         //
         // Register file
         //
         /xreg[31:0]           
            \viz_js
               box: {width: 90, height: 18, strokeWidth: 0},
               all: {
                  box: {strokeWidth: 0},
                  init() {
                     let regname = new fabric.Text("Reg File", {
                        top: -20, left: 2,
                        fontSize: 14,
                        fontFamily: "monospace",
                        fill: "white"
                     });
                     return {regname};
                  }
               },
               init() {
                  let reg = new fabric.Text("", {
                     top: 0, left: 0,
                     fontSize: 14,
                     fontFamily: "monospace",
                     fill: "white"
                  });
                  return {reg};
               },
               render() {
                  let mod = '$wr'.asBool(false);
                  let reg = parseInt(this.getIndex());
                  let regIdent = reg.toString();
                  let oldValStr = mod ? `(${'>>1$value'.asInt(NaN).toString()})` : "";
                  this.getObjects().reg.set({
                     text: regIdent + ": " + '$value'.asInt(NaN).toString() + oldValStr,
                     fill: mod ? "cyan" : "white"});
               },
               where: {left: 365, top: -20},
               where0: {left: 0, top: 0}
         //
         // DMem
         //
         /dmem[15:0]
            \viz_js
               box: {width: 100, height: 18, strokeWidth: 0},
               all: {
                  box: {strokeWidth: 0},
                  init() {
                  let memname = new fabric.Text("Mini DMem", {
                        top: -20,
                        left: 2,
                        fontSize: 14,
                        fontFamily: "monospace",
                        fill: "white"
                     });
                     return {memname};
                  }
               },
               init() {
                  let mem = new fabric.Text("", {
                     top: 0,
                     left: 10,
                     fontSize: 14,
                     fontFamily: "monospace",
                     fill: "white"
                  });
                  return {mem};
               },
               render() {
                  let mod = '$wr'.asBool(false);
                  let mem = parseInt(this.getIndex());
                  let memIdent = mem.toString();
                  let oldValStr = mod ? `(${'>>1$value'.asInt(NaN).toString()})` : "";
                  this.getObjects().mem.set({
                     text: memIdent + ": " + '$value'.asInt(NaN).toString() + oldValStr,
                     fill: mod ? "cyan" : "white"});
               },
               where: {left: 458, top: -20},
               where0: {left: 0, top: 0}
   '])    
   '])
   
\TLV
   /* verilator lint_off UNOPTFLAT */
   // Connect Tiny Tapeout I/Os to Virtual FPGA Lab.
   m5+tt_connections()
   
   // Instantiate the Virtual FPGA Lab.
   m5+board(/top, /fpga, 7, $, , hidden_solution)
   // Label the switch inputs [0..7] (1..8 on the physical switch panel) (bottom-to-top).
   m5+tt_input_labels_viz(['"UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED"'])

\SV
endmodule
