vec2 sine(float freq, float vol, float time) {
  return vec2(vol * sin(6.2831*freq*time));
}
vec2 pulse(float freq, float vol, float time) {
  return vec2((sin(6.2831*freq*time) > 0. ? vol : -vol));
}
vec2 tri(float freq, float vol, float time) {
  return vec2(vol * mod(freq*time, 1.));
}
vec2 saw(float freq, float vol, float time) {
  float a = mod(freq*time*2., 2.);
  float v = fract(freq*time);
  return vec2(vol * clamp((a < 1. ? v : (1.-v))*2.-1., -vol, vol));
  // float a = mod(freq*time*2., 2.);
  // return vec2(vol*4. * (a <= 1. ? a : 2.-a));
}
vec2 wave(float freq, float vol, float time) {
  return sine(freq, vol, time);
  // return saw(freq, vol*2., time);
  // return tri(freq, vol, time);
  // return pulse(freq, vol, time);
}
vec2 saw_w(float freq, float vol, float w, float time) {
  float a = mod(freq*time*2., 2.);
  float v = fract(freq*time) * (1.+w*0.1);//(1.+ 1./(w+1e-6));
  return vec2(vol * clamp((a < 1. ? v : (1.-v))*2.-1., -vol, vol));
}

vec2 pulse_w(float freq, float vol, float w, float time) {
  return vec2((sin(6.2831*freq*time) > asin(w) ? vol : -vol));
}

float p_env(float t) {
  return exp(-10.*t);
}

vec2 p_sine(float freq, float vol, float t) {
  return sine(freq,vol*p_env(t),t);
}
vec2 p_pulse(float freq, float vol, float t) {
  return pulse(freq,vol*p_env(t),t);
}
vec2 p_tri(float freq, float vol, float t) {
  return tri(freq,vol*p_env(t),t);
}
vec2 p_saw(float freq, float vol, float t) {
  return saw(freq,vol*p_env(t),t);
}

float b_env(float t) {
  return exp(-20.*t);
}
float b_freq(float freq, float t) {
  return freq*exp(-10.*t);
}

vec2 d_sine(float freq, float vol, float t)   { return sine(b_freq(freq,t), vol*b_env(t),t); }
vec2 d_pulse(float freq, float vol, float t)  { return pulse(b_freq(freq,t),vol*b_env(t),t); }
vec2 d_tri(float freq, float vol, float t)    { return tri(b_freq(freq,t),  vol*b_env(t),t); }
vec2 d_saw(float freq, float vol, float t)    { return saw(b_freq(freq,t),  vol*b_env(t),t); }

vec2 fx_noise(float vol, float t) { return vec2(mod(12349./(mod(t,.1)+1e-6),1.) * 2. * vol - vol); }
vec2 fx_noise2(float thr, float vol, float t) { return vec2(mod(12349./(mod(t,.1)+1e-6),1.) < thr ? vol : -vol); }
vec2 fx_sweep(float t) { return vec2(mod(12349./t,1.)); }


float R_lin(float f, float t) {return max(min(1.-t/f, 1.),0.); }

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
  float seqn = fract(floor(.5+.5*(1.-tseq)) * 0.8972);
  // float seqn = fract(floor(tseq) * 19871.8972);
  float n = 20.0 + floor(seqn * 38.0);  //50.0 + floor(time * 2.0);
  
  
  // n += sin(tseq*100.)*.0025;
  float base = 440.0 * pow(2.0, (n - 69.0) / 12.0); // ntof
  
  
  vec2 v = vec2(0.0);
  for(int i = 0; i < 1; i ++)
  {
    float h = float(i + 3);
    //v += sin(pi2 * t * base * h);
    // v += clamp(sine(base*h, 1., t)*1., -1.,1.);
    //v += saw(base*h, 1., t);
    v += saw_w(base*h, .5, time*10., t);
    //v += tri(base*h, 1., t);
    // v += pulse(base*h, .25, t);
    // v += pulse_w(base*h, .25, sin(fract(time*2.)), t);
  }
  
  
  
  
  // return vec2(clamp(v*1., -1.0, 1.0)); 
  // return vec2(clamp(v * amps * 4., -1.0, 1.0)); 
  return vec2(v*amps);
}










vec2 mainSound(float time){
  //return fx_noise2(.1, 1., time);
  //return fx_sweep(time);
  
  return _synth(time)*.33;
  
  int bar = int(time/2.);
  int b2th = int(time)%2;
  int b4th = int(time*2.)%4;
  int b8th = int(time*4.)%8;
  int b16th = int(time*8.)%16;
  float t = mod(time, 1.);
  float t60 = mod(time, 1.);
  float t120 = mod(time*2., 1.)/2.;
  float t240 = mod(time*4., 1.)/4.;
  float t480 = mod(time*8., 1.)/8.;
  vec2 master = vec2(0.);
  master += _synth(time)*.33;


  if (b4th == 0 || b4th == 2)
    master += pulse(80.,1.,t120) * exp(-10.*t120);
  if (b4th == 0 || b4th == 2)
    master += d_pulse(220.,2.,t120);
  if (b4th == 1 || b4th == 3)
    master += fx_noise(1.,t120)*exp(-10.*t120);
  // if (b16th >= 12 && b16th <= 15)
  // if (b8th == 0 || (b8th >= 5 && b8th <= 7))
  // if (b8th == 0 || b8th == 4)
  //   master += fx_noise(1.,t240)*exp(-5.*t240);
  if (b16th >= 12 && b16th <= 14)
    master += fx_noise(1.,t480)*exp(-5.*t480);





// 0---1---2---3---
// 0-1-2-3-4-5-6-7-
// 0123456789012345


  //   // master += fx_noise2(exp(-10.*t120), 2., t120)*exp(-20.*t120);
  //   // master += d_tri(880.,1.,t120);
  // if (bpm == 0 || bpm == 2)
  //   master += tri(220.,.25,t);
  // if (bpm == 1 || bpm == 3)
  //   master += tri(440.,.25,t);


  return master * .5;

  if (time < 1.)
    return d_sine(440.,1.,t);
  else if (time < 2.)
    return d_saw(440.,1.,t);
  else if (time < 3.)
    return d_tri(440.,1.,t);
  else if (time < 4.)
    return d_pulse(440.,1.,t);
  // piano
  else if (time < 5.)
    return p_sine(440.,1.,t);
  else if (time < 6.)
    return p_saw(440.,1.,t);
  else if (time < 7.)
    return p_tri(440.,1.,t);
  else if (time < 8.)
    return p_pulse(440.,1.,t);

  // return wave(440.,exp(-10.*time),time);//* ;
  // return wave(440.*exp(-10.*time),1.,time);// * exp(-10.*time);
  // return (wave(50.,1.,time) + wave(93.,1.,time) + wave(136.,1.,time) + wave(182.,1.,time) + wave(225.,1.,time)) * exp(-10.*time);
  return (wave(50.,1.,time) + wave(100.,1.,time) + wave(150.,1.,time) + wave(200.,1.,time) + wave(250.,1.,time)) * exp(-10.*time);
  
  // return (pulse(50.,1.,time)+pulse(100.,1.,time)+pulse(150.,1.,time)+pulse(200.,1.,time)) * exp(-10.*time);
    // vec2() + vec2(0.5*sin(6.2831*100.0*time))) * max(1.-time*5., 0.);
  // *exp(-3.*time));
  // return noise(10);
  // return vec2(sin(6.2831*440.*time)*exp(-3.*time));
}