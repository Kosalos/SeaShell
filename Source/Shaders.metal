#include <metal_stdlib>
#include <simd/simd.h>
#import "Shader.h"

using namespace metal;

struct Transfer {
    float4 position [[position]];
    float2 txt;
    float4 lighting;
    float alpha;
};

vertex Transfer texturedVertexShader
(
 device TVertex* vData [[ buffer(0) ]],
 constant Control& control [[ buffer(1) ]],
 unsigned int vid [[ vertex_id ]])
{
    Transfer out;
    TVertex v = vData[vid];
    
    out.txt = v.txt;
    out.position = control.mvp * float4(v.pos, 1.0);
    
    float intensity = 0.2 + saturate(dot(vData[vid].nrm.rgb, control.light));
    out.lighting = float4(intensity,intensity,intensity,1);
    
    out.alpha = control.alpha;
    
    return out;
}

fragment float4 texturedFragmentShader
(
 Transfer data [[stage_in]],
 texture2d<float> tex2D [[texture(0)]],
 sampler sampler2D [[sampler(0)]])
{
    return tex2D.sample(sampler2D, data.txt.xy) * data.lighting * float4(1,1,1,data.alpha);
}
