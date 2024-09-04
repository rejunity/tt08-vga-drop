#define pi2 6.283185307179586476925286766559
// tb303 core
vec2 _synth(float time)
{
  float t = time;
  //float tseq = mod(time * 9.0, 16.0);
  float tseq = mod(time * 4.0, 16.0);
  float tnote = fract(tseq);
  float dr = 0.26;
  float amp = exp((tnote-dr) * -10.0)*.5;
  float amp2 = exp((tnote-dr) * -1.0);
  float amp3 = exp(tnote * -0.25)*.1;
  // float amps = exp((tnote-.1) * -2.0)*3.;
  float amps = (amp+amp2+amp3) * 2.;
  // clamp(2.5-tnote*5.,0.25,1.)*4.;
  // float seqn = fract(sin(floor(tseq) * 110.082) * 19871.8972);
  float seqn = fract(floor(.5+.5*(1.-tseq)) * 0.18972);
  
  
  // float seqn = fract(floor(tseq) * 19871.8972);
  float n = 20.0 + floor(seqn * 38.0);  //50.0 + floor(time * 2.0);
  
  // n += sin(tseq*100.)*.0025;
  float base = 440.0 * pow(2.0, (n - 69.0) / 12.0); // ntof
  
  float h = 4.;
  float v = sin(pi2 * t * base * h) < 0.0 ? -.2 : .2;
  return vec2(v*amps);
}


vec2 sine(float freq, float vol, float time) {
  return vec2(vol * sin(6.2831*freq*time));
}
vec2 pulse(float freq, float vol, float time) {
  return vec2((sin(6.2831*freq*time) > 0. ? vol : -vol));
}
vec2 tri(float freq, float vol, float time) {
  return vec2(vol * mod(freq*time, 1.));
}
float b_env(float t) {
  return exp(-20.*t);
}
float b_freq(float freq, float t) {
  return freq*exp(-10.*t);
}
vec2 d_pulse(float freq, float vol, float t)  {return pulse(b_freq(freq,t),vol*b_env(t),t); }
vec2 fx_noise(float vol, float t) { return vec2(mod(12349./(mod(t,.1)+1e-6),1.) * 2. * vol - vol); }

vec2 mainSound(float time){
  //return _synth(time)*.33;
  
  int bar = int(time/2.);
  int b2th = int(time)%2;
  int b4th = int(time*2.)%4;
  int b8th = int(time*4.)%8;
  int b16th = int(time*8.)%16;
  float t = mod(time, 1.);
  float t60 = mod(time, 1.);
  
  float time_ = floor(time*60.)/60.;
  float t120_ = mod(time_*2., 1.)/2.;
  float t240_ = mod(time*4., 1.)/4.;
  float t480_ = mod(time_*8., 1.)/8.;
  float t120 = mod(time*2., 1.)/2.;
  float t240 = mod(time*4., 1.)/4.;
  float t480 = mod(time*8., 1.)/8.;
  vec2 master = vec2(0.);
  master += _synth(time)*.33;

  float envA = exp(-10.*t120_);
  float envB = exp(-20.*t120_);
  float envC = exp(-20.*t480_);


  if (b4th == 0 || b4th == 2)
  // if (b4th == 0 || b4th == 2 || b4th == 1|| b4th == 3)
    master += pulse(60.,1.,t120) * envA;
  // if (b4th == 0 || b4th == 2)
  if (b4th == 0 || b4th == 2 || b4th == 1 || b4th == 3)
    // master += pulse(220.,1.,t120) * exp(-10.*t120);
    // master += d_pulse(220.,2.,t120);
    master += pulse(220.*envA, envA, t120);
  if (b4th == 1 || b4th == 3)
    master += fx_noise(1.,t120)*envB;
  // if (b16th >= 11 && b16th <= 13)
  //   master += fx_noise(1.,t480)*envC;
  // if (b16th >= 4 && b16th <= 14 && b16th%2==1)
  //   master += fx_noise(1.,t480)*envC;




  return master;
}


/*
#define pi2 6.283185307179586476925286766559
// tb303 core
vec2 _synth(float time)
{
  float t = time;
  //float tseq = mod(time * 9.0, 16.0);
  float tseq = mod(time * 4.0, 16.0);
  float tnote = fract(tseq);
  float dr = 0.26;
  float amp = exp((tnote-dr) * -10.0)*.5;
  float amp2 = exp((tnote-dr) * -1.0);
  float amp3 = exp(tnote * -0.25)*.1;
  // float amps = exp((tnote-.1) * -2.0)*3.;
  float amps = (amp+amp2+amp3) * 2.;
  // clamp(2.5-tnote*5.,0.25,1.)*4.;
  // float seqn = fract(sin(floor(tseq) * 110.082) * 19871.8972);
  float seqn = fract(floor(.5+.5*(1.-tseq)) * 0.18972);
  
  
  // float seqn = fract(floor(tseq) * 19871.8972);
  float n = 20.0 + floor(seqn * 38.0);  //50.0 + floor(time * 2.0);
  
  // n += sin(tseq*100.)*.0025;
  float base = 440.0 * pow(2.0, (n - 69.0) / 12.0); // ntof
  
  float h = 4.;
  float v = sin(pi2 * t * base * h) < 0.0 ? -.2 : .2;
  return vec2(v*amps);
}


vec2 sine(float freq, float vol, float time) {
  return vec2(vol * sin(6.2831*freq*time));
}
vec2 pulse(float freq, float vol, float time) {
  return vec2((sin(6.2831*freq*time) > 0. ? vol : -vol));
}
vec2 tri(float freq, float vol, float time) {
  return vec2(vol * mod(freq*time, 1.));
}
float b_env(float t) {
  return exp(-20.*t);
}
float b_freq(float freq, float t) {
  return freq*exp(-10.*t);
}
vec2 d_pulse(float freq, float vol, float t)  {return pulse(b_freq(freq,t),vol*b_env(t),t); }
vec2 fx_noise(float vol, float t) { return vec2(mod(12349./(mod(t,.1)+1e-6),1.) * 2. * vol - vol); }

vec2 mainSound(float time){
  //return _synth(time)*.33;
  
  int bar = int(time/2.);
  int b2th = int(time)%2;
  int b4th = int(time*2.)%4;
  int b8th = int(time*4.)%8;
  int b16th = int(time*8.)%16;
  float t = mod(time, 1.);
  float t60 = mod(time, 1.);
  
  float time_ = floor(time*60.)/60.;
  float t120_ = mod(time_*2., 1.)/2.;
  float t240_ = mod(time*4., 1.)/4.;
  float t480_ = mod(time_*8., 1.)/8.;
  float t120 = mod(time*2., 1.)/2.;
  float t240 = mod(time*4., 1.)/4.;
  float t480 = mod(time*8., 1.)/8.;
  vec2 master = vec2(0.);
  master += _synth(time)*.33;

  float envA = exp(-10.*t120_);
  float envB = exp(-20.*t120_);
  float envC = exp(-20.*t480_);

  if (b4th == 0 || b4th == 2 || b4th == 1|| b4th == 3)
    master += pulse(60.,1.,t120) * envA;
  if (b4th == 0 || b4th == 2 || b4th == 1 || b4th == 3)
    // master += pulse(220.,1.,t120) * exp(-10.*t120);
    // master += d_pulse(220.,2.,t120);
    master += pulse(220.*envA, envA, t120);
  if (b4th == 1 || b4th == 3)
    master += fx_noise(1.,t120)*envB;
  // if (b16th >= 12 && b16th <= 14)
  //   master += fx_noise(1.,t480)*envC;
  if (b16th >= 4 && b16th <= 14 && b16th%2==1)
    master += fx_noise(1.,t480)*envC;


  return master;
}
*/