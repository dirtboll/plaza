import
    std/[
        logging
    ],
    nimgl/[
        opengl
    ]

type
    Shader = ref object of RootObj
        program: GLuint

func program*(self: Shader): GLuint = self.program

proc statusShader(shader: uint32): string =
    var status: int32
    glGetShaderiv(shader, GL_COMPILE_STATUS, status.addr);
    if status != GL_TRUE.ord:
        var log_length: int32
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, log_length.addr)
        var message = newSeq[char](log_length)
        glGetShaderInfoLog(shader, log_length, log_length.addr, message[0].addr);
        result = cast[string](message)

proc statusProgram(program: uint32): string =
    var status: int32
    glGetProgramiv(program, GL_LINK_STATUS, status.addr);
    if status != GL_TRUE.ord:
        var log_length: int32
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, log_length.addr)
        var message = newSeq[char](log_length)
        glGetProgramInfoLog(program, log_length, log_length.addr, message[0].addr);
        result = cast[string](message)

proc newShader*(vs: cstring, fs: cstring): Shader =
    new result

    var vertex = glCreateShader GL_VERTEX_SHADER
    glShaderSource vertex, 1'i32, vs.unsafeAddr, nil
    glCompileShader vertex
    var statusMsg = statusShader vertex
    if statusMsg.len > 0:
        logging.error "Failed to compile vertex shader: \n" & statusMsg

    var fragment = glCreateShader GL_FRAGMENT_SHADER
    glShaderSource fragment, 1'i32, fs.unsafeAddr, nil
    glCompileShader fragment
    statusMsg = statusShader fragment
    if statusMsg.len > 0:
        logging.error "Failed to compile fragment shader: \n" & statusMsg

    var program = glCreateProgram()
    glAttachShader program, vertex
    glAttachShader program, fragment
    glLinkProgram program
    statusMsg = statusProgram program
    if statusMsg.len > 0:
        logging.error "Failed to link shader program: \n" & statusMsg

    result.program = program

proc use*(shader: Shader) =
    glUseProgram shader.program