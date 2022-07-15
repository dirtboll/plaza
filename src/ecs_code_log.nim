# SPDX-License-Identifier: Apache-2.0

# Copyright (c) 2020 Ryan Lipscombe
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## This module contains the user accessible shared types used in the library.

# ECS generation options and types.
type
  ECSCompStorage* = enum csSeq, csArray, csTable
  ECSErrorResponse* = enum erAssert, erRaise  ## Note that with cdRaise, the component list is searched for duplicates each time a component is added, even with release/danger.
  ECSEntityItemStorage* = enum esSeq, esArray,
    esPtrArray # TODO: this functionality is experimental and unpolished.
  ECSRecyclerFormat* = enum rfSeq, rfArray
  ECSErrorResponses* = object
    errDuplicates*: ECSErrorResponse  # TODO: needs implementation.
    errEntityOverflow*: ECSErrorResponse
    errCaseComponent*: ECSErrorResponse
    errCaseSystem*: ECSErrorResponse  # TODO: needs implementation.
    errIncompleteOwned*: ECSErrorResponse
  ECSStrDefault* = enum sdShowData, sdHideData

  ECSEntityOptions* = object
    ## Controls code generation for entities.
    maxEntities*: Natural ## Controls the maximum amount of entities for fixed size formats (ignored for esSeq).
    componentStorageFormat*: ECSCompStorage     ## Choose the format of component list in entity items.
    entityStorageFormat*: ECSEntityItemStorage  ## Choose between stack allocated or heap allocated array.
    maxComponentsPerEnt*: Natural       ## Only applies to csArray storage format.
    recyclerFormat*: ECSRecyclerFormat  ## Array access should be much faster, but takes up more space.
    # Note: sets can dramatically increase entity header size with a lot of components,
    # as each `8` components defined will double the size of the set in bytes.
    # Operations like creating, adding or removing are also slightly slower with
    # a set due to the additional update work (~5% depending on component count).
    # The advantage of using a set is that it allows an O(1) response for `hasComponent`
    # when also using seq/array component lists.
    # If you have seq/array component lists and don't want the extra memory burden
    # of sets, you can ameliorate the O(N) cost of iteration for hasComponent by
    # adding often checked/fetched components first, so finding them can return
    # earlier.
    # Component lists defined as a table will probably find the set unnecessary.
    # Note that using hasComponent often can imply the need for a new system
    # incorporating these components.
    useSet*: bool ## Use a set for hasComponent.
    errors*: ECSErrorResponses  ## Control how errors are generated.
    strDefault*: ECSStrDefault ## Defines if the `$` operator should default to displaying component field data or just listing the components.

  # Component storage options
  ECSAccessMethod* = enum amDotOp
  ECSCompItemStorage* = enum cisSeq, cisArray
  ECSCompRecyclerFormat* = enum crfSeq, crfArray
  ECSCompInvalidAccess* = enum iaIgnore, iaAssert

  ECSCompOptions* = object
    maxComponents*: Natural   ## Maximum amount of components for all component types in this prefix.
    componentStorageFormat*: ECSCompItemStorage ## Underlying storage format for components.
    accessMethod*: ECSAccessMethod  ## Controls accessing fields through instances.
    recyclerFormat*: ECSCompRecyclerFormat  ## TODO: Underlying storage format the recycler uses to keep track of deleted component indexes.
    clearAfterDelete*: bool ## Zeros memory of component after deletion.
    useThreadVar*: bool ## Declare the component arrays as {.threadVar.}.
    invalidAccess*: ECSCompInvalidAccess  ## Allow inserting assert checks for each instance field access.

  # System storage options
  ECSSysStorage* = enum ssSeq, ssArray
  ECSSysIndexFormat* = enum sifTable, sifArray, sifAllocatedSeq
  ECSSysTimings* = enum stNone, stRunEvery, stProfiling
  ECSSysEcho* = enum seNone, seEchoUsed, seEchoUsedAndRunning, seEchoUsedAndRunningAndFinished, seEchoAll
  ECSSysThreading* = enum sthNone, sthDistribute

  ECSSysOptions* = object
    maxEntities*: int ## Maximum entities this system can hold.
    storageFormat*: ECSSysStorage ## Underlying storage format for the system groups.
    indexFormat*: ECSSysIndexFormat ## sifArray = constant time deletes, uses `maxEntities` * ~8 bytes per system, uses stack space, sifAllocatedSeq = heap allocated storage, initialised to `maxEntities`, sifTable = adaptive memory use, but requires reallocated when extended.
    timings*: ECSSysTimings ## Generate timing code.
    useThreadVar*: bool ## Declare systems as {.threadVar.}.
    echoRunning*: ECSSysEcho  ## Reporting system execution state can be useful for debugging blocking systems or to monitor the sequence of system actions.
    assertItem*: bool ## Add asserts to check the system `item` is within bounds.
    orderedRemove*: bool  ## Maintains the execution order when items are removed from groups. This changes deletion from an O(1) to an O(N) operation.
    threading*: ECSSysThreading ## System threading options.

  ComponentUpdatePerfTuple* = tuple[componentType: string, systemsUpdated: int]
  EntityOverflow* = object of OverflowDefect
  DuplicateComponent* = object of ValueError

func fixedSizeSystem*(ents: int): ECSSysOptions =
  ## Shortcut for fixed size, high performance, high memory systems.
  ECSSysOptions(
    maxEntities: ents,
    storageFormat: ssArray,
    indexFormat: sifArray)

func dynamicSizeSystem*: ECSSysOptions =
  ## Shortcut for systems that adjust dynamically.
  ECSSysOptions(
    storageFormat: ssSeq,
    indexFormat: sifTable,
    assertItem: compileOption("assertions"))

func fixedSizeComponents*(maxInstances: int): ECSCompOptions =
  ## Shortcut for fixed size, high performance, high memory systems.
  ECSCompOptions(
    maxComponents: maxInstances,
    componentStorageFormat: cisArray,
    recyclerFormat: crfArray,
    )

func dynamicSizeComponents*: ECSCompOptions =
  ## Shortcut for systems that adjust dynamically.
  ECSCompOptions(
    componentStorageFormat: cisSeq,
    recyclerFormat: crfSeq,
  )

func fixedSizeEntities*(ents: int, componentCapacity = 0): ECSEntityOptions =
  ## Shortcut for fixed size, high performance, high memory systems.
  ECSEntityOptions(
    maxEntities: ents,
    componentStorageFormat: if componentCapacity == 0: csSeq else: csArray,
    maxComponentsPerEnt: componentCapacity,
    entityStorageFormat: esArray,
    recyclerFormat: rfArray
    )

func dynamicSizeEntities*: ECSEntityOptions =
  ECSEntityOptions(
    componentStorageFormat: csSeq,
    entityStorageFormat: esSeq,
    recyclerFormat: rfSeq
    )


const
  defaultComponentOptions* = dynamicSizeComponents()
  defaultEntityOptions* = dynamicSizeEntities()
  defaultSystemOptions* = dynamicSizeSystem()
  
  # Save some keystrokes.
  defaultCompOpts* = defaultComponentOptions
  defaultEntOpts* = defaultEntityOptions
  defaultSysOpts* = defaultSystemOptions

# Used as a pragma to statically track the current event entity.
template hostEntity* {.pragma.}

# Base Polymorph types.

type
  # Base type for all ids.
  IdBaseType* = int32
  ## Index representing a system.
  SystemIndex* = distinct int

  EntityId* = distinct IdBaseType
  EntityInstance* = distinct IdBaseType

  EntityRef* = tuple[entityId: EntityId, instance: EntityInstance]
  Entities* = seq[EntityRef]

  EventKind* = enum
    ekNoEvent =           "<none>",
    ekConstruct =         "construct",
    ekClone =             "clone",
    ekDeleteEnt =         "delete",
  
    ekNewEntityWith =     "newEntityWith",
    ekAddComponents =     "addComponent",
    ekRemoveComponents =  "removeComponent",

    ekInit =              "onInit",
    ekUpdate =            "onUpdate",
    ekAdd =               "onAdd",
    ekRemove =            "onRemove",
    ekAddCB =             "onAddCallback",
    ekRemoveCB =          "onRemoveCallback",
    ekDeleteComp =        "onDelete",
  
    ekSystemAddAny =      "onSystemAdd",
    ekSystemRemoveAny =   "onSystemRemove",
  
    ekCompAddTo =         "onSystemAddTo",
    ekCompRemoveFrom =    "onSystemRemoveFrom",

    ekRowAdded =          "added",
    ekRowRemoved =        "removed",
    ekRowAddedCB =        "addedCallback",
    ekRowRemovedCB =      "removedCallback",

  # TODO: this could be minimised to bytes as the set size is.
  ComponentTypeIDBase* = uint16
  ComponentTypeId* = distinct ComponentTypeIDBase

  Component* {.inheritable.} = ref object of RootObj
    ## This root object allows runtime templates of components to be constructed.
    ## `registerComponents` automatically generates a type descending from here for each component
    ## type.
    ## `typeId` has to match the valid componentTypeId for the descended
    ## value's type, and is automatically initialised by `makeContainer`
    ## and the `cl` macro.
    # Internal value exposed for access.
    fTypeId*: ComponentTypeId

  ## Generic index into a component storage array.
  ## This is 'sub-classed' into distinct types per component type by registerComponents.
  ## These distinct versions of ComponentIndex allow direct access to component storage by
  ## transforming the type at compile time to an index into the storage array that contains the
  ## component.
  ## For run-time operations on component ids, use `caseComponent` and pass the ComponentTypeId
  ComponentIndex* = distinct IdBaseType
  ## Instance count, incremented when the slot is used.
  ## This is used to protect against referencing a deleted component with the same slot index.
  ComponentGeneration* = distinct IdBaseType
  ## Allows reference to particular instances of a component.
  ## Component references are how indexes/keys to different components are stored, passed about, and fetched.
  ## Not to be confused with the reference type `Component`.
  ComponentRef* = tuple[typeId: ComponentTypeId, index: ComponentIndex, generation: ComponentGeneration]

  ## Store a list of components, can be used as a template for constructing an entity.
  ## `add` is overridden for this type to allow you to add user types or instance types
  ## and their value is assigned to a ref container ready for `construct`.
  ComponentList* = seq[Component]
  ## A template for multiple entities
  ConstructionTemplate* = seq[ComponentList]

  SystemFetchResult* = tuple[found: bool, row: int]


const
  InvalidComponent* = 0.ComponentTypeId
  InvalidComponentIndex* = 0.ComponentIndex
  InvalidComponentGeneration* = 0.ComponentGeneration
  InvalidComponentRef*: ComponentRef = (InvalidComponent, InvalidComponentIndex, InvalidComponentGeneration)
  InvalidSystemIndex* = SystemIndex(0)
  
  ## An EntityId of zero indicates uninitialised data
  NO_ENTITY* = 0.EntityId
  ## Reference of an invalid entity
  NO_ENTITY_REF*: EntityRef = (entityId: NO_ENTITY, instance: 0.EntityInstance)
  # Max number of entities at once
  # Note this is the maximum concurrent entity count, and
  # defines the amount of memory allocated at start up.
  FIRST_ENTITY_ID* = (NO_ENTITY.int + 1).EntityId
  FIRST_COMPONENT_ID* = (InvalidComponentIndex.int + 1).ComponentIndex

func `==`*(s1, s2: SystemIndex): bool {.inline.} = s1.int == s2.int

func `==`*(c1, c2: ComponentTypeId): bool = c1.int == c2.int
func `==`*(i1, i2: ComponentIndex): bool = i1.int == i2.int
func `==`*(g1, g2: ComponentGeneration): bool = g1.int == g2.int

## Entities start at 1 so a zero EntityId is invalid or not found
func `==`*(e1, e2: EntityId): bool {.inline.} = e1.IdBaseType == e2.IdBaseType
func `==`*(e1, e2: EntityRef): bool {.inline.} =
  e1.entityId.IdBaseType == e2.entityId.IdBaseType and e1.instance.IdBaseType == e2.instance.IdBaseType
template valid*(entityId: EntityId): bool = entityId != NO_ENTITY
template valid*(entity: EntityRef): bool = entity != NO_ENTITY_REF

# Construction.

type
  ## Constructor called on first create.
  ConstructorProc* = proc (entity: EntityRef, component: Component, context: EntityRef): seq[Component]
  ## Constructor called after all entities in a template have been constructed.
  PostConstructorProc* = proc (entity: EntityRef, component: ComponentRef, entities: var Entities)
  ## Constructor called when `clone` is invoked.
  CloneConstructorProc* = proc (entity: EntityRef, component: ComponentRef): seq[Component]

type
  EntityTransitionType* = enum ettUpdate, ettRemoveAdd


# Fragmentation analysis.

import stats

type
  ## This object stores information about the access pattern of a
  ## component from a system.
  ComponentAccessAnalysis* = object
    name*: string
    ## The minimum forward address delta to be included in `forwardJumps`.
    ## When zero anything larger than the size of the type is included.
    jumpThreshold*: int
    ## SizeOf(T) for the component data.
    valueSize*: int
    ## How many lookups go backwards per component that might cause fetching.
    backwardsJumps*: int
    ## How many jumps in forward access that might cause fetching.
    forwardJumps*: int
    ## Average information on the system access pattern for this component.
    allData*: RunningStat
    taggedData*: RunningStat
    ## The ratio of non-sequential vs sequential address accesses.
    fragmentation*: float

  ## Information about access patterns within a system obtained by `analyseSystem`.
  SystemAnalysis* = object
    name*: string
    entities*: int
    components*: seq[ComponentAccessAnalysis]
# Added component type: "Location" = 1
# Added component type: "Rotation" = 2
# Added component type: "Scale" = 3
# Added component type: "TransformMat" = 4
# Added component type: "Relationship" = 5
# Added component type: "RootScene" = 6
# Added component type: "OpenGLModel" = 7

# Register components:

type
  LocationInstance* = distinct IdBaseType
type
  LocationGeneration* = distinct IdBaseType
type
  RotationInstance* = distinct IdBaseType
type
  RotationGeneration* = distinct IdBaseType
type
  ScaleInstance* = distinct IdBaseType
type
  ScaleGeneration* = distinct IdBaseType
type
  TransformMatInstance* = distinct IdBaseType
type
  TransformMatGeneration* = distinct IdBaseType
type
  RelationshipInstance* = distinct IdBaseType
type
  RelationshipGeneration* = distinct IdBaseType
type
  RootSceneInstance* = distinct IdBaseType
type
  RootSceneGeneration* = distinct IdBaseType
type
  OpenGLModelInstance* = distinct IdBaseType
type
  OpenGLModelGeneration* = distinct IdBaseType
type
  Location = object
    v: Vec3f
    old: Vec3f

  Rotation = object
    v: Quatf
    old: Quatf

  Scale = object
    v: Vec3f
    old: Vec3f

  TransformMat = object
    v: Mat4f
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

type
  LocationRef* = ref object of Component
    value*: Location

template typeId*(ty: Location | LocationRef | LocationInstance |
    typedesc[Location] |
    typedesc[LocationRef] |
    typedesc[LocationInstance]): ComponentTypeId =
  1.ComponentTypeId

type
  RotationRef* = ref object of Component
    value*: Rotation

template typeId*(ty: Rotation | RotationRef | RotationInstance |
    typedesc[Rotation] |
    typedesc[RotationRef] |
    typedesc[RotationInstance]): ComponentTypeId =
  2.ComponentTypeId

type
  ScaleRef* = ref object of Component
    value*: Scale

template typeId*(ty: Scale | ScaleRef | ScaleInstance | typedesc[Scale] |
    typedesc[ScaleRef] |
    typedesc[ScaleInstance]): ComponentTypeId =
  3.ComponentTypeId

type
  TransformMatRef* = ref object of Component
    value*: TransformMat

template typeId*(ty: TransformMat | TransformMatRef | TransformMatInstance |
    typedesc[TransformMat] |
    typedesc[TransformMatRef] |
    typedesc[TransformMatInstance]): ComponentTypeId =
  4.ComponentTypeId

type
  RelationshipRef* = ref object of Component
    value*: Relationship

template typeId*(ty: Relationship | RelationshipRef | RelationshipInstance |
    typedesc[Relationship] |
    typedesc[RelationshipRef] |
    typedesc[RelationshipInstance]): ComponentTypeId =
  5.ComponentTypeId

type
  RootSceneRef* = ref object of Component
    value*: RootScene

template typeId*(ty: RootScene | RootSceneRef | RootSceneInstance |
    typedesc[RootScene] |
    typedesc[RootSceneRef] |
    typedesc[RootSceneInstance]): ComponentTypeId =
  6.ComponentTypeId

type
  OpenGLModelRef* = ref object of Component
    value*: OpenGLModel

template typeId*(ty: OpenGLModel | OpenGLModelRef | OpenGLModelInstance |
    typedesc[OpenGLModel] |
    typedesc[OpenGLModelRef] |
    typedesc[OpenGLModelInstance]): ComponentTypeId =
  7.ComponentTypeId


# System "resetTransMat":

type
  SysItemResetTransMat* = object
    entity* {.hostEntity.}: EntityRef
    location*: LocationInstance
    rotation*: RotationInstance
    scale*: ScaleInstance
    transformMat*: TransformMatInstance

type
  ResetTransMatSystem* = object
    id*: SystemIndex
    lastIndex*: int          ## Records the last item position processed for streaming.
    streamRate*: Natural     ## Rate at which this system streams items by default, overridden if defined using `stream x:`.
    systemName*: string      ## Name is automatically set up at code construction in defineSystem.
    disabled*: bool          ## Doesn't run doProc if true, no work is done.
    paused*: bool            ## Pauses this system's entity processing, but still runs init & finish. 
    initialised*: bool       ## Automatically set to true after an `init` body is called.
    deleteList*: seq[EntityRef] ## Anything added to this list is deleted after the `finish` block. This avoids affecting the main loop when iterating.
    requirements: array[4, ComponentTypeId]
    groups*: seq[SysItemResetTransMat]
    index*: Table[EntityId, int]

template high*(system`gensym24: ResetTransMatSystem): int =
  system`gensym24.groups.high

template count*(system`gensym25: ResetTransMatSystem): int =
  system`gensym25.groups.len

var sysResetTransMat*: ResetTransMatSystem
## Returns the type of 'item' for the resetTransMat system.
template itemType*(system`gensym29: ResetTransMatSystem): untyped =
  SysItemResetTransMat

proc initResetTransMatSystem*(value: var ResetTransMatSystem) =
  ## Initialise the system.
  template sys(): untyped {.used.} =
    ## The `sys` template represents the system variable being passed.
    value

  template self(): untyped {.used.} =
    ## The `self` template represents the system variable being passed.
    value

  value.index = initTable[EntityId, int]()
  value.streamRate = 1
  value.requirements = [1.ComponentTypeId, 2.ComponentTypeId, 3.ComponentTypeId,
                        4.ComponentTypeId]
  value.systemName = "resetTransMat"
  sys.id = 1.SystemIndex

func name*(sys`gensym32: ResetTransMatSystem): string =
  "resetTransMat"

sysResetTransMat.initResetTransMatSystem()
proc contains*(sys`gensym32: ResetTransMatSystem; entity: EntityRef): bool =
  sysResetTransMat.index.hasKey(entity.entityId)

template isOwner*(sys`gensym33: ResetTransMatSystem): bool =
  false

template ownedComponents*(sys`gensym33: ResetTransMatSystem): seq[
    ComponentTypeId] =
  []


# System "updateSceneInheritance":

type
  SysItemUpdateSceneInheritance* = object
    entity* {.hostEntity.}: EntityRef
    relationship*: RelationshipInstance
    transformMat*: TransformMatInstance

type
  UpdateSceneInheritanceSystem* = object
    id*: SystemIndex
    lastIndex*: int          ## Records the last item position processed for streaming.
    streamRate*: Natural     ## Rate at which this system streams items by default, overridden if defined using `stream x:`.
    systemName*: string      ## Name is automatically set up at code construction in defineSystem.
    disabled*: bool          ## Doesn't run doProc if true, no work is done.
    paused*: bool            ## Pauses this system's entity processing, but still runs init & finish. 
    initialised*: bool       ## Automatically set to true after an `init` body is called.
    deleteList*: seq[EntityRef] ## Anything added to this list is deleted after the `finish` block. This avoids affecting the main loop when iterating.
    requirements: array[2, ComponentTypeId]
    groups*: seq[SysItemUpdateSceneInheritance]
    index*: Table[EntityId, int]
    scenes: typeof(newSeq[EntityRef]())

template high*(system`gensym55: UpdateSceneInheritanceSystem): int =
  system`gensym55.groups.high

template count*(system`gensym56: UpdateSceneInheritanceSystem): int =
  system`gensym56.groups.len

var sysUpdateSceneInheritance*: UpdateSceneInheritanceSystem
## Returns the type of 'item' for the updateSceneInheritance system.
template itemType*(system`gensym60: UpdateSceneInheritanceSystem): untyped =
  SysItemUpdateSceneInheritance

proc initUpdateSceneInheritanceSystem*(value: var UpdateSceneInheritanceSystem) =
  ## Initialise the system.
  template sys(): untyped {.used.} =
    ## The `sys` template represents the system variable being passed.
    value

  template self(): untyped {.used.} =
    ## The `self` template represents the system variable being passed.
    value

  value.index = initTable[EntityId, int]()
  value.streamRate = 1
  value.requirements = [5.ComponentTypeId, 4.ComponentTypeId]
  value.systemName = "updateSceneInheritance"
  value.scenes = newSeq[EntityRef]()
  sys.id = 2.SystemIndex

func name*(sys`gensym63: UpdateSceneInheritanceSystem): string =
  "updateSceneInheritance"

sysUpdateSceneInheritance.initUpdateSceneInheritanceSystem()
proc contains*(sys`gensym63: UpdateSceneInheritanceSystem; entity: EntityRef): bool =
  sysUpdateSceneInheritance.index.hasKey(entity.entityId)

template isOwner*(sys`gensym64: UpdateSceneInheritanceSystem): bool =
  false

template ownedComponents*(sys`gensym64: UpdateSceneInheritanceSystem): seq[
    ComponentTypeId] =
  []


# System "render":

type
  SysItemRender* = object
    entity* {.hostEntity.}: EntityRef
    transformMat*: TransformMatInstance
    openGLModel*: OpenGLModelInstance

type
  RenderSystem* = object
    id*: SystemIndex
    lastIndex*: int          ## Records the last item position processed for streaming.
    streamRate*: Natural     ## Rate at which this system streams items by default, overridden if defined using `stream x:`.
    systemName*: string      ## Name is automatically set up at code construction in defineSystem.
    disabled*: bool          ## Doesn't run doProc if true, no work is done.
    paused*: bool            ## Pauses this system's entity processing, but still runs init & finish. 
    initialised*: bool       ## Automatically set to true after an `init` body is called.
    deleteList*: seq[EntityRef] ## Anything added to this list is deleted after the `finish` block. This avoids affecting the main loop when iterating.
    requirements: array[2, ComponentTypeId]
    groups*: seq[SysItemRender]
    index*: Table[EntityId, int]

template high*(system`gensym75: RenderSystem): int =
  system`gensym75.groups.high

template count*(system`gensym76: RenderSystem): int =
  system`gensym76.groups.len

var sysRender*: RenderSystem
## Returns the type of 'item' for the render system.
template itemType*(system`gensym80: RenderSystem): untyped =
  SysItemRender

proc initRenderSystem*(value: var RenderSystem) =
  ## Initialise the system.
  template sys(): untyped {.used.} =
    ## The `sys` template represents the system variable being passed.
    value

  template self(): untyped {.used.} =
    ## The `self` template represents the system variable being passed.
    value

  value.index = initTable[EntityId, int]()
  value.streamRate = 1
  value.requirements = [4.ComponentTypeId, 7.ComponentTypeId]
  value.systemName = "render"
  sys.id = 3.SystemIndex

func name*(sys`gensym83: RenderSystem): string =
  "render"

sysRender.initRenderSystem()
proc contains*(sys`gensym83: RenderSystem; entity: EntityRef): bool =
  sysRender.index.hasKey(entity.entityId)

template isOwner*(sys`gensym84: RenderSystem): bool =
  false

template ownedComponents*(sys`gensym84: RenderSystem): seq[ComponentTypeId] =
  []



##
## ------------------------
## Systems use by component
## ------------------------
##


## TransformMat: 3 systems
## Location: 1 systems
## Rotation: 1 systems
## Scale: 1 systems
## Relationship: 1 systems
## OpenGLModel: 1 systems
## RootScene: <No systems using this component>
# ------------------------

# State changes operations:

macro newEntityWith*(componentList: varargs[typed]): untyped =
  ## Create an entity with the parameter components.
  ## This macro statically generates updates for only systems
  ## entirely contained within the parameters and ensures no
  ## run time component list iterations and associated checks.
  doNewEntityWith(EcsIdentity("default"), componentList)

macro addComponents*(id`gensym278: static[EcsIdentity]; entity: EntityRef;
                     componentList: varargs[typed]): untyped =
  ## Add components to a specific identity.
  doAddComponents(id`gensym278, entity, componentList)

macro addComponents*(entity: EntityRef; componentList: varargs[typed]): untyped =
  ## Add components to an entity and return a tuple containing
  ## the instances.
  doAddComponents(EcsIdentity("default"), entity, componentList)

macro add*(entity: EntityRef; componentList: varargs[typed]): untyped =
  ## Add components to an entity and return a tuple containing
  ## the instances.
  doAddComponents(EcsIdentity("default"), entity, componentList)

macro removeComponents*(entity: EntityRef; componentList: varargs[typed]): untyped =
  ## Remove components from an entity.
  doRemoveComponents(EcsIdentity("default"), entity, componentList)

macro remove*(entity: EntityRef; componentList: varargs[typed]): untyped =
  ## Remove a component from an entity.
  doRemoveComponents(EcsIdentity("default"), entity, componentList)

macro removeComponent*(entity: EntityRef; component`gensym278: typed) =
  ## Remove a component from an entity.
  doRemoveComponents(EcsIdentity("default"), entity, component`gensym278)

template removeComponents*(entity`gensym278: EntityRef;
                           compList`gensym278: ComponentList) =
  ## Remove a run time list of components from the entity.
  for c`gensym278 in compList`gensym278:
    assert c`gensym278.typeId != InvalidComponent
    caseComponent c`gensym278.typeId:
      removeComponent(entity`gensym278, componentType())

template add*(entity: EntityRef; component`gensym278: ComponentTypeclass) =
  entity.addComponent component`gensym278

proc addComponent*[T: ComponentTypeclass](entity: EntityRef;
    component`gensym279: T): auto {.discardable.} =
  ## Add a single component to `entity` and return the instance.
  entity.addComponents(component`gensym279)[0]

proc addOrUpdate*[T: ComponentTypeclass](entity: EntityRef;
    component`gensym279: T): auto {.discardable.} =
  ## Add `component` to `entity`, or if `component` already exists, overwrite it.
  ## Returns the component instance.
  let fetched`gensym279 = entity.fetchComponent typedesc[T]
  if fetched`gensym279.valid:
    update(fetched`gensym279, component`gensym279)
    result = fetched`gensym279
  else:
    result = addComponent(entity, component`gensym279)

proc addIfMissing*[T: ComponentTypeclass](entity: EntityRef;
    component`gensym279: T): auto {.discardable.} =
  ## Add a component only if it isn't already present.
  ## If the component is already present, no changes are made and an invalid result is returned.
  ## If the component isn't present, it will be added and the instance is returned.
  if not entity.hasComponent typedesc[T]:
    result = addComponent(entity, component`gensym279)

proc fetchOrAdd*[T: ComponentTypeclass](entity: EntityRef;
                                        component`gensym279: typedesc[T]): auto {.
    discardable.} =
  ## Fetch an existing component type if present, otherwise add
  ## the component type and return the instance.
  ## 
  ## This is useful when you always want a valid component
  ## instance returned, but don't want to overwrite existing
  ## data.
  result = entity.fetchComponent typedesc[T]
  if not result.valid:
    result = addComponent(entity, component`gensym279())

template addComponents*(entity: EntityRef; components`gensym280: ComponentList) =
  ## Add components from a list.
  ## Each component is assembled by it's run time `typeId`.
  static :
    startOperation(EcsIdentity("default"), "Add components from ref list")
  {.line.}:
    for c`gensym280 in components`gensym280:
      caseComponent c`gensym280.typeId:(discard entity.addComponent
          componentRefType()(c`gensym280).value)
  static :
    endOperation(EcsIdentity("default"))

template add*(entity: EntityRef; components`gensym280: ComponentList) =
  ## Add components from a list.
  ## Each component is assembled by its run time `typeId`.
  addComponents(entity, components`gensym280)

template addIfMissing*(entity`gensym280: EntityRef;
                       components`gensym280: ComponentList) =
  ## Add components from a list if they're not already present.
  {.line.}:
    for c`gensym280 in components`gensym280:
      caseComponent c`gensym280.typeId:
        entity`gensym280.addIfMissing componentRefType()(c`gensym280).value

template addOrUpdate*(entity`gensym280: EntityRef;
                      components`gensym280: ComponentList) =
  ## Add or update components from a list.
  {.line.}:
    for c`gensym280 in components`gensym280:
      caseComponent c`gensym280.typeId:(discard addOrUpdate(entity`gensym280,
          componentRefType()(c`gensym280).value))

template updateComponents*(entity`gensym280: EntityRef;
                           components`gensym280: ComponentList) =
  ## Updates existing components from a list.
  ## Components not found on the entity exist are ignored.
  {.line.}:
    for c`gensym280 in components`gensym280:
      caseComponent c`gensym280.typeId:
        let inst`gensym280 = entity`gensym280.fetchComponent componentType()
        if inst`gensym280.valid:
          inst`gensym280.update componentRefType()(c`gensym280).value

template update*(entity`gensym280: EntityRef;
                 components`gensym280: ComponentList) =
  ## Updates existing components from a list.
  ## Components not found on the entity are ignored.
  updateComponents(entity`gensym280, components`gensym280)


# makeEcs() code generation output:

startGenLog("C:\\Users\\testa\\Documents\\Projects\\plaza\\src\\ecs_code_log.nim")
var
  storageLocation*: seq[Location]
  locationFreeIndexes*: seq[LocationInstance]
  locationNextIndex*: LocationInstance
  locationAlive*: seq[bool]
  locationInstanceIds*: seq[int32]
  storageRotation*: seq[Rotation]
  rotationFreeIndexes*: seq[RotationInstance]
  rotationNextIndex*: RotationInstance
  rotationAlive*: seq[bool]
  rotationInstanceIds*: seq[int32]
  storageScale*: seq[Scale]
  scaleFreeIndexes*: seq[ScaleInstance]
  scaleNextIndex*: ScaleInstance
  scaleAlive*: seq[bool]
  scaleInstanceIds*: seq[int32]
  storageTransformMat*: seq[TransformMat]
  transformmatFreeIndexes*: seq[TransformMatInstance]
  transformmatNextIndex*: TransformMatInstance
  transformmatAlive*: seq[bool]
  transformmatInstanceIds*: seq[int32]
  storageRelationship*: seq[Relationship]
  relationshipFreeIndexes*: seq[RelationshipInstance]
  relationshipNextIndex*: RelationshipInstance
  relationshipAlive*: seq[bool]
  relationshipInstanceIds*: seq[int32]
  storageRootScene*: seq[RootScene]
  rootsceneFreeIndexes*: seq[RootSceneInstance]
  rootsceneNextIndex*: RootSceneInstance
  rootsceneAlive*: seq[bool]
  rootsceneInstanceIds*: seq[int32]
  storageOpenGLModel*: seq[OpenGLModel]
  openglmodelFreeIndexes*: seq[OpenGLModelInstance]
  openglmodelNextIndex*: OpenGLModelInstance
  openglmodelAlive*: seq[bool]
  openglmodelInstanceIds*: seq[int32]
template instanceType*(ty: typedesc[Location] | typedesc[LocationRef]): untyped =
  LocationInstance

template containerType*(ty: typedesc[Location] |
    typedesc[LocationInstance]): untyped =
  LocationRef

template makeContainer*(ty: Location): LocationRef =
  LocationRef(fTypeId: 1.ComponentTypeId, value: ty)

template makeContainer*(ty: LocationInstance): LocationRef =
  ty.access.makeContainer()

template instanceType*(ty: typedesc[Rotation] | typedesc[RotationRef]): untyped =
  RotationInstance

template containerType*(ty: typedesc[Rotation] |
    typedesc[RotationInstance]): untyped =
  RotationRef

template makeContainer*(ty: Rotation): RotationRef =
  RotationRef(fTypeId: 2.ComponentTypeId, value: ty)

template makeContainer*(ty: RotationInstance): RotationRef =
  ty.access.makeContainer()

template instanceType*(ty: typedesc[Scale] | typedesc[ScaleRef]): untyped =
  ScaleInstance

template containerType*(ty: typedesc[Scale] | typedesc[ScaleInstance]): untyped =
  ScaleRef

template makeContainer*(ty: Scale): ScaleRef =
  ScaleRef(fTypeId: 3.ComponentTypeId, value: ty)

template makeContainer*(ty: ScaleInstance): ScaleRef =
  ty.access.makeContainer()

template instanceType*(ty: typedesc[TransformMat] |
    typedesc[TransformMatRef]): untyped =
  TransformMatInstance

template containerType*(ty: typedesc[TransformMat] |
    typedesc[TransformMatInstance]): untyped =
  TransformMatRef

template makeContainer*(ty: TransformMat): TransformMatRef =
  TransformMatRef(fTypeId: 4.ComponentTypeId, value: ty)

template makeContainer*(ty: TransformMatInstance): TransformMatRef =
  ty.access.makeContainer()

template instanceType*(ty: typedesc[Relationship] |
    typedesc[RelationshipRef]): untyped =
  RelationshipInstance

template containerType*(ty: typedesc[Relationship] |
    typedesc[RelationshipInstance]): untyped =
  RelationshipRef

template makeContainer*(ty: Relationship): RelationshipRef =
  RelationshipRef(fTypeId: 5.ComponentTypeId, value: ty)

template makeContainer*(ty: RelationshipInstance): RelationshipRef =
  ty.access.makeContainer()

template instanceType*(ty: typedesc[RootScene] | typedesc[RootSceneRef]): untyped =
  RootSceneInstance

template containerType*(ty: typedesc[RootScene] |
    typedesc[RootSceneInstance]): untyped =
  RootSceneRef

template makeContainer*(ty: RootScene): RootSceneRef =
  RootSceneRef(fTypeId: 6.ComponentTypeId, value: ty)

template makeContainer*(ty: RootSceneInstance): RootSceneRef =
  ty.access.makeContainer()

template instanceType*(ty: typedesc[OpenGLModel] |
    typedesc[OpenGLModelRef]): untyped =
  OpenGLModelInstance

template containerType*(ty: typedesc[OpenGLModel] |
    typedesc[OpenGLModelInstance]): untyped =
  OpenGLModelRef

template makeContainer*(ty: OpenGLModel): OpenGLModelRef =
  OpenGLModelRef(fTypeId: 7.ComponentTypeId, value: ty)

template makeContainer*(ty: OpenGLModelInstance): OpenGLModelRef =
  ty.access.makeContainer()

template accessType*(ty: LocationInstance | typedesc[LocationInstance]): untyped =
  ## Returns the source component type of a component instance.
  ## This can also be achieved with `instance.access.type`.
  typedesc[Location]

template `.`*(instance: LocationInstance; field: untyped): untyped =
  when compiles(storageLocation[instance.int].field):
    storageLocation[instance.int].field
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type Location".}

template `.=`*(instance: LocationInstance; field: untyped; value: untyped): untyped =
  when compiles(storageLocation[instance.int].field):
    storageLocation[instance.int].field = value
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type Location".}

template isOwnedComponent*(value`gensym115: typedesc[LocationInstance] |
    LocationInstance |
    Location): bool =
  false

template access*(instance`gensym115: LocationInstance): Location =
  storageLocation[instance`gensym115.int]

template alive*(inst`gensym115: LocationInstance): bool =
  ## Check if this component ref's index is still in use.
  inst`gensym115.int > 0 and inst`gensym115.int < locationAlive.len and
      locationAlive[inst`gensym115.int] == true

template valid*(inst`gensym115: LocationInstance): bool =
  inst`gensym115.int != InvalidComponentIndex.int

template generation*(inst`gensym115: LocationInstance): untyped =
  ## Access the generation of this component.
  LocationGeneration(locationInstanceIds[inst`gensym115.int]).ComponentGeneration

template componentStorage*(value`gensym115: typedesc[LocationInstance] |
    LocationInstance |
    Location): untyped =
  storageLocation

template ownerSystemIndex*(value`gensym115: typedesc[LocationInstance] |
    LocationInstance |
    Location): untyped =
  InvalidSystemIndex

template componentCount*(ty: typedesc[Location] |
    typedesc[LocationInstance]): untyped =
  ## Returns an estimate of the number of allocated components.
  ## This value is based on last index used and the number of indexes waiting to be used (from previous deletes).
  let freeCount`gensym124 = locationFreeIndexes.len
  storageLocation.len - freeCount`gensym124

proc genLocation*(): LocationInstance =
  ## Create a component instance for this type.
  result =
    var r`gensym121: LocationInstance
    if locationFreeIndexes.len > 0:
      r`gensym121 = locationFreeIndexes.pop
    else:
      r`gensym121 =
        let newLen`gensym118 = storageLocation.len + 1
        storageLocation.setLen(newLen`gensym118)
        locationInstanceIds.setLen(newLen`gensym118)
        locationAlive.setLen(newLen`gensym118)
        storageLocation.high.LocationInstance
    assert r`gensym121.int != 0
    locationAlive[r`gensym121.int] = true
    locationInstanceIds[r`gensym121.int] += 1
    assert r`gensym121.int >= 0
    r`gensym121
  
proc delete*(instance: LocationInstance) =
  ## Free a component instance
  let idx = instance.int
  {.line.}:
    assert idx < locationAlive.len, "Cannot delete, instance is out of range"
  if locationAlive[idx]:
    locationAlive[idx] = false
    if idx == storageLocation.high:
      let newLen`gensym119 = max(1, storageLocation.len - 1)
      storageLocation.setLen(newLen`gensym119)
      locationInstanceIds.setLen(newLen`gensym119)
      locationAlive.setLen(newLen`gensym119)
    elif locationFreeIndexes.high == storageLocation.high:
      locationFreeIndexes.setLen(0)
    else:
      locationFreeIndexes.add idx.LocationInstance
  
template newInstance*(ty: typedesc[Location] |
    typedesc[LocationInstance]): LocationInstance =
  ## Create a new component instance. Does not update systems.
  let res`gensym124 = genLocation()
  res`gensym124

proc newInstance*(value: Location): LocationInstance {.inline.} =
  ## Create a new component instance from the supplied value. Does not update systems.
  result =
    var r`gensym121: LocationInstance
    if locationFreeIndexes.len > 0:
      r`gensym121 = locationFreeIndexes.pop
    else:
      r`gensym121 =
        let newLen`gensym118 = storageLocation.len + 1
        storageLocation.setLen(newLen`gensym118)
        locationInstanceIds.setLen(newLen`gensym118)
        locationAlive.setLen(newLen`gensym118)
        storageLocation.high.LocationInstance
    assert r`gensym121.int != 0
    locationAlive[r`gensym121.int] = true
    locationInstanceIds[r`gensym121.int] += 1
    assert r`gensym121.int >= 0
    r`gensym121
  storageLocation[result.int] = value
  
template newInstance*(ty: typedesc[Location] |
    typedesc[LocationInstance]; val`gensym124: Component): untyped =
  ## Creates a new component from a generated `ref` component descendant. Does not update systems.
  newInstance(LocationRef(val`gensym124).value)

template delInstance*(ty: Location | LocationInstance): untyped =
  ## Marks a component as deleted. Does not update systems.
  ty.delete()

template update*(instance: LocationInstance; value: Location): untyped =
  ## Update storage.
  ## `update` operates as a simple assignment into the storage array and uses the type's `==` proc.
  storageLocation[instance.int] = value

template `==`*(i1`gensym125, i2`gensym125: LocationInstance): bool =
  i1`gensym125.int == i2`gensym125.int

template toRef*(inst`gensym125: LocationInstance): ComponentRef =
  ## Utility function that takes this type's distinct `ComponentIndex`,
  ## returned for example from fetchComponent, and creates a reference
  ## tuple for the live component currently at this index.
  let i`gensym125 = inst`gensym125
  (i`gensym125.typeId, i`gensym125.ComponentIndex, i`gensym125.generation)

template accessType*(ty: RotationInstance | typedesc[RotationInstance]): untyped =
  ## Returns the source component type of a component instance.
  ## This can also be achieved with `instance.access.type`.
  typedesc[Rotation]

template `.`*(instance: RotationInstance; field: untyped): untyped =
  when compiles(storageRotation[instance.int].field):
    storageRotation[instance.int].field
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type Rotation".}

template `.=`*(instance: RotationInstance; field: untyped; value: untyped): untyped =
  when compiles(storageRotation[instance.int].field):
    storageRotation[instance.int].field = value
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type Rotation".}

template isOwnedComponent*(value`gensym130: typedesc[RotationInstance] |
    RotationInstance |
    Rotation): bool =
  false

template access*(instance`gensym130: RotationInstance): Rotation =
  storageRotation[instance`gensym130.int]

template alive*(inst`gensym130: RotationInstance): bool =
  ## Check if this component ref's index is still in use.
  inst`gensym130.int > 0 and inst`gensym130.int < rotationAlive.len and
      rotationAlive[inst`gensym130.int] == true

template valid*(inst`gensym130: RotationInstance): bool =
  inst`gensym130.int != InvalidComponentIndex.int

template generation*(inst`gensym130: RotationInstance): untyped =
  ## Access the generation of this component.
  RotationGeneration(rotationInstanceIds[inst`gensym130.int]).ComponentGeneration

template componentStorage*(value`gensym130: typedesc[RotationInstance] |
    RotationInstance |
    Rotation): untyped =
  storageRotation

template ownerSystemIndex*(value`gensym130: typedesc[RotationInstance] |
    RotationInstance |
    Rotation): untyped =
  InvalidSystemIndex

template componentCount*(ty: typedesc[Rotation] |
    typedesc[RotationInstance]): untyped =
  ## Returns an estimate of the number of allocated components.
  ## This value is based on last index used and the number of indexes waiting to be used (from previous deletes).
  let freeCount`gensym139 = rotationFreeIndexes.len
  storageRotation.len - freeCount`gensym139

proc genRotation*(): RotationInstance =
  ## Create a component instance for this type.
  result =
    var r`gensym136: RotationInstance
    if rotationFreeIndexes.len > 0:
      r`gensym136 = rotationFreeIndexes.pop
    else:
      r`gensym136 =
        let newLen`gensym133 = storageRotation.len + 1
        storageRotation.setLen(newLen`gensym133)
        rotationInstanceIds.setLen(newLen`gensym133)
        rotationAlive.setLen(newLen`gensym133)
        storageRotation.high.RotationInstance
    assert r`gensym136.int != 0
    rotationAlive[r`gensym136.int] = true
    rotationInstanceIds[r`gensym136.int] += 1
    assert r`gensym136.int >= 0
    r`gensym136
  
proc delete*(instance: RotationInstance) =
  ## Free a component instance
  let idx = instance.int
  {.line.}:
    assert idx < rotationAlive.len, "Cannot delete, instance is out of range"
  if rotationAlive[idx]:
    rotationAlive[idx] = false
    if idx == storageRotation.high:
      let newLen`gensym134 = max(1, storageRotation.len - 1)
      storageRotation.setLen(newLen`gensym134)
      rotationInstanceIds.setLen(newLen`gensym134)
      rotationAlive.setLen(newLen`gensym134)
    elif rotationFreeIndexes.high == storageRotation.high:
      rotationFreeIndexes.setLen(0)
    else:
      rotationFreeIndexes.add idx.RotationInstance
  
template newInstance*(ty: typedesc[Rotation] |
    typedesc[RotationInstance]): RotationInstance =
  ## Create a new component instance. Does not update systems.
  let res`gensym139 = genRotation()
  res`gensym139

proc newInstance*(value: Rotation): RotationInstance {.inline.} =
  ## Create a new component instance from the supplied value. Does not update systems.
  result =
    var r`gensym136: RotationInstance
    if rotationFreeIndexes.len > 0:
      r`gensym136 = rotationFreeIndexes.pop
    else:
      r`gensym136 =
        let newLen`gensym133 = storageRotation.len + 1
        storageRotation.setLen(newLen`gensym133)
        rotationInstanceIds.setLen(newLen`gensym133)
        rotationAlive.setLen(newLen`gensym133)
        storageRotation.high.RotationInstance
    assert r`gensym136.int != 0
    rotationAlive[r`gensym136.int] = true
    rotationInstanceIds[r`gensym136.int] += 1
    assert r`gensym136.int >= 0
    r`gensym136
  storageRotation[result.int] = value
  
template newInstance*(ty: typedesc[Rotation] |
    typedesc[RotationInstance]; val`gensym139: Component): untyped =
  ## Creates a new component from a generated `ref` component descendant. Does not update systems.
  newInstance(RotationRef(val`gensym139).value)

template delInstance*(ty: Rotation | RotationInstance): untyped =
  ## Marks a component as deleted. Does not update systems.
  ty.delete()

template update*(instance: RotationInstance; value: Rotation): untyped =
  ## Update storage.
  ## `update` operates as a simple assignment into the storage array and uses the type's `==` proc.
  storageRotation[instance.int] = value

template `==`*(i1`gensym140, i2`gensym140: RotationInstance): bool =
  i1`gensym140.int == i2`gensym140.int

template toRef*(inst`gensym140: RotationInstance): ComponentRef =
  ## Utility function that takes this type's distinct `ComponentIndex`,
  ## returned for example from fetchComponent, and creates a reference
  ## tuple for the live component currently at this index.
  let i`gensym140 = inst`gensym140
  (i`gensym140.typeId, i`gensym140.ComponentIndex, i`gensym140.generation)

template accessType*(ty: ScaleInstance | typedesc[ScaleInstance]): untyped =
  ## Returns the source component type of a component instance.
  ## This can also be achieved with `instance.access.type`.
  typedesc[Scale]

template `.`*(instance: ScaleInstance; field: untyped): untyped =
  when compiles(storageScale[instance.int].field):
    storageScale[instance.int].field
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type Scale".}

template `.=`*(instance: ScaleInstance; field: untyped; value: untyped): untyped =
  when compiles(storageScale[instance.int].field):
    storageScale[instance.int].field = value
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type Scale".}

template isOwnedComponent*(value`gensym145: typedesc[ScaleInstance] |
    ScaleInstance |
    Scale): bool =
  false

template access*(instance`gensym145: ScaleInstance): Scale =
  storageScale[instance`gensym145.int]

template alive*(inst`gensym145: ScaleInstance): bool =
  ## Check if this component ref's index is still in use.
  inst`gensym145.int > 0 and inst`gensym145.int < scaleAlive.len and
      scaleAlive[inst`gensym145.int] == true

template valid*(inst`gensym145: ScaleInstance): bool =
  inst`gensym145.int != InvalidComponentIndex.int

template generation*(inst`gensym145: ScaleInstance): untyped =
  ## Access the generation of this component.
  ScaleGeneration(scaleInstanceIds[inst`gensym145.int]).ComponentGeneration

template componentStorage*(value`gensym145: typedesc[ScaleInstance] |
    ScaleInstance |
    Scale): untyped =
  storageScale

template ownerSystemIndex*(value`gensym145: typedesc[ScaleInstance] |
    ScaleInstance |
    Scale): untyped =
  InvalidSystemIndex

template componentCount*(ty: typedesc[Scale] | typedesc[ScaleInstance]): untyped =
  ## Returns an estimate of the number of allocated components.
  ## This value is based on last index used and the number of indexes waiting to be used (from previous deletes).
  let freeCount`gensym154 = scaleFreeIndexes.len
  storageScale.len - freeCount`gensym154

proc genScale*(): ScaleInstance =
  ## Create a component instance for this type.
  result =
    var r`gensym151: ScaleInstance
    if scaleFreeIndexes.len > 0:
      r`gensym151 = scaleFreeIndexes.pop
    else:
      r`gensym151 =
        let newLen`gensym148 = storageScale.len + 1
        storageScale.setLen(newLen`gensym148)
        scaleInstanceIds.setLen(newLen`gensym148)
        scaleAlive.setLen(newLen`gensym148)
        storageScale.high.ScaleInstance
    assert r`gensym151.int != 0
    scaleAlive[r`gensym151.int] = true
    scaleInstanceIds[r`gensym151.int] += 1
    assert r`gensym151.int >= 0
    r`gensym151
  
proc delete*(instance: ScaleInstance) =
  ## Free a component instance
  let idx = instance.int
  {.line.}:
    assert idx < scaleAlive.len, "Cannot delete, instance is out of range"
  if scaleAlive[idx]:
    scaleAlive[idx] = false
    if idx == storageScale.high:
      let newLen`gensym149 = max(1, storageScale.len - 1)
      storageScale.setLen(newLen`gensym149)
      scaleInstanceIds.setLen(newLen`gensym149)
      scaleAlive.setLen(newLen`gensym149)
    elif scaleFreeIndexes.high == storageScale.high:
      scaleFreeIndexes.setLen(0)
    else:
      scaleFreeIndexes.add idx.ScaleInstance
  
template newInstance*(ty: typedesc[Scale] | typedesc[ScaleInstance]): ScaleInstance =
  ## Create a new component instance. Does not update systems.
  let res`gensym154 = genScale()
  res`gensym154

proc newInstance*(value: Scale): ScaleInstance {.inline.} =
  ## Create a new component instance from the supplied value. Does not update systems.
  result =
    var r`gensym151: ScaleInstance
    if scaleFreeIndexes.len > 0:
      r`gensym151 = scaleFreeIndexes.pop
    else:
      r`gensym151 =
        let newLen`gensym148 = storageScale.len + 1
        storageScale.setLen(newLen`gensym148)
        scaleInstanceIds.setLen(newLen`gensym148)
        scaleAlive.setLen(newLen`gensym148)
        storageScale.high.ScaleInstance
    assert r`gensym151.int != 0
    scaleAlive[r`gensym151.int] = true
    scaleInstanceIds[r`gensym151.int] += 1
    assert r`gensym151.int >= 0
    r`gensym151
  storageScale[result.int] = value
  
template newInstance*(ty: typedesc[Scale] | typedesc[ScaleInstance];
                      val`gensym154: Component): untyped =
  ## Creates a new component from a generated `ref` component descendant. Does not update systems.
  newInstance(ScaleRef(val`gensym154).value)

template delInstance*(ty: Scale | ScaleInstance): untyped =
  ## Marks a component as deleted. Does not update systems.
  ty.delete()

template update*(instance: ScaleInstance; value: Scale): untyped =
  ## Update storage.
  ## `update` operates as a simple assignment into the storage array and uses the type's `==` proc.
  storageScale[instance.int] = value

template `==`*(i1`gensym155, i2`gensym155: ScaleInstance): bool =
  i1`gensym155.int == i2`gensym155.int

template toRef*(inst`gensym155: ScaleInstance): ComponentRef =
  ## Utility function that takes this type's distinct `ComponentIndex`,
  ## returned for example from fetchComponent, and creates a reference
  ## tuple for the live component currently at this index.
  let i`gensym155 = inst`gensym155
  (i`gensym155.typeId, i`gensym155.ComponentIndex, i`gensym155.generation)

template accessType*(ty: TransformMatInstance |
    typedesc[TransformMatInstance]): untyped =
  ## Returns the source component type of a component instance.
  ## This can also be achieved with `instance.access.type`.
  typedesc[TransformMat]

template `.`*(instance: TransformMatInstance; field: untyped): untyped =
  when compiles(storageTransformMat[instance.int].field):
    storageTransformMat[instance.int].field
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type TransformMat".}

template `.=`*(instance: TransformMatInstance; field: untyped; value: untyped): untyped =
  when compiles(storageTransformMat[instance.int].field):
    storageTransformMat[instance.int].field = value
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type TransformMat".}

template isOwnedComponent*(value`gensym160: typedesc[TransformMatInstance] |
    TransformMatInstance |
    TransformMat): bool =
  false

template access*(instance`gensym160: TransformMatInstance): TransformMat =
  storageTransformMat[instance`gensym160.int]

template alive*(inst`gensym160: TransformMatInstance): bool =
  ## Check if this component ref's index is still in use.
  inst`gensym160.int > 0 and inst`gensym160.int < transformmatAlive.len and
      transformmatAlive[inst`gensym160.int] == true

template valid*(inst`gensym160: TransformMatInstance): bool =
  inst`gensym160.int != InvalidComponentIndex.int

template generation*(inst`gensym160: TransformMatInstance): untyped =
  ## Access the generation of this component.
  TransformMatGeneration(transformmatInstanceIds[inst`gensym160.int]).ComponentGeneration

template componentStorage*(value`gensym160: typedesc[TransformMatInstance] |
    TransformMatInstance |
    TransformMat): untyped =
  storageTransformMat

template ownerSystemIndex*(value`gensym160: typedesc[TransformMatInstance] |
    TransformMatInstance |
    TransformMat): untyped =
  InvalidSystemIndex

template componentCount*(ty: typedesc[TransformMat] |
    typedesc[TransformMatInstance]): untyped =
  ## Returns an estimate of the number of allocated components.
  ## This value is based on last index used and the number of indexes waiting to be used (from previous deletes).
  let freeCount`gensym169 = transformmatFreeIndexes.len
  storageTransformMat.len - freeCount`gensym169

proc genTransformMat*(): TransformMatInstance =
  ## Create a component instance for this type.
  result =
    var r`gensym166: TransformMatInstance
    if transformmatFreeIndexes.len > 0:
      r`gensym166 = transformmatFreeIndexes.pop
    else:
      r`gensym166 =
        let newLen`gensym163 = storageTransformMat.len + 1
        storageTransformMat.setLen(newLen`gensym163)
        transformmatInstanceIds.setLen(newLen`gensym163)
        transformmatAlive.setLen(newLen`gensym163)
        storageTransformMat.high.TransformMatInstance
    assert r`gensym166.int != 0
    transformmatAlive[r`gensym166.int] = true
    transformmatInstanceIds[r`gensym166.int] += 1
    assert r`gensym166.int >= 0
    r`gensym166
  
proc delete*(instance: TransformMatInstance) =
  ## Free a component instance
  let idx = instance.int
  {.line.}:
    assert idx < transformmatAlive.len,
           "Cannot delete, instance is out of range"
  if transformmatAlive[idx]:
    transformmatAlive[idx] = false
    if idx == storageTransformMat.high:
      let newLen`gensym164 = max(1, storageTransformMat.len - 1)
      storageTransformMat.setLen(newLen`gensym164)
      transformmatInstanceIds.setLen(newLen`gensym164)
      transformmatAlive.setLen(newLen`gensym164)
    elif transformmatFreeIndexes.high == storageTransformMat.high:
      transformmatFreeIndexes.setLen(0)
    else:
      transformmatFreeIndexes.add idx.TransformMatInstance
  
template newInstance*(ty: typedesc[TransformMat] |
    typedesc[TransformMatInstance]): TransformMatInstance =
  ## Create a new component instance. Does not update systems.
  let res`gensym169 = genTransformMat()
  res`gensym169

proc newInstance*(value: TransformMat): TransformMatInstance {.inline.} =
  ## Create a new component instance from the supplied value. Does not update systems.
  result =
    var r`gensym166: TransformMatInstance
    if transformmatFreeIndexes.len > 0:
      r`gensym166 = transformmatFreeIndexes.pop
    else:
      r`gensym166 =
        let newLen`gensym163 = storageTransformMat.len + 1
        storageTransformMat.setLen(newLen`gensym163)
        transformmatInstanceIds.setLen(newLen`gensym163)
        transformmatAlive.setLen(newLen`gensym163)
        storageTransformMat.high.TransformMatInstance
    assert r`gensym166.int != 0
    transformmatAlive[r`gensym166.int] = true
    transformmatInstanceIds[r`gensym166.int] += 1
    assert r`gensym166.int >= 0
    r`gensym166
  storageTransformMat[result.int] = value
  
template newInstance*(ty: typedesc[TransformMat] |
    typedesc[TransformMatInstance]; val`gensym169: Component): untyped =
  ## Creates a new component from a generated `ref` component descendant. Does not update systems.
  newInstance(TransformMatRef(val`gensym169).value)

template delInstance*(ty: TransformMat | TransformMatInstance): untyped =
  ## Marks a component as deleted. Does not update systems.
  ty.delete()

template update*(instance: TransformMatInstance; value: TransformMat): untyped =
  ## Update storage.
  ## `update` operates as a simple assignment into the storage array and uses the type's `==` proc.
  storageTransformMat[instance.int] = value

template `==`*(i1`gensym170, i2`gensym170: TransformMatInstance): bool =
  i1`gensym170.int == i2`gensym170.int

template toRef*(inst`gensym170: TransformMatInstance): ComponentRef =
  ## Utility function that takes this type's distinct `ComponentIndex`,
  ## returned for example from fetchComponent, and creates a reference
  ## tuple for the live component currently at this index.
  let i`gensym170 = inst`gensym170
  (i`gensym170.typeId, i`gensym170.ComponentIndex, i`gensym170.generation)

template accessType*(ty: RelationshipInstance |
    typedesc[RelationshipInstance]): untyped =
  ## Returns the source component type of a component instance.
  ## This can also be achieved with `instance.access.type`.
  typedesc[Relationship]

template `.`*(instance: RelationshipInstance; field: untyped): untyped =
  when compiles(storageRelationship[instance.int].field):
    storageRelationship[instance.int].field
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type Relationship".}

template `.=`*(instance: RelationshipInstance; field: untyped; value: untyped): untyped =
  when compiles(storageRelationship[instance.int].field):
    storageRelationship[instance.int].field = value
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type Relationship".}

template isOwnedComponent*(value`gensym175: typedesc[RelationshipInstance] |
    RelationshipInstance |
    Relationship): bool =
  false

template access*(instance`gensym175: RelationshipInstance): Relationship =
  storageRelationship[instance`gensym175.int]

template alive*(inst`gensym175: RelationshipInstance): bool =
  ## Check if this component ref's index is still in use.
  inst`gensym175.int > 0 and inst`gensym175.int < relationshipAlive.len and
      relationshipAlive[inst`gensym175.int] == true

template valid*(inst`gensym175: RelationshipInstance): bool =
  inst`gensym175.int != InvalidComponentIndex.int

template generation*(inst`gensym175: RelationshipInstance): untyped =
  ## Access the generation of this component.
  RelationshipGeneration(relationshipInstanceIds[inst`gensym175.int]).ComponentGeneration

template componentStorage*(value`gensym175: typedesc[RelationshipInstance] |
    RelationshipInstance |
    Relationship): untyped =
  storageRelationship

template ownerSystemIndex*(value`gensym175: typedesc[RelationshipInstance] |
    RelationshipInstance |
    Relationship): untyped =
  InvalidSystemIndex

template componentCount*(ty: typedesc[Relationship] |
    typedesc[RelationshipInstance]): untyped =
  ## Returns an estimate of the number of allocated components.
  ## This value is based on last index used and the number of indexes waiting to be used (from previous deletes).
  let freeCount`gensym184 = relationshipFreeIndexes.len
  storageRelationship.len - freeCount`gensym184

proc genRelationship*(): RelationshipInstance =
  ## Create a component instance for this type.
  result =
    var r`gensym181: RelationshipInstance
    if relationshipFreeIndexes.len > 0:
      r`gensym181 = relationshipFreeIndexes.pop
    else:
      r`gensym181 =
        let newLen`gensym178 = storageRelationship.len + 1
        storageRelationship.setLen(newLen`gensym178)
        relationshipInstanceIds.setLen(newLen`gensym178)
        relationshipAlive.setLen(newLen`gensym178)
        storageRelationship.high.RelationshipInstance
    assert r`gensym181.int != 0
    relationshipAlive[r`gensym181.int] = true
    relationshipInstanceIds[r`gensym181.int] += 1
    assert r`gensym181.int >= 0
    r`gensym181
  
proc delete*(instance: RelationshipInstance) =
  ## Free a component instance
  let idx = instance.int
  {.line.}:
    assert idx < relationshipAlive.len,
           "Cannot delete, instance is out of range"
  if relationshipAlive[idx]:
    relationshipAlive[idx] = false
    if idx == storageRelationship.high:
      let newLen`gensym179 = max(1, storageRelationship.len - 1)
      storageRelationship.setLen(newLen`gensym179)
      relationshipInstanceIds.setLen(newLen`gensym179)
      relationshipAlive.setLen(newLen`gensym179)
    elif relationshipFreeIndexes.high == storageRelationship.high:
      relationshipFreeIndexes.setLen(0)
    else:
      relationshipFreeIndexes.add idx.RelationshipInstance
  
template newInstance*(ty: typedesc[Relationship] |
    typedesc[RelationshipInstance]): RelationshipInstance =
  ## Create a new component instance. Does not update systems.
  let res`gensym184 = genRelationship()
  res`gensym184

proc newInstance*(value: Relationship): RelationshipInstance {.inline.} =
  ## Create a new component instance from the supplied value. Does not update systems.
  result =
    var r`gensym181: RelationshipInstance
    if relationshipFreeIndexes.len > 0:
      r`gensym181 = relationshipFreeIndexes.pop
    else:
      r`gensym181 =
        let newLen`gensym178 = storageRelationship.len + 1
        storageRelationship.setLen(newLen`gensym178)
        relationshipInstanceIds.setLen(newLen`gensym178)
        relationshipAlive.setLen(newLen`gensym178)
        storageRelationship.high.RelationshipInstance
    assert r`gensym181.int != 0
    relationshipAlive[r`gensym181.int] = true
    relationshipInstanceIds[r`gensym181.int] += 1
    assert r`gensym181.int >= 0
    r`gensym181
  storageRelationship[result.int] = value
  
template newInstance*(ty: typedesc[Relationship] |
    typedesc[RelationshipInstance]; val`gensym184: Component): untyped =
  ## Creates a new component from a generated `ref` component descendant. Does not update systems.
  newInstance(RelationshipRef(val`gensym184).value)

template delInstance*(ty: Relationship | RelationshipInstance): untyped =
  ## Marks a component as deleted. Does not update systems.
  ty.delete()

template update*(instance: RelationshipInstance; value: Relationship): untyped =
  ## Update storage.
  ## `update` operates as a simple assignment into the storage array and uses the type's `==` proc.
  storageRelationship[instance.int] = value

template `==`*(i1`gensym185, i2`gensym185: RelationshipInstance): bool =
  i1`gensym185.int == i2`gensym185.int

template toRef*(inst`gensym185: RelationshipInstance): ComponentRef =
  ## Utility function that takes this type's distinct `ComponentIndex`,
  ## returned for example from fetchComponent, and creates a reference
  ## tuple for the live component currently at this index.
  let i`gensym185 = inst`gensym185
  (i`gensym185.typeId, i`gensym185.ComponentIndex, i`gensym185.generation)

template accessType*(ty: RootSceneInstance | typedesc[RootSceneInstance]): untyped =
  ## Returns the source component type of a component instance.
  ## This can also be achieved with `instance.access.type`.
  typedesc[RootScene]

template `.`*(instance: RootSceneInstance; field: untyped): untyped =
  when compiles(storageRootScene[instance.int].field):
    storageRootScene[instance.int].field
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type RootScene".}

template `.=`*(instance: RootSceneInstance; field: untyped; value: untyped): untyped =
  when compiles(storageRootScene[instance.int].field):
    storageRootScene[instance.int].field = value
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type RootScene".}

template isOwnedComponent*(value`gensym190: typedesc[RootSceneInstance] |
    RootSceneInstance |
    RootScene): bool =
  false

template access*(instance`gensym190: RootSceneInstance): RootScene =
  storageRootScene[instance`gensym190.int]

template alive*(inst`gensym190: RootSceneInstance): bool =
  ## Check if this component ref's index is still in use.
  inst`gensym190.int > 0 and inst`gensym190.int < rootsceneAlive.len and
      rootsceneAlive[inst`gensym190.int] == true

template valid*(inst`gensym190: RootSceneInstance): bool =
  inst`gensym190.int != InvalidComponentIndex.int

template generation*(inst`gensym190: RootSceneInstance): untyped =
  ## Access the generation of this component.
  RootSceneGeneration(rootsceneInstanceIds[inst`gensym190.int]).ComponentGeneration

template componentStorage*(value`gensym190: typedesc[RootSceneInstance] |
    RootSceneInstance |
    RootScene): untyped =
  storageRootScene

template ownerSystemIndex*(value`gensym190: typedesc[RootSceneInstance] |
    RootSceneInstance |
    RootScene): untyped =
  InvalidSystemIndex

template componentCount*(ty: typedesc[RootScene] |
    typedesc[RootSceneInstance]): untyped =
  ## Returns an estimate of the number of allocated components.
  ## This value is based on last index used and the number of indexes waiting to be used (from previous deletes).
  let freeCount`gensym199 = rootsceneFreeIndexes.len
  storageRootScene.len - freeCount`gensym199

proc genRootScene*(): RootSceneInstance =
  ## Create a component instance for this type.
  result =
    var r`gensym196: RootSceneInstance
    if rootsceneFreeIndexes.len > 0:
      r`gensym196 = rootsceneFreeIndexes.pop
    else:
      r`gensym196 =
        let newLen`gensym193 = storageRootScene.len + 1
        storageRootScene.setLen(newLen`gensym193)
        rootsceneInstanceIds.setLen(newLen`gensym193)
        rootsceneAlive.setLen(newLen`gensym193)
        storageRootScene.high.RootSceneInstance
    assert r`gensym196.int != 0
    rootsceneAlive[r`gensym196.int] = true
    rootsceneInstanceIds[r`gensym196.int] += 1
    assert r`gensym196.int >= 0
    r`gensym196
  
proc delete*(instance: RootSceneInstance) =
  ## Free a component instance
  let idx = instance.int
  {.line.}:
    assert idx < rootsceneAlive.len, "Cannot delete, instance is out of range"
  if rootsceneAlive[idx]:
    rootsceneAlive[idx] = false
    if idx == storageRootScene.high:
      let newLen`gensym194 = max(1, storageRootScene.len - 1)
      storageRootScene.setLen(newLen`gensym194)
      rootsceneInstanceIds.setLen(newLen`gensym194)
      rootsceneAlive.setLen(newLen`gensym194)
    elif rootsceneFreeIndexes.high == storageRootScene.high:
      rootsceneFreeIndexes.setLen(0)
    else:
      rootsceneFreeIndexes.add idx.RootSceneInstance
  
template newInstance*(ty: typedesc[RootScene] |
    typedesc[RootSceneInstance]): RootSceneInstance =
  ## Create a new component instance. Does not update systems.
  let res`gensym199 = genRootScene()
  res`gensym199

proc newInstance*(value: RootScene): RootSceneInstance {.inline.} =
  ## Create a new component instance from the supplied value. Does not update systems.
  result =
    var r`gensym196: RootSceneInstance
    if rootsceneFreeIndexes.len > 0:
      r`gensym196 = rootsceneFreeIndexes.pop
    else:
      r`gensym196 =
        let newLen`gensym193 = storageRootScene.len + 1
        storageRootScene.setLen(newLen`gensym193)
        rootsceneInstanceIds.setLen(newLen`gensym193)
        rootsceneAlive.setLen(newLen`gensym193)
        storageRootScene.high.RootSceneInstance
    assert r`gensym196.int != 0
    rootsceneAlive[r`gensym196.int] = true
    rootsceneInstanceIds[r`gensym196.int] += 1
    assert r`gensym196.int >= 0
    r`gensym196
  storageRootScene[result.int] = value
  
template newInstance*(ty: typedesc[RootScene] |
    typedesc[RootSceneInstance]; val`gensym199: Component): untyped =
  ## Creates a new component from a generated `ref` component descendant. Does not update systems.
  newInstance(RootSceneRef(val`gensym199).value)

template delInstance*(ty: RootScene | RootSceneInstance): untyped =
  ## Marks a component as deleted. Does not update systems.
  ty.delete()

template update*(instance: RootSceneInstance; value: RootScene): untyped =
  ## Update storage.
  ## `update` operates as a simple assignment into the storage array and uses the type's `==` proc.
  storageRootScene[instance.int] = value

template `==`*(i1`gensym200, i2`gensym200: RootSceneInstance): bool =
  i1`gensym200.int == i2`gensym200.int

template toRef*(inst`gensym200: RootSceneInstance): ComponentRef =
  ## Utility function that takes this type's distinct `ComponentIndex`,
  ## returned for example from fetchComponent, and creates a reference
  ## tuple for the live component currently at this index.
  let i`gensym200 = inst`gensym200
  (i`gensym200.typeId, i`gensym200.ComponentIndex, i`gensym200.generation)

template accessType*(ty: OpenGLModelInstance | typedesc[OpenGLModelInstance]): untyped =
  ## Returns the source component type of a component instance.
  ## This can also be achieved with `instance.access.type`.
  typedesc[OpenGLModel]

template `.`*(instance: OpenGLModelInstance; field: untyped): untyped =
  when compiles(storageOpenGLModel[instance.int].field):
    storageOpenGLModel[instance.int].field
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type OpenGLModel".}

template `.=`*(instance: OpenGLModelInstance; field: untyped; value: untyped): untyped =
  when compiles(storageOpenGLModel[instance.int].field):
    storageOpenGLModel[instance.int].field = value
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type OpenGLModel".}

template isOwnedComponent*(value`gensym205: typedesc[OpenGLModelInstance] |
    OpenGLModelInstance |
    OpenGLModel): bool =
  false

template access*(instance`gensym205: OpenGLModelInstance): OpenGLModel =
  storageOpenGLModel[instance`gensym205.int]

template alive*(inst`gensym205: OpenGLModelInstance): bool =
  ## Check if this component ref's index is still in use.
  inst`gensym205.int > 0 and inst`gensym205.int < openglmodelAlive.len and
      openglmodelAlive[inst`gensym205.int] == true

template valid*(inst`gensym205: OpenGLModelInstance): bool =
  inst`gensym205.int != InvalidComponentIndex.int

template generation*(inst`gensym205: OpenGLModelInstance): untyped =
  ## Access the generation of this component.
  OpenGLModelGeneration(openglmodelInstanceIds[inst`gensym205.int]).ComponentGeneration

template componentStorage*(value`gensym205: typedesc[OpenGLModelInstance] |
    OpenGLModelInstance |
    OpenGLModel): untyped =
  storageOpenGLModel

template ownerSystemIndex*(value`gensym205: typedesc[OpenGLModelInstance] |
    OpenGLModelInstance |
    OpenGLModel): untyped =
  InvalidSystemIndex

template componentCount*(ty: typedesc[OpenGLModel] |
    typedesc[OpenGLModelInstance]): untyped =
  ## Returns an estimate of the number of allocated components.
  ## This value is based on last index used and the number of indexes waiting to be used (from previous deletes).
  let freeCount`gensym214 = openglmodelFreeIndexes.len
  storageOpenGLModel.len - freeCount`gensym214

proc genOpenGLModel*(): OpenGLModelInstance =
  ## Create a component instance for this type.
  result =
    var r`gensym211: OpenGLModelInstance
    if openglmodelFreeIndexes.len > 0:
      r`gensym211 = openglmodelFreeIndexes.pop
    else:
      r`gensym211 =
        let newLen`gensym208 = storageOpenGLModel.len + 1
        storageOpenGLModel.setLen(newLen`gensym208)
        openglmodelInstanceIds.setLen(newLen`gensym208)
        openglmodelAlive.setLen(newLen`gensym208)
        storageOpenGLModel.high.OpenGLModelInstance
    assert r`gensym211.int != 0
    openglmodelAlive[r`gensym211.int] = true
    openglmodelInstanceIds[r`gensym211.int] += 1
    assert r`gensym211.int >= 0
    r`gensym211
  
proc delete*(instance: OpenGLModelInstance) =
  ## Free a component instance
  let idx = instance.int
  {.line.}:
    assert idx < openglmodelAlive.len, "Cannot delete, instance is out of range"
  if openglmodelAlive[idx]:
    openglmodelAlive[idx] = false
    if idx == storageOpenGLModel.high:
      let newLen`gensym209 = max(1, storageOpenGLModel.len - 1)
      storageOpenGLModel.setLen(newLen`gensym209)
      openglmodelInstanceIds.setLen(newLen`gensym209)
      openglmodelAlive.setLen(newLen`gensym209)
    elif openglmodelFreeIndexes.high == storageOpenGLModel.high:
      openglmodelFreeIndexes.setLen(0)
    else:
      openglmodelFreeIndexes.add idx.OpenGLModelInstance
  
template newInstance*(ty: typedesc[OpenGLModel] |
    typedesc[OpenGLModelInstance]): OpenGLModelInstance =
  ## Create a new component instance. Does not update systems.
  let res`gensym214 = genOpenGLModel()
  res`gensym214

proc newInstance*(value: OpenGLModel): OpenGLModelInstance {.inline.} =
  ## Create a new component instance from the supplied value. Does not update systems.
  result =
    var r`gensym211: OpenGLModelInstance
    if openglmodelFreeIndexes.len > 0:
      r`gensym211 = openglmodelFreeIndexes.pop
    else:
      r`gensym211 =
        let newLen`gensym208 = storageOpenGLModel.len + 1
        storageOpenGLModel.setLen(newLen`gensym208)
        openglmodelInstanceIds.setLen(newLen`gensym208)
        openglmodelAlive.setLen(newLen`gensym208)
        storageOpenGLModel.high.OpenGLModelInstance
    assert r`gensym211.int != 0
    openglmodelAlive[r`gensym211.int] = true
    openglmodelInstanceIds[r`gensym211.int] += 1
    assert r`gensym211.int >= 0
    r`gensym211
  storageOpenGLModel[result.int] = value
  
template newInstance*(ty: typedesc[OpenGLModel] |
    typedesc[OpenGLModelInstance]; val`gensym214: Component): untyped =
  ## Creates a new component from a generated `ref` component descendant. Does not update systems.
  newInstance(OpenGLModelRef(val`gensym214).value)

template delInstance*(ty: OpenGLModel | OpenGLModelInstance): untyped =
  ## Marks a component as deleted. Does not update systems.
  ty.delete()

template update*(instance: OpenGLModelInstance; value: OpenGLModel): untyped =
  ## Update storage.
  ## `update` operates as a simple assignment into the storage array and uses the type's `==` proc.
  storageOpenGLModel[instance.int] = value

template `==`*(i1`gensym215, i2`gensym215: OpenGLModelInstance): bool =
  i1`gensym215.int == i2`gensym215.int

template toRef*(inst`gensym215: OpenGLModelInstance): ComponentRef =
  ## Utility function that takes this type's distinct `ComponentIndex`,
  ## returned for example from fetchComponent, and creates a reference
  ## tuple for the live component currently at this index.
  let i`gensym215 = inst`gensym215
  (i`gensym215.typeId, i`gensym215.ComponentIndex, i`gensym215.generation)

storageLocation.setLen 1
locationAlive.setLen 1
locationInstanceIds.setLen 1
locationNextIndex = FIRST_COMPONENT_ID.LocationInstance
storageRotation.setLen 1
rotationAlive.setLen 1
rotationInstanceIds.setLen 1
rotationNextIndex = FIRST_COMPONENT_ID.RotationInstance
storageScale.setLen 1
scaleAlive.setLen 1
scaleInstanceIds.setLen 1
scaleNextIndex = FIRST_COMPONENT_ID.ScaleInstance
storageTransformMat.setLen 1
transformmatAlive.setLen 1
transformmatInstanceIds.setLen 1
transformmatNextIndex = FIRST_COMPONENT_ID.TransformMatInstance
storageRelationship.setLen 1
relationshipAlive.setLen 1
relationshipInstanceIds.setLen 1
relationshipNextIndex = FIRST_COMPONENT_ID.RelationshipInstance
storageRootScene.setLen 1
rootsceneAlive.setLen 1
rootsceneInstanceIds.setLen 1
rootsceneNextIndex = FIRST_COMPONENT_ID.RootSceneInstance
storageOpenGLModel.setLen 1
openglmodelAlive.setLen 1
openglmodelInstanceIds.setLen 1
openglmodelNextIndex = FIRST_COMPONENT_ID.OpenGLModelInstance
type
  ComponentTypeClass* = Location | Rotation | Scale | TransformMat |
      Relationship |
      RootScene |
      OpenGLModel
type
  ComponentRefTypeClass* = LocationRef | RotationRef | ScaleRef |
      TransformMatRef |
      RelationshipRef |
      RootSceneRef |
      OpenGLModelRef
type
  ComponentIndexTypeClass* = LocationInstance | RotationInstance | ScaleInstance |
      TransformMatInstance |
      RelationshipInstance |
      RootSceneInstance |
      OpenGLModelInstance
proc add*(items`gensym219: var ComponentList; component`gensym219: ComponentTypeClass |
    ComponentIndexTypeClass |
    ComponentRefTypeClass) =
  ## Add a component to a component list, automatically handling `typeId`.
  when component`gensym219 is ComponentRefTypeClass:
    const
      cRange`gensym219 = EcsIdentity("default").typeIdRange()
    if component`gensym219.typeId.int notin
        cRange`gensym219.a.int .. cRange`gensym219.b.int:
      var copy`gensym219 = component`gensym219
      copy`gensym219.fTypeId = component`gensym219.typeId()
      add items`gensym219, copy`gensym219
    else:
      add items`gensym219, component`gensym219
  else:
    add items`gensym219, component`gensym219.makeContainer()
  assert items`gensym219[^1].typeId != InvalidComponent,
         "Could not resolve type id for " & $component`gensym219.type

type
  ComponentsEnum* {.used.} = enum
    ceInvalid, ceLocation = 1, ceRotation = 2, ceScale = 3, ceTransformMat = 4,
    ceRelationship = 5, ceRootScene = 6, ceOpenGLModel = 7
type
  SystemsEnum* {.used.} = enum
    seInvalidSystem = 0, seResetTransMat = 1, seUpdateSceneInheritance = 2,
    seRender = 3
type
  EntityComponentItem* = object
    setup*: bool
    instance*: EntityInstance
    componentRefs*: seq[ComponentRef]

  EntityStorageItems = seq[EntityComponentItem]
  EntityStorage* = object
    entityComponents: EntityStorageItems ## Stores the entity-component state data.
    entityCounter: int
    entityRecycler: seq[EntityId]
    nextEntityId: EntityId

proc initEntityStorage(value: var EntityStorage) =
  ## Initialiser for entity state.
  value.nextEntityId = FIRST_ENTITY_ID

var entityStorage*: EntityStorage
initEntityStorage(entityStorage)
template entityData*(entityId: EntityId): untyped =
  entityStorage.entityComponents[entityId.int]

proc lastEntityId*(): EntityId =
  (entityStorage.nextEntityId.IdBaseType - 1.IdBaseType).EntityId

proc `==`*(eRef`gensym227: EntityRef; e`gensym227: EntityId): bool {.inline.} =
  eRef`gensym227.entityId.IdBaseType == e`gensym227.IdBaseType and
      eRef`gensym227.instance.IdBaseType ==
      entityData(e`gensym227).instance.IdBaseType

proc isCurrent*(eRef`gensym227: EntityRef): bool =
  eRef`gensym227.instance.IdBaseType ==
      entityData(eRef`gensym227.entityId).instance.IdBaseType

template `==`*(live`gensym227: EntityId; eRef`gensym227: EntityRef): bool =
  eRef`gensym227.entityId.IdBaseType == live`gensym227.IdBaseType and
      eRef`gensym227.instance.IdBaseType ==
      entityData(live`gensym227).instance.IdBaseType

proc instance*(e`gensym227: EntityId): EntityInstance {.inline.} =
  entityData(e`gensym227).instance

proc instance*(e`gensym227: EntityRef): EntityInstance {.inline.} =
  entityData(e`gensym227.entityId).instance

proc makeRef*(entityId`gensym227: EntityId): EntityRef {.inline.} =
  (entityId`gensym227, entityData(entityId`gensym227).instance)

proc entityCount*(): int =
  ## Returns the number of alive entities.
  entityStorage.entityCounter

proc high*(entityType`gensym227: typedesc[EntityId] |
    typedesc[EntityRef]): int =
  entityStorage.entityComponents.len

template alive*(entity`gensym227: EntityId): bool =
  ## Checks the entity id (the slot, not instance) is valid
  ## (not NO_ENTITY) and that its index has been initialised.
  entity`gensym227.valid and entity`gensym227.int >= 1 and
      entity`gensym227.int <= entityStorage.entityComponents.len and
      entityData(entity`gensym227).setup

template alive*(entRef`gensym227: EntityRef): bool =
  ## Checks that the instance matches the referenced entity, ie; if
  ## the entity has been deleted/recreated since the reference was
  ## made, as well as checking if the entity itself is valid and
  ## initialised.
  entRef`gensym227.entityId.alive and
      entityData(entRef`gensym227.entityId).instance.int ==
      entRef`gensym227.instance.int

template components*(entity`gensym227: EntityRef; index`gensym227: int): untyped =
  ## Access to entity's components.
  assert entity`gensym227.alive
  entityData(entityId).componentRefs[index`gensym227]

template withComponent*(entity`gensym227: EntityRef;
                        t`gensym227: typedesc[ComponentTypeClass];
                        actions`gensym227: untyped): untyped =
  block:
    let component {.inject.} = entity`gensym227.fetchComponent(t`gensym227)
    actions`gensym227

proc hasComponent*(entity: EntityRef; componentTypeId: ComponentTypeId): bool =
  let entityId = entity.entityId
  if not entity.alive:
    var str`gensym229 = "hasComponent on dead entity: " & $entityId.int &
        " instance " &
        $(entityId.instance.int)
    if entityId != entity:
      str`gensym229 &=
          " expected instance " & $entity.instance.int & " type " &
          $componentTypeId.int
    assert false, str`gensym229
  if entityData(entityId).setup:
    for c`gensym228 in entityData(entityId).componentRefs:
      if c`gensym228.typeId == componentTypeId:
        return true

template hasComponent*(entity`gensym229: EntityRef;
                       t`gensym229: typedesc[ComponentTypeClass]): untyped =
  entity`gensym229.hasComponent t`gensym229.typeId

template has*(entity`gensym229: EntityRef;
              t`gensym229: typedesc[ComponentTypeClass]): untyped =
  ## Returns true if the entity contains `t`.
  entity`gensym229.hasComponent t`gensym229

template has*(entity`gensym229: EntityRef; t`gensym229: varargs[untyped]): untyped =
  ## Returns true if the entity contains all of the components listed in `t`.
  let fetched`gensym229 = entity`gensym229.fetch t`gensym229
  var r`gensym229: bool
  block hasMain`gensym229:
    for field`gensym229, value`gensym229 in fetched`gensym229.fieldPairs:
      if not value`gensym229.valid:
        break hasMain`gensym229
    r`gensym229 = true
  r`gensym229

template hasAny*(entity`gensym229: EntityRef; t`gensym229: varargs[untyped]): untyped =
  ## Returns true if the entity contains any of the components listed in `t`.
  let fetched`gensym229 = entity`gensym229.fetch t`gensym229
  var r`gensym229: bool
  block hasMain`gensym229:
    for field`gensym229, value`gensym229 in fetched`gensym229.fieldPairs:
      if value`gensym229.valid:
        r`gensym229 = true
        break hasMain`gensym229
  r`gensym229

proc contains*(entity`gensym229: EntityRef; componentTypeId: ComponentTypeId): bool {.
    inline.} =
  entity`gensym229.hasComponent(componentTypeId)

template contains*(entity`gensym229: EntityRef;
                   t`gensym229: typedesc[ComponentTypeClass]): untyped =
  entity`gensym229.hasComponent(t`gensym229.typeId)

iterator components*(entityId: EntityId): ComponentRef =
  ## Iterate through components.
  for item`gensym231 in entityData(entityId).componentRefs:
    yield item`gensym231

iterator pairs*(entityId: EntityId): (int, ComponentRef) =
  ## Iterate through components.
  for i`gensym231, item`gensym231 in entityData(entityId).componentRefs.pairs:
    yield (i`gensym231, item`gensym231)

proc componentCount*(entityId: EntityId): int =
  entityData(entityId).componentRefs.len

proc componentCount*(entityRef`gensym232: EntityRef): int =
  entityRef`gensym232.entityId.componentCount

template components*(entity`gensym232: EntityRef): untyped =
  entity`gensym232.entityId.components

iterator items*(entity`gensym232: EntityRef): ComponentRef =
  for comp`gensym232 in entity`gensym232.entityId.components:
    yield comp`gensym232

template pairs*(entity`gensym232: EntityRef): (int, ComponentRef) =
  entity`gensym232.entityId.pairs

template forAllEntities*(actions`gensym232: untyped) =
  ## Walk all active entities.
  var found`gensym232, pos`gensym232: int
  while found`gensym232 < entityCount():
    if entityData(pos`gensym232.EntityId).setup:
      let
        index {.inject, used.} = found`gensym232
        storageIndex {.inject, used.} = pos`gensym232
        entity {.inject.}: EntityRef = (pos`gensym232.EntityId, entityData(
            pos`gensym232.EntityId).instance)
      actions`gensym232
      found`gensym232 += 1
    pos`gensym232 += 1

proc newEntity*(): EntityRef =
  var entityId: EntityId
  if entityStorage.entityRecycler.len > 0:
    entityId = entityStorage.entityRecycler.pop
  else:
    entityId = entityStorage.nextEntityId
    entityStorage.entityComponents.setLen entityStorage.nextEntityId.int + 1
    entityStorage.nextEntityId = entityStorage.entityComponents.len.EntityId
  assert entityData(entityId).setup == false, "Overwriting EntityId = " &
      $entityId.int &
      " counter = " &
      $entityStorage.entityCounter
  entityStorage.entityCounter += 1
  entityData(entityId).setup = true
  let i`gensym236 = (entityData(entityId).instance.IdBaseType + 1).EntityInstance
  entityData(entityId).instance = i`gensym236
  (entityId, i`gensym236)

template alive*(compRef`gensym237: ComponentRef): bool =
  ## Check if this component ref's index is still valid and active.
  ## Requires use of run-time case statement to match against type id.
  let index`gensym237 = compRef`gensym237.index.int
  var r`gensym237: bool
  caseComponent compRef`gensym237.typeId:
    r`gensym237 = componentAlive()[index`gensym237] and
        compRef`gensym237.generation.int ==
        componentGenerations()[index`gensym237]
  r`gensym237

macro fetchComponents*(entity: EntityRef;
                       components`gensym239: varargs[typed]): untyped =
  ## Generate code to look up a list of components from an entity,
  ## returning a tuple of fetched instances for the component.
  ## 
  ## Components that were not found will be `InvalidComponent`.
  ## 
  ## Example:
  ## 
  ##   let results = entity.fetch Comp1, Comp2
  ##   echo results.comp1
  ##   echo results.comp2
  doFetchComponents(EcsIdentity("default"), entity, components`gensym239)

template fetch*(entity: EntityRef; components`gensym239: varargs[typed]): untyped =
  fetchComponents(entity, components`gensym239)

template fetchComponent*(entity: EntityRef; t`gensym239: typedesc): auto =
  ## Looks up and returns the instance of the component, which allows direct field access.
  ## Returns default no component index if the component cannot be found.
  ## Eg;
  ##   let comp = entity.fetchComponent CompType  # Will be of type CompTypeInstance
  ##   comp.x = 3 # Edit some supposed fields for this component.
  fetchComponents(entity, t`gensym239)[0]

template fetch*(entity: EntityRef; component`gensym239: typedesc): auto =
  fetchComponent(entity, component`gensym239)

template caseComponent*(id: ComponentTypeId; actions: untyped): untyped =
  ## Creates a case statement that matches `id` with its component.
  ## 
  ## Note:
  ## * Has no concept of entity, this is a static case statement with injected
  ##   actions.
  ## * The same action block is compiled for every component.
  ## 
  ## For example, the following will display the name of a run-time component type id.
  ## 
  ## .. code-block:: nim
  ##   myCompId.caseComponent:
  ##     echo "Component Name: ", componentName
  ## 
  ## Within `actions`, the following templates provide typed access to the runtime index.
  ## 
  ##   - `componentId`: the ComponentTypeId of the component.
  ##   - `componentName`: string name.
  ##   - `componentType`: static type represented by `id`.
  ##   - `componentInstanceType`: index type, eg; MyComponentInstance.
  ##   - `componentRefType`: ref type for this component, eg: MyComponentRef.
  ##   - `componentDel`: delete procedure for this type.
  ##   - `componentAlive`: direct access to proc to test if this component is alive.
  ##   - `componentGenerations`: direct access to the generation values for this type.
  ##   - `componentData`: direct access to the storage list for this component.
  ##   - `isOwned: returns `true` when the component is owned by a system, or `false` otherwise.
  ##   - `owningSystemIndex`: the `SystemIndex` of the owner system, or `InvalidSystemIndex` if the component is not owned.
  ##   - `owningSystem`: this is only included for owned components, and references the owner system variable.
  case id.int
  of 1:
    template componentId(): untyped {.used.} =
      1.ComponentTypeId

    template componentName(): untyped {.used.} =
      "Location"

    template componentType(): untyped {.used.} =
      Location

    template componentRefType(): untyped {.used.} =
      LocationRef

    template componentDel(index`gensym241: LocationInstance): untyped {.used.} =
      delete(index`gensym241)

    template componentAlive(): untyped {.used.} =
      locationAlive

    template componentGenerations(): untyped {.used.} =
      locationInstanceIds

    template componentInstanceType(): untyped {.used.} =
      LocationInstance

    template componentData(): untyped {.used.} =
      storageLocation

    template isOwned(): bool {.used.} =
      false

    template owningSystemIndex(): SystemIndex {.used.} =
      0.SystemIndex

    actions
  of 2:
    template componentId(): untyped {.used.} =
      2.ComponentTypeId

    template componentName(): untyped {.used.} =
      "Rotation"

    template componentType(): untyped {.used.} =
      Rotation

    template componentRefType(): untyped {.used.} =
      RotationRef

    template componentDel(index`gensym242: RotationInstance): untyped {.used.} =
      delete(index`gensym242)

    template componentAlive(): untyped {.used.} =
      rotationAlive

    template componentGenerations(): untyped {.used.} =
      rotationInstanceIds

    template componentInstanceType(): untyped {.used.} =
      RotationInstance

    template componentData(): untyped {.used.} =
      storageRotation

    template isOwned(): bool {.used.} =
      false

    template owningSystemIndex(): SystemIndex {.used.} =
      0.SystemIndex

    actions
  of 3:
    template componentId(): untyped {.used.} =
      3.ComponentTypeId

    template componentName(): untyped {.used.} =
      "Scale"

    template componentType(): untyped {.used.} =
      Scale

    template componentRefType(): untyped {.used.} =
      ScaleRef

    template componentDel(index`gensym243: ScaleInstance): untyped {.used.} =
      delete(index`gensym243)

    template componentAlive(): untyped {.used.} =
      scaleAlive

    template componentGenerations(): untyped {.used.} =
      scaleInstanceIds

    template componentInstanceType(): untyped {.used.} =
      ScaleInstance

    template componentData(): untyped {.used.} =
      storageScale

    template isOwned(): bool {.used.} =
      false

    template owningSystemIndex(): SystemIndex {.used.} =
      0.SystemIndex

    actions
  of 4:
    template componentId(): untyped {.used.} =
      4.ComponentTypeId

    template componentName(): untyped {.used.} =
      "TransformMat"

    template componentType(): untyped {.used.} =
      TransformMat

    template componentRefType(): untyped {.used.} =
      TransformMatRef

    template componentDel(index`gensym244: TransformMatInstance): untyped {.used.} =
      delete(index`gensym244)

    template componentAlive(): untyped {.used.} =
      transformmatAlive

    template componentGenerations(): untyped {.used.} =
      transformmatInstanceIds

    template componentInstanceType(): untyped {.used.} =
      TransformMatInstance

    template componentData(): untyped {.used.} =
      storageTransformMat

    template isOwned(): bool {.used.} =
      false

    template owningSystemIndex(): SystemIndex {.used.} =
      0.SystemIndex

    actions
  of 5:
    template componentId(): untyped {.used.} =
      5.ComponentTypeId

    template componentName(): untyped {.used.} =
      "Relationship"

    template componentType(): untyped {.used.} =
      Relationship

    template componentRefType(): untyped {.used.} =
      RelationshipRef

    template componentDel(index`gensym245: RelationshipInstance): untyped {.used.} =
      delete(index`gensym245)

    template componentAlive(): untyped {.used.} =
      relationshipAlive

    template componentGenerations(): untyped {.used.} =
      relationshipInstanceIds

    template componentInstanceType(): untyped {.used.} =
      RelationshipInstance

    template componentData(): untyped {.used.} =
      storageRelationship

    template isOwned(): bool {.used.} =
      false

    template owningSystemIndex(): SystemIndex {.used.} =
      0.SystemIndex

    actions
  of 6:
    template componentId(): untyped {.used.} =
      6.ComponentTypeId

    template componentName(): untyped {.used.} =
      "RootScene"

    template componentType(): untyped {.used.} =
      RootScene

    template componentRefType(): untyped {.used.} =
      RootSceneRef

    template componentDel(index`gensym246: RootSceneInstance): untyped {.used.} =
      delete(index`gensym246)

    template componentAlive(): untyped {.used.} =
      rootsceneAlive

    template componentGenerations(): untyped {.used.} =
      rootsceneInstanceIds

    template componentInstanceType(): untyped {.used.} =
      RootSceneInstance

    template componentData(): untyped {.used.} =
      storageRootScene

    template isOwned(): bool {.used.} =
      false

    template owningSystemIndex(): SystemIndex {.used.} =
      0.SystemIndex

    actions
  of 7:
    template componentId(): untyped {.used.} =
      7.ComponentTypeId

    template componentName(): untyped {.used.} =
      "OpenGLModel"

    template componentType(): untyped {.used.} =
      OpenGLModel

    template componentRefType(): untyped {.used.} =
      OpenGLModelRef

    template componentDel(index`gensym247: OpenGLModelInstance): untyped {.used.} =
      delete(index`gensym247)

    template componentAlive(): untyped {.used.} =
      openglmodelAlive

    template componentGenerations(): untyped {.used.} =
      openglmodelInstanceIds

    template componentInstanceType(): untyped {.used.} =
      OpenGLModelInstance

    template componentData(): untyped {.used.} =
      storageOpenGLModel

    template isOwned(): bool {.used.} =
      false

    template owningSystemIndex(): SystemIndex {.used.} =
      0.SystemIndex

    actions
  else:
    {.line.}:
      assert false, "Invalid component type id: " & $(id.toInt)
  
template caseSystem*(index: SystemIndex; actions: untyped): untyped =
  ## Creates a case statement that matches a `SystemIndex` with its instantiation.
  ## This generates a runtime case statement that will perform `actions`
  ## for all systems.
  ## 
  ## `actions` is executed using the correct `system` context
  ## for the runtime system.
  ## 
  ## This allows you to write generic code that dynamically applies to any system
  ## chosen at runtime.
  ## 
  ## Within `caseSystem`, use the `sys` template to access to the system
  ## variable the index represents, and `ItemType` to get the type of an
  ## `item` in the system `groups` list.
  case index.int
  of 1:
    template sys(): untyped {.used.} =
      sysResetTransMat

    template ItemType(): typedesc {.used.} =
      SysItemResetTransMat

    actions
  of 2:
    template sys(): untyped {.used.} =
      sysUpdateSceneInheritance

    template ItemType(): typedesc {.used.} =
      SysItemUpdateSceneInheritance

    actions
  of 3:
    template sys(): untyped {.used.} =
      sysRender

    template ItemType(): typedesc {.used.} =
      SysItemRender

    actions
  else:
    raise newException(ValueError, "Invalid system index: " & $index.int)
  
template forAllSystems*(actions: untyped): untyped =
  ## This will perform `actions` for every system.
  ## Injects the `sys` template for easier operation.
  block:
    template sys(): untyped {.used.} =
      sysResetTransMat

    template ItemType(): typedesc {.used.} =
      SysItemResetTransMat

    actions
  block:
    template sys(): untyped {.used.} =
      sysUpdateSceneInheritance

    template ItemType(): typedesc {.used.} =
      SysItemUpdateSceneInheritance

    actions
  block:
    template sys(): untyped {.used.} =
      sysRender

    template ItemType(): typedesc {.used.} =
      SysItemRender

    actions

type
  SystemsTypeClass* = ResetTransMatSystem | UpdateSceneInheritanceSystem |
      RenderSystem
proc `$`*[T: ComponentIndexTypeClass](val`gensym260: T): string =
  ## Generic `$` for component indexes.
  if val`gensym260.valid:
    result = $val`gensym260.access
  else:
    if val`gensym260.int == InvalidComponentIndex.int:
      result = "<Invalid " & $T & ">"
    else:
      result = "<Out of bounds instance of " & $T & " (index: " &
          $val`gensym260.int &
          ")>"

proc `$`*(componentId`gensym260: ComponentTypeId): string =
  ## Display the name and id for a component type.
  componentId`gensym260.caseComponent:
    result = componentName() & " (" & `$`(int(componentId`gensym260)) & ")"

func typeName*(componentId`gensym260: ComponentTypeId): string =
  componentId`gensym260.caseComponent:
    result = componentName()

proc toString*(componentRef`gensym260: ComponentRef; showData: bool = true): string =
  ## Display the name, type and data for a component reference.
  let tId`gensym260 = componentRef`gensym260.typeId
  tId`gensym260.caseComponent:
    result = componentName() & " (id: " & `$`(int(tId`gensym260)) & ", index: " &
        `$`(componentRef`gensym260.index.int) &
        ", generation: " &
        `$`(componentRef`gensym260.generation.int) &
        ")"
    if showData:
      result &= ":\n"
      try:
        result &=
            `$`(componentInstanceType()(componentRef`gensym260.index.int).access)
      except:
        result &=
            "<ERROR ACCESSING (index: " & `$`(componentRef`gensym260.index.int) &
            ", count: " &
            $(componentInstanceType().componentCount).int &
            ")>\n"

proc `$`*(componentRef`gensym260: ComponentRef; showData: bool = true): string =
  componentRef`gensym260.toString(showData)

proc toString*(comp`gensym260: Component; showData = true): string =
  ## `$` function for dynamic component superclass.
  ## Displays the sub-class data according to the component's `typeId`.
  caseComponent comp`gensym260.typeId:
    result &= componentName()
    if showData:
      result &= ":\n" & $componentRefType()(comp`gensym260).value & "\n"

proc `$`*(comp`gensym260: Component): string =
  comp`gensym260.toString

proc toString*(componentList`gensym260: ComponentList; showData: bool = true): string =
  ## `$` for listing construction templates.
  let maxIdx`gensym260 = componentList`gensym260.high
  for i`gensym260, item`gensym260 in componentList`gensym260:
    let s`gensym260 = item`gensym260.toString(showData)
    if i`gensym260 < maxIdx`gensym260 and not showData:
      result &= s`gensym260 & ", "
    else:
      result &= s`gensym260

proc `$`*(componentList`gensym260: ComponentList): string =
  componentList`gensym260.toString

proc toString*(construction`gensym260: ConstructionTemplate;
               showData: bool = true): string =
  for i`gensym260, item`gensym260 in construction`gensym260:
    result &= `$`(i`gensym260) & ": " & item`gensym260.toString(showData) & "\n"

proc `$`*(construction`gensym260: ConstructionTemplate): string =
  construction`gensym260.toString

proc componentCount*(): int =
  7

proc listSystems*(entity: EntityRef): string =
  if entity.alive:
    var matchesEnt_452986860 = true
    for req`gensym262 in [1'u, 2'u, 3'u, 4'u]:
      if req`gensym262.ComponentTypeId notin entity:
        matchesEnt_452986860 = false
        break
    let inSys`gensym263 = sysResetTransMat.index.hasKey(entity.entityId)
    if matchesEnt_452986860 != inSys`gensym263:
      let issue`gensym263 = if matchesEnt_452986860:
        "[System]: entity contains the required components but is missing from the system index" else:
        "[Entity]: the system index references this entity but the entity doesn\'t have the required components"
      result &=
          "resetTransMat (sysResetTransMat)" & " Sync issue " & issue`gensym263 &
          "\n"
    elif inSys`gensym263:
      result &= "resetTransMat (sysResetTransMat)" & " \n"
    var matchesEnt_452986864 = true
    for req`gensym265 in [5'u, 4'u]:
      if req`gensym265.ComponentTypeId notin entity:
        matchesEnt_452986864 = false
        break
    let inSys`gensym266 = sysUpdateSceneInheritance.index.hasKey(entity.entityId)
    if matchesEnt_452986864 != inSys`gensym266:
      let issue`gensym266 = if matchesEnt_452986864:
        "[System]: entity contains the required components but is missing from the system index" else:
        "[Entity]: the system index references this entity but the entity doesn\'t have the required components"
      result &=
          "updateSceneInheritance (sysUpdateSceneInheritance)" & " Sync issue " &
          issue`gensym266 &
          "\n"
    elif inSys`gensym266:
      result &= "updateSceneInheritance (sysUpdateSceneInheritance)" & " \n"
    var matchesEnt_452986868 = true
    for req`gensym268 in [4'u, 7'u]:
      if req`gensym268.ComponentTypeId notin entity:
        matchesEnt_452986868 = false
        break
    let inSys`gensym269 = sysRender.index.hasKey(entity.entityId)
    if matchesEnt_452986868 != inSys`gensym269:
      let issue`gensym269 = if matchesEnt_452986868:
        "[System]: entity contains the required components but is missing from the system index" else:
        "[Entity]: the system index references this entity but the entity doesn\'t have the required components"
      result &= "render (sysRender)" & " Sync issue " & issue`gensym269 & "\n"
    elif inSys`gensym269:
      result &= "render (sysRender)" & " \n"
  else:
    if entity == NO_ENTITY_REF:
      result = "<Entity is NO_ENTITY_REF>"
    else:
      result = "<Entity is not alive>"

proc listComponents*(entity`gensym272: EntityRef; showData`gensym272 = true): string =
  ## List all components attached to an entity.
  ## The parameter `showData` controls whether the component's data is included in the output.
  if entity`gensym272.alive:
    let entityId`gensym272 = entity`gensym272.entityId
    for compRef`gensym272 in entityId`gensym272.components:
      let compDesc`gensym272 = toString(compRef`gensym272, showData`gensym272)
      var
        owned`gensym272: bool
        genMax`gensym272: int
        genStr`gensym272: string
      try:
        caseComponent compRef`gensym272.typeId:
          genMax`gensym272 = componentGenerations().len
          let gen`gensym272 = componentGenerations()[compRef`gensym272.index.int]
          genStr`gensym272 = `$`(gen`gensym272)
          owned`gensym272 = componentInstanceType().isOwnedComponent
      except:
        genStr`gensym272 = " ERROR ACCESSING generations (index: " &
            `$`(compRef`gensym272.index.int) &
            ", count: " &
            `$`(genMax`gensym272) &
            ")"
      result &= compDesc`gensym272
      if owned`gensym272:
        if not compRef`gensym272.alive:
          result &=
              " <DEAD OWNED COMPONENT Type: " & `$`(compRef`gensym272.typeId) &
              ", generation: " &
              genStr`gensym272 &
              ">\n"
      else:
        if not compRef`gensym272.valid:
          result &=
              " <INVALID COMPONENT Type: " & `$`(compRef`gensym272.typeId) &
              ", generation: " &
              genStr`gensym272 &
              ">\n"
      let needsNL`gensym272 = result[^1] != '\n'
      if needsNL`gensym272:
        result &= "\n"
      if showData`gensym272:
        result &= "\n"
  else:
    result &= "[Entity not alive, no component item entry]\n"

proc `$`*(entity: EntityRef; showData`gensym272 = true): string =
  ## `$` function for `EntityRef`.
  ## List all components and what systems the entity uses.
  ## By default adds data inside components with `repr`.
  ## Set `showData` to false to just display the component types.
  let id`gensym272 = entity.entityId.int
  result = "[EntityId: " & $(id`gensym272)
  if id`gensym272 < 1 or id`gensym272 > entityStorage.entityComponents.len:
    result &= " Out of bounds!]"
  else:
    let
      comps`gensym272 = entity.listComponents(showData`gensym272)
      systems`gensym272 = entity.listSystems()
      sys`gensym272 = if systems`gensym272 == "":
        "<No systems used>\n" else:
        systems`gensym272
      invalidStr`gensym272 = if not entity.entityId.valid:
        " INVALID/NULL ENTITY ID" else:
        ""
    result &=
        " (generation: " & $(entity.instance.int) & ")" & invalidStr`gensym272 &
        "\nAlive: " &
        $entity.alive &
        "\nComponents:\n" &
        comps`gensym272 &
        "Systems:\n" &
        $sys`gensym272 &
        "]"

proc `$`*(entity: EntityId): string =
  ## Display the entity currently instantiated for this `EntityId`.
  `$`(entity.makeRef)

proc `$`*(sysIdx`gensym272: SystemIndex): string =
  ## Outputs the system name passed to `sysIdx`.
  caseSystem sysIdx`gensym272:
    systemStr(sys.name)

const
  totalSystemCount* {.used.} = 3
proc analyseSystem*[T](sys`gensym272: T; jumpThreshold`gensym272: Natural = 0): SystemAnalysis =
  ## Analyse a system for sequential component access by measuring
  ## the difference between consecutively accessed memory addresses.
  ## 
  ## Address deltas greater than `jumpThreshold` are counted in the field
  ## `forwardJumps`.
  ## 
  ## If `jumpThreshold` is zero, each component's `jumpThreshold` is set
  ## to the size of the component type in bytes.
  ## 
  ## The ideal access pattern is generally forward sequential memory access,
  ## minimising jumps and not moving backwards.
  ## 
  ## Passing `SystemAnalysis` to `$` outputs a string that includes
  ## fragmentation metrics and distribution data.
  ## 
  ## Note that different systems may have different memory access patterns
  ## to the same components. Systems and component storage generally takes
  ## a "first come, first served" approach with regard to processing.
  ## 
  ## For example, if the first entity in a system list has component(s)
  ## binding it to the system removed, then re-added, its position in the
  ## system's processing order is likely to change even if the component(s)
  ## added back have the same memory address as before, leading to
  ## non-sequential access.
  mixin name
  result.name = sys`gensym272.name
  template getAddressInt(value`gensym272: untyped): int =
    var address`gensym272: pointer
    when value`gensym272 is ComponentIndexTypeClass:
      address`gensym272 = value`gensym272.access.addr
    else:
      address`gensym272 = value`gensym272.unsafeAddr
    cast[int](address`gensym272)

  const
    compCount`gensym272 = sys`gensym272.requirements.len
  result.components.setLen compCount`gensym272
  result.entities = sys`gensym272.count
  template component(idx`gensym272): untyped =
    result.components[idx`gensym272]

  var
    sysItem`gensym272: sys`gensym272.itemType
    fieldIdx`gensym272 = 0
  for field`gensym272, value`gensym272 in sysItem`gensym272.fieldPairs:
    when not (value`gensym272 is EntityRef):
      when value`gensym272 is ComponentIndexTypeClass:
        type
          valueType`gensym272 = value`gensym272.access.type
      else:
        type
          valueType`gensym272 = value`gensym272.type
      let valueSize`gensym272 = valueType`gensym272.sizeof
      component(fieldIdx`gensym272).name = field`gensym272
      component(fieldIdx`gensym272).valueSize = valueSize`gensym272
      component(fieldIdx`gensym272).jumpThreshold = if jumpThreshold`gensym272 ==
          0:
        if value`gensym272.isOwnedComponent:
          sysItem`gensym272.sizeof
        else:
          valueSize`gensym272 else:
        jumpThreshold`gensym272
      fieldIdx`gensym272 += 1
  var lastAddresses`gensym272: array[compCount`gensym272, int]
  let systemItems`gensym272 = sys`gensym272.count
  if systemItems`gensym272 > 1:
    const
      startIdx`gensym272 = if sys`gensym272.isOwner:
        2 else:
        1
    fieldIdx`gensym272 = 0
    for value`gensym272 in sys`gensym272.groups[startIdx`gensym272 - 1].fields:
      when not (value`gensym272 is EntityRef):
        lastAddresses`gensym272[fieldIdx`gensym272] = value`gensym272.getAddressInt
        fieldIdx`gensym272 += 1
    for i`gensym272 in startIdx`gensym272 ..< systemItems`gensym272:
      fieldIdx`gensym272 = 0
      for value`gensym272 in sys`gensym272.groups[i`gensym272].fields:
        when not (value`gensym272 is EntityRef):
          let
            thresh`gensym272 = component(fieldIdx`gensym272).jumpThreshold
            address`gensym272 = getAddressInt(value`gensym272)
            diff`gensym272 = address`gensym272 -
                lastAddresses`gensym272[fieldIdx`gensym272]
          var tagged`gensym272: bool
          component(fieldIdx`gensym272).allData.push diff`gensym272
          if diff`gensym272 < 0:
            component(fieldIdx`gensym272).backwardsJumps += 1
            tagged`gensym272 = true
          elif diff`gensym272 > thresh`gensym272:
            component(fieldIdx`gensym272).forwardJumps += 1
            tagged`gensym272 = true
          if tagged`gensym272:
            component(fieldIdx`gensym272).taggedData.push diff`gensym272
          lastAddresses`gensym272[fieldIdx`gensym272] = address`gensym272
          fieldIdx`gensym272 += 1
    for i`gensym272, c`gensym272 in result.components:
      component(i`gensym272).fragmentation = (
          c`gensym272.backwardsJumps + c`gensym272.forwardJumps).float /
          systemItems`gensym272.float

proc summary*(analysis`gensym272: SystemAnalysis): string =
  ## List the fragmentation for each component in the analysis system.
  result = analysis`gensym272.name & ":"
  for component`gensym272 in analysis`gensym272.components:
    result &=
        "\n  " & component`gensym272.name & ": " &
        formatFloat(component`gensym272.fragmentation * 100.0, ffDecimal, 3) &
        "%"

proc `$`*(analysis`gensym272: SystemAnalysis): string =
  ## Outputs a string detailing a system analysis.
  ## 
  ## For each component in the system, fragmentation is calculated
  ## as the ratio of non-consecutive vs consecutive address accesses
  ## that the system makes.
  ## 
  ## A fragmentation of 0.0 means the system accesses this component
  ## sequentially forward no greater than `jumpThreshold` per item.
  ## 
  ## A fragmentation of 1.0 means every consecutive address
  ## accessed by the system for this component was greater than
  ## the `jumpThreshold`, or travelling backwards in memory. 
  ## 
  ## The shape of the distribution of address accesses by this system
  ## is described in the "Address deltas" section.
  const
    alignPos`gensym272 = 70
    decimals`gensym272 = 4
  result = "Analysis for " & analysis`gensym272.name & " (" &
      $analysis`gensym272.entities &
      " rows of " &
      $analysis`gensym272.components.len &
      " components):\n"
  if analysis`gensym272.components.len == 0:
    result &= "<No components found>\n"
  else:
    func numStr(value`gensym272: float; precision`gensym272 = decimals`gensym272): string =
      result = formatFloat(value`gensym272, ffDecimal, precision`gensym272)
      trimZeros(result)

    func numStr(value`gensym272: SomeInteger): string =
      let
        strVal`gensym272 = $value`gensym272
        digits`gensym272 = strVal`gensym272.len
      result.setLen digits`gensym272 + (digits`gensym272 div 3)
      var pos`gensym272: int
      for d`gensym272 in 0 ..< digits`gensym272:
        if d`gensym272 > 0 and ((digits`gensym272 - d`gensym272) mod 3 == 0):
          result[pos`gensym272] = ','
          result[pos`gensym272 + 1] = strVal`gensym272[d`gensym272]
          pos`gensym272 += 2
        else:
          result[pos`gensym272] = strVal`gensym272[d`gensym272]
          pos`gensym272 += 1

    func pad(s1`gensym272, s2`gensym272: string): string =
      if s2`gensym272.len > 0:
        s1`gensym272 & spaces(max(1, alignPos`gensym272 - s1`gensym272.len)) &
            s2`gensym272
      else:
        s1`gensym272

    for c`gensym272 in analysis`gensym272.components:
      func dataStr(data`gensym272: RunningStat): string =
        func eqTol(a`gensym272, b`gensym272: float; tol`gensym272 = 0.001): bool =
          abs(a`gensym272 - b`gensym272) < tol`gensym272

        let
          exKurt`gensym272 = data`gensym272.kurtosis - 3.0
          dataRange`gensym272 = data`gensym272.max - data`gensym272.min
        const
          cont`gensym272 = -6 / 5
          indent`gensym272 = "      "
        result = pad(indent`gensym272 & "Min: " & data`gensym272.min.numStr &
            ", max: " &
            $data`gensym272.max.numStr &
            ", sum: " &
            $data`gensym272.sum.numStr, "Range: " &
            formatSize(dataRange`gensym272.int64, includeSpace = true)) &
            "\n" &
            indent`gensym272 &
            "Mean: " &
            $data`gensym272.mean.numStr &
            "\n" &
            pad(indent`gensym272 & "Std dev: " &
            data`gensym272.standardDeviation.numStr, "CoV: " &
          if data`gensym272.mean != 0.0:
            numStr(data`gensym272.standardDeviation / data`gensym272.mean)
           else:
            "N/A" &
            "\n") &
            indent`gensym272 &
            "Variance: " &
            $data`gensym272.variance.numStr &
            "\n" &
            pad(indent`gensym272 & "Kurtosis/spread (normal = 3.0): " &
            $data`gensym272.kurtosis.numStr &
            " (excess: " &
            exKurt`gensym272.numStr &
            ")", if exKurt`gensym272 > 2.0:
          "Many outliers" elif exKurt`gensym272.eqTol 0.0:
          "Normally distributed" elif exKurt`gensym272.eqTol cont`gensym272:
          "Continuous/no outliers" elif exKurt`gensym272 < -2.0:
          "Few outliers" else:
          "") &
            "\n" &
            pad(indent`gensym272 & "Skewness: " &
            $data`gensym272.skewness.numStr, if data`gensym272.skewness < 0:
          "Outliers trend backwards" elif data`gensym272.skewness > 0:
          "Outliers trend forwards" else:
          "") &
            "\n"

      let
        jt`gensym272 = c`gensym272.jumpThreshold.float
        n`gensym272 = c`gensym272.allData.n
        fwdPerc`gensym272 = if n`gensym272 > 0:
          numStr((c`gensym272.forwardJumps / n`gensym272) * 100.0) else:
          "N/A"
        bkdPerc`gensym272 = if n`gensym272 > 0:
          numStr((c`gensym272.backwardsJumps / n`gensym272) * 100.0) else:
          "N/A"
        indent`gensym272 = "    "
      result &=
          "  " & c`gensym272.name & ":\n" & indent`gensym272 & "Value size: " &
          formatSize(c`gensym272.valueSize, includeSpace = true) &
          ", jump threshold: " &
          formatSize(c`gensym272.jumpThreshold, includeSpace = true) &
          "\n" &
          pad(indent`gensym272 & "Jumps over threshold : " &
          $c`gensym272.forwardJumps.numStr,
              "Jump ahead: " & fwdPerc`gensym272 & " %") &
          "\n" &
          pad(indent`gensym272 & "Backwards jumps      : " &
          $c`gensym272.backwardsJumps.numStr,
              "Jump back: " & bkdPerc`gensym272 & " %") &
          "\n" &
          indent`gensym272 &
          "Fragmentation: " &
          numStr(c`gensym272.fragmentation * 100.0) &
          " %" &
          " (n = " &
          $c`gensym272.taggedData.n &
          "):\n"
      if c`gensym272.taggedData.n > 0:
        result &=
            indent`gensym272 & "  Mean scale: " &
            numStr(c`gensym272.taggedData.mean / jt`gensym272) &
            " times threshold\n" &
            c`gensym272.taggedData.dataStr
      else:
        result &= indent`gensym272 & "  <No fragmented indirections>\n"
      result &=
          indent`gensym272 & "All address deltas (n = " & $n`gensym272 & "):\n"
      if n`gensym272 > 0:
        result &= c`gensym272.allData.dataStr
      else:
        result &= indent`gensym272 & "  <No data>\n"

proc doDelete*(entity: EntityRef)
template delete*(entity: EntityRef) =
  when EcsIdentity("default").inSystem:
    static :
      EcsIdentity("default").setsystemCalledDelete true
  elif EcsIdentity("default").ecsEventEnv.len > 0:
    static :
      when isSymbol(entity):
        when hasCustomPragma(entity, hostEntity):
          error "Delete cannot remove the current event entity"
    when declared(curEntity):
      assert entity != curEntity(),
             "Delete cannot remove the current event entity"
  doDelete(entity)

macro newEntityWith*(componentList: varargs[typed]): untyped =
  ## Create an entity with the parameter components.
  ## This macro statically generates updates for only systems
  ## entirely contained within the parameters and ensures no
  ## run time component list iterations and associated checks.
  doNewEntityWith(EcsIdentity("default"), componentList)

macro addComponents*(id`gensym278: static[EcsIdentity]; entity: EntityRef;
                     componentList: varargs[typed]): untyped =
  ## Add components to a specific identity.
  doAddComponents(id`gensym278, entity, componentList)

macro addComponents*(entity: EntityRef; componentList: varargs[typed]): untyped =
  ## Add components to an entity and return a tuple containing
  ## the instances.
  doAddComponents(EcsIdentity("default"), entity, componentList)

macro add*(entity: EntityRef; componentList: varargs[typed]): untyped =
  ## Add components to an entity and return a tuple containing
  ## the instances.
  doAddComponents(EcsIdentity("default"), entity, componentList)

macro removeComponents*(entity: EntityRef; componentList: varargs[typed]): untyped =
  ## Remove components from an entity.
  doRemoveComponents(EcsIdentity("default"), entity, componentList)

macro remove*(entity: EntityRef; componentList: varargs[typed]): untyped =
  ## Remove a component from an entity.
  doRemoveComponents(EcsIdentity("default"), entity, componentList)

macro removeComponent*(entity: EntityRef; component`gensym278: typed) =
  ## Remove a component from an entity.
  doRemoveComponents(EcsIdentity("default"), entity, component`gensym278)

template removeComponents*(entity`gensym278: EntityRef;
                           compList`gensym278: ComponentList) =
  ## Remove a run time list of components from the entity.
  for c`gensym278 in compList`gensym278:
    assert c`gensym278.typeId != InvalidComponent
    caseComponent c`gensym278.typeId:
      removeComponent(entity`gensym278, componentType())

template add*(entity: EntityRef; component`gensym278: ComponentTypeclass) =
  entity.addComponent component`gensym278

proc addComponent*[T: ComponentTypeclass](entity: EntityRef;
    component`gensym279: T): auto {.discardable.} =
  ## Add a single component to `entity` and return the instance.
  entity.addComponents(component`gensym279)[0]

proc addOrUpdate*[T: ComponentTypeclass](entity: EntityRef;
    component`gensym279: T): auto {.discardable.} =
  ## Add `component` to `entity`, or if `component` already exists, overwrite it.
  ## Returns the component instance.
  let fetched`gensym279 = entity.fetchComponent typedesc[T]
  if fetched`gensym279.valid:
    update(fetched`gensym279, component`gensym279)
    result = fetched`gensym279
  else:
    result = addComponent(entity, component`gensym279)

proc addIfMissing*[T: ComponentTypeclass](entity: EntityRef;
    component`gensym279: T): auto {.discardable.} =
  ## Add a component only if it isn't already present.
  ## If the component is already present, no changes are made and an invalid result is returned.
  ## If the component isn't present, it will be added and the instance is returned.
  if not entity.hasComponent typedesc[T]:
    result = addComponent(entity, component`gensym279)

proc fetchOrAdd*[T: ComponentTypeclass](entity: EntityRef;
                                        component`gensym279: typedesc[T]): auto {.
    discardable.} =
  ## Fetch an existing component type if present, otherwise add
  ## the component type and return the instance.
  ## 
  ## This is useful when you always want a valid component
  ## instance returned, but don't want to overwrite existing
  ## data.
  result = entity.fetchComponent typedesc[T]
  if not result.valid:
    result = addComponent(entity, component`gensym279())

template addComponents*(entity: EntityRef; components`gensym280: ComponentList) =
  ## Add components from a list.
  ## Each component is assembled by it's run time `typeId`.
  static :
    startOperation(EcsIdentity("default"), "Add components from ref list")
  {.line.}:
    for c`gensym280 in components`gensym280:
      caseComponent c`gensym280.typeId:(discard entity.addComponent
          componentRefType()(c`gensym280).value)
  static :
    endOperation(EcsIdentity("default"))

template add*(entity: EntityRef; components`gensym280: ComponentList) =
  ## Add components from a list.
  ## Each component is assembled by its run time `typeId`.
  addComponents(entity, components`gensym280)

template addIfMissing*(entity`gensym280: EntityRef;
                       components`gensym280: ComponentList) =
  ## Add components from a list if they're not already present.
  {.line.}:
    for c`gensym280 in components`gensym280:
      caseComponent c`gensym280.typeId:
        entity`gensym280.addIfMissing componentRefType()(c`gensym280).value

template addOrUpdate*(entity`gensym280: EntityRef;
                      components`gensym280: ComponentList) =
  ## Add or update components from a list.
  {.line.}:
    for c`gensym280 in components`gensym280:
      caseComponent c`gensym280.typeId:(discard addOrUpdate(entity`gensym280,
          componentRefType()(c`gensym280).value))

template updateComponents*(entity`gensym280: EntityRef;
                           components`gensym280: ComponentList) =
  ## Updates existing components from a list.
  ## Components not found on the entity exist are ignored.
  {.line.}:
    for c`gensym280 in components`gensym280:
      caseComponent c`gensym280.typeId:
        let inst`gensym280 = entity`gensym280.fetchComponent componentType()
        if inst`gensym280.valid:
          inst`gensym280.update componentRefType()(c`gensym280).value

template update*(entity`gensym280: EntityRef;
                 components`gensym280: ComponentList) =
  ## Updates existing components from a list.
  ## Components not found on the entity are ignored.
  updateComponents(entity`gensym280, components`gensym280)

proc doDelete(entity: EntityRef) =
  static :
    startOperation(EcsIdentity("default"), "delete")
  let entityId = entity.entityId
  if not entity.alive or not (entityData(entityId).setup):
    return
  static :
    enterEvent(EcsIdentity("default"), EventKind(3), @[0])
  static :
    exitEvent(EcsIdentity("default"), EventKind(3), @[0])
  var sysProcessed_452986995: set[SystemsEnum]
  block:
    for curComp_452986994 in entity:
      case curComp_452986994.typeId.int
      of 1:
        var sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw: SystemFetchResult
        sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.found =
          sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row = sysResetTransMat.index.getOrDefault(
              entity.entityId, -1)
          sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row >= 0
        if seResetTransMat notin sysProcessed_452986995:
          sysProcessed_452986995.incl seResetTransMat
          if sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.found:
            sysResetTransMat.index.del(entity.entityId)
            let
              topIdx`gensym287 = sysResetTransMat.groups.high
              ri`gensym287 = sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row
            if ri`gensym287 < topIdx`gensym287:
              sysResetTransMat.groups[ri`gensym287] = move
                  sysResetTransMat.groups[topIdx`gensym287]
              let updatedRowEnt_452987031 = sysResetTransMat.groups[ri`gensym287].entity
              {.line.}:
                assert updatedRowEnt_452987031.alive, "Internal error: dead entity in system groups: id = " &
                    $updatedRowEnt_452987031.entityId.int &
                    ", current entity id upper bound = " &
                    $entityStorage.entityComponents.len
              sysResetTransMat.index[updatedRowEnt_452987031.entityId] = sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row
            {.line.}:
              assert sysResetTransMat.groups.len > 0, "Internal error: system \"" &
                  sysResetTransMat.name &
                  "\" groups are empty but is scheduling to delete from row " &
                  $ri`gensym287 &
                  ". Top row is " &
                  $topIdx`gensym287
            sysResetTransMat.groups.setLen(sysResetTransMat.groups.len - 1)
            static :
              recordMutation(EcsIdentity("default"), ekRowRemoved, [1])
      of 2:
        var sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw: SystemFetchResult
        sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.found =
          sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row = sysResetTransMat.index.getOrDefault(
              entity.entityId, -1)
          sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row >= 0
        if seResetTransMat notin sysProcessed_452986995:
          sysProcessed_452986995.incl seResetTransMat
          if sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.found:
            sysResetTransMat.index.del(entity.entityId)
            let
              topIdx`gensym303 = sysResetTransMat.groups.high
              ri`gensym303 = sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row
            if ri`gensym303 < topIdx`gensym303:
              sysResetTransMat.groups[ri`gensym303] = move
                  sysResetTransMat.groups[topIdx`gensym303]
              let updatedRowEnt_452987145 = sysResetTransMat.groups[ri`gensym303].entity
              {.line.}:
                assert updatedRowEnt_452987145.alive, "Internal error: dead entity in system groups: id = " &
                    $updatedRowEnt_452987145.entityId.int &
                    ", current entity id upper bound = " &
                    $entityStorage.entityComponents.len
              sysResetTransMat.index[updatedRowEnt_452987145.entityId] = sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row
            {.line.}:
              assert sysResetTransMat.groups.len > 0, "Internal error: system \"" &
                  sysResetTransMat.name &
                  "\" groups are empty but is scheduling to delete from row " &
                  $ri`gensym303 &
                  ". Top row is " &
                  $topIdx`gensym303
            sysResetTransMat.groups.setLen(sysResetTransMat.groups.len - 1)
            static :
              recordMutation(EcsIdentity("default"), ekRowRemoved, [1])
      of 3:
        var sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw: SystemFetchResult
        sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.found =
          sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row = sysResetTransMat.index.getOrDefault(
              entity.entityId, -1)
          sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row >= 0
        if seResetTransMat notin sysProcessed_452986995:
          sysProcessed_452986995.incl seResetTransMat
          if sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.found:
            sysResetTransMat.index.del(entity.entityId)
            let
              topIdx`gensym319 = sysResetTransMat.groups.high
              ri`gensym319 = sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row
            if ri`gensym319 < topIdx`gensym319:
              sysResetTransMat.groups[ri`gensym319] = move
                  sysResetTransMat.groups[topIdx`gensym319]
              let updatedRowEnt_452987148 = sysResetTransMat.groups[ri`gensym319].entity
              {.line.}:
                assert updatedRowEnt_452987148.alive, "Internal error: dead entity in system groups: id = " &
                    $updatedRowEnt_452987148.entityId.int &
                    ", current entity id upper bound = " &
                    $entityStorage.entityComponents.len
              sysResetTransMat.index[updatedRowEnt_452987148.entityId] = sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row
            {.line.}:
              assert sysResetTransMat.groups.len > 0, "Internal error: system \"" &
                  sysResetTransMat.name &
                  "\" groups are empty but is scheduling to delete from row " &
                  $ri`gensym319 &
                  ". Top row is " &
                  $topIdx`gensym319
            sysResetTransMat.groups.setLen(sysResetTransMat.groups.len - 1)
            static :
              recordMutation(EcsIdentity("default"), ekRowRemoved, [1])
      of 4:
        var sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw: SystemFetchResult
        sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.found =
          sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row = sysResetTransMat.index.getOrDefault(
              entity.entityId, -1)
          sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row >= 0
        if seResetTransMat notin sysProcessed_452986995:
          sysProcessed_452986995.incl seResetTransMat
          if sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.found:
            sysResetTransMat.index.del(entity.entityId)
            let
              topIdx`gensym335 = sysResetTransMat.groups.high
              ri`gensym335 = sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row
            if ri`gensym335 < topIdx`gensym335:
              sysResetTransMat.groups[ri`gensym335] = move
                  sysResetTransMat.groups[topIdx`gensym335]
              let updatedRowEnt_452987151 = sysResetTransMat.groups[ri`gensym335].entity
              {.line.}:
                assert updatedRowEnt_452987151.alive, "Internal error: dead entity in system groups: id = " &
                    $updatedRowEnt_452987151.entityId.int &
                    ", current entity id upper bound = " &
                    $entityStorage.entityComponents.len
              sysResetTransMat.index[updatedRowEnt_452987151.entityId] = sysFetchresetTransMat__VKyIrfLUK6NeG39bDAuMnQw.row
            {.line.}:
              assert sysResetTransMat.groups.len > 0, "Internal error: system \"" &
                  sysResetTransMat.name &
                  "\" groups are empty but is scheduling to delete from row " &
                  $ri`gensym335 &
                  ". Top row is " &
                  $topIdx`gensym335
            sysResetTransMat.groups.setLen(sysResetTransMat.groups.len - 1)
            static :
              recordMutation(EcsIdentity("default"), ekRowRemoved, [1])
        var sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw: SystemFetchResult
        sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.found =
          sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row = sysUpdateSceneInheritance.index.getOrDefault(
              entity.entityId, -1)
          sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row >= 0
        if seUpdateSceneInheritance notin sysProcessed_452986995:
          sysProcessed_452986995.incl seUpdateSceneInheritance
          if sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.found:
            sysUpdateSceneInheritance.index.del(entity.entityId)
            let
              topIdx`gensym345 = sysUpdateSceneInheritance.groups.high
              ri`gensym345 = sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row
            if ri`gensym345 < topIdx`gensym345:
              sysUpdateSceneInheritance.groups[ri`gensym345] = move
                  sysUpdateSceneInheritance.groups[topIdx`gensym345]
              let updatedRowEnt_452987154 = sysUpdateSceneInheritance.groups[
                  ri`gensym345].entity
              {.line.}:
                assert updatedRowEnt_452987154.alive, "Internal error: dead entity in system groups: id = " &
                    $updatedRowEnt_452987154.entityId.int &
                    ", current entity id upper bound = " &
                    $entityStorage.entityComponents.len
              sysUpdateSceneInheritance.index[updatedRowEnt_452987154.entityId] = sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row
            {.line.}:
              assert sysUpdateSceneInheritance.groups.len > 0, "Internal error: system \"" &
                  sysUpdateSceneInheritance.name &
                  "\" groups are empty but is scheduling to delete from row " &
                  $ri`gensym345 &
                  ". Top row is " &
                  $topIdx`gensym345
            sysUpdateSceneInheritance.groups.setLen(
                sysUpdateSceneInheritance.groups.len - 1)
            static :
              recordMutation(EcsIdentity("default"), ekRowRemoved, [2])
        var sysFetchrender__VKyIrfLUK6NeG39bDAuMnQw: SystemFetchResult
        sysFetchrender__VKyIrfLUK6NeG39bDAuMnQw.found =
          sysFetchrender__VKyIrfLUK6NeG39bDAuMnQw.row = sysRender.index.getOrDefault(
              entity.entityId, -1)
          sysFetchrender__VKyIrfLUK6NeG39bDAuMnQw.row >= 0
        if seRender notin sysProcessed_452986995:
          sysProcessed_452986995.incl seRender
          if sysFetchrender__VKyIrfLUK6NeG39bDAuMnQw.found:
            sysRender.index.del(entity.entityId)
            let
              topIdx`gensym353 = sysRender.groups.high
              ri`gensym353 = sysFetchrender__VKyIrfLUK6NeG39bDAuMnQw.row
            if ri`gensym353 < topIdx`gensym353:
              sysRender.groups[ri`gensym353] = move
                  sysRender.groups[topIdx`gensym353]
              let updatedRowEnt_452987157 = sysRender.groups[ri`gensym353].entity
              {.line.}:
                assert updatedRowEnt_452987157.alive, "Internal error: dead entity in system groups: id = " &
                    $updatedRowEnt_452987157.entityId.int &
                    ", current entity id upper bound = " &
                    $entityStorage.entityComponents.len
              sysRender.index[updatedRowEnt_452987157.entityId] = sysFetchrender__VKyIrfLUK6NeG39bDAuMnQw.row
            {.line.}:
              assert sysRender.groups.len > 0, "Internal error: system \"" &
                  sysRender.name &
                  "\" groups are empty but is scheduling to delete from row " &
                  $ri`gensym353 &
                  ". Top row is " &
                  $topIdx`gensym353
            sysRender.groups.setLen(sysRender.groups.len - 1)
            static :
              recordMutation(EcsIdentity("default"), ekRowRemoved, [3])
      of 5:
        var sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw: SystemFetchResult
        sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.found =
          sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row = sysUpdateSceneInheritance.index.getOrDefault(
              entity.entityId, -1)
          sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row >= 0
        if seUpdateSceneInheritance notin sysProcessed_452986995:
          sysProcessed_452986995.incl seUpdateSceneInheritance
          if sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.found:
            sysUpdateSceneInheritance.index.del(entity.entityId)
            let
              topIdx`gensym377 = sysUpdateSceneInheritance.groups.high
              ri`gensym377 = sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row
            if ri`gensym377 < topIdx`gensym377:
              sysUpdateSceneInheritance.groups[ri`gensym377] = move
                  sysUpdateSceneInheritance.groups[topIdx`gensym377]
              let updatedRowEnt_452987160 = sysUpdateSceneInheritance.groups[
                  ri`gensym377].entity
              {.line.}:
                assert updatedRowEnt_452987160.alive, "Internal error: dead entity in system groups: id = " &
                    $updatedRowEnt_452987160.entityId.int &
                    ", current entity id upper bound = " &
                    $entityStorage.entityComponents.len
              sysUpdateSceneInheritance.index[updatedRowEnt_452987160.entityId] = sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row
            {.line.}:
              assert sysUpdateSceneInheritance.groups.len > 0, "Internal error: system \"" &
                  sysUpdateSceneInheritance.name &
                  "\" groups are empty but is scheduling to delete from row " &
                  $ri`gensym377 &
                  ". Top row is " &
                  $topIdx`gensym377
            sysUpdateSceneInheritance.groups.setLen(
                sysUpdateSceneInheritance.groups.len - 1)
            static :
              recordMutation(EcsIdentity("default"), ekRowRemoved, [2])
      of 7:
        var sysFetchrender__VKyIrfLUK6NeG39bDAuMnQw: SystemFetchResult
        sysFetchrender__VKyIrfLUK6NeG39bDAuMnQw.found =
          sysFetchrender__VKyIrfLUK6NeG39bDAuMnQw.row = sysRender.index.getOrDefault(
              entity.entityId, -1)
          sysFetchrender__VKyIrfLUK6NeG39bDAuMnQw.row >= 0
        if seRender notin sysProcessed_452986995:
          sysProcessed_452986995.incl seRender
          if sysFetchrender__VKyIrfLUK6NeG39bDAuMnQw.found:
            sysRender.index.del(entity.entityId)
            let
              topIdx`gensym392 = sysRender.groups.high
              ri`gensym392 = sysFetchrender__VKyIrfLUK6NeG39bDAuMnQw.row
            if ri`gensym392 < topIdx`gensym392:
              sysRender.groups[ri`gensym392] = move
                  sysRender.groups[topIdx`gensym392]
              let updatedRowEnt_452987163 = sysRender.groups[ri`gensym392].entity
              {.line.}:
                assert updatedRowEnt_452987163.alive, "Internal error: dead entity in system groups: id = " &
                    $updatedRowEnt_452987163.entityId.int &
                    ", current entity id upper bound = " &
                    $entityStorage.entityComponents.len
              sysRender.index[updatedRowEnt_452987163.entityId] = sysFetchrender__VKyIrfLUK6NeG39bDAuMnQw.row
            {.line.}:
              assert sysRender.groups.len > 0, "Internal error: system \"" &
                  sysRender.name &
                  "\" groups are empty but is scheduling to delete from row " &
                  $ri`gensym392 &
                  ". Top row is " &
                  $topIdx`gensym392
            sysRender.groups.setLen(sysRender.groups.len - 1)
            static :
              recordMutation(EcsIdentity("default"), ekRowRemoved, [3])
      else:
        discard
  for compRef`gensym405 in entityData(entityId).componentRefs:
    caseComponent compRef`gensym405.typeId:
      componentDel(componentInstanceType()(compRef`gensym405.index))
  entityData(entityId).componentRefs.setLen(0)
  entityData(entityId).setup = false
  entityStorage.entityCounter -= 1
  entityStorage.entityRecycler.add entityId
  if entityStorage.entityCounter == 0:
    entityStorage.entityRecycler.setLen 0
    entityStorage.nextEntityId = FIRST_ENTITY_ID
  static :
    endOperation(EcsIdentity("default"))

proc deleteAll*(entities`gensym411: var Entities; resize`gensym411 = true) =
  for i`gensym411 in 0 ..< entities`gensym411.len:
    entities`gensym411[i`gensym411].delete
  if resize`gensym411:
    entities`gensym411.setLen 0

proc resetEntityStorage*() =
  ## This deletes all entities, removes them from associated systems and resets next entity.
  for i`gensym411 in 0 ..< entityStorage.nextEntityId.int:
    let ent`gensym411 = (i`gensym411.EntityId).makeRef
    ent`gensym411.delete
  entityStorage.entityRecycler.setLen 0
  entityStorage.nextEntityId = FIRST_ENTITY_ID
  entityStorage.entityCounter = 0

template matchToSystems*(componentTypeId`gensym412: ComponentTypeId;
                         actions`gensym412: untyped): untyped =
  forAllSystems:
    if componentTypeId`gensym412 in system.requirements:
      actions`gensym412

template transition*(entity`gensym412: EntityRef;
                     prevState`gensym412, newState`gensym412: ComponentList;
                     transitionType`gensym412: static[EntityTransitionType]) =
  ## Removes components in `prevState` that aren't in `newState` and
  ## adds or updates components in `newState`.
  ## 
  ## `transitionType` controls whether to just update components that
  ## are in both states, or to always remove components in
  ## `prevState` and add `newState`.
  ## 
  ## - A transition type of `ettUpdate` will remove components that are in
  ## `prevState` but don't exist in `newState`, and update components that
  ## exist in both `prevState` and `newState`.
  ## Events such as `onAdd`/`onRemove` for updated components are not
  ## triggered, the data for the component is just updated.
  ## 
  ## A transition type of `ettRemoveAdd` will always trigger events
  ## such as `onAdd`/`onRemove`, but does more work if many components
  ## are shared between `prevState` and `newState` and may reorder
  ## more system rows. This can be useful for components containing
  ## managed resources and other situations where events must be
  ## triggered.
  ## 
  ## Note: be aware when using `transition` whilst iterating in a
  ## system that removing components the system uses can invalidate
  ## the current `item` template.
  ## 
  ## **Note**: as components are added/removed individually, designs
  ## with systems that own two or more components **may not allow such
  ## transitions to compile** as they are not added in a single state
  ## change.
  {.line.}:
    if prevState`gensym412.len > 0:
      when transitionType`gensym412 == ettUpdate:
        var newIds`gensym412 = newSeq[ComponentTypeId](newState`gensym412.len)
        for i`gensym412, c`gensym412 in newState`gensym412:
          newIds`gensym412[i`gensym412] = c`gensym412.typeId
        for c`gensym412 in prevState`gensym412:
          let tyId`gensym412 = c`gensym412.typeId
          if tyId`gensym412 notin newIds`gensym412:
            caseComponent tyId`gensym412:
              entity`gensym412.removeComponent componentType()
      elif transitionType`gensym412 == ettRemoveAdd:
        for c`gensym412 in prevState`gensym412:
          caseComponent c`gensym412.typeId:
            entity`gensym412.removeComponent componentType()
      else:
        {.fatal: "Unknown transition type \'" & $transitionType`gensym412 &
            "\'".}
    entity`gensym412.addOrUpdate newState`gensym412

template transition*(entity`gensym412: EntityRef;
                     prevState`gensym412, newState`gensym412: ComponentList) =
  ## Removes components in `prevState` that aren't in `newState` and
  ## adds or updates components in `newState`.
  transition(entity`gensym412, prevState`gensym412, newState`gensym412,
             ettUpdate)

var
  manualConstruct: array[1 .. 7, ConstructorProc]
  postConstruct: array[1 .. 7, PostConstructorProc]
  cloneConstruct: array[1 .. 7, CloneConstructorProc]
proc registerConstructor*(typeId: ComponentTypeId; callback: ConstructorProc) =
  manualConstruct[typeId.int] = callback

template registerConstructor*(t`gensym913: typedesc[ComponentTypeClass];
                              callback: ConstructorProc) =
  registerConstructor(t`gensym913.typeId, callback)

proc registerPostConstructor*(typeId: ComponentTypeId;
                              callback: PostConstructorProc) =
  postConstruct[typeId.int] = callback

template registerPostConstructor*(t`gensym913: typedesc[ComponentTypeClass];
                                  callback: PostConstructorProc) =
  registerPostConstructor(t`gensym913.typeId, callback)

proc registerCloneConstructor*(typeId: ComponentTypeId;
                               callback: CloneConstructorProc) =
  cloneConstruct[typeId.int] = callback

template registerCloneConstructor*(t`gensym913: typedesc[ComponentTypeClass];
                                   callback: CloneConstructorProc) =
  registerCloneConstructor(t`gensym913.typeId, callback)

proc construct*(componentList: ComponentList; context: EntityRef = NO_ENTITY_REF): EntityRef =
  ## Create a runtime entity from a list of components.
  ## 
  ## The user may use `registerCallback` to control construction of particular types.
  ## 
  ## When called from a `ConstructionList`, `context` is set to the first entity constructed.
  ## If no `context` is specified, the currently constructed entity is used.
  static :
    startOperation(EcsIdentity("default"), "construct")
  result = newEntity()
  let contextEnt`gensym913 = if context.entityId != NO_ENTITY:
    context else:
    result
  var
    types: Table[int, tuple[component: Component, compIdx: ComponentIndex]]
    visited_452987281 {.used.}: set[SystemsEnum]
  for compRef`gensym913 in componentList:
    assert compRef`gensym913.typeId != InvalidComponent, "Cannot construct: invalid component type id: " &
        $compRef`gensym913.typeId.int
    assert not types.hasKey(compRef`gensym913.typeId.int), "Cannot construct: Entity has duplicate components for " &
        $compRef`gensym913.typeId
    var reference: ComponentRef
    caseComponent compRef`gensym913.typeId:
      let cb`gensym913 = manualConstruct[compRef`gensym913.typeId.int]
      if cb`gensym913 != nil:
        let compsAdded`gensym913 = cb`gensym913(result, compRef`gensym913,
            contextEnt`gensym913)
        for comp`gensym913 in compsAdded`gensym913:
          assert comp`gensym913.typeId != InvalidComponent, "Cannot construct: invalid component type id: " &
              $comp`gensym913.typeId.int
          assert not types.hasKey(comp`gensym913.typeId.int), "Cannot construct: Entity has duplicate components for " &
              $comp`gensym913.typeId
          caseComponent comp`gensym913.typeId:
            when owningSystemIndex == InvalidSystemIndex:
              reference = newInstance(componentRefType()(comp`gensym913).value).toRef
            else:
              let
                c`gensym913 = owningSystem.count
                nextGen`gensym913 = if c`gensym913 < componentGenerations().len:
                  (componentGenerations()[c`gensym913].int + 1).ComponentGeneration else:
                  1.ComponentGeneration
              reference = (componentId(), owningSystem.count.ComponentIndex,
                           nextGen`gensym913)
            entityData(result.entityId).componentRefs.add(reference)
            types[comp`gensym913.typeId.int] = (comp`gensym913, reference.index)
      else:
        when owningSystemIndex == InvalidSystemIndex:
          reference = newInstance(componentRefType()(compRef`gensym913).value).toRef
        else:
          let
            c`gensym913 = owningSystem.count
            nextGen`gensym913 = if c`gensym913 < componentGenerations().len:
              (componentGenerations()[c`gensym913].int + 1).ComponentGeneration else:
              1.ComponentGeneration
          reference = (componentId(), owningSystem.count.ComponentIndex,
                       nextGen`gensym913)
        entityData(result.entityId).componentRefs.add(reference)
        types[compRef`gensym913.typeId.int] = (compRef`gensym913,
            reference.index)
  for curCompInfo in types.pairs:
    case curCompInfo[1].component.typeId.int
    of 1:
      if types.hasKey(3) and types.hasKey(4) and types.hasKey(2) and
          types.hasKey(1):
        if seResetTransMat notin visited_452987281:
          visited_452987281.incl seResetTransMat
          {.line.}:
            assert not (sysResetTransMat.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"resetTransMat\""
          var row_452987339: int
          sysResetTransMat.groups.add(SysItemResetTransMat(entity: result,
              location: LocationInstance(types[1][1]),
              rotation: RotationInstance(types[2][1]),
              scale: ScaleInstance(types[3][1]),
              transformMat: TransformMatInstance(types[4][1])))
          row_452987339 = sysResetTransMat.groups.high
          sysResetTransMat.index[result.entityId] = row_452987339
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [1])
    of 2:
      if types.hasKey(3) and types.hasKey(4) and types.hasKey(2) and
          types.hasKey(1):
        if seResetTransMat notin visited_452987281:
          visited_452987281.incl seResetTransMat
          {.line.}:
            assert not (sysResetTransMat.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"resetTransMat\""
          var row_452987419: int
          sysResetTransMat.groups.add(SysItemResetTransMat(entity: result,
              location: LocationInstance(types[1][1]),
              rotation: RotationInstance(types[2][1]),
              scale: ScaleInstance(types[3][1]),
              transformMat: TransformMatInstance(types[4][1])))
          row_452987419 = sysResetTransMat.groups.high
          sysResetTransMat.index[result.entityId] = row_452987419
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [1])
    of 3:
      if types.hasKey(3) and types.hasKey(4) and types.hasKey(2) and
          types.hasKey(1):
        if seResetTransMat notin visited_452987281:
          visited_452987281.incl seResetTransMat
          {.line.}:
            assert not (sysResetTransMat.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"resetTransMat\""
          var row_452987422: int
          sysResetTransMat.groups.add(SysItemResetTransMat(entity: result,
              location: LocationInstance(types[1][1]),
              rotation: RotationInstance(types[2][1]),
              scale: ScaleInstance(types[3][1]),
              transformMat: TransformMatInstance(types[4][1])))
          row_452987422 = sysResetTransMat.groups.high
          sysResetTransMat.index[result.entityId] = row_452987422
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [1])
    of 4:
      if types.hasKey(3) and types.hasKey(4) and types.hasKey(2) and
          types.hasKey(1):
        if seResetTransMat notin visited_452987281:
          visited_452987281.incl seResetTransMat
          {.line.}:
            assert not (sysResetTransMat.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"resetTransMat\""
          var row_452987425: int
          sysResetTransMat.groups.add(SysItemResetTransMat(entity: result,
              location: LocationInstance(types[1][1]),
              rotation: RotationInstance(types[2][1]),
              scale: ScaleInstance(types[3][1]),
              transformMat: TransformMatInstance(types[4][1])))
          row_452987425 = sysResetTransMat.groups.high
          sysResetTransMat.index[result.entityId] = row_452987425
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [1])
      if types.hasKey(4) and types.hasKey(5):
        if seUpdateSceneInheritance notin visited_452987281:
          visited_452987281.incl seUpdateSceneInheritance
          {.line.}:
            assert not (sysUpdateSceneInheritance.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"updateSceneInheritance\""
          var row_452987426: int
          sysUpdateSceneInheritance.groups.add(SysItemUpdateSceneInheritance(
              entity: result,
              relationship: RelationshipInstance(types[5][1]),
              transformMat: TransformMatInstance(types[4][1])))
          row_452987426 = sysUpdateSceneInheritance.groups.high
          sysUpdateSceneInheritance.index[result.entityId] = row_452987426
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [2])
      if types.hasKey(4) and types.hasKey(7):
        if seRender notin visited_452987281:
          visited_452987281.incl seRender
          {.line.}:
            assert not (sysRender.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"render\""
          var row_452987427: int
          sysRender.groups.add(SysItemRender(entity: result,
              transformMat: TransformMatInstance(types[4][1]),
              openGLModel: OpenGLModelInstance(types[7][1])))
          row_452987427 = sysRender.groups.high
          sysRender.index[result.entityId] = row_452987427
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [3])
    of 5:
      if types.hasKey(4) and types.hasKey(5):
        if seUpdateSceneInheritance notin visited_452987281:
          visited_452987281.incl seUpdateSceneInheritance
          {.line.}:
            assert not (sysUpdateSceneInheritance.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"updateSceneInheritance\""
          var row_452987430: int
          sysUpdateSceneInheritance.groups.add(SysItemUpdateSceneInheritance(
              entity: result,
              relationship: RelationshipInstance(types[5][1]),
              transformMat: TransformMatInstance(types[4][1])))
          row_452987430 = sysUpdateSceneInheritance.groups.high
          sysUpdateSceneInheritance.index[result.entityId] = row_452987430
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [2])
    of 7:
      if types.hasKey(4) and types.hasKey(7):
        if seRender notin visited_452987281:
          visited_452987281.incl seRender
          {.line.}:
            assert not (sysRender.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"render\""
          var row_452987433: int
          sysRender.groups.add(SysItemRender(entity: result,
              transformMat: TransformMatInstance(types[4][1]),
              openGLModel: OpenGLModelInstance(types[7][1])))
          row_452987433 = sysRender.groups.high
          sysRender.index[result.entityId] = row_452987433
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [3])
    else:
      discard
  visited_452987281 = {}
  static :
    endOperation(EcsIdentity("default"))

proc construct*(construction: ComponentList; amount`gensym913: int;
                context = NO_ENTITY_REF): seq[EntityRef] {.discardable.} =
  for i`gensym913 in 0 ..< amount`gensym913:
    result.add construct(construction, context)

proc construct*(construction: ConstructionTemplate): seq[EntityRef] =
  ## Constructs multiple entities and returns their entity ids.
  ## The first entity in the list is passed to the others as the "context".
  ## This same entity is also passed to each individual component's constructor,
  ## this allows components to have some reference to their construction environment.
  ## For example, the first entity can contain a physics body component that others may
  ## reference.
  ## No other structure is assumed, and the meaning of 'context' is defined by the user.
  ## Components are constructed in order, calling manual construction code per type,
  ## then a second pass calls post construction procs with reference to the completed component
  ## lists.
  ## Post construction procs are fed the fully constructed entity and its existing component,
  ## along with the rest of the constructed entities in this template.
  ## This allows fetching components to read/modify initialised values.
  if construction.len > 0:
    result.setLen(construction.len)
    result[0] = construction[0].construct(NO_ENTITY_REF)
    for i in 1 ..< construction.len:
      result[i] = construction[i].construct(result[0])
    var i: int
    while i < result.len:
      let entity = result[i]
      var compIdx`gensym912: int
      while compIdx`gensym912 < entityData(entity.entityId).componentRefs.len:
        let
          compRef`gensym912 = entityData(entity.entityId).componentRefs[
              compIdx`gensym912]
          tId`gensym912 = compRef`gensym912.typeId
          pc`gensym912 = postConstruct[tId`gensym912.int]
        if pc`gensym912 != nil:
          pc`gensym912(entity, compRef`gensym912, result)
        compIdx`gensym912 += 1
      i += 1

proc toTemplate*(entity: EntityRef): seq[Component] =
  ## Creates a list of components ready to be used for construction.
  assert entity.alive
  let length`gensym913 = entityData(entity.entityId).componentRefs.len
  result = newSeq[Component](length`gensym913)
  for i`gensym913, compRef`gensym913 in entity.entityId.pairs:
    caseComponent(compRef`gensym913.typeId):
      result[i`gensym913] = componentInstanceType()(compRef`gensym913.index).makeContainer()

proc clone*(entity`gensym913: EntityRef): EntityRef =
  ## Copy an entity's components to a new entity.
  ## Note that copying objects with pointers/references can have undesirable results.
  ## For special setup, use `registerCloneConstructor` for the type. This gets passed
  ## the clone type it would have added. You can then add a modified component or 
  ## entirely different set of components, or ignore it by not adding anything.
  let entity = entity`gensym913
  assert entity.alive, "Cloning a dead entity"
  static :
    startOperation(EcsIdentity("default"), "clone")
  result = newEntity()
  var
    types: Table[int, ComponentIndex]
    visited_452987282 {.used.}: set[SystemsEnum]
  for compRef`gensym913 in entity.components:
    assert compRef`gensym913.typeId != InvalidComponent, "Cannot construct: invalid component type id: " &
        $compRef`gensym913.typeId.int
    assert not types.hasKey(compRef`gensym913.typeId.int), "Cannot construct: Entity has duplicate components for " &
        $compRef`gensym913.typeId
    var reference: ComponentRef
    caseComponent compRef`gensym913.typeId:
      let cb`gensym913 = cloneConstruct[compRef`gensym913.typeId.int]
      if cb`gensym913 != nil:
        let compsAdded`gensym913 = cb`gensym913(result, compRef`gensym913)
        for comp`gensym913 in compsAdded`gensym913:
          assert comp`gensym913.typeId != InvalidComponent, "Cannot construct: invalid component type id: " &
              $comp`gensym913.typeId.int
          assert not types.hasKey(comp`gensym913.typeId.int), "Cannot construct: Entity has duplicate components for " &
              $comp`gensym913.typeId
          caseComponent comp`gensym913.typeId:
            when owningSystemIndex == InvalidSystemIndex:
              reference = newInstance(componentRefType()(comp`gensym913).value).toRef
            else:
              reference = (componentId(), owningSystem.count.ComponentIndex,
                           1.ComponentGeneration)
            entityData(result.entityId).componentRefs.add(reference)
            types[comp`gensym913.typeId.int] = reference.index
      else:
        when owningSystemIndex == InvalidSystemIndex:
          reference = newInstance(componentInstanceType()(
              compRef`gensym913.index).access).toRef
        else:
          reference = compRef`gensym913
        entityData(result.entityId).componentRefs.add(reference)
        types[compRef`gensym913.typeId.int] = reference.index
  for curCompInfo in types.pairs:
    case curCompInfo[0]
    of 1:
      if types.hasKey(3) and types.hasKey(4) and types.hasKey(2) and
          types.hasKey(1):
        if seResetTransMat notin visited_452987282:
          visited_452987282.incl seResetTransMat
          {.line.}:
            assert not (sysResetTransMat.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"resetTransMat\""
          var row_452987436: int
          sysResetTransMat.groups.add(SysItemResetTransMat(entity: result,
              location: LocationInstance(types[1]),
              rotation: RotationInstance(types[2]),
              scale: ScaleInstance(types[3]),
              transformMat: TransformMatInstance(types[4])))
          row_452987436 = sysResetTransMat.groups.high
          sysResetTransMat.index[result.entityId] = row_452987436
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [1])
    of 2:
      if types.hasKey(3) and types.hasKey(4) and types.hasKey(2) and
          types.hasKey(1):
        if seResetTransMat notin visited_452987282:
          visited_452987282.incl seResetTransMat
          {.line.}:
            assert not (sysResetTransMat.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"resetTransMat\""
          var row_452987439: int
          sysResetTransMat.groups.add(SysItemResetTransMat(entity: result,
              location: LocationInstance(types[1]),
              rotation: RotationInstance(types[2]),
              scale: ScaleInstance(types[3]),
              transformMat: TransformMatInstance(types[4])))
          row_452987439 = sysResetTransMat.groups.high
          sysResetTransMat.index[result.entityId] = row_452987439
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [1])
    of 3:
      if types.hasKey(3) and types.hasKey(4) and types.hasKey(2) and
          types.hasKey(1):
        if seResetTransMat notin visited_452987282:
          visited_452987282.incl seResetTransMat
          {.line.}:
            assert not (sysResetTransMat.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"resetTransMat\""
          var row_452987442: int
          sysResetTransMat.groups.add(SysItemResetTransMat(entity: result,
              location: LocationInstance(types[1]),
              rotation: RotationInstance(types[2]),
              scale: ScaleInstance(types[3]),
              transformMat: TransformMatInstance(types[4])))
          row_452987442 = sysResetTransMat.groups.high
          sysResetTransMat.index[result.entityId] = row_452987442
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [1])
    of 4:
      if types.hasKey(3) and types.hasKey(4) and types.hasKey(2) and
          types.hasKey(1):
        if seResetTransMat notin visited_452987282:
          visited_452987282.incl seResetTransMat
          {.line.}:
            assert not (sysResetTransMat.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"resetTransMat\""
          var row_452987445: int
          sysResetTransMat.groups.add(SysItemResetTransMat(entity: result,
              location: LocationInstance(types[1]),
              rotation: RotationInstance(types[2]),
              scale: ScaleInstance(types[3]),
              transformMat: TransformMatInstance(types[4])))
          row_452987445 = sysResetTransMat.groups.high
          sysResetTransMat.index[result.entityId] = row_452987445
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [1])
      if types.hasKey(4) and types.hasKey(5):
        if seUpdateSceneInheritance notin visited_452987282:
          visited_452987282.incl seUpdateSceneInheritance
          {.line.}:
            assert not (sysUpdateSceneInheritance.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"updateSceneInheritance\""
          var row_452987446: int
          sysUpdateSceneInheritance.groups.add(SysItemUpdateSceneInheritance(
              entity: result, relationship: RelationshipInstance(types[5]),
              transformMat: TransformMatInstance(types[4])))
          row_452987446 = sysUpdateSceneInheritance.groups.high
          sysUpdateSceneInheritance.index[result.entityId] = row_452987446
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [2])
      if types.hasKey(4) and types.hasKey(7):
        if seRender notin visited_452987282:
          visited_452987282.incl seRender
          {.line.}:
            assert not (sysRender.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"render\""
          var row_452987447: int
          sysRender.groups.add(SysItemRender(entity: result,
              transformMat: TransformMatInstance(types[4]),
              openGLModel: OpenGLModelInstance(types[7])))
          row_452987447 = sysRender.groups.high
          sysRender.index[result.entityId] = row_452987447
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [3])
    of 5:
      if types.hasKey(4) and types.hasKey(5):
        if seUpdateSceneInheritance notin visited_452987282:
          visited_452987282.incl seUpdateSceneInheritance
          {.line.}:
            assert not (sysUpdateSceneInheritance.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"updateSceneInheritance\""
          var row_452987450: int
          sysUpdateSceneInheritance.groups.add(SysItemUpdateSceneInheritance(
              entity: result, relationship: RelationshipInstance(types[5]),
              transformMat: TransformMatInstance(types[4])))
          row_452987450 = sysUpdateSceneInheritance.groups.high
          sysUpdateSceneInheritance.index[result.entityId] = row_452987450
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [2])
    of 7:
      if types.hasKey(4) and types.hasKey(7):
        if seRender notin visited_452987282:
          visited_452987282.incl seRender
          {.line.}:
            assert not (sysRender.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"render\""
          var row_452987453: int
          sysRender.groups.add(SysItemRender(entity: result,
              transformMat: TransformMatInstance(types[4]),
              openGLModel: OpenGLModelInstance(types[7])))
          row_452987453 = sysRender.groups.high
          sysRender.index[result.entityId] = row_452987453
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [3])
    else:
      discard
  static :
    endOperation(EcsIdentity("default"))

