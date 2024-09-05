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
  wire audio;

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

  reg signed [17:0] r1;                                               // was 23 bit
  reg signed [18:0] r2;                                               // was 23 bit
  wire signed [19:0] r = 2*(r1 - center_y*2) + r2 - center_x*2 + 2;   // was 23 bit

  reg signed [13:0] title_r;
  reg [5:0] title_r_pixels_in_scanline;

  always @(posedge clk) begin
    if (~rst_n) begin
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

      // circle for title
      if (!video_active & y[6:0] == 0) begin
        title_r <= 64*64+64*64;
      end else if (x == 640) begin
        title_r <= title_r + 2*(y[6:0]-64)+1 - 64*2;
        title_r_pixels_in_scanline <= 0;
      end else if (x > 640 && x < 640+128) begin
        title_r <= title_r + 2*(x[6:0]-64)+1;
        if (x > 640+64 & title_r < 60*60)
          title_r_pixels_in_scanline <= title_r_pixels_in_scanline + 1; // count pixels in circle for each scanline
      end
    end
  end

  // wire signed [22:0] dot = ((p_x * p_x + p_y * p_y*2) * (128-frame)) >> (9+frame[6:5]);
  // wire signed [22:0] dot = (r * (128-frame)) >> (9+frame[6:5]);
  wire signed [22:0] dot = (r * (128-frame)) >> (9+((frame[6:4]+1)>>1) );  // zoom on snare
  // wire signed [22:0] dot = (r * (128-frame)) >> (9+(frame[6:4]-(~frame[4])));  // zoom on snare
  wire [7:0] pp_x = dot;
  wire [7:0] pp_y = dot;

  wire zoom_mode = (frame_counter[7] & frame_counter[8]);
  // wire signed [22:0] dot2 = ((pp_x * pp_x * 8) * frame) >> (18 - 2*zoom_mode);
  wire signed [22:0] dot2 = ((pp_x * pp_x) * frame) >> (15 - 2*zoom_mode);
  wire [7:0] ppp_x = dot2;

  // A
  // wire [7:0] ppp_y = dot2 + p_y * (frame[7:5]+1'd1) * frame_counter[7] - p_x * (frame[6:5]+1'd1) * frame_counter[7];
  // B
  // wire [7:0] ppp_y = dot2 + p_y*frame_counter[7] - p_x/2*frame_counter[7];

  // A & B combined
  wire mode_a = frame_counter[8];
  wire mode_b = frame_counter[7]^frame_counter[8];
  // wire [7:0] ppp_y = dot2 + p_y*mode_a - p_x/2*mode_a +
  //                           p_y*(frame[7:5]+1'd1)*mode_b - p_x*(frame[6:5]+1'd1) * mode_b;
  wire [7:0] p_p =          p_y*mode_a - p_x/2*mode_a +
                            p_y*(frame[7:5]+1'd1)*mode_b - p_x*(frame[6:5]+1'd1) * mode_b;

  wire [7:0] ppp_y = frame_counter[8:7] == 2? 
                      -(y & 8'h7f & p_x) + (r>>11):
                        dot2 + p_p;

  // generate title pixels
  wire ringR = y[9:7] == 3'b010 & |x[9:7] & (x[6:0] < title_r_pixels_in_scanline) &
      ~(y > 256+70 & y < 256+128 & (x >= 256 & x < 256+64));
  wire ringL = y[9:7] == 3'b010 & x[9:7] == 3'b010 & (~x[6:0] < title_r_pixels_in_scanline);
  // .DDRR.OPP. => column on every odd 64 pixel sections except 0, 5 and 8th
  // 012345678 
  wire columns = y > 256+4 & y < 256+124 & x[6] & x[8:6] != 5 & ~x[9];
  wire tails = y > 256+64 & y < 256+128+16 & x >= 256+256-64 & x < 256+256;


  wire [2:0] part = frame_counter[9-:3];
  assign {R,G,B} =
    (~video_active) ? 6'b00_00_00 :
    // (part == 2) ? { (&ppp_y[5:2]) * ppp_y[1-:2], 1'b0, &ppp_y[5:3] * ppp_y[0], 2'b00 } : // red/golden serpinsky
    // (part == 2) ? { (&ppp_y[5:2]) * ppp_y[1-:2], (&ppp_y[5:2]) * ppp_y[0], 3'b000 } : // red/golden serpinsky
    part == 2 ? { &ppp_y[5:2] * ppp_y[1-:2], &ppp_y[6:0] * ppp_y[1-:2], 2'b00 }: // red/golden serpinsky
    (part == 6) ? { ppp_y[7-:2], ppp_y[6-:2], ppp_y[5-:2] } :     // colored serpinsky
    (part == 1) ? { &ppp_y[6:4] * 6'b110000 | &ppp_y[6:3]*dot[7]*6'b000010 } : // red lines
    (part == 0) ? { |ppp_y[7:6] ? {4'b11_00, dot[6:5]} : ppp_y[5:4] } : //+6'b110001
    // //               // 4'b1000 * (ppp_y > 200), ppp_y[6:5] };
    (part == 5) ? { &ppp_y[5:2] | ringR | ringL | columns | tails ? 6'b111_111 : 6'b0 } : 
                // { ppp_x[7-:2] + ppp_y[5-:2], ppp_y[5-:2], ppp_y[3-:2] };
                { ppp_x[7-:2] + ppp_y[5-:2], ppp_y[5-:2], ppp_y[3-:2] };



  // assign R = video_active ? (&ppp_y[7:3]) * ppp_y[2-:2] : 2'b00; <-- deformed sierkpinsky 
  // assign R = video_active ? (&ppp_y[5:3]) * ppp_y[1-:2] : 2'b00; <-- deformed sierkpinsky 2
  // assign R = video_active ? &ppp_y[5:3] : 2'b00;//video_active ? { ppp_x[7-:2] + ppp_y[5-:2]} : 2'b00;
  // assign G = video_active ? ppp_y[7-:2]*0 : 2'b00;
  // assign B = video_active ? ppp_y[7-:2]*0 : 2'b00;

  // assign R = video_active ? { ppp_x[7-:2] + ppp_y[5-:2]} : 2'b00;
  // assign G = video_active ? { ppp_y[5-:2] } : 2'b00; // works bettter for combined A&B: ppp_y[7-:2]
  // assign B = video_active ? { ppp_y[3-:2] } : 2'b00;
  
  // assign R = video_active ? { ppp_x[7-:2] } : 2'b00;
  // assign G = video_active ? { ppp_y[5-:2] } : 2'b00;
  // assign B = video_active ? { ppp_y[3-:2] } : 2'b00;

  // assign R = video_active ? { (ppp_x > 8'd200) * 2'b11 } : 2'b00;
  // assign G = video_active ? { (ppp_x > 8'd200) * 2'b11 } : 2'b00;
  // assign B = video_active ? { (ppp_y > 8'd200) * 2'b11 } : 2'b00;

  // assign R = video_active ? ppp_x[4:3]  : 2'b00;
  // assign G = video_active ? ppp_x[2:1]  : 2'b00;
  // assign B = video_active ? ppp_y[4:3]  : 2'b00;

  // assign R = video_active ? frame_counter[4:3]  : 2'b00;
  // assign G = video_active ? frame_counter[2:1]  : 2'b00;
  // assign B = video_active ? frame_counter[3:2]  : 2'b00;

  wire [12:0] timer = {frame_counter, frame_counter_frac};
  reg noise, noise_src = ^r1;
  reg [2:0] noise_counter;

  wire square60hz = y < 255;                  // 60Hz square wave
  wire [4:0] envelopeA = 5'd31 - timer[4:0];  // exp(t*-10) decays to 0 approximately in 32 frames  [255 215 181 153 129 109  92  77  65  55  46  39  33  28  23  20  16  14 12  10   8   7   6   5   4   3   3   2   2]
  wire [4:0] envelopeB = 5'd31 - timer[3:0]*2;// exp(t*-20) decays to 0 approximately in 16 frames  [255 181 129  92  65  46  33  23  16  12   8   6   4   3]
  wire       envelopeP8 = (|timer[3:2])*5'd31;// pulse for 8 frames
  wire beats_1_3 = timer[5:4] == 2'b10;


  // melody notes: 151  26  40  60 _ 90 143  23  35
  // x1.5 wrap-around progression
  reg [8:0] note_freq;
  reg [8:0] note_counter;
  reg       note;
  wire [2:0] note_in = timer[7-:3];           // 8 notes, 32 frames per note each. 256 frames total, ~4 seconds
  always @(note_in)
  case(note_in)
      3'd0 : note_freq = 8'd151;
      3'd1 : note_freq = 8'd26;
      3'd2 : note_freq = 8'd40;
      3'd3 : note_freq = 8'd60;
      3'd4 : note_freq = 8'd90;
      3'd5 : note_freq = 8'd143;
      3'd6 : note_freq = 8'd23;
      3'd7 : note_freq = 8'd35;
  endcase

  wire kick   = square60hz & (x < envelopeA);                 // 60Hz square wave with half second envelope
  wire snare  = noise      & (x >= 32 && x < 32+envelopeB);   // noise with half second envelope
  wire lead   = note       & (x >= 64 && x < 64+envelopeB);   // ROM square wave with quarter second envelope
  assign audio = { kick | (snare & beats_1_3) | lead };

  reg [11:0] frame_counter;
  reg frame_counter_frac;
  always @(posedge clk) begin
    if (~rst_n) begin
      frame_counter <= 0;
      frame_counter_frac <= 0;
    end else begin
      if (x == 0 && y == 0) begin
        {frame_counter, frame_counter_frac} <= {frame_counter,frame_counter_frac} + 1;
      end

      // noise
      if (x == 0) begin
        if (noise_counter > 1) begin 
          noise_counter <= 0;
          noise <= noise ^ noise_src;
        end else
          noise_counter <= noise_counter + 1'b1;
      end

      // square wave
      if (x == 0) begin
        if (note_counter > note_freq) begin 
          note_counter <= 0;
          note <= ~note;
        end else
          note_counter <= note_counter + 1'b1;
      end

      // if (x == 256 && |y[1:0]==0) begin
      // if (x == 256 && y[0]==0) begin
      //   noise <= noise ^ noise_;
      // end
    end
  end
  

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  // TinyAudio PMOD
  assign uio_out = {8{audio}};

endmodule



//   reg [6:0] note;
//   reg audio_out;

//   reg [11:0] frame_counter;
//   reg frame_counter_frac;
//   always @(posedge clk) begin
//     if (~rst_n) begin
//       frame_counter <= 0;//60*5;
//       frame_counter_frac <= 0;
//     end else begin
//       if (x == 0 && y == 0) begin
//         {frame_counter, frame_counter_frac} <= {frame_counter,frame_counter_frac} + 1;
//       end
//       if (x == 1) begin
//         if (note > 35) begin  // 440Hz
//           note <= 0;
//           audio_out <= ~audio_out;
//         end else
//           note <= note + 1'b1;
//       end
//       // if (vsync && x == 0 && y == 0) begin
//       //   frame_counter <= 3;//frame_counter + 1;
//       // end
//     end
//   end

//   // TinyVGA PMOD
//   assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
//   wire audio = {audio_out & (x < 10)};
//   assign uio_out = {8{audio}};

// endmodule
