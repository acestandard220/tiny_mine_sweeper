#version 330 core
out vec4 fragColor;

in vec3 color;
in vec2 Tex;

uniform sampler2D font_texture;

void main()
{
    fragColor = vec4(color,1.0f);
}