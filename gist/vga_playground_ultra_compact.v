// "Drop" demo in just 7 tweets of #Verilog
// @tinytapeout #ASIC
// To run demo in the browser - copy paste tweets below into: https://tinytapeout.github.io/vga-playground
// Or use human readable source from: https://github.com/rejunity/tt08-vga-drop/blob/main/gist/vga_playground.v

module tt_um_vga_example(input `W clk,input `W rst_n,output `W[7:0] uo_out);

`W hs,vs,act;
`W[1:0] R,G,B;
`W[9:0] x,y;
hvsync_generator hvg(.clk(clk),.reset(~rst_n),.hsync(hs),.vsync(vs),.display_on(act),.hpos(x),.vpos(y));

`W b13=fc[4:3]==2;
`W[4:0] be=5'd31-fc[2:0]*4;

reg [18:0] r1,r2;
`W[19:0] r=2*(r1-cy*2)+r2-cx*2+2,
f=fc[6:0],ox=f/2,oy=f,cx=320+ox,cy=240+oy,px=x-cx,py=y-cy+(b13&p==6)*(be>>1)+(b13&p==1)*(16-be>>1);

reg [13:0] fc, tr;
reg [5:0] c;
always @(posedge clk) `B
  if(~rst_n) `B r1<=0;r2<=0;tr<=0;`E `L `B
    if(vs) `B r1<=0;r2<=0;`E
    if(act&y==0) `B if(x<cy)r1<=r1+cy;`E `L if(x==640) `B r2<=320*320;`E `L if(x>640) `B if(x-640<=ox)r2<=r2+640+ox;`E `L if(act&x==0) `B r1<=r1+2*py+1;`E `L if(act) `B r2<=r2+2*px+1;`E
    if(!act&y[6:0]==0) `B tr<=8192;`E `L if(x==640) `B tr<=tr+2*(y[6:0]-64)-127;c<=0;`E `L if(x>640&x<768) `B tr<=tr+2*(x[6:0]-64)+1;if(x>704&tr<3600)c<=c+1;`E
  `E
  if(~rst_n) `B fc<=0;`E `L `B if(x+y==0) `B fc<=fc+1;`E `E
`E

`W a=p==0|p==1|p==2|p==5,
b=p==0|p==4,
z=p==5|p==6;
`W[22:0] dot=(r*(128-f))>>(9+((f[6:4]+1)>>1)),
dot2=((dot[7:0]*dot[7:0])*f)>>(15-2*z);

`W[7:0] p_p=py*a-px/2*a+py*(f[7:5]+1'd1)*b-px*(f[6:5]+1'd1)*b,
o=(p==1|p==6)?-(y&8'h7f&px)+(r>>11):dot2+p_p;

`W tR=y[9:7]==2&|x[9:7]&(x[6:0]<c)&~(y[6]&(x[9:7]==2)),
tL=y[9:7]==2&x[9:7]==2&(~x[6:0]<c),
tc=x[6]&x[8:6]!=5&~x[9]&(y[9:7]==2|y[9:7]==3)&y[7:0]>4&(y[7:0]<124|x[8]),
t=tR|tL|tc;

`W[2:0] p=fc[9-:3];
assign {R,G,B}=(~act)?0:(p==0)?{&o[5:3]|t?63:0}:(p==1)?{&o[5:2]*o[1-:2],&o[6:0]*o[1-:2],2'b00}:(p==3)?{|o[7:6]?{4'b11_00,dot[6:5]}:o[5:4]}:(p==4)?{&o[6:4]*48|&o[6:3]*dot[7]*6'd2}:(p==6)?{o[7-:2],o[6-:2],o[5-:2]}:(p==7)?{|o[7:6]?{12,dot[6:5]}:o[5:4]}|{6{t&(fc[6:0]>=96)}}:{o[7-:2],o[7-:2],o[7-:2]}|{0,~dot2[6-:2]};
assign uo_out={hs,B[0],G[0],R[0],vs,B[1],G[1],R[1]};

endmodule
