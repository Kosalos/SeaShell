#ifndef Shader_h
#define Shader_h
#include <simd/simd.h>
#include <simd/base.h>

struct TVertex {
    simd_float3 pos;
    simd_float3 nrm;
    simd_float2 txt;
};

struct Control {
    matrix_float4x4 mvp;
    simd_float3 light;
    float alpha;
    int tCount;
};

#endif /* Shader_h */
