//
// vignette.fx — escurecimento/cor nas bordas da tela (vida baixa, morte, foco).
//
float4 sColor = float4(0, 0, 0, 1);
float  sInner = 0.55;
float  sOuter = 1.35;

struct PSInput
{
    float4 Diffuse  : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    float2 uv = PS.TexCoord - 0.5;
    uv.x *= 1.25;
    float d = length(uv) * 2;
    float a = smoothstep(sInner, sOuter, d);
    return float4(sColor.rgb, sColor.a * a) * PS.Diffuse;
}

technique vignette
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
