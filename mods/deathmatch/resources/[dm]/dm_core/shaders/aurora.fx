//
// aurora.fx — gradiente animado (fundo "vivo" de cabeçalhos, login e destaques).
//
float  sTime = 0;
float  sAlpha = 1;
float4 sColorA = float4(0.13, 0.90, 0.54, 1);
float4 sColorB = float4(0.47, 1.00, 0.70, 1);
float4 sColorC = float4(0.02, 0.04, 0.03, 1);

struct PSInput
{
    float4 Diffuse  : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    float2 uv = PS.TexCoord;
    float t = sTime;
    float w1 = sin(uv.x * 3.0 + t * 0.6) * 0.5 + 0.5;
    float w2 = sin(uv.y * 2.5 - t * 0.45 + uv.x * 1.5) * 0.5 + 0.5;
    float w3 = sin((uv.x + uv.y) * 2.0 + t * 0.3) * 0.5 + 0.5;
    float w4 = sin(uv.x * 5.0 - uv.y * 3.0 + t * 0.9) * 0.5 + 0.5;
    float4 col = sColorA * w1 + sColorB * w2 * 0.6 + sColorC * (w3 + 0.5);
    col /= (w1 + w2 * 0.6 + w3 + 0.5);
    col.rgb += w4 * w1 * 0.08;
    col.a = sAlpha * (0.55 + 0.45 * w3);
    return col * PS.Diffuse;
}

technique aurora
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
