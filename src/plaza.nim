import
    std/[
        logging,
        sequtils,
        times,
        strformat,
        marshal,
        lists,
        tables,
        deques,
    ],
    nimgl/[
        glfw,
        opengl,
    ],
    polymorph,
    vmath,

    common/[settings, utils],
    render/shader,
    "static"/objects

# ============= ECS =============

registerComponents defaultComponentOptions:
    type
        Location = object
            v: Vec3
            old: Vec3
        Rotation = object
            v: Quat
            old: Quat
        Scale = object
            v: Vec3
            old: Vec3
        TransformMat = object
            v: Mat4
            updated: bool
        Relationship = object
            parent: RelationshipInstance
            children: seq[RelationshipInstance]
            childIndex: int

            entity: EntityRef
        RootScene = object
        OpenGLModel = object
            vao: uint32
            vbo: uint32
            vertLen: int32
            modelLoc: GLint

makeSystem "resetTransMat", [Location, Rotation, Scale, TransformMat]:
    all:
        if item.location.v != item.location.old or
           item.rotation.v != item.rotation.old or
           item.scale.v != item.scale.old:
            item.transformMat.v = mat4()

            item.transformMat.v = item.transformMat.v * translate(item.location.v)
            item.transformMat.v = item.transformMat.v * mat4(item.rotation.v)
            item.transformMat.v = item.transformMat.v * scale(item.scale.v)

            item.location.old = item.location.v
            item.rotation.old = item.rotation.v
            item.scale.old = item.scale.v
            item.transformMat.updated = true
        else:
            item.transformMat.updated = false
defineSystem "updateSceneInheritance", [Relationship, TransformMat], defaultSysOpts:
    scenes = newSeq[EntityRef]()

makeSystemBody "updateSceneInheritance":
    var q = initDeque[SysItemUpdateSceneInheritance]()

    for scene in sys.scenes:
        if unlikely(not sys.contains scene):
            continue

        var sceneItem = sys.groups[sys.index[scene.entityId]]
        q.addLast(sceneItem)

        while q.len > 0:
            var parentItem = q.popFirst()
            var itemTrans = parentItem.transformMat.v

            for child in parentItem.relationship.children:
                if unlikely(not sys.contains(child.entity)):
                    continue
                var 
                    childItem = sys.groups[sys.index[child.entity.entityId]]
                    shouldUpdate = parentItem.transformMat.updated or childItem.transformMat.updated
                if not shouldUpdate:
                    continue

                childItem.transformMat.v = itemTrans * childItem.transformMat.v
                childItem.transformMat.updated = true
                q.addLast(childItem)


defineGroup "updateTransGroup"

makeSystem "render", [TransformMat, OpenGLModel]:
    all:
        # Upload model
        var mat = flatten(item.transformMat.v)
        glUniformMatrix4fv(item.openGLModel.modelLoc, 1, false, mat[0].addr)

        # Draw
        glBindVertexArray item.openGLModel.vao
        glDrawArrays(GL_TRIANGLES, 0, item.openGLModel.vertLen)
defineGroup "renderGroup"

makeEcs()

commitGroup "updateTransGroup", "runUpdateTrans"
commitGroup "renderGroup", "runRender"

let
    rootSceneBp = cl(
        Location(v: vec3(), old: vec3()),
        Rotation(v: quat(), old: quat()),
        Scale(v: vec3(1, 1, 1), old: vec3(1, 1, 1)),
        TransformMat(v: mat4()),
        Relationship(children: newSeq[RelationshipInstance]()),
        RootScene()
    )
    renderEntityBp = cl(
        Location(v: vec3(), old: vec3()),
        Rotation(v: quat(), old: quat()),
        Scale(v: vec3(1, 1, 1), old: vec3(1, 1, 1)),
        TransformMat(v: mat4()),
        Relationship(children: newSeq[RelationshipInstance]()),
        OpenGLModel()
    )

template createModelEntity(): EntityRef =
    var e = renderEntityBp.construct
    var rel = e.fetch(Relationship)
    rel.entity = e
    e

template createModelScene(): EntityRef =
    var e = rootSceneBp.construct
    var rel = e.fetch(Relationship)
    rel.entity = e
    e

template removeChild(parentComp, childComp: RelationshipInstance) =
    parentComp.children[parentComp.children.high].childIndex = childComp.childIndex
    parentComp.children.del(childComp.childIndex)
    childComp.parent = 0.RelationshipInstance
    childComp.childIndex = -1

proc removeChild*(parentEntity: EntityRef, childEntity: EntityRef) =
    var parentComp = parentEntity.fetch Relationship
    var childComp = childEntity.fetch Relationship

    if (parentComp.valid and childComp.valid) and childComp.parent != parentComp:
        removeChild(parentComp, childComp)

proc addChild*(parentEntity: EntityRef, childEntity: EntityRef) =
    var parentComp = parentEntity.fetch Relationship
    var childComp = childEntity.fetch Relationship

    if not (parentComp.valid and childComp.valid) or childComp.parent == parentComp:
        return

    if childComp.parent.valid:
        removeChild(childComp.parent, childComp)

    parentComp.children.add(childComp)
    childComp.childIndex = parentComp.children.high
    childComp.parent = parentComp

# ============= ECS =============


proc initWindow(): void
proc deinitWindow(): void
proc keyProc(window: GLFWWindow, key: int32, scancode: int32, action: int32,
        mods: int32): void {.cdecl.}
proc resizeProc(window: GLFWWindow, width: int32, height: int32): void {.cdecl.}
proc debugProc (source: GLenum, typ: GLenum, id: GLuint, severity: GLenum,
        length: GLsizei, message: ptr GLchar, userParam: pointer) {.stdcall.}

var window: GLFWWindow

proc main() =
    initWindow()

    # GL Initialization
    assert glInit()
    glEnable(GL_DEPTH_TEST)
    glEnable(GL_BLEND)
    glEnable(GL_CULL_FACE)
    # glEnable(GL_DEBUG_OUTPUT)
    # glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS)
    # glDebugMessageCallback(debugProc, nil)
    # glDebugMessageControl(GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, nil, true);





    # Create shader
    var defaultShader = newShader(DEFAULT_VS, DEFAULT_FS)
    defaultShader.use()





    # Create Cube Mesh
    var combined = concat(CUBE_VERT, CUBE_NORM)
    var vertI = 0
    var normI = CUBE_VERT.len * cfloat.sizeof
    var vao, vbo: uint32

    glGenVertexArrays 1, vao.addr
    glBindVertexArray vao

    glGenBuffers 1, vbo.addr
    glBindBuffer GL_ARRAY_BUFFER, vbo
    glBufferData GL_ARRAY_BUFFER, cint(cfloat.sizeof * combined.len), combined[
            0].addr, GL_STATIC_DRAW

    glEnableVertexAttribArray 0
    glVertexAttribPointer 0, 3, EGL_FLOAT, false, 0, cast[pointer](vertI)
    glEnableVertexAttribArray 1
    glVertexAttribPointer 1, 3, EGL_FLOAT, false, 0, cast[pointer](normI.cint)

    glBindVertexArray 0





    # Uniforms
    var modelMat = flatten(mat4())
    var viewMat = flatten(lookAt(vec3(0, 0, -10), vec3(0, 0, 0), vec3(0, 1, 0)))
    var projectionMat = flatten(perspective(60.0, 800/600, 0.01, 100000))
    var lightPosVec = flatten(vec3(10.0, 10, 10))
    var viewPosVec = flatten(vec3(0.0, 0, -5))
    var lightColorVec = flatten(vec3(1.0, 1, 1))

    var modelLoc = glGetUniformLocation(defaultShader.program, "uModel")
    var viewLoc = glGetUniformLocation(defaultShader.program, "uView")
    var projectionLoc = glGetUniformLocation(defaultShader.program, "uProjection")
    var lightPosLoc = glGetUniformLocation(defaultShader.program, "uLightPos")
    var viewPosLoc = glGetUniformLocation(defaultShader.program, "uViewPos")
    var lightColorPos = glGetUniformLocation(defaultShader.program, "uLightColor")

    glUniformMatrix4fv(modelLoc, 1, false, modelMat[0].addr)
    glUniformMatrix4fv(viewLoc, 1, false, viewMat[0].addr)
    glUniformMatrix4fv(projectionLoc, 1, false, projectionMat[0].addr)
    glUniform3fv(lightPosLoc, 1, lightPosVec[0].addr)
    glUniform3fv(viewPosLoc, 1, viewPosVec[0].addr)
    glUniform3fv(lightColorPos, 1, lightColorVec[0].addr)





    var
        rootScene = createModelScene()
        boxEntity1 = createModelEntity()
        boxEntity2 = createModelEntity()
        glModel1 = boxEntity1.fetch OpenGLModel
        glModel2 = boxEntity2.fetch OpenGLModel
        sceneLoc = rootScene.fetch Location
        be1Rot = boxEntity1.fetch Rotation
        be2Loc = boxEntity2.fetch Location
        


    rootScene.addChild(boxEntity1)
    boxEntity1.addChild(boxEntity2)
    sysUpdateSceneInheritance.scenes.add(rootScene)

    glModel1.vao = vao
    glModel1.vbo = vbo
    glModel1.vertLen = CUBE_VERT.len
    glModel1.modelLoc = modelLoc

    glModel2.vao = vao
    glModel2.vbo = vbo
    glModel2.vertLen = CUBE_VERT.len
    glModel2.modelLoc = modelLoc

    sceneLoc.v.x += 3
    be2Loc.v.x -= 3

    # Tick
    var t = 0.0
    var up = vec3(0, 1, 0)

    var prevTime = 0.0
    var currTime = 0.0
    var delta = 0.0
    while not window.windowShouldClose:
        prevTime = currTime
        currTime = cpuTime()
        delta = currTime - prevTime

        glfwPollEvents()
        glClearColor(0f, 0f, 0f, 1f)
        glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

        defaultShader.use()

        t += delta * 0.1
        echo t
        var r = t*(math.PI/180)
        be1Rot.v = quat(mat4(be1Rot.v) * rotateY(r.float32))

        runUpdateTrans()
        runRender()

        window.swapBuffers()
    deinitWindow()





proc initWindow() =

    # Window initializations
    assert glfwInit()

    glfwWindowHint GLFWContextVersionMajor, 4
    glfwWindowHint GLFWContextVersionMinor, 6
    glfwWindowHint GLFWOpenglForwardCompat, GLFW_TRUE # Used for Mac
    glfwWindowHint GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE
    glfwWindowHint GLFWResizable, GLFW_TRUE
    glfwWindowHint GLFWOpenglDebugContext, GLFW_TRUE


    window = glfwCreateWindow(800, 600, "Plaza")
    if window == nil:
        logging.fatal "Failed to initialize window."
        quit -1

    discard window.setKeyCallback keyProc
    discard window.setWindowSizeCallback resizeProc
    window.makeContextCurrent()

proc deinitWindow() =
    window.destroyWindow()
    glfwTerminate()

# process all input: query GLFW whether relevant keys are pressed/released this frame and react accordingly
# ---------------------------------------------------------------------------------------------------------
proc keyProc(window: GLFWWindow, key: int32, scancode: int32, action: int32,
        mods: int32): void {.cdecl.} =
    if key == GLFWKey.ESCAPE and action == GLFWPress:
        window.setWindowShouldClose true

# glfw: whenever the window size changed (by OS or user resize) this callback function executes
# ---------------------------------------------------------------------------------------------
proc resizeProc(window: GLFWWindow, width: int32, height: int32) =
    # make sure the viewport matches the new window dimensions; note that width and
    # height will be significantly larger than specified on retina displays.
    glViewport 0, 0, width, height

proc debugProc (source: GLenum, typ: GLenum, id: GLuint, severity: GLenum,
        length: GLsizei, message: ptr GLchar, userParam: pointer) =
    discard

if isMainModule:
    var logger = newConsoleLogger()
    addHandler logger
    main()
