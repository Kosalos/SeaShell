#ifndef Shader_h
#define Shader_h
#include <simd/simd.h>
#include <simd/base.h>

struct TVertex {
    vector_float3 pos;
    vector_float3 nrm;
    vector_float2 txt;
};

struct Control {
    matrix_float4x4 mvp;
    vector_float3 light;
    float alpha;
    int tCount;
};

#endif /* Shader_h */
