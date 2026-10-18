// Troca de textura (skins de arma por jogador)
texture Tex0;
technique TexReplace
{
    pass P0
    {
        Texture[0] = Tex0;
    }
}
