/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 8'b1111_1111;

  
  wire [9:0] x;
  wire [9:0] y;
  wire video_active;
    hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(x),
    .vpos(y)
  );

  wire signed [9:0] frame = frame_counter[6:0];
  wire signed [9:0] offset_x = frame/2; 
  wire signed [9:0] offset_y = frame; 
  wire signed [9:0] center_x = 10'sd320+offset_x;
  wire signed [9:0] center_y = 10'sd240+offset_y;
  wire signed [9:0] p_x = x - center_x;
  wire signed [9:0] p_y = y - center_y;

  // (x+a)*(x+a)=(x+a)^2 = x^2 + 2ax + a^2
  // (x+a+1)*(x+a+1) = x^2 + 2(a+1)x + (a+1)^2 = x^2 + 2ax + +  a^2 + 2x + 2a + 1 = (x+a)^2 + 2x + 2a + 1
  

  // no multipliers - sequential only access
  //reg signed [22:0] r;
  reg signed [17:0] r1;
  reg signed [18:0] r2;
  wire [19:0] r = 2*(r1 - center_y*2) + r2 - center_x*2 + 2;

  reg signed [13:0] title_r;
  reg [5:0] title_r_pixels_in_scanline;
  // wire [19:0] r = 2*(r1 - center_y*2) + r2 - center_x*2 + 2;
  always @(posedge clk) begin
    if (~rst_n) begin
      frame_counter <= 0;
      //r <= 0;
      r1 <= 0;
      r2 <= 0;
      title_r <= 0;
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

      // grid of circles
      if (!video_active & y[6:0] == 0) begin
        title_r <= 64*64+64*64;
      // end else if (video_active & x == 0) begin
      end else if (x == 640) begin
        title_r <= title_r + 2*(y[6:0]-64)+1 - 64*2;
        title_r_pixels_in_scanline <= 0;
      // end else if (video_active & x < 128) begin
      end else if (x > 640 && x < 640+128) begin
        title_r <= title_r + 2*(x[6:0]-64)+1;
        if (x > 640+64 & title_r < 60*60)
          title_r_pixels_in_scanline <= title_r_pixels_in_scanline + 1;
      end

      // // grid of circles
      // if (!video_active & y[6:0] == 0) begin
      //   title_r <= 64*64+64*64;
      // end else if (video_active & x == 0) begin
      //   title_r <= title_r + 2*(y[6:0]-64)+1 - 64*2;
      // end else if (video_active & x[6:0] == 0) begin
      //   title_r <= title_r - 64*2;
      // end else if (video_active & x[6:0] < 128) begin
      //   title_r <= title_r + 2*(x[6:0]-64)+1;
      // end
    end
  end

  wire /*signed*/ [22:0] dot__ = (p_x * p_x + p_y * p_y) * (128-frame);
  wire /*signed*/ [22:0] dot___ = r* (128-frame);
  // wire /*signed*/ [22:0] dot = ((p_x * p_x + p_y * p_y*2) * (130-frame)) >> (9+frame[6:5]);
  // wire signed [22:0] dot = ((p_x * p_x + p_y * p_y*2) * (128-frame)) >> (9+frame[6:5]);
  // wire signed [22:0] dot = (r * (128-frame)) >> (9+frame[6:5]);
  wire signed [22:0] dot = (r * (128-frame)) >> (9+((frame[6:4]+1)>>1) );  // zoom on snare
  // wire signed [22:0] dot = (r * (128-frame)) >> (9+(frame[6:4]-(~frame[4])));  // zoom on snare
  wire [7:0] pp_x = dot;
  wire [7:0] pp_y = dot;

  wire zoom_mode = (frame_counter[7] & frame_counter[8]);
  // wire /*signed*/ [22:0] dot2 = ((pp_x * pp_x * 8) * frame) >> (18 - 2*zoom_mode);
  wire /*signed*/ [22:0] dot2 = ((pp_x * pp_x) * frame) >> (15 - 2*zoom_mode);
  wire [7:0] ppp_x = dot2;

  // A
  // wire [7:0] ppp_y = dot2 + p_y * (frame[7:5]+1'd1) * frame_counter[7] - p_x * (frame[6:5]+1'd1) * frame_counter[7];
  // B
  // wire [7:0] ppp_y = dot2 + p_y*frame_counter[7] - p_x/2*frame_counter[7];

  // A & B combined
  wire mode_a = frame_counter[8];
  wire mode_b = frame_counter[7]^frame_counter[8];
  wire [7:0] p_p =          p_y*mode_a - p_x/2*mode_a +
                            p_y*(frame[7:5]+1'd1)*mode_b - p_x*(frame[6:5]+1'd1) * mode_b;
  // wire [7:0] p_p =          -(p_y & p_x);

  // // wire [7:0] ppp_y = -(y & x); // sierpinksy
  // wire [7:0] ppp_y = ((y & x))+(255-(dot>>8)); // sierpinksy
  // wire [7:0] ppp_y = ((y & x))+(255-((r * (128-frame))>>19)); // sierpinksy
  // wire [7:0] ppp_y = (r>>8) >> (y & 8'h7f & x);// sierpinksy modulated by rings
  // wire [7:0] ppp_y = (r>>14) - (((dot>>7) & 8'h7f) & (p_y+frame));// warped sierpinsky
  // wire [7:0] ppp_y = -(((r * (196-frame))>>16) & y);// warped sierpinsky 2d tunnel
  // wire [7:0] ppp_y = (dot>>9)&(r>>9);// tunnel animated, going in
  // wire [7:0] ppp_y = -(y & 8'h7f & p_x) + (r>>12);// interesting sierpinksy slightly lense warped
  // wire [7:0] ppp_y = -(r>>10)+((p_y*(frame[7:5]-4)) & 8'h7f & (p_x*(frame[6:5]-4)));// interesting sierpinksy slightly lense warped
  wire [7:0] ppp_y = 1 ? //frame_counter[8:7] == 2? 
                      -(y & 8'h7f & p_x) + (r>>12):
                        dot2 + p_p;

  // wire [7:0] ppp_y = dot2 + p_p; // standard mode
  // wire [7:0] ppp_y = (dot>>9) - ((p_y & p_x)>>1);
  // wire [7:0] ppp_y = ((r*(frame_counter[6:0])>>14)) - ((y & x));
  

  // Zoom: p_y>>(frame[6:5])) + (p_x>>(frame[6:5]));

  // wire signed [15:0] dot = (p_x * p_x + p_y * p_y) >> 4; //(p_x[7:0] * p_x[7:0] + p_y[7:0] * p_y[7:0]) >> 6;

  // wire [3:0] frame = frame_counter[3:0];

  // wire signed [15:0] pp_x = (dot * (p_x > 0 ? p_x : -p_x)) >> 10;// - frame;
  // wire signed [31:0] pp_y = (dot * (p_y > 0 ? p_y : -p_y)) >> (10 - frame);

  // wire signed [15:0] dot2 = (pp_x * pp_x + pp_y * pp_y) >> 8; //(p_x[7:0] * p_x[7:0] + p_y[7:0] * p_y[7:0]) >> 6;

  // wire signed [31:0] ppp_x = (dot2 * (pp_x > 0 ? pp_x : -pp_x)) >> 10;// - frame;
  // wire signed [31:0] ppp_y = (dot2 * (pp_x > 0 ? pp_x : -pp_x)) >> (20 - frame/2);

  // wire [8:0] pp_x = dot[7:0] + p_x[8:0] - frame;
  // wire [8:0] pp_y = dot[7:0] + p_y[8:0] - frame;

  // wire [8:0] dot2 = (pp_x * pp_x + pp_y * pp_y)>>4;

  // wire [8:0] ppp_x = dot2 + pp_x - frame;
  // wire [8:0] ppp_y = dot2 + pp_y - frame;

  // wire [7:0] ppp_x = dot2 * pp_x[8-:8] - frame;
  // wire [7:0] ppp_y = dot2 * pp_y[8-:8] - frame;

  // wire [8:0] ppp_x = pp_x;
  // wire [8:0] ppp_y = pp_y;

  // wire [7:0] ppp_x_ = {8{dot__ < 100*100}};
  // wire [7:0] ppp_y_ = {8{dot___ < 100*100}};

  // assign R = video_active ? { ppp_x[7-:2] + ppp_y[5-:2]} : 2'b00;

  // wire ring = title_r < 60*60;//(240-36)*(240-36);
  wire ringR = y[9:7] == 3'b010 & |(x[9:7] & 3'b111) & (x[6:0] < title_r_pixels_in_scanline) &
      ~(y > 256+70 & y < 256+128 & (x >= 256 & x < 256+64));
  wire ringL = y[9:7] == 3'b010 & x[9:7] == 3'b010 & (~x[6:0] < title_r_pixels_in_scanline);
  //.DDRR.OPP.
  //012345678 -> except 5 & 8
  wire columns = y > 256+4 & y < 256+124 & ~x[9] & x[8:6] & x[8:6] != 5;
  wire tails = y > 256+64 & y < 256+128+16 & (x >= 256+256-64 & x < 256+256);

  wire [2:0] part = 2;//frame_counter[9-:3];
  assign {R,G,B} =
    (~video_active) ? 6'b00_00_00 :
    // (part == 2) ? { (&ppp_y[5:2]) * ppp_y[1-:2], 1'b0, &ppp_y[5:3] * ppp_y[0], 2'b00 } : // red/golden serpinsky
    // (part == 2) ? { (&ppp_y[5:2]) * ppp_y[1-:2], (&ppp_y[5:2]) * ppp_y[0], 3'b000 } : // red/golden serpinsky
    // part == 2 ? { &ppp_y[5:2], &ppp_y[1:0], 4'b0000 } : // red/golden serpinsky
    // part == 2 ? { &ppp_y[5:2] * ppp_y[1-:2], &ppp_y[6:0] * ppp_y[1-:2], 2'b00 } : // red/golden serpinsky
    part == 2 ? { &ppp_y[5:2] | ringR | ringL | columns | tails ? 6'b111_111 : 6'b0 } : 
    part == 6 ? { ppp_y[7-:2], ppp_y[6-:2], ppp_y[5-:2] } :     // colored serpinsky
    part == 1 ? { &ppp_y[6:4] * 6'b100000 | &ppp_y[6:3]*dot[7]*6'b000010 } : // red lines
    part == 0 ? { |ppp_y[7:6] ? {4'b11_00, dot[6:5]} : ppp_y[5:4] } : //+6'b110001
    //               // 4'b1000 * (ppp_y > 200), ppp_y[6:5] };

                // { ppp_x[7-:2] + ppp_y[5-:2], ppp_y[5-:2], ppp_y[3-:2] };
                { ppp_x[7-:2] + ppp_y[5-:2], ppp_y[5-:2], ppp_y[3-:2] };

                // { ppp_y[7-:2], ppp_y[6-:2], ppp_y[5-:2] };

  // assign R = video_active ? &ppp_y[5:3] : 2'b00;
  // assign G = video_active ? ppp_y[7-:2]*0 : 2'b00;
  // assign B = video_active ? ppp_y[7-:2]*0 : 2'b00;

  // assign G = video_active ? { ppp_y[5-:2] } : 2'b00; // works bettter for combined A&B: ppp_y[7-:2]
  // assign B = video_active ? { ppp_y[3-:2] } : 2'b00;
  
  //wire [1:0] px = video_active ? |((p_y & 8'h7f) & p_x): 2'b00; serpinsky
  // wire [1:0] px = video_active ? ppp_y/16: 2'b00;
  // assign R = px;
  // assign G = px;
  // assign B = px;
  
  // assign R = video_active ? { (ppp_x > 8'd8) * 2'b11 } : 2'b00;
  // assign G = video_active ? { (ppp_x > 8'd10) * 2'b11 } : 2'b00;
  // assign B = video_active ? { (ppp_y > 8'd37) * 2'b11 } : 2'b00;

  reg [11:0] frame_counter;
  always @(posedge vsync) begin
      if (~rst_n) begin end
      else
        frame_counter <= frame_counter + 1;
  end

  // always @(posedge clk) begin
  //   if (~rst_n) begin
  //     tm <= 0;
  //   end else begin
  //     y_prv <= y_px;
  //     if (y_px == 0 && y_prv != y_px) begin
  //         tm <= tm + 1;
  //     end
  //   end
  // end
  
endmodule
