import
    std/[
        logging,
        sequtils,
        times,
        lists,
        tables,
        deques,
        math
    ],
    nimgl/[
        glfw,
        opengl,
    ],
    polymorph,
    glm/[
        vec,
        mat,
        quat,
        mat_transform
    ],
    common/[settings],
    render/shader,
    "static"/objects

# ============= ECS =============

type TransMatState = enum
    NOT_UPDATED, UPDATED

registerComponents defaultComponentOptions:
    type
        Transform = object
            loc: Vec3f
            oldLoc: Vec3f
            rot: Quatf
            oldRot: Quatf
            sca: Vec3f
            oldSca: Vec3f
        TransformState = object
            v: TransMatState
        LocalTransformMatrix = object
            v: Mat4f
        GlobalTransformMatrix = object
            v: Mat4f
        Relationship = object
            parent: RelationshipInstance
            children: seq[RelationshipInstance]
            childIndex: int
            entity: EntityRef
        OpenGLModel = object
            vao: uint32
            vbo: uint32
            vertLen: int32
            modelLoc: GLint

makeSystem "updateTrans", [Transform, TransformState, LocalTransformMatrix]:
    all:
        if item.transform.loc != item.transform.oldLoc or
           item.transform.rot != item.transform.oldRot or
           item.transform.sca != item.transform.oldSca:
            var m = mat4f()
                .translate(item.transform.loc)
                .`*`(mat4(item.transform.rot))
                .scale(item.transform.sca)
            item.localTransformMatrix.v = m

            item.transform.oldLoc = item.transform.loc
            item.transform.oldRot = item.transform.rot
            item.transform.oldSca = item.transform.sca
            item.transformState.v = TransMatState.UPDATED
        else:
            item.transformState.v = TransMatState.NOT_UPDATED

defineSystem "updateInheritance", [Relationship, TransformState,
        LocalTransformMatrix, GlobalTransformMatrix], defaultSysOpts:
    scenes = newSeq[EntityRef]()

makeSystemBody "updateInheritance":
    var q = initDeque[SysItemUpdateInheritance]()

    for scene in sys.scenes:
        var sceneItem = sys.groups[sys.index[scene.entityId]]
        q.addLast(sceneItem)

        while q.len > 0:
            if unlikely(not sys.contains scene):
                continue

            var parentItem = q.popFirst()
            var parentTrans = parentItem.globalTransformMatrix.v
            var parentTransState = parentItem.transformState.v

            for child in parentItem.relationship.children:
                if unlikely(not sys.contains(child.entity)):
                    continue

                var childItem = sys.groups[sys.index[child.entity.entityId]]
                if childItem.transformState.v != TransMatState.UPDATED and
                   parentTransState != TransMatState.UPDATED:
                    continue

                var m = parentTrans * childItem.localTransformMatrix.v
                childItem.globalTransformMatrix.v = m
                childItem.transformState.v = TransMatState.UPDATED
                q.addLast(childItem)

                # if child.entity.entityId.int == 3:
                #     echo "========================="
                #     echo "Child mat: \n" & $childItem.globalTransformMatrix.v
                #     echo "Parent mat: \n" & $parentTrans
                #     echo "Mult: \n" & $(parentTrans * childItem.globalTransformMatrix.v)
defineGroup "updateTransGroup"

makeSystem "render", [GlobalTransformMatrix, OpenGLModel]:
    all:
        # Upload model
        var mat = item.globalTransformMatrix.v
        glUniformMatrix4fv(item.openGLModel.modelLoc, 1, false, mat.caddr)

        # Draw
        glBindVertexArray item.openGLModel.vao
        glDrawArrays(GL_TRIANGLES, 0, item.openGLModel.vertLen)
defineGroup "renderGroup"

makeEcs()

commitGroup "updateTransGroup", "runUpdateTrans"
commitGroup "renderGroup", "runRender"

let
    rootSceneBp = cl(
        Transform(loc: vec3f(0), rot: quatf(), sca: vec3f(1)),
        TransformState(),
        LocalTransformMatrix(v: mat4f()),
        GlobalTransformMatrix(v: mat4f()),
        Relationship(children: newSeq[RelationshipInstance]()),
    )
    renderEntityBp = cl(
        Transform(loc: vec3f(0), rot: quatf(), sca: vec3f(1)),
        TransformState(),
        LocalTransformMatrix(v: mat4f()),
        GlobalTransformMatrix(v: mat4f()),
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
    var modelMat = mat4f()
    var viewMat = lookAtRH(vec3f(0, 0, -10), vec3f(0, 0, 0), vec3f(0, 1, 0))
    var projectionMat = perspective(60f.degToRad, 800/600, 0.01, 100000)
    var lightPosVec = vec3f(10, 10, 10)
    var viewPosVec = vec3f(0, 0, -5)
    var lightColorVec = vec3f(1, 1, 1)

    var modelLoc = glGetUniformLocation(defaultShader.program, "uModel")
    var viewLoc = glGetUniformLocation(defaultShader.program, "uView")
    var projectionLoc = glGetUniformLocation(defaultShader.program, "uProjection")
    var lightPosLoc = glGetUniformLocation(defaultShader.program, "uLightPos")
    var viewPosLoc = glGetUniformLocation(defaultShader.program, "uViewPos")
    var lightColorPos = glGetUniformLocation(defaultShader.program, "uLightColor")

    # glUniformMatrix4fv(modelLoc, 1, false, modelMat.caddr)
    glUniformMatrix4fv(viewLoc, 1, false, viewMat.caddr)
    glUniformMatrix4fv(projectionLoc, 1, false, projectionMat.caddr)
    glUniform3fv(lightPosLoc, 1, lightPosVec.caddr)
    glUniform3fv(viewPosLoc, 1, viewPosVec.caddr)
    glUniform3fv(lightColorPos, 1, lightColorVec.caddr)





    var
        rootScene = createModelScene()
        box1 = createModelEntity()
        box2 = createModelEntity()
        box1GlModel = box1.fetch OpenGLModel
        box2GlModel = box2.fetch OpenGLModel
        sceneTrans = rootScene.fetch Transform
        box1Trans = box1.fetch Transform
        box2Trans = box2.fetch Transform

        sceneMat = rootScene.fetch GlobalTransformMatrix
        box1Mat = box1.fetch GlobalTransformMatrix
        box2Mat = box2.fetch GlobalTransformMatrix

    rootScene.addChild(box1)
    box1.addChild(box2)
    sysUpdateInheritance.scenes.add(rootScene)

    box1GlModel.vao = vao
    box1GlModel.vbo = vbo
    box1GlModel.vertLen = CUBE_VERT.len
    box1GlModel.modelLoc = modelLoc

    box2GlModel.vao = vao
    box2GlModel.vbo = vbo
    box2GlModel.vertLen = CUBE_VERT.len
    box2GlModel.modelLoc = modelLoc

    sceneTrans.loc.x += 3
    box2Trans.loc.x -= 3


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

        box1Trans.rot = box1Trans.rot.rotate(delta, vec3f(0, 1, 0))

        doUpdateTrans()
        doUpdateInheritance()
        doRender()

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
