package tiny

import "core:fmt"
import "core:math/rand"
import "core:os"
import "base:runtime"

import "vendor:glfw"
import gl "vendor:OpenGL"
import stb "vendor:stb/image"
import tt "vendor:stb/truetype"
import image "core:image/png"

/*
    TODO: Defer image_ptr destruction

    UI:
        Buttons
        Screen Startup
*/


log_error :: fmt.println
log_warning ::fmt.println
log_info :: fmt.println


window_width  :i32     =  800
window_height :i32     =  800
window_title  :cstring =  "tiny_sweeper"

window:glfw.WindowHandle

// TEXT_FILE :: "C:\\Windows\\Fonts\\Vodafon ExB Regular.ttf"
TEXT_FILE :: "C:\\Users\\User\\Downloads\\bitter-ht-full-pack\\BitterPro-Medium.ttf"
BOMB_FILE :: "bomb.png"



buttons : [100]Button

num_mines:int = 25
num_reaveled:= make(map[int]bool)



quad_vao:u32
quad_vbo:u32

text_texture:u32
text_vbo:u32

Vector3::struct
{
    x:f32,
    y:f32,
    z:f32
}

Vector2::struct
{
    x:f32,
    y:f32,
}

Vector2_64::struct
{
    x:f64,
    y:f64,
}

AABB::struct 
{
    position:Vector3,
    size:Vector2
}

Sprite::struct
{
    texture:u32,
    color:Vector3
}

GameObject::struct 
{
    aabb:AABB,
    sprite:Sprite
}

Button::struct
{
    rect:AABB,
    sprite:Sprite,
    hint:i32,

    _index:i32
}

Panel::struct
{
    rect:AABB,
    sprite:Sprite,

    id:int
}

GAME_STATE::enum
{
    GAME_ON,
    GAME_OVER,
    GAME_PAUSE,
    GAME_YTS
}

game_state:GAME_STATE = GAME_STATE.GAME_YTS

create_aabb::proc(_position:Vector3,_size:Vector2)-> ^AABB
{ 
    temp : ^AABB = &{
        position = _position,
        size = _size  
    }
    return temp         
}

get_min_aabb::proc(aabb:^AABB)->Vector3
{
    vec:Vector3 = {
        x = aabb.position.x,
        y = aabb.position.y,
        z = aabb.position.z
    }
    return vec
}

get_max_aabb::proc(aabb:^AABB)->Vector3
{
    vec:Vector3 = {
        x = aabb.position.x + aabb.size.x,
        y = aabb.position.y + aabb.size.y,
        z = aabb.position.z
    }
    return vec
}

contains_point::proc(parent:^AABB,point:Vector3)->bool
{
    parent_min:= get_min_aabb(parent)
    parent_max:= get_max_aabb(parent)

    if(point.x >= parent_min.x && point.x <= parent_max.x)
    {
        if(point.x >= parent_min.y && point.x <= parent_max.y)
        {
            return true
        }
    }
    return false
}

contains_point2d::proc(parent:^AABB,point:Vector2)->bool
{
    parent_min:= get_min_aabb(parent)
    parent_max:= get_max_aabb(parent)

    if(point.x >= parent_min.x && point.x <= parent_max.x)
    {
        if(point.y >= parent_min.y && point.y <= parent_max.y)
        {
            return true
        }
    }
    return false
}

contains_aabb::proc(parent:^AABB,child:^AABB)->bool
{
    child_min:=get_min_aabb(child)
    child_max:=get_max_aabb(child)

    parent_min:=get_min_aabb(parent)
    parent_max:=get_max_aabb(parent)

    if(child_min.x >= parent_min.x && child_max.x<= parent_max.x)
    {
        if(child_min.y >= parent_min.y && child_max.y <= parent_max.y)
        {
            return true
        }
    }    
    return false
}

quad_vertex_shader:= #load("quad_vertex.glsl",string)
quad_fragment_shader:= #load("quad_fragment.glsl",string)

create_program::proc(vertex_source:^string,fragment_source:^string)->u32
{
    program :u32
    status :bool

    program,status =  gl.load_shaders_source(vertex_source^,fragment_source^)
    
    if !status
    {
        log_warning("Could not load shaders")
        log_info(quad_vertex_shader)
    }
   

    return program
}

VertexType::struct 
{
    position:Vector3,
    texture_coordinate:Vector2
}

Renderer2D::struct
{
    vao:u32,
    vbo:u32,

    program:u32
}
Renderer:Renderer2D

initialize_renderer::proc() ->u32
{
    

     return Renderer.vao
}

load_texture::proc(path_to:cstring)->u32
{
    return 0
}

draw_quad::proc(object:GameObject)
{
    aabb := object.aabb
    color := object.sprite.color
    vertices:[36]f32 = {
        aabb.position.x,               aabb.position.y,               aabb.position.z,  color.x, color.y, color.z,
        aabb.position.x,               aabb.position.y + aabb.size.y, aabb.position.z,  color.x, color.y, color.z,
        aabb.position.x + aabb.size.x, aabb.position.y,               aabb.position.z,  color.x, color.y, color.z,

        aabb.position.x,               aabb.position.y + aabb.size.y, aabb.position.z,  color.x, color.y, color.z,
        aabb.position.x + aabb.size.x, aabb.position.y,               aabb.position.z,  color.x, color.y, color.z,
        aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z,  color.x, color.y, color.z

    }
    gl.BindVertexArray(quad_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER,quad_vbo)

    gl.BufferSubData(gl.ARRAY_BUFFER,0,size_of(f32)*36,&vertices)

    gl.DrawArrays(gl.TRIANGLES,0,6)

    gl.BindVertexArray(0)
    gl.BindBuffer(gl.ARRAY_BUFFER,0)
}




draw_button::proc(button:^Button)
{ 
    aabb := button.rect
    color := button.sprite.color

    vertices:[48]f32 = {
        aabb.position.x,               aabb.position.y,               aabb.position.z,  color.x, color.y, color.z,  0.0, 0.0,
        aabb.position.x,               aabb.position.y + aabb.size.y, aabb.position.z,  color.x, color.y, color.z,  0.0, 1.0,
        aabb.position.x + aabb.size.x, aabb.position.y,               aabb.position.z,  color.x, color.y, color.z,  1.0, 0.0,

        aabb.position.x,               aabb.position.y + aabb.size.y, aabb.position.z,  color.x, color.y, color.z,  0.0, 1.0,
        aabb.position.x + aabb.size.x, aabb.position.y,               aabb.position.z,  color.x, color.y, color.z,  1.0, 0.0,
        aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z,  color.x, color.y, color.z,  1.0, 1.0
    }

    gl.UseProgram(Renderer.program)
    gl.BindVertexArray(Renderer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER,Renderer.vbo)  

    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(f32) * 48, &vertices)

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D,button.sprite.texture)
    

    gl.DrawArrays(gl.TRIANGLES,0,6)

    gl.BindVertexArray(0)
    gl.BindBuffer(gl.ARRAY_BUFFER,0)
}


draw_panel::proc(panel:^Panel)
{ 
    aabb := panel.rect
    color := panel.sprite.color

    vertices:[48]f32 = {
        aabb.position.x,               aabb.position.y,               aabb.position.z,  color.x, color.y, color.z,  0.0, 0.0,
        aabb.position.x,               aabb.position.y + aabb.size.y, aabb.position.z,  color.x, color.y, color.z,  0.0, 1.0,
        aabb.position.x + aabb.size.x, aabb.position.y,               aabb.position.z,  color.x, color.y, color.z,  1.0, 0.0,

        aabb.position.x,               aabb.position.y + aabb.size.y, aabb.position.z,  color.x, color.y, color.z,  0.0, 1.0,
        aabb.position.x + aabb.size.x, aabb.position.y,               aabb.position.z,  color.x, color.y, color.z,  1.0, 0.0,
        aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z,  color.x, color.y, color.z,  1.0, 1.0
    }

    gl.UseProgram(Renderer.program)
    gl.BindVertexArray(Renderer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER,Renderer.vbo)  

    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(f32) * 48, &vertices)

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D,panel.sprite.texture)
    

    gl.DrawArrays(gl.TRIANGLES,0,6)

    gl.BindVertexArray(0)
    gl.BindBuffer(gl.ARRAY_BUFFER,0)
}

get_adjacent_in_color::proc(button:^Button)
{
    switch button.hint
    {
        case 1:
            button.sprite.color = { 0.0, 0.0, 1.0 }
        case 2:
            button.sprite.color = { 0.0, 1.0, 0.0 }
        case 3:
            button.sprite.color = { 1.0, 0.0, 0.0 }
        case 4:
            button.sprite.color = { 0.5, 0.5, 0.0 }
        case 5:
            button.sprite.color = { 0.5, 0.0, 0.0 }
        case 6:
            button.sprite.color = { 0.0, 0.6, 0.6 }
        case 7:
            button.sprite.color = { 0.3, 0.3, 0.3 }
        case 8:
            button.sprite.color = { 0.8, 0.0, 0.0 }
        case 0:
            button.sprite.color = { 1.0, 1.0, 1.0 } 

    }
}


get_adjacent_in_text::proc(button:^Button)
{
    //TODO: Asset Manager
    switch button.hint
    {
        case 1:
            button.sprite.texture = create_fonts('1')
        case 2:
            button.sprite.texture = create_fonts('2')
        case 3:
            button.sprite.texture = create_fonts('3')
        case 4:
            button.sprite.texture = create_fonts('4')
        case 5:
            button.sprite.texture = create_fonts('5')
        case 6:
            button.sprite.texture = create_fonts('6')
        case 7:
            button.sprite.texture = create_fonts('7')
        case 8:
            button.sprite.texture = create_fonts('8')
    }
}
reveal_all::proc()
{
    for &b in buttons
    {
        get_adjacent_in_color(&b)
    }
}

visited := make(map[int]bool)

free_zero_adjacent::proc(button:^Button)
{
    if cast(int)button._index in visited
    {
        return 
    }

    visited[cast(int)button._index] = true

    row := button._index / 10
    col := button._index % 10
    for r := -1; r <= 1; r += 1
    {
        for c :=- 1; c <=1; c += 1
        {
            if r == 0 && c == 0 { continue }
            new_row := cast(int)row + r
            new_col := cast(int)col + c
            if (new_row >=0 && new_row < 10 && new_col >=0 && new_col < 10)
            {
                if buttons[new_col + 10 * new_row].hint == 0
                {
                    get_adjacent_in_color(&buttons[new_col + 10 * new_row])
                    num_reaveled[cast(int)buttons[new_col + 10 * new_row]._index] = true
                    free_zero_adjacent(&buttons[new_col + 10 * new_row])
                }
                if buttons[new_col + 10 * new_row].hint >= 1
                {
                    get_adjacent_in_color(&buttons[new_col + 10 * new_row])
                    num_reaveled[cast(int)buttons[new_col + 10 * new_row]._index] = true
                }
            }
        }
    }
}

expose_button::proc(button:^Button)
{
    clear(&visited)
    if has_mine(button)
    {
        game_state = GAME_STATE.GAME_OVER

        button.sprite.texture = create_bomb_texture()
        button.sprite.color = {0.0,0.0,0.0}
    }
    if button.hint == 0
    {
        log_info("HINTLESS: ")
        get_adjacent_in_color(button)
        num_reaveled[cast(int)button._index] = true
        free_zero_adjacent(button)
    }
    else
    {
        num_reaveled[cast(int)button._index] = true
        get_adjacent_in_color(button)
    }
}


on_game_button_clicked::proc(button:^Button)
{
    expose_button(button)
}

on_game_button_sec_clicked::proc(button:^Button)
{
    button.sprite.color = {0.1,0.1,0.1}
}

on_start_button_clicked::proc(button:^Button)
{
    game_state = GAME_STATE.GAME_ON
}

on_button_hover::proc(window:glfw.WindowHandle, button:^Button, n:int)->b8
{
    xPos,yPos:f64
    xPos,yPos = glfw.GetCursorPos(window)
    
    pos:Vector2
    pos.x = cast(f32)xPos
    pos.y = cast(f32)yPos
    pos.x /=800; pos.y /=800

    pos.x = (2 * pos.x) - 1.0
    pos.y = 1.0 - (2.0 * pos.y)  
    
    if contains_point2d(&button.rect,pos)
    {
       return true
    }
    return false

}


on_panel_hover::proc(window:glfw.WindowHandle, panel:^Panel, n:int)->b8
{
    xPos,yPos:f64
    xPos,yPos = glfw.GetCursorPos(window)
    
    pos : Vector2
    pos.x = cast(f32)xPos
    pos.y = cast(f32)yPos
    pos.x /= 800; pos.y /=800

    pos.x = (2 * pos.x) - 1.0
    pos.y = 1.0 - (2.0 * pos.y)  
    
    if contains_point2d(&panel.rect,pos)
    {
       return true
    }
    return false

}

create_fonts::proc(character:rune) ->u32
{
    ttf_buffer::[1<<23]u8
    font_data,status := os.read_entire_file(TEXT_FILE)
    if !status
    {
        log_error("Could not load fonts")
        return 0
    }

    font_ptr :[^]u8 = &font_data[0]
    font:tt.fontinfo

    if !tt.InitFont(&font,font_ptr,0)
    {
        log_error("Could not InitFont")
        return 0
    }
    
    char_index := tt.FindGlyphIndex(&font, character)
    if char_index == 0
    {
        log_error("Could not find glyph")
        return 0
    }

    bitmap_w,bitmap_h,xo,yo:i32
    glyph_bitmap := tt.GetGlyphBitmap(&font,0,tt.ScaleForPixelHeight(&font,100),char_index,&bitmap_w,&bitmap_h,&xo,&xo)

    _texture:u32

    gl.GenTextures(1,&_texture)
    gl.BindTexture(gl.TEXTURE_2D,_texture)
    // gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

    gl.TextureParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TextureParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

    gl.TextureParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TextureParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)


    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RED, bitmap_w, bitmap_h, 0, gl.RED, gl.UNSIGNED_BYTE, glyph_bitmap)

    gl.BindTexture(gl.TEXTURE_2D,0)

    return _texture

}

create_bomb_texture::proc()->u32
{
    image_bytes := #load(BOMB_FILE)

    image_ptr : ^image.Image
    image_error : image.Error
    // image_options :image.Options()

    image_ptr,image_error = image.load_from_bytes(image_bytes)
    if image_error != nil
    {
        log_error("FAILED TO LOAD IMAGE: ", BOMB_FILE)
        return 0
    }
    
    image_w := image_ptr.width
    image_h := image_ptr.height

    pixels := make([]u8, len(image_ptr.pixels.buf))

    for data, index in image_ptr.pixels.buf
    {
        pixels[index] = data
    }

    bomb_texture:u32
    gl.GenTextures(1,&bomb_texture)
    gl.BindTexture(gl.TEXTURE_2D,bomb_texture)

    gl.TextureParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE)
    gl.TextureParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE)

    gl.TextureParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.NEAREST)
    gl.TextureParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.NEAREST)


    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, cast(i32)image_w, cast(i32)image_h, 0, gl.RGBA, gl.UNSIGNED_BYTE, &pixels[0])
    return bomb_texture
}

has_mine::proc(button:^Button)->b8
{
    if(button.hint == -1)
    {
        return true
    }
    return false
}

// button.hint = 0
check_for_mine::proc(button:^Button, list:^[100]Button, index:int)
{    
    row := index / 10
    col := index % 10

    for r := -1; r <= 1; r += 1
    {
        for c :=- 1; c <=1; c += 1
        {
            if r == 0 && c == 0 { continue }

            new_row := row + r
            new_col := col + c

            if (new_row >=0 && new_row < 10 && new_col >=0 && new_col < 10)
            {
                if has_mine(&list[new_col + 10 * new_row]) // button.hint = 0
                {
                    button.hint +=1
                }
            }
        }

    }
}


initialize_buttons::proc(buttons:^[100]Button)
{

    // This is the list of mine indexes the random number generator will chooes from 
    arr:[99]i32
    for x in 0..<len(arr)
    {
        arr[x] = cast(i32)x
    }
    
    for a:int=0; a<10; a+=1
    {
        for b:int=0; b<10; b+=1
        {
            button_index:= 10*a + b
            buttons[button_index] = 
            {
                rect = {
                    position = {-0.98 + (cast(f32)b * 0.198), 0.8 - (cast(f32)a * 0.198), 0.0},
                    size = {0.18,0.18}
                },
                sprite = {
                    color = {0.30,0.3,0.4},
                    texture = create_fonts('@')                    
                },
                hint =0,
                _index = cast(i32)button_index
            }
        }
    }

    for m in 0..<30
    {    
        buttons[rand.choice(arr[:])].hint = -1
    }


    for a:int=0; a<10; a+=1
    {
        for b:int=0; b<10; b+=1
        {
            button_index:= 10*a + b
            if buttons[button_index].hint != -1
            {
                check_for_mine( &buttons[button_index],buttons,button_index)
            }
        }
    }

  
}

mouse_callback::proc "c" (window:glfw.WindowHandle,a:i32,b:i32,c:i32 )
{
    context = runtime.default_context()

}

start_button:Button = {
    rect = 
    {
        position = {
            -0.5,0.5,0.0
        },
        size = {
            0.6,0.2
        }
    },
    sprite = 
    {
        color = {
            0.9,1.0,0.4
        }
    }
}

exit_button:Button = {
    rect = 
    {
        position = {
            -0.5,0.0,0.0
        },
        size = {
            0.6,0.2
        }
    },
    sprite = 
    {
        color = {
            0.9,1.0,0.4
        }
    }
}

game_over_ui:Panel = 
{
    rect = 
    {
        position = {
            -0.7, -0.2, 0.0
        },
        size = {
            1.4, 0.6
        }
    },

    sprite = 
    {
        color = 
        {
            0.4,0.8,0.1
        }
    }
}


on_game_startup::proc()
{
    // draw_button(&start_button)
    // draw_button(&exit_button)

    draw_panel(&game_over_ui)
}

on_game_over::proc()
{
    draw_panel(&game_over_ui)
}

is_mouse_clicked:bool = false
user_game_on_input::proc()->bool
{
    if game_state != GAME_STATE.GAME_ON
    {
        return false
    }
    if glfw.GetKey(window,glfw.KEY_TAB) == glfw.PRESS && !is_mouse_clicked
    {
        is_mouse_clicked = true
        reveal_all();
        return true
    }

    if glfw.GetMouseButton(window,glfw.MOUSE_BUTTON_1) == glfw.PRESS && !is_mouse_clicked
    {
        is_mouse_clicked = true
        for &b, n in buttons
        {
            if on_button_hover(window,&b, 1)
            {
                on_game_button_clicked(&b)
            }
        }   
        return true
    }

    if glfw.GetMouseButton(window,glfw.MOUSE_BUTTON_2) == glfw.PRESS && !is_mouse_clicked
    {
        is_mouse_clicked = true
        for &b, n in buttons
        {
            if on_button_hover(window,&b, 1)
            {
                on_game_button_sec_clicked(&b)
            }
        }  
        return true
    }
    return false
}

user_game_yts_input::proc() ->bool
{
    // if glfw.GetMouseButton(window,glfw.MOUSE_BUTTON_1) == glfw.PRESS && !is_mouse_clicked
    // {
    //     is_mouse_clicked = true
    //     if on_button_hover(window,&start_button, 1)
    //     {
    //         on_start_button_clicked(&start_button)
    //     }  
        
    //     if on_button_hover(window,&exit_button, 1)
    //     {
    //         glfw.SetWindowShouldClose(window,true)
    //     } 

    //     return true

    // }

    if glfw.GetKey(window,glfw.KEY_SPACE) == glfw.PRESS
    {
        game_state = GAME_STATE.GAME_ON
        clear(&num_reaveled)
        return true
    }

    return false
}

user_game_over_input::proc() ->bool
{
    /*
    if glfw.GetMouseButton(window,glfw.MOUSE_BUTTON_1) == glfw.PRESS && !is_mouse_clicked
    {
        is_mouse_clicked = true
        if on_panel_hover(window,&game_over_ui, 1)
        {
            initialize_buttons(&buttons)
            clear(&visited)
            game_state = GAME_STATE.GAME_YTS
        }  
        return true
    }
    */

    if glfw.GetKey(window,glfw.KEY_SPACE) == glfw.PRESS
    {
        initialize_buttons(&buttons)
        clear(&visited)
        clear(&num_reaveled)
        game_state = GAME_STATE.GAME_ON
        return true
    }

    if glfw.GetKey(window,glfw.KEY_BACKSPACE) == glfw.PRESS
    {
        game_state = GAME_STATE.GAME_ON
        return true
    }
    return false
}


user_input::proc()->bool
{
    #partial switch game_state{
        case .GAME_ON:
            user_game_on_input()
            return true
        case .GAME_OVER:
            user_game_over_input()
            return true
        case .GAME_YTS:
            user_game_yts_input()
            return true
    }
    return false
}

main::proc()
{
    if !glfw.Init()
    {
        log_error("Could not initialize GLFW")
        return 
    }
    defer glfw.Terminate()
  
    glfw.WindowHint_bool(glfw.RESIZABLE,false)
    window = glfw.CreateWindow(window_width,window_height,window_title,nil,nil)
    if window == nil
    {
        log_error("Could not create window")
    }
    defer glfw.DestroyWindow(window)

    glfw.MakeContextCurrent(window);
    glfw.SetMouseButtonCallback(window,mouse_callback)
    gl.load_up_to(4,6, glfw.gl_set_proc_address)
    gl.Viewport(0,0,800,800)

    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA)
    

    status:bool
    Renderer.program,status  = gl.load_shaders_source(quad_vertex_shader,quad_fragment_shader)

     //QUAD BUFFER INIT
     gl.GenVertexArrays(1,&Renderer.vao)
     gl.BindVertexArray(Renderer.vao)
     defer gl.DeleteVertexArrays(1,&Renderer.vao)
 
     gl.GenBuffers(1,&Renderer.vbo)
     defer gl.DeleteBuffers(1,&Renderer.vbo)
     
     gl.BindBuffer(gl.ARRAY_BUFFER,Renderer.vbo)
     gl.BufferData(gl.ARRAY_BUFFER, size_of(f32) * 48, nil ,gl.DYNAMIC_DRAW ) //NOTE: Remember to change size when new data
 
     gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 0)
     gl.EnableVertexAttribArray(0)

     gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 3 * size_of(f32))
     gl.EnableVertexAttribArray(1)
 
     gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 6 * size_of(f32))
     gl.EnableVertexAttribArray(2)
 
     gl.BindVertexArray(0)
     gl.BindBuffer(gl.ARRAY_BUFFER,0)
    

    initialize_buttons(&buttons)

    bottom:Button = {
        rect = {
            position = {0.0,0.0,0.0},
            size = { 0.5,0.5}
        },
        sprite = {
            texture = create_bomb_texture()
        }
    }

    fps := 0
    new_frame_time := glfw.GetTime()
    for !glfw.WindowShouldClose(window)
    {
        gl.ClearColor(0.0, 0.0, 0.0, 1.0)
        // gl.ClearColor(0.3,0.5,0.8,1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        glfw.PollEvents()
        {
            user_input()
            gl.Uniform1i(gl.GetUniformLocation(Renderer.program,"font_texture"),0)
            is_mouse_clicked = false
            
            if game_state == GAME_STATE.GAME_YTS
            {
                on_game_startup()   
            }
            else if game_state == GAME_STATE.GAME_ON
            {
                for &b in buttons
                {
                    draw_button(&b)
                }
            }
            else if game_state == GAME_STATE.GAME_OVER
            {
                on_game_over()
            }

            if len(num_reaveled) == 75
            {
                log_info("GAME WON")
            }
        }
        fps+=1
        if(glfw.GetTime() - new_frame_time >= 1.0)
        {
            //log_info("FPS: ", fps)
            fps = 0
            new_frame_time = glfw.GetTime()
        }
        glfw.SwapBuffers(window)

    }
}