/*
 * "Drop" ASIC audio/visual demo. No CPU, no GPU, no RAM!
 * Racing the beam and straight to VGA 640x480.
 * Entry to Tiny Tapeout Demoscene 2024 competition:
 *   https://tinytapeout.com/competitions/demoscene/
 *
 * Full version: https://github.com/rejunity/tt08-vga-drop
 * VGA video recording: https://youtu.be/jJBU0J2ceMM
 * Live recording from FPGA: https://youtu.be/rCupc2soGqo
 *
 * Copyright (c) 2024 Renaldas Zioma, Erik Hemming and Matthias Kampa
 * Code is based on the VGA examples by Uri Shaked
 * Inspired by "Memories" 256b demo by Desire
 * SPDX-License-Identifier: Apache-2.0
 */

// Shortened variable names: hsync -> hs, vsync -> vs, active -> actv, frame_counter -> fc, etc.
// ChatGPT:
// Remove all unnecessary spaces from code:

`define S reg signed
`define WS wire signed
`define W wire
`define A assign
`define B begin
`define E end
`define L else

module tt_um_vga_example(
  input  `W clk,
  input  `W rst_n,
  output `W[7:0] uo_out
);

  `W hs, vs, actv;
  `W[1:0] R, G, B;
  `A uo_out = {hs, B[0], G[0], R[0], vs, B[1], G[1], R[1]};

  `W[9:0] x, y;
  hvsync_generator hvg(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hs),
    .vsync(vs),
    .display_on(actv),
    .hpos(x),
    .vpos(y)
  );


  `W b13 = fc[4:3] == 2'b10;
  `W[4:0] envB = 5'd31 - fc[2:0]*4;

  `WS[9:0] frm =  fc[6:0],
                  ox = frm/2,
                  oy = frm,
                  cx = 320 + ox,
                  cy = 240 + oy,
                  px = x - cx,
                  py = y - cy + (b13 & prt == 6)*(envB>>1) + (b13 & prt == 1)*(16-envB>>1);

  `S[18:0] r1, r2;
  `WS[19:0] r = 2*(r1 - cy*2) + r2 - cx*2 + 2;

  `S [13:0] tr;
  reg [5:0] tr_cnt;

  always @(posedge clk) `B
    if (~rst_n) `B
      r1 <= 0;
      r2 <= 0;
      tr <= 0;
    `E `L `B
      if (vs) `B
        r1 <= 0;
        r2 <= 0;
      `E

      if (actv & y == 0) `B
        if (x < cy)
          r1 <= r1 + cy;
      `E `L if (x == 640) `B
        r2 <= 320*320;
      `E `L if (x > 640) `B
        if (x-640 <= ox)
          r2 <= r2 + 2*320 + ox;
      `E `L if (actv & x == 0) `B
        r1 <= r1 + 2*py + 1;
      `E `L if (actv) `B
        r2 <= r2 + 2*px + 1;
      `E

      if (!actv & y[6:0] == 0) `B
        tr <= 64*64+64*64;
      `E `L if (x == 640) `B
        tr <= tr + 2*(y[6:0]-64)+1 - 64*2;
        tr_cnt <= 0;
      `E `L if (x > 640 && x < 640+128) `B
        tr <= tr + 2*(x[6:0]-64)+1;
        if (x > 640+64 & tr < 60*60)
          tr_cnt <= tr_cnt + 1;
      `E
    `E
  `E

  `WS[22:0] dot = (r * (128-frm)) >> (9+((frm[6:4]+1)>>1) );

  `W zm_mode = prt == 5 | prt == 6;
  `WS[22:0] dot2 = ((dot[7:0] * dot[7:0]) * frm) >> (15 - 2*zm_mode);

  `W a = prt == 0 | prt == 1 | prt == 2 | prt == 5;
  `W b = prt == 0 | prt == 4;
  `W[7:0] p_p = py*a - px/2*a + py*(frm[7:5]+1'd1)*b - px*(frm[6:5]+1'd1)*b;

  `W[7:0] o = (prt == 1 | prt == 6) ? -(y & 8'h7f & px) + (r>>11) : dot2 + p_p;

  `W tR = y[9:7] == 3'b010 & |x[9:7] & (x[6:0] < tr_cnt) & ~(y[6] & (x[9:7] == 2));
  `W tL = y[9:7] == 3'b010 & x[9:7] == 3'b010 & (~x[6:0] < tr_cnt);
  `W cols = x[6] & x[8:6] != 5 & ~x[9] & (y[9:7] == 2 | y[9:7] == 3) & y[7:0] > 4 & (y[7:0] < 124 | x[8]);
  `W t = tR | tL | cols;

  `W[2:0] prt = fc[9-:3];
  `A {R,G,B} =
    (~actv) ? 6'b00_00_00 :
    (prt == 0) ? { &o[5:3] | t ? 6'b111_111 : 6'b0 } :
    (prt == 1) ? { &o[5:2] * o[1-:2], &o[6:0] * o[1-:2], 2'b00 } :
    (prt == 3) ? { |o[7:6] ? {4'b11_00, dot[6:5]} : o[5:4] } :
    (prt == 4) ? { &o[6:4] * 6'b110000 | &o[6:3]*dot[7]*6'b000010 } :
    (prt == 6) ? { o[7-:2], o[6-:2], o[5-:2] } :
    (prt == 7) ? { |o[7:6] ? {4'b11_00, dot[6:5]} : o[5:4] } |
                { 6{t & (fc[6:0] >= 96) } } :
                { o[7-:2], o[7-:2], o[7-:2] } | {4'b0,~dot2[6-:2]};

  reg [11:0] fc;
  always @(posedge clk) `B
    if (~rst_n) `B
      fc <= 0;
    `E `L `B
      if (x == 0 && y == 0) `B
        fc <= fc + 1;
      `E
    `E
  `E

endmodule
