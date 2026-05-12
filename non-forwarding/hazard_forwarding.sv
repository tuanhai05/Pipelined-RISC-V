module hazard_forwarding(
    // Inputs Addresses
    input  logic [4:0] i_rs1_addr_id, i_rs2_addr_id,
    input  logic [4:0] i_rs1_addr_ex, i_rs2_addr_ex,
    input  logic [4:0] i_rd_addr_ex,  i_rd_addr_dm, i_rd_addr_wb,
    
    // Control Signals
    input  logic i_reg_wr_ex, i_reg_wr_dm, i_reg_wr_wb,
    input  logic i_is_load_ex,       // Lệnh ở EX là Load?
    input  logic i_opcode_is_branch, // Lệnh ở ID là Branch?
    input  logic i_opcode_is_jalr,   // Lệnh ở ID là JALR?
    input  logic i_branch_taken,     // Branch/Jump thực sự xảy ra?
    
    // Outputs
    output logic o_stall_pc_if,
    output logic o_stall_if_id,
    output logic o_clear_if_id,
    output logic o_clear_id_ex,
    output logic [1:0] o_rs1_sel, o_rs2_sel
);

    
     logic raw_ex, raw_mem, raw_wb;
 

    //   NON_FORWARDING BLOCK
    always_comb begin
        o_rs1_sel = 2'b00;
        o_rs2_sel = 2'b00;
    end


    // =========================================================
    // 1) RAW hazard detection (non-forwarding)
    //    Nếu ID đọc rs1/rs2 mà trùng rd của EX/MEM(/WB) -> stall
    // =========================================================
   

    // Lưu ý: ở đây giả sử ID luôn "đọc" cả rs1/rs2.
    // Nếu bạn muốn chuẩn hơn: thêm rs1_en/rs2_en theo opcode.
    assign raw_ex  = i_reg_wr_ex && (i_rd_addr_ex != 5'd0) &&
                     ((i_rs1_addr_id == i_rd_addr_ex) || (i_rs2_addr_id == i_rd_addr_ex));

    assign raw_mem = i_reg_wr_dm && (i_rd_addr_dm != 5'd0) &&
                     ((i_rs1_addr_id == i_rd_addr_dm) || (i_rs2_addr_id == i_rd_addr_dm));

    // WB: tùy regfile "write-first" hay không.
    // - Nếu regfile write-first / write in first half cycle: có thể bỏ raw_wb.
    // - Nếu bạn không chắc spec testbench: KEEP raw_wb để an toàn (nhưng stall nhiều hơn).
    assign raw_wb  = i_reg_wr_wb && (i_rd_addr_wb != 5'd0) &&
                     ((i_rs1_addr_id == i_rd_addr_wb) || (i_rs2_addr_id == i_rd_addr_wb));

    // Chọn 1 trong 2:
    // 1) An toàn tuyệt đối (stall cả WB)
    //assign total_stall = raw_ex || raw_mem || raw_wb;
    // 2) Nếu chắc regfile write-first thì dùng dòng dưới và comment dòng trên:
    assign total_stall = raw_ex || raw_mem;

   



    // --- 3. Control Outputs ---
    // Khi Stall: Giữ nguyên PC và IF/ID.
    assign o_stall_pc_if  = total_stall;
    assign o_stall_if_id  = total_stall;
    
    // Clear IF/ID (Flush lệnh kế tiếp) khi:
    // 1. Branch/Jump thực sự xảy ra (Taken).
    // 2. VÀ chúng ta KHÔNG bị stall (nếu stall thì chưa quyết định nhảy được).
    assign o_clear_if_id  = i_branch_taken && !total_stall; 
    
    // Clear ID/EX (Chèn bong bóng vào EX) khi:
    // 1. Xảy ra Stall (ID bị giữ lại, cần đẩy bong bóng sang EX).
    // LƯU Ý QUAN TRỌNG: KHÔNG flush khi i_branch_taken. Lệnh Branch phải đi tiếp để được retire.
    assign o_clear_id_ex  = total_stall;

endmodule