/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

/*
Video sync generator, used to drive a VGA monitor.
Timing from: https://en.wikipedia.org/wiki/Video_Graphics_Array
To use:
- Wire the hsync and vsync signals to top level outputs
- Add a 3-bit (or more) "rgb" output to the top level
*/

module hvsync_generator(clk, reset, hsync, vsync, display_on, hpos, vpos);
    input clk;
    input reset;
    output reg hsync, vsync;
    output display_on;
    output reg [9:0] hpos;
    output reg [9:0] vpos;

    // declarations for TV-simulator sync parameters
    // horizontal constants
    parameter H_DISPLAY       = 640; // horizontal display width
    parameter H_BACK          =  48; // horizontal left border (back porch)
    parameter H_FRONT         =  16; // horizontal right border (front porch)
    parameter H_SYNC          =  96; // horizontal sync width
    // vertical constants
    parameter V_DISPLAY       = 480; // vertical display height
    parameter V_TOP           =  33; // vertical top border
    parameter V_BOTTOM        =  10; // vertical bottom border
    parameter V_SYNC          =   2; // vertical sync # lines
    // derived constants
    parameter H_SYNC_START    = H_DISPLAY + H_FRONT;
    parameter H_SYNC_END      = H_DISPLAY + H_FRONT + H_SYNC - 1;
    parameter H_MAX           = H_DISPLAY + H_BACK + H_FRONT + H_SYNC - 1;
    parameter V_SYNC_START    = V_DISPLAY + V_BOTTOM;
    parameter V_SYNC_END      = V_DISPLAY + V_BOTTOM + V_SYNC - 1;
    parameter V_MAX           = V_DISPLAY + V_TOP + V_BOTTOM + V_SYNC - 1;

    wire hmaxxed = (hpos == H_MAX) || reset;  // set when hpos is maximum
    wire vmaxxed = (vpos == V_MAX) || reset;  // set when vpos is maximum
    
    // horizontal position counter
    always @(posedge clk)
    begin
      hsync <= (hpos>=H_SYNC_START && hpos<=H_SYNC_END);
      if(hmaxxed)
        hpos <= 0;
      else
        hpos <= hpos + 1;
    end

    // vertical position counter
    always @(posedge clk)
    begin
      vsync <= (vpos>=V_SYNC_START && vpos<=V_SYNC_END);
      if(hmaxxed)
        if (vmaxxed)
          vpos <= 0;
        else
          vpos <= vpos + 1;
    end
    
    // display_on is set when beam is in "safe" visible frame
    assign display_on = (hpos<H_DISPLAY) && (vpos<V_DISPLAY);
endmodule


module tt_um_rejunity_vga_test01 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock 25.200 (25.175 MHz)
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.

  assign uio_out = 0;
  assign uio_oe  = 8'b1111_1111;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};
  wire _unused_inputs = &{ui_in, uio_in, 8'b0};

  wire hsync;
  wire vsync;

  wire video_active;
  wire [9:0] x;
  wire [9:0] y;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(x),
    .vpos(y)
  );


  wire /*signed*/ [9:0] frame = frame_counter[6:0];
  wire /*signed*/ [9:0] offset_x = frame/2; 
  wire /*signed*/ [9:0] offset_y = frame; 
  wire /*signed*/ [9:0] center_x = 10'sd320+offset_x;
  wire /*signed*/ [9:0] center_y = 10'sd240+offset_y;
  wire signed [9:0] p_x = x - center_x;
  wire signed [9:0] p_y = y - center_y;

  reg signed [17:0] r1;                                               // was 23 bit
  reg signed [18:0] r2;                                               // was 23 bit
  wire signed [19:0] r = 2*(r1 - center_y*2) + r2 - center_x*2 + 2;   // was 23 bit
  always @(posedge clk) begin
    if (~rst_n) begin
      //r <= 0;
      r1 <= 0;
      r2 <= 0;
    end else begin
      if (vsync) begin
        r1 <= 0;
        r2 <= 0;
      end

      if (video_active & y == 0) begin
        // no mul optimisation, equivalent to:
        //   r1 <= center_y*center_y;
        if (x < center_y)
          r1 <= r1 + center_y;
      end else if (x == 640) begin
        // need to calculate (320+offset)^2
        // (320+offset) * (320+offset) = 320*320 + 2*320*offset + offset*offset
        r2 <= 320*320;
      end else if (x > 640) begin
        // remainder of (320+offset)^2 from above ^^^
        //    2*320*offset + offset*offset
        if (x-640 <= offset_x)
          r2 <= r2 + 2*320 + offset_x;
      end else if (video_active & x == 0) begin
        r1 <= r1 + 2*p_y + 1;
      end else if (video_active) begin
        r2 <= r2 + 2*p_x + 1;
      end
    end
  end

  // wire signed [22:0] dot = ((p_x * p_x + p_y * p_y*2) * (128-frame)) >> (9+frame[6:5]);
    wire /*signed*/ [22:0] dot = (r * (128-frame)) >> (9+frame[6:5]);
  wire [7:0] pp_x = dot;
  wire [7:0] pp_y = dot;

  wire zoom_mode = (frame_counter[7] & frame_counter[8]);
  // wire signed [22:0] dot2 = ((pp_x * pp_x * 8) * frame) >> (18 - 2*zoom_mode);
  wire /*signed*/ [22:0] dot2 = ((pp_x * pp_x) * frame) >> (15 - 2*zoom_mode);
  wire [7:0] ppp_x = dot2;

  // A
  // wire [7:0] ppp_y = dot2 + p_y * (frame[7:5]+1'd1) * frame_counter[7] - p_x * (frame[6:5]+1'd1) * frame_counter[7];
  // B
  // wire [7:0] ppp_y = dot2 + p_y*frame_counter[7] - p_x/2*frame_counter[7];

  // A & B combined
  wire mode_a = frame_counter[8];
  wire mode_b = frame_counter[7]^frame_counter[8];
  wire [7:0] ppp_y = dot2 + p_y*mode_a - p_x/2*mode_a +
                            p_y*(frame[7:5]+1'd1)*mode_b - p_x*(frame[6:5]+1'd1) * mode_b;


  assign R = video_active ? { ppp_x[7-:2] } : 2'b00;
  assign G = video_active ? { ppp_y[5-:2] } : 2'b00;
  assign B = video_active ? { ppp_y[3-:2] } : 2'b00;

  // assign R = video_active ? { (ppp_x > 8'd200) * 2'b11 } : 2'b00;
  // assign G = video_active ? { (ppp_x > 8'd200) * 2'b11 } : 2'b00;
  // assign B = video_active ? { (ppp_y > 8'd200) * 2'b11 } : 2'b00;

  reg [11:0] frame_counter;
  always @(posedge clk) begin
    if (~rst_n) begin
      frame_counter <= 60*5;
    end else begin
      if (vsync) begin
        frame_counter <= frame_counter + 1;
      end
    end
  end

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

endmodule
