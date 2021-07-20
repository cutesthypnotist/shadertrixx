#define PI 3.1415926535

mat2 rot( in float a ) {
    float c = cos(a);
    float s = sin(a);
	return mat2(c,s,-s,c);	
}

float drawLine(vec2 uv, vec2 p1, vec2 p2, float Thickness, float blur) {

  float a = abs(distance(p1, uv));
  float b = abs(distance(p2, uv));
  float c = abs(distance(p1, p2));
  
  float d = sqrt(c*c + Thickness*Thickness);

  if ( a >= d || b >= d )
  {
  	return smoothstep(Thickness, Thickness-blur, min(distance(p1, uv),distance(p2, uv)));
  }

  float p = (a + b + c) * 0.5;

  // median to (p1, p2) vector
  float h = 2.0 / c * sqrt( p * ( p - a) * ( p - b) * ( p - c));
  if(isnan(h) || isinf(h))
      h = -11111.;
  
  return smoothstep(Thickness, Thickness-blur, h);
}

float circle(vec2 uv, vec2 p, float r, float blur)
{
    return smoothstep(r, r-blur, length(uv - p));
}

float thumb(vec2 uv, vec2 p)
{
    uv -= p;
    uv *= rot(PI/14.);
    float a = drawLine(uv, vec2(0,0.1), vec2(0.65,0.1), 0.08, 0.01);
    float c = a;
    c += drawLine(uv, vec2(0,-0.04), vec2(0.35,-0.04), 0.08, 0.01);
    c += drawLine(uv, vec2(0,-0.18), vec2(0.3,-0.18), 0.075, 0.01);
    c += drawLine(uv, vec2(0,-0.30), vec2(0.2,-0.30), 0.07, 0.01);
    c += circle((uv * vec2(1.2,1)) + uv.y*0.1, vec2(0,-0.105), 0.3,0.01);
    vec2 q = vec2(0);
    uv*= rot(-PI/20.);
        uv.y -= 0.2;
    uv.x -= 0.01;
    q.x += uv.y*0.7;
    c += drawLine(uv, vec2(0,-0.105) + q, vec2(0,0.2), 0.10 - uv.y*0.1, 0.01);
    
    c = clamp(c, 0.,1.);
    return c;
}

vec4 head(vec2 uv, vec2 p, float scale)
{
    uv -= p;
    float c = circle(uv, vec2(0), .8, .01);
    vec4 col = mix(vec4(0), c*vec4(1,0.8,0.3,1.), c);
    c = circle(uv * vec2(1.3,1), vec2(0.35,0.2), .15, .01);
    c += circle(uv * vec2(1.3,1), vec2(-0.35,0.25), .15, .01);
    
    float d = 0.275-uv.x;
    d *= d;
    
    float a = drawLine(uv, vec2(0.1,0.35- d), vec2(0.45,0.35- d), 0.05, 0.01);
    c += a;
    
    d = -0.275-uv.x;
    d *= d;
    
    a = drawLine(uv, vec2(-0.1,0.55- d), vec2(-0.45,0.55- d), 0.05, 0.01);
    c += a;
    
     d = -0.1-uv.x;
    d *= d;
    
    a = drawLine(uv, vec2(-0.2,-0.2- d), vec2(0.2,-0.2- d), 0.05, 0.01);
    c += a;
    
    c = clamp(c, 0.,1.);

    col = mix(col, c*vec4(0.4,0.27,0,1.), c);
    
    c = thumb(uv, vec2(-0.5,-0.7));
    
    col = mix(col, c*vec4(0.95,0.6,0.05,1.), c);
    
    
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy;
    uv = -1. + 2.* uv;
    uv.x *= iResolution.x/iResolution.y;
    
    vec3 col = head(uv, vec2(0,0.15), 1.).rgb;

    fragColor = vec4(col,1.0);
}