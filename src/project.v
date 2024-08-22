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

  wire activevideo;
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
    .display_on(activevideo),
    .hpos(x),
    .vpos(y)
  );

  // reg [7:0] counter;

  // always @(posedge clk) begin
  //   if (~rst_n) begin
  //     counter <= 0;
  //   end else
  //     counter <= counter + 1;
  // end

  // // TinyVGA PMOD
  // //assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  // assign uo_out = {hsync, counter[7:5] & video_active, vsync, counter[2:0] & video_active};



  wire signed [9:0] frame = frame_counter[7:0];//frame_counter[8] ? frame_counter[7:0] : 255-frame_counter[7:0];
  wire signed [9:0] p_x = x - 9'd320 - frame;//frame_counter[2:0];
  wire signed [9:0] p_y = y - 9'd240 - frame;//frame_counter[4:0];

  wire signed [22:0] dot = ((p_x * p_x + p_y * p_y * 2) * (130-frame)) >> (9+frame[6:5]);
  wire [7:0] pp_x = dot;
  wire [7:0] pp_y = dot;

  wire signed [22:0] dot2 = ((pp_x * pp_x * 8) * frame) >> 18;
  wire [7:0] ppp_x = dot2;
  wire [7:0] ppp_y = dot2;



  assign R = activevideo ? { ppp_x[7-:2] } : 2'b00;
  assign G = activevideo ? { ppp_y[5-:2] } : 2'b00;
  assign B = activevideo ? { ppp_y[3-:2] } : 2'b00;

  // assign R = activevideo ? { (ppp_x > 8'd200) * 2'b11 } : 2'b00;
  // assign G = activevideo ? { (ppp_x > 8'd200) * 2'b11 } : 2'b00;
  // assign B = activevideo ? { (ppp_y > 8'd200) * 2'b11 } : 2'b00;

  reg [11:0] frame_counter;
  always @(posedge vsync) begin
    if (~rst_n) begin
      frame_counter <= 0;
    end else begin
      frame_counter <= frame_counter + 1;
    end
  end


  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

endmodule
