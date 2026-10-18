//
// blur.fx — desfoque de 13 amostras sobre uma screen source (usado em 2 passagens).
//
texture sTex;
float2 sTexel = float2(0.002, 0.0037);
float  sStrength = 1.5;

sampler Sampler0 = sampler_state
{
    Texture = (sTex);
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

struct PSInput
{
    float4 Diffuse  : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    float2 uv = PS.TexCoord;
    float2 o = sTexel * sStrength;
    float4 c = tex2D(Sampler0, uv) * 0.16;
    c += tex2D(Sampler0, uv + float2( o.x, 0)) * 0.11;
    c += tex2D(Sampler0, uv + float2(-o.x, 0)) * 0.11;
    c += tex2D(Sampler0, uv + float2(0,  o.y)) * 0.11;
    c += tex2D(Sampler0, uv + float2(0, -o.y)) * 0.11;
    c += tex2D(Sampler0, uv + float2( o.x,  o.y)) * 0.07;
    c += tex2D(Sampler0, uv + float2(-o.x,  o.y)) * 0.07;
    c += tex2D(Sampler0, uv + float2( o.x, -o.y)) * 0.07;
    c += tex2D(Sampler0, uv + float2(-o.x, -o.y)) * 0.07;
    c += tex2D(Sampler0, uv + float2( 2 * o.x, 0)) * 0.03;
    c += tex2D(Sampler0, uv + float2(-2 * o.x, 0)) * 0.03;
    c += tex2D(Sampler0, uv + float2(0,  2 * o.y)) * 0.03;
    c += tex2D(Sampler0, uv + float2(0, -2 * o.y)) * 0.03;
    c.a = 1;
    return c * PS.Diffuse;
}

technique blur
{
    pass P0
    {
        AlphaBlendEnable = TRUE;
        SrcBlend = SRCALPHA;
        DestBlend = INVSRCALPHA;
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}

technique fallback
{
    pass P0
    {
    }
}
