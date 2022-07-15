import std/[
    sets,
    lists
]
import nimgl/opengl
import vmath

## ======= Node =======

var nextId = 0


type Node* = ref object of RootObj
    id: int
    name*: string
    location*: Vec3
    rotation*: Quat
    scale*: Vec3
    transformationMatrix: Mat4
    parent: Node
    children: HashSet[Node]

func hash(node: Node): int =
    return node.id

proc newNode*(name = "", location = vec3(), rotation = quat(), scale = vec3(1)): Node =
    nextId += 1
    return Node(
        id: nextId,
        name: name,
        location: location,
        scale: scale,
        transformationMatrix: mat4()
    )

method addChild*(self: Node, node: Node) {.base.} =
    if not node.parent.isNil:
        node.parent.children.excl node
    node.parent = self
    self.children.incl node

method prepareTransformationMatrix(self: Node) {.base.} =
    var mat = mat4()
    if not self.parent.isNil:
        mat = mat * self.parent.transformationMatrix
    mat = mat * translate(self.location) * mat4(self.rotation) * scale(self.scale)
    self.transformationMatrix = mat


method tick(self: Node, tick: float) {.base.} =
    discard

method draw(self: Node, tick: float) {.base.} =
    discard



## ======= Mesh =======

type Mesh = ref object of Node
    vao: uint32
    vbo: uint32

proc init(self: Mesh) =
    # var buff
    discard
