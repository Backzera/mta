//
// rounded.fx — retângulo arredondado com AA, borda, brilho externo e gradiente (ps_2_0).
// Desenhado com dxDrawImage(x - glow, y - glow, w + 2*glow, h + 2*glow, shader, 0, 0, 0, tint)
//
float2 sSize = float2(100, 100);        // tamanho total do quad (incluindo o brilho)
float  sRadius = 8;
float  sBorder = 0;
float  sGlow = 0;                       // px de brilho externo
float  sGlowK = 1;                      // 3 / sGlow (calculado no Lua)
float  sShine = 0;
float  sGradientOn = 0;                 // 0 ou 1
float  sGradientX = 0;                  // 0 vertical, 1 horizontal, 0.5 diagonal
float4 sColor = float4(1, 1, 1, 1);
float4 sColor2 = float4(1, 1, 1, 1);
float4 sBorderColor = float4(1, 1, 1, 0);
float4 sGlowColor = float4(0, 0, 0, 0);

struct PSInput
{
    float4 Diffuse  : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    float2 inner = sSize - sGlow * 2;
    float2 c = PS.TexCoord * sSize - sGlow - inner * 0.5;
    float2 q = abs(c) - (inner * 0.5 - sRadius);
    float d = length(max(q, 0)) + min(max(q.x, q.y), 0) - sRadius;

    float fill = saturate(0.5 - d);
    float innerFill = saturate(0.5 - d - sBorder);

    float t = lerp(PS.TexCoord.y, PS.TexCoord.x, sGradientX) * sGradientOn;
    float4 base = lerp(sColor, sColor2, t);
    base.rgb += sShine * (1 - PS.TexCoord.y) * 0.25;

    float fillA = innerFill * base.a;
    float borderA = saturate(fill - innerFill) * sBorderColor.a;
    float glowA = exp(-max(d, 0) * sGlowK) * (1 - fill) * sGlowColor.a;

    float total = fillA + borderA + glowA;
    float3 rgb = (base.rgb * fillA + sBorderColor.rgb * borderA + sGlowColor.rgb * glowA) / max(total, 0.001);
    return float4(rgb, saturate(total)) * PS.Diffuse;
}

technique rounded
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
