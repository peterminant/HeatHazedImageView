#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    packed_float2 position;
    packed_float2 texCoord;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float time;
    float speed;
    float distortion;
    float evaporation;
};

vertex VertexOut vertex_shader(const device VertexIn* vertex_array [[ buffer(0) ]],
                               unsigned int vid                    [[ vertex_id ]]) {

    VertexIn in = vertex_array[vid];
    VertexOut out;
    out.position = float4(in.position, 0, 1);
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 fragment_shader(VertexOut in                [[ stage_in ]],
                                constant Uniforms& uniforms [[ buffer(0) ]],
                                texture2d<float> sourceTex  [[ texture(0) ]],
                                texture2d<float> noiseTex   [[ texture(1) ]],
                                sampler sourceSampler       [[ sampler(0) ]],
                                sampler noiseSampler        [[ sampler(1) ]]) {
    
    float2 offsetCoord = in.texCoord;
    offsetCoord.y += uniforms.time * uniforms.speed;
    float2 offset = noiseTex.sample(noiseSampler, offsetCoord).xy;
    offset -= float2(0.5, 0.5);
    offset *= 2.0;
    offset *= uniforms.distortion;
    if (uniforms.evaporation > 0) {
        offset *= clamp(1.0 - ((1.0 - in.texCoord.y) * uniforms.evaporation), 0.0, 1.0);
    }
    return sourceTex.sample(sourceSampler, in.texCoord + offset);
}
