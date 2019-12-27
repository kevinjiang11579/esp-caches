`timescale 1ps / 1ps 
`include "cache_consts.svh"
`include "cache_types.svh"

module l2_write_word(clk, rst, word_in, w_off_in, b_off_in, hsize_in, line_in, line_out);

    input logic clk, rst;
    input word_t word_in;
    input word_offset_t w_off_in;
    input byte_offset_t b_off_in;
    input hsize_t hsize_in;
    input line_t line_in;
    
    output line_t line_out; 

    logic[6:0] size, b_off_tmp, w_off_bits, b_off_bits, off_bits, word_range_hi, line_range_hi;

    always_comb begin 
        size = `BITS_PER_WORD;
        b_off_tmp = 0; 

        if (hsize_in == `BYTE) begin 
            b_off_tmp = `BYTES_PER_WORD - 1 - b_off_in;
            size = 8;
        end else if (hsize_in == `HALFWORD) begin 
            b_off_tmp = `BYTES_PER_WORD - `BYTES_PER_WORD/2 - b_off_in;
            size = `BITS_PER_HALFWORD;
        end else if (hsize_in == `WORD) begin 
            b_off_tmp = 0;
            size = `BITS_PER_WORD;
        end
        w_off_bits = `BITS_PER_WORD * w_off_in;
        b_off_bits = 8 * b_off_tmp;
        off_bits = w_off_bits + b_off_bits;

        word_range_hi = b_off_bits + size - 1;
        line_range_hi = off_bits + size - 1;
        line_out = line_in;
        
        if (hsize_in == `BYTE) begin 
            line_out[off_bits +: 8] = word_in[b_off_bits +: 8]; 
        end else if (hsize_in == `HALFWORD) begin 
            line_out[off_bits +: `BITS_PER_HALFWORD] = word_in[b_off_bits +: `BITS_PER_HALFWORD]; 
        end else if (hsize_in == `WORD) begin 
            line_out[off_bits +: `BITS_PER_WORD] = word_in[b_off_bits +: `BITS_PER_WORD]; 
        end
    end

endmodule
