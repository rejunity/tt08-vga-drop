/*
 * Copyright (c) 2024 ReJ aka Renaldas Zioma
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`define C1	481; // 32.70375 Hz 
`define Cs1	454; // 34.6475 Hz 
`define D1	429; // 36.7075 Hz 
`define Ds1	405; // 38.89125 Hz 
`define E1	382; // 41.20375 Hz 
`define F1	360; // 43.65375 Hz 
`define Fs1	340; // 46.24875 Hz 
`define G1	321; // 49.0 Hz 
`define Gs1	303; // 51.9125 Hz 
`define A1	286; // 55.0 Hz 
`define As1	270; // 58.27 Hz 
`define B1	255; // 61.735 Hz 
`define C2	241; // 65.4075 Hz 
`define Cs2	227; // 69.295 Hz 
`define D2	214; // 73.415 Hz 
`define Ds2	202; // 77.7825 Hz 
`define E2	191; // 82.4075 Hz 
`define F2	180; // 87.3075 Hz 
`define Fs2	170; // 92.4975 Hz 
`define G2	161; // 98.0 Hz 
`define Gs2	152; // 103.825 Hz 
`define A2	143; // 110.0 Hz 
`define As2	135; // 116.54 Hz 
`define B2	127; // 123.47 Hz 
`define C3	120; // 130.815 Hz 
`define Cs3	114; // 138.59 Hz 
`define D3	107; // 146.83 Hz 
`define Ds3	101; // 155.565 Hz 
`define E3	95; // 164.815 Hz 
`define F3	90; // 174.615 Hz 
`define Fs3	85; // 184.995 Hz 
`define G3	80; // 196.0 Hz 
`define Gs3	76; // 207.65 Hz 
`define A3	72; // 220.0 Hz 
`define As3	68; // 233.08 Hz 
`define B3	64; // 246.94 Hz 
`define C4	60; // 261.63 Hz 
`define Cs4	57; // 277.18 Hz 
`define D4	54; // 293.66 Hz 
`define Ds4	51; // 311.13 Hz 
`define E4	48; // 329.63 Hz 
`define F4	45; // 349.23 Hz 
`define Fs4	43; // 369.99 Hz 
`define G4	40; // 392.0 Hz 
`define Gs4	38; // 415.3 Hz 
`define A4	36; // 440.0 Hz 
`define As4	34; // 466.16 Hz 
`define B4	32; // 493.88 Hz 
`define C5	30; // 523.26 Hz 
`define Cs5	28; // 554.36 Hz 
`define D5	27; // 587.32 Hz 
`define Ds5	25; // 622.26 Hz 
`define E5	24; // 659.26 Hz 
`define F5	23; // 698.46 Hz 
`define Fs5	21; // 739.98 Hz 
`define G5	20; // 784.0 Hz 
`define Gs5	19; // 830.6 Hz 
`define A5	18; // 880.0 Hz 
`define As5	17; // 932.32 Hz 
`define B5	16; // 987.76 Hz 

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
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire audio;

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
  wire signed [9:0] p_y = y - center_y + (beats_1_3 & part==6)*(envelopeB>>1)
                                       + (beats_1_3 & part==1)*(16-envelopeB>>1);

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

      // repeating circle for title
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

  // (x^2 + y^2)*(128-frame) / 512 // >> (9+frame[6:5]);
  // (x^2 + y^2)*(128-frame) / 1024
  // (x^2 + y^2)*(128-frame) / 2048
  // (x^2 + y^2)*(128-frame) / 4096

  // x*x*(128-frame)/f + y*y*(128-frame)/f
  // (x+1)*(x+1)*(128-frame)/f
  // x^2*(128-frame)/f + 2*x*(128-frame)/f + (128-frame)/f

  // wire signed [22:0] dot = ((p_x * p_x + p_y * p_y*2) * (128-frame)) >> (9+frame[6:5]);
  // wire signed [22:0] dot = (r * (128-frame)) >> (9+frame[6:5]);
  wire signed [22:0] dot = (r * (128-frame)) >> (9+((frame[6:4]+1)>>1) );  // zoom on snare
  // wire signed [22:0] dot = (r * (128-frame)) >> (9+(frame[6:4]-(~frame[4])));  // zoom on snare
  wire [7:0] pp_x = dot;
  wire [7:0] pp_y = dot;

  wire zoom_mode = part == 5 | part == 6; ////(frame_counter[7] & frame_counter[8]);
  // wire signed [22:0] dot2 = ((pp_x * pp_x * 8) * frame) >> (18 - 2*zoom_mode);
  wire signed [22:0] dot2 = ((pp_x * pp_x) * frame) >> (15 - 2*zoom_mode);
  wire [7:0] ppp_x = dot2;

  // A: enables drop with different angle, otherwise tunnel
  wire mode_a = part == 0 | part == 1 | part == 2 | part == 5;//frame_counter[8];
  // B: enables drop and starting close
  wire mode_b = part == 0 | part == 4;//frame_counter[7]^frame_counter[8];
  wire [7:0] p_p =          p_y*mode_a - p_x/2*mode_a +
                            p_y*(frame[7:5]+1'd1)*mode_b - p_x*(frame[6:5]+1'd1)*mode_b;

  wire fractal_mode = part == 1 | part == 6;//frame_counter[8:7] == 2;
  wire [7:0] ppp_y = fractal_mode? 
                      -(y & 8'h7f & p_x) + (r>>11):
                        dot2 + p_p;

  // generate title pixels
  // wire ringR = y[9:7] == 3'b010 & |x[9:7] & (x[6:0] < title_r_pixels_in_scanline) &
  //     ~(y > 256+70 & y < 256+128 & (x >= 256 & x < 256+64));
  // wire ringL = y[9:7] == 3'b010 & x[9:7] == 3'b010 & (~x[6:0] < title_r_pixels_in_scanline);
  // // .DDRR.OPP. => column on every odd 64 pixel sections except 0, 5 and 8th
  // // 012345678 
  // wire columns = y > 256+4 & y < 256+124 & x[6] & x[8:6] != 5 & ~x[9];
  // wire tails = y > 256+64 & y < 256+128+16 & x >= 256+256-64 & x < 256+256;

  wire ringR = y[9:7] == 3'b010 & |x[9:7] & (x[6:0] < title_r_pixels_in_scanline) &
      ~(y[6] & (x[9:7] == 2));
  wire ringL = y[9:7] == 3'b010 & x[9:7] == 3'b010 & (~x[6:0] < title_r_pixels_in_scanline);
  // column on every odd 64 pixel sections except 0, 5 and 8th:
  //    .DDRR.OPP.
  //    012345678 
  wire columns = x[6] & x[8:6] != 5 & ~x[9] & (y[9:7] == 2 | y[9:7] == 3) & y[7:0] > 4 & (y[7:0] < 124 | x[8]);
  wire title = ringR | ringL | columns;
  

  // 0: title + wakes
  // 1: fractal red/golden
  // 2: drop zoom 1
  // 3: tunnel
  // 4: red wakes
  // 5: drop zoom 2 (2 zoom beats)
  // 6: fractal multi-color
  // 7: title+tunnel

wire [2:0] part = frame_counter[9-:3];
  assign {R,G,B} =
    (~video_active) ? 6'b00_00_00 :
    (part == 0) ? { &ppp_y[5:3] | title ? 6'b111_111 : 6'b0 } :                     // title + wakes
    (part == 1) ? { &ppp_y[5:2] * ppp_y[1-:2], &ppp_y[6:0] * ppp_y[1-:2], 2'b00 } : // red/golden serpinsky
    (part == 3) ? { |ppp_y[7:6] ? {4'b11_00, dot[6:5]} : ppp_y[5:4] } :             // tunnel
    (part == 4) ? { &ppp_y[6:4] * 6'b110000 | &ppp_y[6:3]*dot[7]*6'b000010 } :      // red wakes
    (part == 6) ? { ppp_y[7-:2], ppp_y[6-:2], ppp_y[5-:2] } :                       // multi-color serpinsky
    (part == 7) ? { |ppp_y[7:6] ? {4'b11_00, dot[6:5]} : ppp_y[5:4] } |
                  // { 6{title} } :                                    // title + tunnel
                  { 6{title & (frame_counter[6:0] >= 96) }  } :                                    // title + tunnel
                  // { ppp_x[7-:2] + ppp_y[5-:2], ppp_y[5-:2], ppp_y[3-:2] };
                  // { ppp_y[6-:2], ppp_y[6-:2], ppp_y[6-:2] } | {&ppp_x[7:6],&ppp_x[7:6],~ppp_x[7:6]};
                  { ppp_y[7-:2], ppp_y[7-:2], ppp_y[7-:2] } | {4'b0,~ppp_x[6-:2]};

    // // (part == 2) ? { (&ppp_y[5:2]) * ppp_y[1-:2], 1'b0, &ppp_y[5:3] * ppp_y[0], 2'b00 } : // red/golden serpinsky
    // // (part == 2) ? { (&ppp_y[5:2]) * ppp_y[1-:2], (&ppp_y[5:2]) * ppp_y[0], 3'b000 } : // red/golden serpinsky
    // part == 2 ? { &ppp_y[5:2] * ppp_y[1-:2], &ppp_y[6:0] * ppp_y[1-:2], 2'b00 }: // red/golden serpinsky
    // (part == 6) ? { ppp_y[7-:2], ppp_y[6-:2], ppp_y[5-:2] } :     // colored serpinsky
    // (part == 1) ? { &ppp_y[6:4] * 6'b110000 | &ppp_y[6:3]*dot[7]*6'b000010 } : // red lines
    // (part == 0) ? { |ppp_y[7:6] ? {4'b11_00, dot[6:5]} : ppp_y[5:4] } : //+6'b110001
    // // //               // 4'b1000 * (ppp_y > 200), ppp_y[6:5] };
    // (part == 5) ? { &ppp_y[5:2] | ringR | ringL | columns ? 6'b111_111 : 6'b0 } : 
    //             // { ppp_x[7-:2] + ppp_y[5-:2], ppp_y[5-:2], ppp_y[3-:2] };
    //             { ppp_x[7-:2] + ppp_y[5-:2], ppp_y[5-:2], ppp_y[3-:2] };



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

  // music
  wire [12:0] timer = {frame_counter, frame_counter_frac};
  reg noise, noise_src = ^r1;
  reg [2:0] noise_counter;

  wire square60hz =  y < 262;                 // 60Hz square wave
  wire square120hz = y[7];                    // 120Hz square wave
  wire square240hz = y[6];                    // 240Hz square wave
  wire square480hz = y[5];                    // 480Hz square wave
  wire [4:0] envelopeA = 5'd31 - timer[4:0];  // exp(t*-10) decays to 0 approximately in 32 frames  [255 215 181 153 129 109  92  77  65  55  46  39  33  28  23  20  16  14 12  10   8   7   6   5   4   3   3   2   2]
  wire [4:0] envelopeB = 5'd31 - timer[3:0]*2;// exp(t*-20) decays to 0 approximately in 16 frames  [255 181 129  92  65  46  33  23  16  12   8   6   4   3]
  wire       envelopeP8 = (|timer[3:2])*5'd31;// pulse for 8 frames
  wire beats_1_3 = timer[5:4] == 2'b10;

  // melody notes (in hsync): 151  26  40  60 _ 90 143  23  35
  // (x1.5 wrap-around progression)
  reg [8:0] note2_freq;
  reg [8:0] note2_counter;
  reg       note2;

  reg [7:0] note_freq;
  reg [7:0] note_counter;
  reg       note;
  wire [3:0] note_in = timer[7-:4];           // 8 notes, 32 frames per note each. 256 frames total, ~4 seconds
  always @(note_in)
  case(note_in)
      4'd0 : note_freq = `E2
      4'd1 : note_freq = `E3
      4'd2 : note_freq = `D3
      4'd3 : note_freq = `E3
      4'd4 : note_freq = `A2
      4'd5 : note_freq = `B2
      4'd6 : note_freq = `D3
      4'd7 : note_freq = `E3
      4'd8 : note_freq = `E2
      4'd9 : note_freq = `E3
      4'd10: note_freq = `D3
      4'd11: note_freq = `E3
      4'd12: note_freq = `G2
      4'd13: note_freq = `E3
      4'd14: note_freq = `Fs2
      4'd15: note_freq = `E3
  endcase

  wire [2:0] note2_in = timer[8-:3];           // 8 notes, 32 frames per note each. 256 frames total, ~4 seconds
  always @(note2_in)
  case(note2_in)
      3'd0 : note2_freq = `B1
      3'd1 : note2_freq = `A2
      3'd2 : note2_freq = `E1
      3'd3 : note2_freq = `A2
      3'd4 : note2_freq = `B1
      3'd5 : note2_freq = `A2
      3'd6 : note2_freq = `D1
      3'd7 : note2_freq = `Cs1
  endcase

  // wire kick   = square60hz & (~|x[7:5] & x[4:0] < envelopeA);                 // 60Hz square wave with half second envelope
  wire kick   = square60hz & (x < envelopeA*4);                 // 60Hz square wave with half second envelope
  wire snare  = noise      & (x >= 128 && x < 128+envelopeB*4);   // noise with half second envelope
  wire lead   = note       & (x >= 256 && x < 256+envelopeB*8);   // ROM square wave with quarter second envelope
  wire base   = note2      & (x >= 512 && x < ((beats_1_3)?(512+8*4):(512+32*4)));  
  assign audio = { kick | (snare & beats_1_3 & part != 0) | (base) | (lead & part > 2) };


  reg [7:0] VIDEO_OUT;
  reg [7:0] AUDIO_OUT;


  reg [11:0] frame_counter;
  reg frame_counter_frac;
  always @(posedge clk) begin
    if (~rst_n) begin
      frame_counter <= 0;
      frame_counter_frac <= 0;
      noise_counter <= 0;
      note_counter <= 0;
      note2_counter <= 0;
      noise <= 0;
      note <= 0;
      note2 <= 0;

      VIDEO_OUT <= 0;
      AUDIO_OUT <= 0;


    end else begin

      VIDEO_OUT <= {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
      AUDIO_OUT <= {8{audio}};
      
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
        end else begin
          note_counter <= note_counter + 1'b1;
        end

        if (note2_counter > note2_freq) begin
          note2_counter <= 0;
          note2 <= ~note2;
        end else begin
          note2_counter <= note2_counter + 1'b1;
        end
      end
    end
  end
  

  // TinyVGA PMOD
  assign uo_out = VIDEO_OUT;//{hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  // assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  // TinyAudio PMOD
  assign uio_out = AUDIO_OUT;//{8{audio}};
  // assign uio_out = {8{audio}};

endmodule
