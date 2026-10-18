//
// rounded.fx — retângulo arredondado com anti-aliasing, borda, brilho externo e gradiente.
// Desenhado com dxDrawImage(x - glow, y - glow, w + 2*glow, h + 2*glow, shader, 0, 0, 0, tint)
//
float2 sSize = float2(100, 100);        // tamanho total do quad (incluindo o brilho)
float  sRadius = 8;
float  sBorder = 0;
float  sGlow = 0;
float  sShine = 0;                      // reflexo claro no topo (0..1)
int    sGradient = 0;                   // 0 nenhum, 1 vertical, 2 horizontal, 3 diagonal
float4 sColor = float4(1, 1, 1, 1);
float4 sColor2 = float4(1, 1, 1, 1);
float4 sBorderColor = float4(1, 1, 1, 0.1);
float4 sGlowColor = float4(0.13, 0.9, 0.54, 0.5);

struct PSInput
{
    float4 Diffuse  : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    float2 p = PS.TexCoord * sSize;
    float2 inner = sSize - sGlow * 2;
    float2 c = p - sGlow - inner * 0.5;
    float r = min(sRadius, min(inner.x, inner.y) * 0.5);
    float2 q = abs(c) - (inner * 0.5 - r);
    float d = length(max(q, 0)) + min(max(q.x, q.y), 0) - r;

    float fill = 1 - smoothstep(-0.75, 0.75, d);
    float innerFill = 1 - smoothstep(-0.75, 0.75, d + sBorder);

    float t = (sGradient == 1) ? PS.TexCoord.y : ((sGradient == 2) ? PS.TexCoord.x : (PS.TexCoord.x + PS.TexCoord.y) * 0.5);
    float4 base = (sGradient > 0) ? lerp(sColor, sColor2, t) : sColor;
    base.rgb += sShine * (1 - PS.TexCoord.y) * 0.25;

    float fillA = innerFill * base.a;
    float borderA = saturate(fill - innerFill) * sBorderColor.a;
    float glowA = (sGlow > 0) ? exp(-max(d, 0) / max(sGlow, 0.001) * 3) * (1 - fill) * sGlowColor.a : 0;

    float total = fillA + borderA + glowA;
    float3 rgb = (base.rgb * fillA + sBorderColor.rgb * borderA + sGlowColor.rgb * glowA) / max(total, 0.0001);
    float4 outc = float4(rgb, saturate(total));
    return outc * PS.Diffuse;
}

technique high
{
    pass P0
    {
        AlphaBlendEnable = TRUE;
        SrcBlend = SRCALPHA;
        DestBlend = INVSRCALPHA;
        PixelShader = compile ps_3_0 PixelShaderFunction();
    }
}

technique low
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
