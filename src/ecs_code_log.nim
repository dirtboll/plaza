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
# Added component type: "Transform" = 1
# Added component type: "TransformMatrix" = 2
# Added component type: "Relationship" = 3

# Register components:

type
  TransformInstance* = distinct IdBaseType
type
  TransformGeneration* = distinct IdBaseType
type
  TransformMatrixInstance* = distinct IdBaseType
type
  TransformMatrixGeneration* = distinct IdBaseType
type
  RelationshipInstance* = distinct IdBaseType
type
  RelationshipGeneration* = distinct IdBaseType
type
  Transform = object
    loc: Vec3f
    oldLoc: Vec3f
    rot: Quatf
    oldRot: Quatf
    sca: Vec3f
    oldSca: Vec3f

  TransformMatrix = object
    v: Mat4f
    state: TransMatState

  Relationship = object
    parent: RelationshipInstance
    children: seq[RelationshipInstance]
    childIndex: int
    entity: EntityRef

type
  TransformRef* = ref object of Component
    value*: Transform

template typeId*(ty: Transform | TransformRef | TransformInstance |
    typedesc[Transform] |
    typedesc[TransformRef] |
    typedesc[TransformInstance]): ComponentTypeId =
  1.ComponentTypeId

type
  TransformMatrixRef* = ref object of Component
    value*: TransformMatrix

template typeId*(ty: TransformMatrix | TransformMatrixRef |
    TransformMatrixInstance |
    typedesc[TransformMatrix] |
    typedesc[TransformMatrixRef] |
    typedesc[TransformMatrixInstance]): ComponentTypeId =
  2.ComponentTypeId

type
  RelationshipRef* = ref object of Component
    value*: Relationship

template typeId*(ty: Relationship | RelationshipRef | RelationshipInstance |
    typedesc[Relationship] |
    typedesc[RelationshipRef] |
    typedesc[RelationshipInstance]): ComponentTypeId =
  3.ComponentTypeId


# System "shouldUpdateTrans":

type
  SysItemShouldUpdateTrans* = object
    entity* {.hostEntity.}: EntityRef
    transform*: TransformInstance
    transformMatrix*: TransformMatrixInstance

type
  ShouldUpdateTransSystem* = object
    id*: SystemIndex
    lastIndex*: int          ## Records the last item position processed for streaming.
    streamRate*: Natural     ## Rate at which this system streams items by default, overridden if defined using `stream x:`.
    systemName*: string      ## Name is automatically set up at code construction in defineSystem.
    disabled*: bool          ## Doesn't run doProc if true, no work is done.
    paused*: bool            ## Pauses this system's entity processing, but still runs init & finish. 
    initialised*: bool       ## Automatically set to true after an `init` body is called.
    deleteList*: seq[EntityRef] ## Anything added to this list is deleted after the `finish` block. This avoids affecting the main loop when iterating.
    requirements: array[2, ComponentTypeId]
    groups*: seq[SysItemShouldUpdateTrans]
    index*: Table[EntityId, int]

template high*(system`gensym12: ShouldUpdateTransSystem): int =
  system`gensym12.groups.high

template count*(system`gensym13: ShouldUpdateTransSystem): int =
  system`gensym13.groups.len

var sysShouldUpdateTrans*: ShouldUpdateTransSystem
## Returns the type of 'item' for the shouldUpdateTrans system.
template itemType*(system`gensym17: ShouldUpdateTransSystem): untyped =
  SysItemShouldUpdateTrans

proc initShouldUpdateTransSystem*(value: var ShouldUpdateTransSystem) =
  ## Initialise the system.
  template sys(): untyped {.used.} =
    ## The `sys` template represents the system variable being passed.
    value

  template self(): untyped {.used.} =
    ## The `self` template represents the system variable being passed.
    value

  value.index = initTable[EntityId, int]()
  value.streamRate = 1
  value.requirements = [1.ComponentTypeId, 2.ComponentTypeId]
  value.systemName = "shouldUpdateTrans"
  sys.id = 1.SystemIndex

func name*(sys`gensym20: ShouldUpdateTransSystem): string =
  "shouldUpdateTrans"

sysShouldUpdateTrans.initShouldUpdateTransSystem()
proc contains*(sys`gensym20: ShouldUpdateTransSystem; entity: EntityRef): bool =
  sysShouldUpdateTrans.index.hasKey(entity.entityId)

template isOwner*(sys`gensym21: ShouldUpdateTransSystem): bool =
  false

template ownedComponents*(sys`gensym21: ShouldUpdateTransSystem): seq[
    ComponentTypeId] =
  []


# System "updateSceneInheritance":

type
  SysItemUpdateSceneInheritance* = object
    entity* {.hostEntity.}: EntityRef
    relationship*: RelationshipInstance
    transformMatrix*: TransformMatrixInstance

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

template high*(system`gensym43: UpdateSceneInheritanceSystem): int =
  system`gensym43.groups.high

template count*(system`gensym44: UpdateSceneInheritanceSystem): int =
  system`gensym44.groups.len

var sysUpdateSceneInheritance*: UpdateSceneInheritanceSystem
## Returns the type of 'item' for the updateSceneInheritance system.
template itemType*(system`gensym48: UpdateSceneInheritanceSystem): untyped =
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
  value.requirements = [3.ComponentTypeId, 2.ComponentTypeId]
  value.systemName = "updateSceneInheritance"
  value.scenes = newSeq[EntityRef]()
  sys.id = 2.SystemIndex

func name*(sys`gensym51: UpdateSceneInheritanceSystem): string =
  "updateSceneInheritance"

sysUpdateSceneInheritance.initUpdateSceneInheritanceSystem()
proc contains*(sys`gensym51: UpdateSceneInheritanceSystem; entity: EntityRef): bool =
  sysUpdateSceneInheritance.index.hasKey(entity.entityId)

template isOwner*(sys`gensym52: UpdateSceneInheritanceSystem): bool =
  false

template ownedComponents*(sys`gensym52: UpdateSceneInheritanceSystem): seq[
    ComponentTypeId] =
  []



##
## ------------------------
## Systems use by component
## ------------------------
##


## TransformMatrix: 2 systems
## Transform: 1 systems
## Relationship: 1 systems
# ------------------------

# State changes operations:

macro newEntityWith*(componentList: varargs[typed]): untyped =
  ## Create an entity with the parameter components.
  ## This macro statically generates updates for only systems
  ## entirely contained within the parameters and ensures no
  ## run time component list iterations and associated checks.
  doNewEntityWith(EcsIdentity("default"), componentList)

macro addComponents*(id`gensym164: static[EcsIdentity]; entity: EntityRef;
                     componentList: varargs[typed]): untyped =
  ## Add components to a specific identity.
  doAddComponents(id`gensym164, entity, componentList)

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

macro removeComponent*(entity: EntityRef; component`gensym164: typed) =
  ## Remove a component from an entity.
  doRemoveComponents(EcsIdentity("default"), entity, component`gensym164)

template removeComponents*(entity`gensym164: EntityRef;
                           compList`gensym164: ComponentList) =
  ## Remove a run time list of components from the entity.
  for c`gensym164 in compList`gensym164:
    assert c`gensym164.typeId != InvalidComponent
    caseComponent c`gensym164.typeId:
      removeComponent(entity`gensym164, componentType())

template add*(entity: EntityRef; component`gensym164: ComponentTypeclass) =
  entity.addComponent component`gensym164

proc addComponent*[T: ComponentTypeclass](entity: EntityRef;
    component`gensym165: T): auto {.discardable.} =
  ## Add a single component to `entity` and return the instance.
  entity.addComponents(component`gensym165)[0]

proc addOrUpdate*[T: ComponentTypeclass](entity: EntityRef;
    component`gensym165: T): auto {.discardable.} =
  ## Add `component` to `entity`, or if `component` already exists, overwrite it.
  ## Returns the component instance.
  let fetched`gensym165 = entity.fetchComponent typedesc[T]
  if fetched`gensym165.valid:
    update(fetched`gensym165, component`gensym165)
    result = fetched`gensym165
  else:
    result = addComponent(entity, component`gensym165)

proc addIfMissing*[T: ComponentTypeclass](entity: EntityRef;
    component`gensym165: T): auto {.discardable.} =
  ## Add a component only if it isn't already present.
  ## If the component is already present, no changes are made and an invalid result is returned.
  ## If the component isn't present, it will be added and the instance is returned.
  if not entity.hasComponent typedesc[T]:
    result = addComponent(entity, component`gensym165)

proc fetchOrAdd*[T: ComponentTypeclass](entity: EntityRef;
                                        component`gensym165: typedesc[T]): auto {.
    discardable.} =
  ## Fetch an existing component type if present, otherwise add
  ## the component type and return the instance.
  ## 
  ## This is useful when you always want a valid component
  ## instance returned, but don't want to overwrite existing
  ## data.
  result = entity.fetchComponent typedesc[T]
  if not result.valid:
    result = addComponent(entity, component`gensym165())

template addComponents*(entity: EntityRef; components`gensym166: ComponentList) =
  ## Add components from a list.
  ## Each component is assembled by it's run time `typeId`.
  static :
    startOperation(EcsIdentity("default"), "Add components from ref list")
  {.line.}:
    for c`gensym166 in components`gensym166:
      caseComponent c`gensym166.typeId:(discard entity.addComponent
          componentRefType()(c`gensym166).value)
  static :
    endOperation(EcsIdentity("default"))

template add*(entity: EntityRef; components`gensym166: ComponentList) =
  ## Add components from a list.
  ## Each component is assembled by its run time `typeId`.
  addComponents(entity, components`gensym166)

template addIfMissing*(entity`gensym166: EntityRef;
                       components`gensym166: ComponentList) =
  ## Add components from a list if they're not already present.
  {.line.}:
    for c`gensym166 in components`gensym166:
      caseComponent c`gensym166.typeId:
        entity`gensym166.addIfMissing componentRefType()(c`gensym166).value

template addOrUpdate*(entity`gensym166: EntityRef;
                      components`gensym166: ComponentList) =
  ## Add or update components from a list.
  {.line.}:
    for c`gensym166 in components`gensym166:
      caseComponent c`gensym166.typeId:(discard addOrUpdate(entity`gensym166,
          componentRefType()(c`gensym166).value))

template updateComponents*(entity`gensym166: EntityRef;
                           components`gensym166: ComponentList) =
  ## Updates existing components from a list.
  ## Components not found on the entity exist are ignored.
  {.line.}:
    for c`gensym166 in components`gensym166:
      caseComponent c`gensym166.typeId:
        let inst`gensym166 = entity`gensym166.fetchComponent componentType()
        if inst`gensym166.valid:
          inst`gensym166.update componentRefType()(c`gensym166).value

template update*(entity`gensym166: EntityRef;
                 components`gensym166: ComponentList) =
  ## Updates existing components from a list.
  ## Components not found on the entity are ignored.
  updateComponents(entity`gensym166, components`gensym166)


# makeEcs() code generation output:

startGenLog("C:\\Users\\testa\\Documents\\Projects\\plaza\\src\\ecs_code_log.nim")
var
  storageTransform*: seq[Transform]
  transformFreeIndexes*: seq[TransformInstance]
  transformNextIndex*: TransformInstance
  transformAlive*: seq[bool]
  transformInstanceIds*: seq[int32]
  storageTransformMatrix*: seq[TransformMatrix]
  transformmatrixFreeIndexes*: seq[TransformMatrixInstance]
  transformmatrixNextIndex*: TransformMatrixInstance
  transformmatrixAlive*: seq[bool]
  transformmatrixInstanceIds*: seq[int32]
  storageRelationship*: seq[Relationship]
  relationshipFreeIndexes*: seq[RelationshipInstance]
  relationshipNextIndex*: RelationshipInstance
  relationshipAlive*: seq[bool]
  relationshipInstanceIds*: seq[int32]
template instanceType*(ty: typedesc[Transform] | typedesc[TransformRef]): untyped =
  TransformInstance

template containerType*(ty: typedesc[Transform] |
    typedesc[TransformInstance]): untyped =
  TransformRef

template makeContainer*(ty: Transform): TransformRef =
  TransformRef(fTypeId: 1.ComponentTypeId, value: ty)

template makeContainer*(ty: TransformInstance): TransformRef =
  ty.access.makeContainer()

template instanceType*(ty: typedesc[TransformMatrix] |
    typedesc[TransformMatrixRef]): untyped =
  TransformMatrixInstance

template containerType*(ty: typedesc[TransformMatrix] |
    typedesc[TransformMatrixInstance]): untyped =
  TransformMatrixRef

template makeContainer*(ty: TransformMatrix): TransformMatrixRef =
  TransformMatrixRef(fTypeId: 2.ComponentTypeId, value: ty)

template makeContainer*(ty: TransformMatrixInstance): TransformMatrixRef =
  ty.access.makeContainer()

template instanceType*(ty: typedesc[Relationship] |
    typedesc[RelationshipRef]): untyped =
  RelationshipInstance

template containerType*(ty: typedesc[Relationship] |
    typedesc[RelationshipInstance]): untyped =
  RelationshipRef

template makeContainer*(ty: Relationship): RelationshipRef =
  RelationshipRef(fTypeId: 3.ComponentTypeId, value: ty)

template makeContainer*(ty: RelationshipInstance): RelationshipRef =
  ty.access.makeContainer()

template accessType*(ty: TransformInstance | typedesc[TransformInstance]): untyped =
  ## Returns the source component type of a component instance.
  ## This can also be achieved with `instance.access.type`.
  typedesc[Transform]

template `.`*(instance: TransformInstance; field: untyped): untyped =
  when compiles(storageTransform[instance.int].field):
    storageTransform[instance.int].field
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type Transform".}

template `.=`*(instance: TransformInstance; field: untyped; value: untyped): untyped =
  when compiles(storageTransform[instance.int].field):
    storageTransform[instance.int].field = value
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type Transform".}

template isOwnedComponent*(value`gensym70: typedesc[TransformInstance] |
    TransformInstance |
    Transform): bool =
  false

template access*(instance`gensym70: TransformInstance): Transform =
  storageTransform[instance`gensym70.int]

template alive*(inst`gensym70: TransformInstance): bool =
  ## Check if this component ref's index is still in use.
  inst`gensym70.int > 0 and inst`gensym70.int < transformAlive.len and
      transformAlive[inst`gensym70.int] == true

template valid*(inst`gensym70: TransformInstance): bool =
  inst`gensym70.int != InvalidComponentIndex.int

template generation*(inst`gensym70: TransformInstance): untyped =
  ## Access the generation of this component.
  TransformGeneration(transformInstanceIds[inst`gensym70.int]).ComponentGeneration

template componentStorage*(value`gensym70: typedesc[TransformInstance] |
    TransformInstance |
    Transform): untyped =
  storageTransform

template ownerSystemIndex*(value`gensym70: typedesc[TransformInstance] |
    TransformInstance |
    Transform): untyped =
  InvalidSystemIndex

template componentCount*(ty: typedesc[Transform] |
    typedesc[TransformInstance]): untyped =
  ## Returns an estimate of the number of allocated components.
  ## This value is based on last index used and the number of indexes waiting to be used (from previous deletes).
  let freeCount`gensym79 = transformFreeIndexes.len
  storageTransform.len - freeCount`gensym79

proc genTransform*(): TransformInstance =
  ## Create a component instance for this type.
  result =
    var r`gensym76: TransformInstance
    if transformFreeIndexes.len > 0:
      r`gensym76 = transformFreeIndexes.pop
    else:
      r`gensym76 =
        let newLen`gensym73 = storageTransform.len + 1
        storageTransform.setLen(newLen`gensym73)
        transformInstanceIds.setLen(newLen`gensym73)
        transformAlive.setLen(newLen`gensym73)
        storageTransform.high.TransformInstance
    assert r`gensym76.int != 0
    transformAlive[r`gensym76.int] = true
    transformInstanceIds[r`gensym76.int] += 1
    assert r`gensym76.int >= 0
    r`gensym76
  
proc delete*(instance: TransformInstance) =
  ## Free a component instance
  let idx = instance.int
  {.line.}:
    assert idx < transformAlive.len, "Cannot delete, instance is out of range"
  if transformAlive[idx]:
    transformAlive[idx] = false
    if idx == storageTransform.high:
      let newLen`gensym74 = max(1, storageTransform.len - 1)
      storageTransform.setLen(newLen`gensym74)
      transformInstanceIds.setLen(newLen`gensym74)
      transformAlive.setLen(newLen`gensym74)
    elif transformFreeIndexes.high == storageTransform.high:
      transformFreeIndexes.setLen(0)
    else:
      transformFreeIndexes.add idx.TransformInstance
  
template newInstance*(ty: typedesc[Transform] |
    typedesc[TransformInstance]): TransformInstance =
  ## Create a new component instance. Does not update systems.
  let res`gensym79 = genTransform()
  res`gensym79

proc newInstance*(value: Transform): TransformInstance {.inline.} =
  ## Create a new component instance from the supplied value. Does not update systems.
  result =
    var r`gensym76: TransformInstance
    if transformFreeIndexes.len > 0:
      r`gensym76 = transformFreeIndexes.pop
    else:
      r`gensym76 =
        let newLen`gensym73 = storageTransform.len + 1
        storageTransform.setLen(newLen`gensym73)
        transformInstanceIds.setLen(newLen`gensym73)
        transformAlive.setLen(newLen`gensym73)
        storageTransform.high.TransformInstance
    assert r`gensym76.int != 0
    transformAlive[r`gensym76.int] = true
    transformInstanceIds[r`gensym76.int] += 1
    assert r`gensym76.int >= 0
    r`gensym76
  storageTransform[result.int] = value
  
template newInstance*(ty: typedesc[Transform] |
    typedesc[TransformInstance]; val`gensym79: Component): untyped =
  ## Creates a new component from a generated `ref` component descendant. Does not update systems.
  newInstance(TransformRef(val`gensym79).value)

template delInstance*(ty: Transform | TransformInstance): untyped =
  ## Marks a component as deleted. Does not update systems.
  ty.delete()

template update*(instance: TransformInstance; value: Transform): untyped =
  ## Update storage.
  ## `update` operates as a simple assignment into the storage array and uses the type's `==` proc.
  storageTransform[instance.int] = value

template `==`*(i1`gensym80, i2`gensym80: TransformInstance): bool =
  i1`gensym80.int == i2`gensym80.int

template toRef*(inst`gensym80: TransformInstance): ComponentRef =
  ## Utility function that takes this type's distinct `ComponentIndex`,
  ## returned for example from fetchComponent, and creates a reference
  ## tuple for the live component currently at this index.
  let i`gensym80 = inst`gensym80
  (i`gensym80.typeId, i`gensym80.ComponentIndex, i`gensym80.generation)

template accessType*(ty: TransformMatrixInstance |
    typedesc[TransformMatrixInstance]): untyped =
  ## Returns the source component type of a component instance.
  ## This can also be achieved with `instance.access.type`.
  typedesc[TransformMatrix]

template `.`*(instance: TransformMatrixInstance; field: untyped): untyped =
  when compiles(storageTransformMatrix[instance.int].field):
    storageTransformMatrix[instance.int].field
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type TransformMatrix".}

template `.=`*(instance: TransformMatrixInstance; field: untyped; value: untyped): untyped =
  when compiles(storageTransformMatrix[instance.int].field):
    storageTransformMatrix[instance.int].field = value
  else:
    {.fatal: "undeclared field: \'" & astToStr(field) &
        "\' for component type TransformMatrix".}

template isOwnedComponent*(value`gensym85: typedesc[TransformMatrixInstance] |
    TransformMatrixInstance |
    TransformMatrix): bool =
  false

template access*(instance`gensym85: TransformMatrixInstance): TransformMatrix =
  storageTransformMatrix[instance`gensym85.int]

template alive*(inst`gensym85: TransformMatrixInstance): bool =
  ## Check if this component ref's index is still in use.
  inst`gensym85.int > 0 and inst`gensym85.int < transformmatrixAlive.len and
      transformmatrixAlive[inst`gensym85.int] == true

template valid*(inst`gensym85: TransformMatrixInstance): bool =
  inst`gensym85.int != InvalidComponentIndex.int

template generation*(inst`gensym85: TransformMatrixInstance): untyped =
  ## Access the generation of this component.
  TransformMatrixGeneration(transformmatrixInstanceIds[inst`gensym85.int]).ComponentGeneration

template componentStorage*(value`gensym85: typedesc[TransformMatrixInstance] |
    TransformMatrixInstance |
    TransformMatrix): untyped =
  storageTransformMatrix

template ownerSystemIndex*(value`gensym85: typedesc[TransformMatrixInstance] |
    TransformMatrixInstance |
    TransformMatrix): untyped =
  InvalidSystemIndex

template componentCount*(ty: typedesc[TransformMatrix] |
    typedesc[TransformMatrixInstance]): untyped =
  ## Returns an estimate of the number of allocated components.
  ## This value is based on last index used and the number of indexes waiting to be used (from previous deletes).
  let freeCount`gensym94 = transformmatrixFreeIndexes.len
  storageTransformMatrix.len - freeCount`gensym94

proc genTransformMatrix*(): TransformMatrixInstance =
  ## Create a component instance for this type.
  result =
    var r`gensym91: TransformMatrixInstance
    if transformmatrixFreeIndexes.len > 0:
      r`gensym91 = transformmatrixFreeIndexes.pop
    else:
      r`gensym91 =
        let newLen`gensym88 = storageTransformMatrix.len + 1
        storageTransformMatrix.setLen(newLen`gensym88)
        transformmatrixInstanceIds.setLen(newLen`gensym88)
        transformmatrixAlive.setLen(newLen`gensym88)
        storageTransformMatrix.high.TransformMatrixInstance
    assert r`gensym91.int != 0
    transformmatrixAlive[r`gensym91.int] = true
    transformmatrixInstanceIds[r`gensym91.int] += 1
    assert r`gensym91.int >= 0
    r`gensym91
  
proc delete*(instance: TransformMatrixInstance) =
  ## Free a component instance
  let idx = instance.int
  {.line.}:
    assert idx < transformmatrixAlive.len,
           "Cannot delete, instance is out of range"
  if transformmatrixAlive[idx]:
    transformmatrixAlive[idx] = false
    if idx == storageTransformMatrix.high:
      let newLen`gensym89 = max(1, storageTransformMatrix.len - 1)
      storageTransformMatrix.setLen(newLen`gensym89)
      transformmatrixInstanceIds.setLen(newLen`gensym89)
      transformmatrixAlive.setLen(newLen`gensym89)
    elif transformmatrixFreeIndexes.high == storageTransformMatrix.high:
      transformmatrixFreeIndexes.setLen(0)
    else:
      transformmatrixFreeIndexes.add idx.TransformMatrixInstance
  
template newInstance*(ty: typedesc[TransformMatrix] |
    typedesc[TransformMatrixInstance]): TransformMatrixInstance =
  ## Create a new component instance. Does not update systems.
  let res`gensym94 = genTransformMatrix()
  res`gensym94

proc newInstance*(value: TransformMatrix): TransformMatrixInstance {.inline.} =
  ## Create a new component instance from the supplied value. Does not update systems.
  result =
    var r`gensym91: TransformMatrixInstance
    if transformmatrixFreeIndexes.len > 0:
      r`gensym91 = transformmatrixFreeIndexes.pop
    else:
      r`gensym91 =
        let newLen`gensym88 = storageTransformMatrix.len + 1
        storageTransformMatrix.setLen(newLen`gensym88)
        transformmatrixInstanceIds.setLen(newLen`gensym88)
        transformmatrixAlive.setLen(newLen`gensym88)
        storageTransformMatrix.high.TransformMatrixInstance
    assert r`gensym91.int != 0
    transformmatrixAlive[r`gensym91.int] = true
    transformmatrixInstanceIds[r`gensym91.int] += 1
    assert r`gensym91.int >= 0
    r`gensym91
  storageTransformMatrix[result.int] = value
  
template newInstance*(ty: typedesc[TransformMatrix] |
    typedesc[TransformMatrixInstance]; val`gensym94: Component): untyped =
  ## Creates a new component from a generated `ref` component descendant. Does not update systems.
  newInstance(TransformMatrixRef(val`gensym94).value)

template delInstance*(ty: TransformMatrix | TransformMatrixInstance): untyped =
  ## Marks a component as deleted. Does not update systems.
  ty.delete()

template update*(instance: TransformMatrixInstance; value: TransformMatrix): untyped =
  ## Update storage.
  ## `update` operates as a simple assignment into the storage array and uses the type's `==` proc.
  storageTransformMatrix[instance.int] = value

template `==`*(i1`gensym95, i2`gensym95: TransformMatrixInstance): bool =
  i1`gensym95.int == i2`gensym95.int

template toRef*(inst`gensym95: TransformMatrixInstance): ComponentRef =
  ## Utility function that takes this type's distinct `ComponentIndex`,
  ## returned for example from fetchComponent, and creates a reference
  ## tuple for the live component currently at this index.
  let i`gensym95 = inst`gensym95
  (i`gensym95.typeId, i`gensym95.ComponentIndex, i`gensym95.generation)

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

template isOwnedComponent*(value`gensym100: typedesc[RelationshipInstance] |
    RelationshipInstance |
    Relationship): bool =
  false

template access*(instance`gensym100: RelationshipInstance): Relationship =
  storageRelationship[instance`gensym100.int]

template alive*(inst`gensym100: RelationshipInstance): bool =
  ## Check if this component ref's index is still in use.
  inst`gensym100.int > 0 and inst`gensym100.int < relationshipAlive.len and
      relationshipAlive[inst`gensym100.int] == true

template valid*(inst`gensym100: RelationshipInstance): bool =
  inst`gensym100.int != InvalidComponentIndex.int

template generation*(inst`gensym100: RelationshipInstance): untyped =
  ## Access the generation of this component.
  RelationshipGeneration(relationshipInstanceIds[inst`gensym100.int]).ComponentGeneration

template componentStorage*(value`gensym100: typedesc[RelationshipInstance] |
    RelationshipInstance |
    Relationship): untyped =
  storageRelationship

template ownerSystemIndex*(value`gensym100: typedesc[RelationshipInstance] |
    RelationshipInstance |
    Relationship): untyped =
  InvalidSystemIndex

template componentCount*(ty: typedesc[Relationship] |
    typedesc[RelationshipInstance]): untyped =
  ## Returns an estimate of the number of allocated components.
  ## This value is based on last index used and the number of indexes waiting to be used (from previous deletes).
  let freeCount`gensym109 = relationshipFreeIndexes.len
  storageRelationship.len - freeCount`gensym109

proc genRelationship*(): RelationshipInstance =
  ## Create a component instance for this type.
  result =
    var r`gensym106: RelationshipInstance
    if relationshipFreeIndexes.len > 0:
      r`gensym106 = relationshipFreeIndexes.pop
    else:
      r`gensym106 =
        let newLen`gensym103 = storageRelationship.len + 1
        storageRelationship.setLen(newLen`gensym103)
        relationshipInstanceIds.setLen(newLen`gensym103)
        relationshipAlive.setLen(newLen`gensym103)
        storageRelationship.high.RelationshipInstance
    assert r`gensym106.int != 0
    relationshipAlive[r`gensym106.int] = true
    relationshipInstanceIds[r`gensym106.int] += 1
    assert r`gensym106.int >= 0
    r`gensym106
  
proc delete*(instance: RelationshipInstance) =
  ## Free a component instance
  let idx = instance.int
  {.line.}:
    assert idx < relationshipAlive.len,
           "Cannot delete, instance is out of range"
  if relationshipAlive[idx]:
    relationshipAlive[idx] = false
    if idx == storageRelationship.high:
      let newLen`gensym104 = max(1, storageRelationship.len - 1)
      storageRelationship.setLen(newLen`gensym104)
      relationshipInstanceIds.setLen(newLen`gensym104)
      relationshipAlive.setLen(newLen`gensym104)
    elif relationshipFreeIndexes.high == storageRelationship.high:
      relationshipFreeIndexes.setLen(0)
    else:
      relationshipFreeIndexes.add idx.RelationshipInstance
  
template newInstance*(ty: typedesc[Relationship] |
    typedesc[RelationshipInstance]): RelationshipInstance =
  ## Create a new component instance. Does not update systems.
  let res`gensym109 = genRelationship()
  res`gensym109

proc newInstance*(value: Relationship): RelationshipInstance {.inline.} =
  ## Create a new component instance from the supplied value. Does not update systems.
  result =
    var r`gensym106: RelationshipInstance
    if relationshipFreeIndexes.len > 0:
      r`gensym106 = relationshipFreeIndexes.pop
    else:
      r`gensym106 =
        let newLen`gensym103 = storageRelationship.len + 1
        storageRelationship.setLen(newLen`gensym103)
        relationshipInstanceIds.setLen(newLen`gensym103)
        relationshipAlive.setLen(newLen`gensym103)
        storageRelationship.high.RelationshipInstance
    assert r`gensym106.int != 0
    relationshipAlive[r`gensym106.int] = true
    relationshipInstanceIds[r`gensym106.int] += 1
    assert r`gensym106.int >= 0
    r`gensym106
  storageRelationship[result.int] = value
  
template newInstance*(ty: typedesc[Relationship] |
    typedesc[RelationshipInstance]; val`gensym109: Component): untyped =
  ## Creates a new component from a generated `ref` component descendant. Does not update systems.
  newInstance(RelationshipRef(val`gensym109).value)

template delInstance*(ty: Relationship | RelationshipInstance): untyped =
  ## Marks a component as deleted. Does not update systems.
  ty.delete()

template update*(instance: RelationshipInstance; value: Relationship): untyped =
  ## Update storage.
  ## `update` operates as a simple assignment into the storage array and uses the type's `==` proc.
  storageRelationship[instance.int] = value

template `==`*(i1`gensym110, i2`gensym110: RelationshipInstance): bool =
  i1`gensym110.int == i2`gensym110.int

template toRef*(inst`gensym110: RelationshipInstance): ComponentRef =
  ## Utility function that takes this type's distinct `ComponentIndex`,
  ## returned for example from fetchComponent, and creates a reference
  ## tuple for the live component currently at this index.
  let i`gensym110 = inst`gensym110
  (i`gensym110.typeId, i`gensym110.ComponentIndex, i`gensym110.generation)

storageTransform.setLen 1
transformAlive.setLen 1
transformInstanceIds.setLen 1
transformNextIndex = FIRST_COMPONENT_ID.TransformInstance
storageTransformMatrix.setLen 1
transformmatrixAlive.setLen 1
transformmatrixInstanceIds.setLen 1
transformmatrixNextIndex = FIRST_COMPONENT_ID.TransformMatrixInstance
storageRelationship.setLen 1
relationshipAlive.setLen 1
relationshipInstanceIds.setLen 1
relationshipNextIndex = FIRST_COMPONENT_ID.RelationshipInstance
type
  ComponentTypeClass* = Transform | TransformMatrix | Relationship
type
  ComponentRefTypeClass* = TransformRef | TransformMatrixRef | RelationshipRef
type
  ComponentIndexTypeClass* = TransformInstance | TransformMatrixInstance |
      RelationshipInstance
proc add*(items`gensym114: var ComponentList; component`gensym114: ComponentTypeClass |
    ComponentIndexTypeClass |
    ComponentRefTypeClass) =
  ## Add a component to a component list, automatically handling `typeId`.
  when component`gensym114 is ComponentRefTypeClass:
    const
      cRange`gensym114 = EcsIdentity("default").typeIdRange()
    if component`gensym114.typeId.int notin
        cRange`gensym114.a.int .. cRange`gensym114.b.int:
      var copy`gensym114 = component`gensym114
      copy`gensym114.fTypeId = component`gensym114.typeId()
      add items`gensym114, copy`gensym114
    else:
      add items`gensym114, component`gensym114
  else:
    add items`gensym114, component`gensym114.makeContainer()
  assert items`gensym114[^1].typeId != InvalidComponent,
         "Could not resolve type id for " & $component`gensym114.type

type
  ComponentsEnum* {.used.} = enum
    ceInvalid, ceTransform = 1, ceTransformMatrix = 2, ceRelationship = 3
type
  SystemsEnum* {.used.} = enum
    seInvalidSystem = 0, seShouldUpdateTrans = 1, seUpdateSceneInheritance = 2
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

proc `==`*(eRef`gensym122: EntityRef; e`gensym122: EntityId): bool {.inline.} =
  eRef`gensym122.entityId.IdBaseType == e`gensym122.IdBaseType and
      eRef`gensym122.instance.IdBaseType ==
      entityData(e`gensym122).instance.IdBaseType

proc isCurrent*(eRef`gensym122: EntityRef): bool =
  eRef`gensym122.instance.IdBaseType ==
      entityData(eRef`gensym122.entityId).instance.IdBaseType

template `==`*(live`gensym122: EntityId; eRef`gensym122: EntityRef): bool =
  eRef`gensym122.entityId.IdBaseType == live`gensym122.IdBaseType and
      eRef`gensym122.instance.IdBaseType ==
      entityData(live`gensym122).instance.IdBaseType

proc instance*(e`gensym122: EntityId): EntityInstance {.inline.} =
  entityData(e`gensym122).instance

proc instance*(e`gensym122: EntityRef): EntityInstance {.inline.} =
  entityData(e`gensym122.entityId).instance

proc makeRef*(entityId`gensym122: EntityId): EntityRef {.inline.} =
  (entityId`gensym122, entityData(entityId`gensym122).instance)

proc entityCount*(): int =
  ## Returns the number of alive entities.
  entityStorage.entityCounter

proc high*(entityType`gensym122: typedesc[EntityId] |
    typedesc[EntityRef]): int =
  entityStorage.entityComponents.len

template alive*(entity`gensym122: EntityId): bool =
  ## Checks the entity id (the slot, not instance) is valid
  ## (not NO_ENTITY) and that its index has been initialised.
  entity`gensym122.valid and entity`gensym122.int >= 1 and
      entity`gensym122.int <= entityStorage.entityComponents.len and
      entityData(entity`gensym122).setup

template alive*(entRef`gensym122: EntityRef): bool =
  ## Checks that the instance matches the referenced entity, ie; if
  ## the entity has been deleted/recreated since the reference was
  ## made, as well as checking if the entity itself is valid and
  ## initialised.
  entRef`gensym122.entityId.alive and
      entityData(entRef`gensym122.entityId).instance.int ==
      entRef`gensym122.instance.int

template components*(entity`gensym122: EntityRef; index`gensym122: int): untyped =
  ## Access to entity's components.
  assert entity`gensym122.alive
  entityData(entityId).componentRefs[index`gensym122]

template withComponent*(entity`gensym122: EntityRef;
                        t`gensym122: typedesc[ComponentTypeClass];
                        actions`gensym122: untyped): untyped =
  block:
    let component {.inject.} = entity`gensym122.fetchComponent(t`gensym122)
    actions`gensym122

proc hasComponent*(entity: EntityRef; componentTypeId: ComponentTypeId): bool =
  let entityId = entity.entityId
  if not entity.alive:
    var str`gensym124 = "hasComponent on dead entity: " & $entityId.int &
        " instance " &
        $(entityId.instance.int)
    if entityId != entity:
      str`gensym124 &=
          " expected instance " & $entity.instance.int & " type " &
          $componentTypeId.int
    assert false, str`gensym124
  if entityData(entityId).setup:
    for c`gensym123 in entityData(entityId).componentRefs:
      if c`gensym123.typeId == componentTypeId:
        return true

template hasComponent*(entity`gensym124: EntityRef;
                       t`gensym124: typedesc[ComponentTypeClass]): untyped =
  entity`gensym124.hasComponent t`gensym124.typeId

template has*(entity`gensym124: EntityRef;
              t`gensym124: typedesc[ComponentTypeClass]): untyped =
  ## Returns true if the entity contains `t`.
  entity`gensym124.hasComponent t`gensym124

template has*(entity`gensym124: EntityRef; t`gensym124: varargs[untyped]): untyped =
  ## Returns true if the entity contains all of the components listed in `t`.
  let fetched`gensym124 = entity`gensym124.fetch t`gensym124
  var r`gensym124: bool
  block hasMain`gensym124:
    for field`gensym124, value`gensym124 in fetched`gensym124.fieldPairs:
      if not value`gensym124.valid:
        break hasMain`gensym124
    r`gensym124 = true
  r`gensym124

template hasAny*(entity`gensym124: EntityRef; t`gensym124: varargs[untyped]): untyped =
  ## Returns true if the entity contains any of the components listed in `t`.
  let fetched`gensym124 = entity`gensym124.fetch t`gensym124
  var r`gensym124: bool
  block hasMain`gensym124:
    for field`gensym124, value`gensym124 in fetched`gensym124.fieldPairs:
      if value`gensym124.valid:
        r`gensym124 = true
        break hasMain`gensym124
  r`gensym124

proc contains*(entity`gensym124: EntityRef; componentTypeId: ComponentTypeId): bool {.
    inline.} =
  entity`gensym124.hasComponent(componentTypeId)

template contains*(entity`gensym124: EntityRef;
                   t`gensym124: typedesc[ComponentTypeClass]): untyped =
  entity`gensym124.hasComponent(t`gensym124.typeId)

iterator components*(entityId: EntityId): ComponentRef =
  ## Iterate through components.
  for item`gensym126 in entityData(entityId).componentRefs:
    yield item`gensym126

iterator pairs*(entityId: EntityId): (int, ComponentRef) =
  ## Iterate through components.
  for i`gensym126, item`gensym126 in entityData(entityId).componentRefs.pairs:
    yield (i`gensym126, item`gensym126)

proc componentCount*(entityId: EntityId): int =
  entityData(entityId).componentRefs.len

proc componentCount*(entityRef`gensym127: EntityRef): int =
  entityRef`gensym127.entityId.componentCount

template components*(entity`gensym127: EntityRef): untyped =
  entity`gensym127.entityId.components

iterator items*(entity`gensym127: EntityRef): ComponentRef =
  for comp`gensym127 in entity`gensym127.entityId.components:
    yield comp`gensym127

template pairs*(entity`gensym127: EntityRef): (int, ComponentRef) =
  entity`gensym127.entityId.pairs

template forAllEntities*(actions`gensym127: untyped) =
  ## Walk all active entities.
  var found`gensym127, pos`gensym127: int
  while found`gensym127 < entityCount():
    if entityData(pos`gensym127.EntityId).setup:
      let
        index {.inject, used.} = found`gensym127
        storageIndex {.inject, used.} = pos`gensym127
        entity {.inject.}: EntityRef = (pos`gensym127.EntityId, entityData(
            pos`gensym127.EntityId).instance)
      actions`gensym127
      found`gensym127 += 1
    pos`gensym127 += 1

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
  let i`gensym131 = (entityData(entityId).instance.IdBaseType + 1).EntityInstance
  entityData(entityId).instance = i`gensym131
  (entityId, i`gensym131)

template alive*(compRef`gensym132: ComponentRef): bool =
  ## Check if this component ref's index is still valid and active.
  ## Requires use of run-time case statement to match against type id.
  let index`gensym132 = compRef`gensym132.index.int
  var r`gensym132: bool
  caseComponent compRef`gensym132.typeId:
    r`gensym132 = componentAlive()[index`gensym132] and
        compRef`gensym132.generation.int ==
        componentGenerations()[index`gensym132]
  r`gensym132

macro fetchComponents*(entity: EntityRef;
                       components`gensym134: varargs[typed]): untyped =
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
  doFetchComponents(EcsIdentity("default"), entity, components`gensym134)

template fetch*(entity: EntityRef; components`gensym134: varargs[typed]): untyped =
  fetchComponents(entity, components`gensym134)

template fetchComponent*(entity: EntityRef; t`gensym134: typedesc): auto =
  ## Looks up and returns the instance of the component, which allows direct field access.
  ## Returns default no component index if the component cannot be found.
  ## Eg;
  ##   let comp = entity.fetchComponent CompType  # Will be of type CompTypeInstance
  ##   comp.x = 3 # Edit some supposed fields for this component.
  fetchComponents(entity, t`gensym134)[0]

template fetch*(entity: EntityRef; component`gensym134: typedesc): auto =
  fetchComponent(entity, component`gensym134)

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
      "Transform"

    template componentType(): untyped {.used.} =
      Transform

    template componentRefType(): untyped {.used.} =
      TransformRef

    template componentDel(index`gensym136: TransformInstance): untyped {.used.} =
      delete(index`gensym136)

    template componentAlive(): untyped {.used.} =
      transformAlive

    template componentGenerations(): untyped {.used.} =
      transformInstanceIds

    template componentInstanceType(): untyped {.used.} =
      TransformInstance

    template componentData(): untyped {.used.} =
      storageTransform

    template isOwned(): bool {.used.} =
      false

    template owningSystemIndex(): SystemIndex {.used.} =
      0.SystemIndex

    actions
  of 2:
    template componentId(): untyped {.used.} =
      2.ComponentTypeId

    template componentName(): untyped {.used.} =
      "TransformMatrix"

    template componentType(): untyped {.used.} =
      TransformMatrix

    template componentRefType(): untyped {.used.} =
      TransformMatrixRef

    template componentDel(index`gensym137: TransformMatrixInstance): untyped {.
        used.} =
      delete(index`gensym137)

    template componentAlive(): untyped {.used.} =
      transformmatrixAlive

    template componentGenerations(): untyped {.used.} =
      transformmatrixInstanceIds

    template componentInstanceType(): untyped {.used.} =
      TransformMatrixInstance

    template componentData(): untyped {.used.} =
      storageTransformMatrix

    template isOwned(): bool {.used.} =
      false

    template owningSystemIndex(): SystemIndex {.used.} =
      0.SystemIndex

    actions
  of 3:
    template componentId(): untyped {.used.} =
      3.ComponentTypeId

    template componentName(): untyped {.used.} =
      "Relationship"

    template componentType(): untyped {.used.} =
      Relationship

    template componentRefType(): untyped {.used.} =
      RelationshipRef

    template componentDel(index`gensym138: RelationshipInstance): untyped {.used.} =
      delete(index`gensym138)

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
      sysShouldUpdateTrans

    template ItemType(): typedesc {.used.} =
      SysItemShouldUpdateTrans

    actions
  of 2:
    template sys(): untyped {.used.} =
      sysUpdateSceneInheritance

    template ItemType(): typedesc {.used.} =
      SysItemUpdateSceneInheritance

    actions
  else:
    raise newException(ValueError, "Invalid system index: " & $index.int)
  
template forAllSystems*(actions: untyped): untyped =
  ## This will perform `actions` for every system.
  ## Injects the `sys` template for easier operation.
  block:
    template sys(): untyped {.used.} =
      sysShouldUpdateTrans

    template ItemType(): typedesc {.used.} =
      SysItemShouldUpdateTrans

    actions
  block:
    template sys(): untyped {.used.} =
      sysUpdateSceneInheritance

    template ItemType(): typedesc {.used.} =
      SysItemUpdateSceneInheritance

    actions

type
  SystemsTypeClass* = ShouldUpdateTransSystem | UpdateSceneInheritanceSystem
proc `$`*[T: ComponentIndexTypeClass](val`gensym149: T): string =
  ## Generic `$` for component indexes.
  if val`gensym149.valid:
    result = $val`gensym149.access
  else:
    if val`gensym149.int == InvalidComponentIndex.int:
      result = "<Invalid " & $T & ">"
    else:
      result = "<Out of bounds instance of " & $T & " (index: " &
          $val`gensym149.int &
          ")>"

proc `$`*(componentId`gensym149: ComponentTypeId): string =
  ## Display the name and id for a component type.
  componentId`gensym149.caseComponent:
    result = componentName() & " (" & `$`(int(componentId`gensym149)) & ")"

func typeName*(componentId`gensym149: ComponentTypeId): string =
  componentId`gensym149.caseComponent:
    result = componentName()

proc toString*(componentRef`gensym149: ComponentRef; showData: bool = true): string =
  ## Display the name, type and data for a component reference.
  let tId`gensym149 = componentRef`gensym149.typeId
  tId`gensym149.caseComponent:
    result = componentName() & " (id: " & `$`(int(tId`gensym149)) & ", index: " &
        `$`(componentRef`gensym149.index.int) &
        ", generation: " &
        `$`(componentRef`gensym149.generation.int) &
        ")"
    if showData:
      result &= ":\n"
      try:
        result &=
            `$`(componentInstanceType()(componentRef`gensym149.index.int).access)
      except:
        result &=
            "<ERROR ACCESSING (index: " & `$`(componentRef`gensym149.index.int) &
            ", count: " &
            $(componentInstanceType().componentCount).int &
            ")>\n"

proc `$`*(componentRef`gensym149: ComponentRef; showData: bool = true): string =
  componentRef`gensym149.toString(showData)

proc toString*(comp`gensym149: Component; showData = true): string =
  ## `$` function for dynamic component superclass.
  ## Displays the sub-class data according to the component's `typeId`.
  caseComponent comp`gensym149.typeId:
    result &= componentName()
    if showData:
      result &= ":\n" & $componentRefType()(comp`gensym149).value & "\n"

proc `$`*(comp`gensym149: Component): string =
  comp`gensym149.toString

proc toString*(componentList`gensym149: ComponentList; showData: bool = true): string =
  ## `$` for listing construction templates.
  let maxIdx`gensym149 = componentList`gensym149.high
  for i`gensym149, item`gensym149 in componentList`gensym149:
    let s`gensym149 = item`gensym149.toString(showData)
    if i`gensym149 < maxIdx`gensym149 and not showData:
      result &= s`gensym149 & ", "
    else:
      result &= s`gensym149

proc `$`*(componentList`gensym149: ComponentList): string =
  componentList`gensym149.toString

proc toString*(construction`gensym149: ConstructionTemplate;
               showData: bool = true): string =
  for i`gensym149, item`gensym149 in construction`gensym149:
    result &= `$`(i`gensym149) & ": " & item`gensym149.toString(showData) & "\n"

proc `$`*(construction`gensym149: ConstructionTemplate): string =
  construction`gensym149.toString

proc componentCount*(): int =
  3

proc listSystems*(entity: EntityRef): string =
  if entity.alive:
    var matchesEnt_452986602 = true
    for req`gensym151 in [1'u, 2'u]:
      if req`gensym151.ComponentTypeId notin entity:
        matchesEnt_452986602 = false
        break
    let inSys`gensym152 = sysShouldUpdateTrans.index.hasKey(entity.entityId)
    if matchesEnt_452986602 != inSys`gensym152:
      let issue`gensym152 = if matchesEnt_452986602:
        "[System]: entity contains the required components but is missing from the system index" else:
        "[Entity]: the system index references this entity but the entity doesn\'t have the required components"
      result &=
          "shouldUpdateTrans (sysShouldUpdateTrans)" & " Sync issue " &
          issue`gensym152 &
          "\n"
    elif inSys`gensym152:
      result &= "shouldUpdateTrans (sysShouldUpdateTrans)" & " \n"
    var matchesEnt_452986606 = true
    for req`gensym154 in [3'u, 2'u]:
      if req`gensym154.ComponentTypeId notin entity:
        matchesEnt_452986606 = false
        break
    let inSys`gensym155 = sysUpdateSceneInheritance.index.hasKey(entity.entityId)
    if matchesEnt_452986606 != inSys`gensym155:
      let issue`gensym155 = if matchesEnt_452986606:
        "[System]: entity contains the required components but is missing from the system index" else:
        "[Entity]: the system index references this entity but the entity doesn\'t have the required components"
      result &=
          "updateSceneInheritance (sysUpdateSceneInheritance)" & " Sync issue " &
          issue`gensym155 &
          "\n"
    elif inSys`gensym155:
      result &= "updateSceneInheritance (sysUpdateSceneInheritance)" & " \n"
  else:
    if entity == NO_ENTITY_REF:
      result = "<Entity is NO_ENTITY_REF>"
    else:
      result = "<Entity is not alive>"

proc listComponents*(entity`gensym158: EntityRef; showData`gensym158 = true): string =
  ## List all components attached to an entity.
  ## The parameter `showData` controls whether the component's data is included in the output.
  if entity`gensym158.alive:
    let entityId`gensym158 = entity`gensym158.entityId
    for compRef`gensym158 in entityId`gensym158.components:
      let compDesc`gensym158 = toString(compRef`gensym158, showData`gensym158)
      var
        owned`gensym158: bool
        genMax`gensym158: int
        genStr`gensym158: string
      try:
        caseComponent compRef`gensym158.typeId:
          genMax`gensym158 = componentGenerations().len
          let gen`gensym158 = componentGenerations()[compRef`gensym158.index.int]
          genStr`gensym158 = `$`(gen`gensym158)
          owned`gensym158 = componentInstanceType().isOwnedComponent
      except:
        genStr`gensym158 = " ERROR ACCESSING generations (index: " &
            `$`(compRef`gensym158.index.int) &
            ", count: " &
            `$`(genMax`gensym158) &
            ")"
      result &= compDesc`gensym158
      if owned`gensym158:
        if not compRef`gensym158.alive:
          result &=
              " <DEAD OWNED COMPONENT Type: " & `$`(compRef`gensym158.typeId) &
              ", generation: " &
              genStr`gensym158 &
              ">\n"
      else:
        if not compRef`gensym158.valid:
          result &=
              " <INVALID COMPONENT Type: " & `$`(compRef`gensym158.typeId) &
              ", generation: " &
              genStr`gensym158 &
              ">\n"
      let needsNL`gensym158 = result[^1] != '\n'
      if needsNL`gensym158:
        result &= "\n"
      if showData`gensym158:
        result &= "\n"
  else:
    result &= "[Entity not alive, no component item entry]\n"

proc `$`*(entity: EntityRef; showData`gensym158 = true): string =
  ## `$` function for `EntityRef`.
  ## List all components and what systems the entity uses.
  ## By default adds data inside components with `repr`.
  ## Set `showData` to false to just display the component types.
  let id`gensym158 = entity.entityId.int
  result = "[EntityId: " & $(id`gensym158)
  if id`gensym158 < 1 or id`gensym158 > entityStorage.entityComponents.len:
    result &= " Out of bounds!]"
  else:
    let
      comps`gensym158 = entity.listComponents(showData`gensym158)
      systems`gensym158 = entity.listSystems()
      sys`gensym158 = if systems`gensym158 == "":
        "<No systems used>\n" else:
        systems`gensym158
      invalidStr`gensym158 = if not entity.entityId.valid:
        " INVALID/NULL ENTITY ID" else:
        ""
    result &=
        " (generation: " & $(entity.instance.int) & ")" & invalidStr`gensym158 &
        "\nAlive: " &
        $entity.alive &
        "\nComponents:\n" &
        comps`gensym158 &
        "Systems:\n" &
        $sys`gensym158 &
        "]"

proc `$`*(entity: EntityId): string =
  ## Display the entity currently instantiated for this `EntityId`.
  `$`(entity.makeRef)

proc `$`*(sysIdx`gensym158: SystemIndex): string =
  ## Outputs the system name passed to `sysIdx`.
  caseSystem sysIdx`gensym158:
    systemStr(sys.name)

const
  totalSystemCount* {.used.} = 2
proc analyseSystem*[T](sys`gensym158: T; jumpThreshold`gensym158: Natural = 0): SystemAnalysis =
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
  result.name = sys`gensym158.name
  template getAddressInt(value`gensym158: untyped): int =
    var address`gensym158: pointer
    when value`gensym158 is ComponentIndexTypeClass:
      address`gensym158 = value`gensym158.access.addr
    else:
      address`gensym158 = value`gensym158.unsafeAddr
    cast[int](address`gensym158)

  const
    compCount`gensym158 = sys`gensym158.requirements.len
  result.components.setLen compCount`gensym158
  result.entities = sys`gensym158.count
  template component(idx`gensym158): untyped =
    result.components[idx`gensym158]

  var
    sysItem`gensym158: sys`gensym158.itemType
    fieldIdx`gensym158 = 0
  for field`gensym158, value`gensym158 in sysItem`gensym158.fieldPairs:
    when not (value`gensym158 is EntityRef):
      when value`gensym158 is ComponentIndexTypeClass:
        type
          valueType`gensym158 = value`gensym158.access.type
      else:
        type
          valueType`gensym158 = value`gensym158.type
      let valueSize`gensym158 = valueType`gensym158.sizeof
      component(fieldIdx`gensym158).name = field`gensym158
      component(fieldIdx`gensym158).valueSize = valueSize`gensym158
      component(fieldIdx`gensym158).jumpThreshold = if jumpThreshold`gensym158 ==
          0:
        if value`gensym158.isOwnedComponent:
          sysItem`gensym158.sizeof
        else:
          valueSize`gensym158 else:
        jumpThreshold`gensym158
      fieldIdx`gensym158 += 1
  var lastAddresses`gensym158: array[compCount`gensym158, int]
  let systemItems`gensym158 = sys`gensym158.count
  if systemItems`gensym158 > 1:
    const
      startIdx`gensym158 = if sys`gensym158.isOwner:
        2 else:
        1
    fieldIdx`gensym158 = 0
    for value`gensym158 in sys`gensym158.groups[startIdx`gensym158 - 1].fields:
      when not (value`gensym158 is EntityRef):
        lastAddresses`gensym158[fieldIdx`gensym158] = value`gensym158.getAddressInt
        fieldIdx`gensym158 += 1
    for i`gensym158 in startIdx`gensym158 ..< systemItems`gensym158:
      fieldIdx`gensym158 = 0
      for value`gensym158 in sys`gensym158.groups[i`gensym158].fields:
        when not (value`gensym158 is EntityRef):
          let
            thresh`gensym158 = component(fieldIdx`gensym158).jumpThreshold
            address`gensym158 = getAddressInt(value`gensym158)
            diff`gensym158 = address`gensym158 -
                lastAddresses`gensym158[fieldIdx`gensym158]
          var tagged`gensym158: bool
          component(fieldIdx`gensym158).allData.push diff`gensym158
          if diff`gensym158 < 0:
            component(fieldIdx`gensym158).backwardsJumps += 1
            tagged`gensym158 = true
          elif diff`gensym158 > thresh`gensym158:
            component(fieldIdx`gensym158).forwardJumps += 1
            tagged`gensym158 = true
          if tagged`gensym158:
            component(fieldIdx`gensym158).taggedData.push diff`gensym158
          lastAddresses`gensym158[fieldIdx`gensym158] = address`gensym158
          fieldIdx`gensym158 += 1
    for i`gensym158, c`gensym158 in result.components:
      component(i`gensym158).fragmentation = (
          c`gensym158.backwardsJumps + c`gensym158.forwardJumps).float /
          systemItems`gensym158.float

proc summary*(analysis`gensym158: SystemAnalysis): string =
  ## List the fragmentation for each component in the analysis system.
  result = analysis`gensym158.name & ":"
  for component`gensym158 in analysis`gensym158.components:
    result &=
        "\n  " & component`gensym158.name & ": " &
        formatFloat(component`gensym158.fragmentation * 100.0, ffDecimal, 3) &
        "%"

proc `$`*(analysis`gensym158: SystemAnalysis): string =
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
    alignPos`gensym158 = 70
    decimals`gensym158 = 4
  result = "Analysis for " & analysis`gensym158.name & " (" &
      $analysis`gensym158.entities &
      " rows of " &
      $analysis`gensym158.components.len &
      " components):\n"
  if analysis`gensym158.components.len == 0:
    result &= "<No components found>\n"
  else:
    func numStr(value`gensym158: float; precision`gensym158 = decimals`gensym158): string =
      result = formatFloat(value`gensym158, ffDecimal, precision`gensym158)
      trimZeros(result)

    func numStr(value`gensym158: SomeInteger): string =
      let
        strVal`gensym158 = $value`gensym158
        digits`gensym158 = strVal`gensym158.len
      result.setLen digits`gensym158 + (digits`gensym158 div 3)
      var pos`gensym158: int
      for d`gensym158 in 0 ..< digits`gensym158:
        if d`gensym158 > 0 and ((digits`gensym158 - d`gensym158) mod 3 == 0):
          result[pos`gensym158] = ','
          result[pos`gensym158 + 1] = strVal`gensym158[d`gensym158]
          pos`gensym158 += 2
        else:
          result[pos`gensym158] = strVal`gensym158[d`gensym158]
          pos`gensym158 += 1

    func pad(s1`gensym158, s2`gensym158: string): string =
      if s2`gensym158.len > 0:
        s1`gensym158 & spaces(max(1, alignPos`gensym158 - s1`gensym158.len)) &
            s2`gensym158
      else:
        s1`gensym158

    for c`gensym158 in analysis`gensym158.components:
      func dataStr(data`gensym158: RunningStat): string =
        func eqTol(a`gensym158, b`gensym158: float; tol`gensym158 = 0.001): bool =
          abs(a`gensym158 - b`gensym158) < tol`gensym158

        let
          exKurt`gensym158 = data`gensym158.kurtosis - 3.0
          dataRange`gensym158 = data`gensym158.max - data`gensym158.min
        const
          cont`gensym158 = -6 / 5
          indent`gensym158 = "      "
        result = pad(indent`gensym158 & "Min: " & data`gensym158.min.numStr &
            ", max: " &
            $data`gensym158.max.numStr &
            ", sum: " &
            $data`gensym158.sum.numStr, "Range: " &
            formatSize(dataRange`gensym158.int64, includeSpace = true)) &
            "\n" &
            indent`gensym158 &
            "Mean: " &
            $data`gensym158.mean.numStr &
            "\n" &
            pad(indent`gensym158 & "Std dev: " &
            data`gensym158.standardDeviation.numStr, "CoV: " &
          if data`gensym158.mean != 0.0:
            numStr(data`gensym158.standardDeviation / data`gensym158.mean)
           else:
            "N/A" &
            "\n") &
            indent`gensym158 &
            "Variance: " &
            $data`gensym158.variance.numStr &
            "\n" &
            pad(indent`gensym158 & "Kurtosis/spread (normal = 3.0): " &
            $data`gensym158.kurtosis.numStr &
            " (excess: " &
            exKurt`gensym158.numStr &
            ")", if exKurt`gensym158 > 2.0:
          "Many outliers" elif exKurt`gensym158.eqTol 0.0:
          "Normally distributed" elif exKurt`gensym158.eqTol cont`gensym158:
          "Continuous/no outliers" elif exKurt`gensym158 < -2.0:
          "Few outliers" else:
          "") &
            "\n" &
            pad(indent`gensym158 & "Skewness: " &
            $data`gensym158.skewness.numStr, if data`gensym158.skewness < 0:
          "Outliers trend backwards" elif data`gensym158.skewness > 0:
          "Outliers trend forwards" else:
          "") &
            "\n"

      let
        jt`gensym158 = c`gensym158.jumpThreshold.float
        n`gensym158 = c`gensym158.allData.n
        fwdPerc`gensym158 = if n`gensym158 > 0:
          numStr((c`gensym158.forwardJumps / n`gensym158) * 100.0) else:
          "N/A"
        bkdPerc`gensym158 = if n`gensym158 > 0:
          numStr((c`gensym158.backwardsJumps / n`gensym158) * 100.0) else:
          "N/A"
        indent`gensym158 = "    "
      result &=
          "  " & c`gensym158.name & ":\n" & indent`gensym158 & "Value size: " &
          formatSize(c`gensym158.valueSize, includeSpace = true) &
          ", jump threshold: " &
          formatSize(c`gensym158.jumpThreshold, includeSpace = true) &
          "\n" &
          pad(indent`gensym158 & "Jumps over threshold : " &
          $c`gensym158.forwardJumps.numStr,
              "Jump ahead: " & fwdPerc`gensym158 & " %") &
          "\n" &
          pad(indent`gensym158 & "Backwards jumps      : " &
          $c`gensym158.backwardsJumps.numStr,
              "Jump back: " & bkdPerc`gensym158 & " %") &
          "\n" &
          indent`gensym158 &
          "Fragmentation: " &
          numStr(c`gensym158.fragmentation * 100.0) &
          " %" &
          " (n = " &
          $c`gensym158.taggedData.n &
          "):\n"
      if c`gensym158.taggedData.n > 0:
        result &=
            indent`gensym158 & "  Mean scale: " &
            numStr(c`gensym158.taggedData.mean / jt`gensym158) &
            " times threshold\n" &
            c`gensym158.taggedData.dataStr
      else:
        result &= indent`gensym158 & "  <No fragmented indirections>\n"
      result &=
          indent`gensym158 & "All address deltas (n = " & $n`gensym158 & "):\n"
      if n`gensym158 > 0:
        result &= c`gensym158.allData.dataStr
      else:
        result &= indent`gensym158 & "  <No data>\n"

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

macro addComponents*(id`gensym164: static[EcsIdentity]; entity: EntityRef;
                     componentList: varargs[typed]): untyped =
  ## Add components to a specific identity.
  doAddComponents(id`gensym164, entity, componentList)

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

macro removeComponent*(entity: EntityRef; component`gensym164: typed) =
  ## Remove a component from an entity.
  doRemoveComponents(EcsIdentity("default"), entity, component`gensym164)

template removeComponents*(entity`gensym164: EntityRef;
                           compList`gensym164: ComponentList) =
  ## Remove a run time list of components from the entity.
  for c`gensym164 in compList`gensym164:
    assert c`gensym164.typeId != InvalidComponent
    caseComponent c`gensym164.typeId:
      removeComponent(entity`gensym164, componentType())

template add*(entity: EntityRef; component`gensym164: ComponentTypeclass) =
  entity.addComponent component`gensym164

proc addComponent*[T: ComponentTypeclass](entity: EntityRef;
    component`gensym165: T): auto {.discardable.} =
  ## Add a single component to `entity` and return the instance.
  entity.addComponents(component`gensym165)[0]

proc addOrUpdate*[T: ComponentTypeclass](entity: EntityRef;
    component`gensym165: T): auto {.discardable.} =
  ## Add `component` to `entity`, or if `component` already exists, overwrite it.
  ## Returns the component instance.
  let fetched`gensym165 = entity.fetchComponent typedesc[T]
  if fetched`gensym165.valid:
    update(fetched`gensym165, component`gensym165)
    result = fetched`gensym165
  else:
    result = addComponent(entity, component`gensym165)

proc addIfMissing*[T: ComponentTypeclass](entity: EntityRef;
    component`gensym165: T): auto {.discardable.} =
  ## Add a component only if it isn't already present.
  ## If the component is already present, no changes are made and an invalid result is returned.
  ## If the component isn't present, it will be added and the instance is returned.
  if not entity.hasComponent typedesc[T]:
    result = addComponent(entity, component`gensym165)

proc fetchOrAdd*[T: ComponentTypeclass](entity: EntityRef;
                                        component`gensym165: typedesc[T]): auto {.
    discardable.} =
  ## Fetch an existing component type if present, otherwise add
  ## the component type and return the instance.
  ## 
  ## This is useful when you always want a valid component
  ## instance returned, but don't want to overwrite existing
  ## data.
  result = entity.fetchComponent typedesc[T]
  if not result.valid:
    result = addComponent(entity, component`gensym165())

template addComponents*(entity: EntityRef; components`gensym166: ComponentList) =
  ## Add components from a list.
  ## Each component is assembled by it's run time `typeId`.
  static :
    startOperation(EcsIdentity("default"), "Add components from ref list")
  {.line.}:
    for c`gensym166 in components`gensym166:
      caseComponent c`gensym166.typeId:(discard entity.addComponent
          componentRefType()(c`gensym166).value)
  static :
    endOperation(EcsIdentity("default"))

template add*(entity: EntityRef; components`gensym166: ComponentList) =
  ## Add components from a list.
  ## Each component is assembled by its run time `typeId`.
  addComponents(entity, components`gensym166)

template addIfMissing*(entity`gensym166: EntityRef;
                       components`gensym166: ComponentList) =
  ## Add components from a list if they're not already present.
  {.line.}:
    for c`gensym166 in components`gensym166:
      caseComponent c`gensym166.typeId:
        entity`gensym166.addIfMissing componentRefType()(c`gensym166).value

template addOrUpdate*(entity`gensym166: EntityRef;
                      components`gensym166: ComponentList) =
  ## Add or update components from a list.
  {.line.}:
    for c`gensym166 in components`gensym166:
      caseComponent c`gensym166.typeId:(discard addOrUpdate(entity`gensym166,
          componentRefType()(c`gensym166).value))

template updateComponents*(entity`gensym166: EntityRef;
                           components`gensym166: ComponentList) =
  ## Updates existing components from a list.
  ## Components not found on the entity exist are ignored.
  {.line.}:
    for c`gensym166 in components`gensym166:
      caseComponent c`gensym166.typeId:
        let inst`gensym166 = entity`gensym166.fetchComponent componentType()
        if inst`gensym166.valid:
          inst`gensym166.update componentRefType()(c`gensym166).value

template update*(entity`gensym166: EntityRef;
                 components`gensym166: ComponentList) =
  ## Updates existing components from a list.
  ## Components not found on the entity are ignored.
  updateComponents(entity`gensym166, components`gensym166)

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
  var sysProcessed_452986733: set[SystemsEnum]
  block:
    for curComp_452986732 in entity:
      case curComp_452986732.typeId.int
      of 1:
        var sysFetchshouldUpdateTrans__VKyIrfLUK6NeG39bDAuMnQw: SystemFetchResult
        sysFetchshouldUpdateTrans__VKyIrfLUK6NeG39bDAuMnQw.found =
          sysFetchshouldUpdateTrans__VKyIrfLUK6NeG39bDAuMnQw.row = sysShouldUpdateTrans.index.getOrDefault(
              entity.entityId, -1)
          sysFetchshouldUpdateTrans__VKyIrfLUK6NeG39bDAuMnQw.row >= 0
        if seShouldUpdateTrans notin sysProcessed_452986733:
          sysProcessed_452986733.incl seShouldUpdateTrans
          if sysFetchshouldUpdateTrans__VKyIrfLUK6NeG39bDAuMnQw.found:
            sysShouldUpdateTrans.index.del(entity.entityId)
            let
              topIdx`gensym173 = sysShouldUpdateTrans.groups.high
              ri`gensym173 = sysFetchshouldUpdateTrans__VKyIrfLUK6NeG39bDAuMnQw.row
            if ri`gensym173 < topIdx`gensym173:
              sysShouldUpdateTrans.groups[ri`gensym173] = move
                  sysShouldUpdateTrans.groups[topIdx`gensym173]
              let updatedRowEnt_452986769 = sysShouldUpdateTrans.groups[
                  ri`gensym173].entity
              {.line.}:
                assert updatedRowEnt_452986769.alive, "Internal error: dead entity in system groups: id = " &
                    $updatedRowEnt_452986769.entityId.int &
                    ", current entity id upper bound = " &
                    $entityStorage.entityComponents.len
              sysShouldUpdateTrans.index[updatedRowEnt_452986769.entityId] = sysFetchshouldUpdateTrans__VKyIrfLUK6NeG39bDAuMnQw.row
            {.line.}:
              assert sysShouldUpdateTrans.groups.len > 0, "Internal error: system \"" &
                  sysShouldUpdateTrans.name &
                  "\" groups are empty but is scheduling to delete from row " &
                  $ri`gensym173 &
                  ". Top row is " &
                  $topIdx`gensym173
            sysShouldUpdateTrans.groups.setLen(
                sysShouldUpdateTrans.groups.len - 1)
            static :
              recordMutation(EcsIdentity("default"), ekRowRemoved, [1])
      of 2:
        var sysFetchshouldUpdateTrans__VKyIrfLUK6NeG39bDAuMnQw: SystemFetchResult
        sysFetchshouldUpdateTrans__VKyIrfLUK6NeG39bDAuMnQw.found =
          sysFetchshouldUpdateTrans__VKyIrfLUK6NeG39bDAuMnQw.row = sysShouldUpdateTrans.index.getOrDefault(
              entity.entityId, -1)
          sysFetchshouldUpdateTrans__VKyIrfLUK6NeG39bDAuMnQw.row >= 0
        if seShouldUpdateTrans notin sysProcessed_452986733:
          sysProcessed_452986733.incl seShouldUpdateTrans
          if sysFetchshouldUpdateTrans__VKyIrfLUK6NeG39bDAuMnQw.found:
            sysShouldUpdateTrans.index.del(entity.entityId)
            let
              topIdx`gensym187 = sysShouldUpdateTrans.groups.high
              ri`gensym187 = sysFetchshouldUpdateTrans__VKyIrfLUK6NeG39bDAuMnQw.row
            if ri`gensym187 < topIdx`gensym187:
              sysShouldUpdateTrans.groups[ri`gensym187] = move
                  sysShouldUpdateTrans.groups[topIdx`gensym187]
              let updatedRowEnt_452986883 = sysShouldUpdateTrans.groups[
                  ri`gensym187].entity
              {.line.}:
                assert updatedRowEnt_452986883.alive, "Internal error: dead entity in system groups: id = " &
                    $updatedRowEnt_452986883.entityId.int &
                    ", current entity id upper bound = " &
                    $entityStorage.entityComponents.len
              sysShouldUpdateTrans.index[updatedRowEnt_452986883.entityId] = sysFetchshouldUpdateTrans__VKyIrfLUK6NeG39bDAuMnQw.row
            {.line.}:
              assert sysShouldUpdateTrans.groups.len > 0, "Internal error: system \"" &
                  sysShouldUpdateTrans.name &
                  "\" groups are empty but is scheduling to delete from row " &
                  $ri`gensym187 &
                  ". Top row is " &
                  $topIdx`gensym187
            sysShouldUpdateTrans.groups.setLen(
                sysShouldUpdateTrans.groups.len - 1)
            static :
              recordMutation(EcsIdentity("default"), ekRowRemoved, [1])
        var sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw: SystemFetchResult
        sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.found =
          sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row = sysUpdateSceneInheritance.index.getOrDefault(
              entity.entityId, -1)
          sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row >= 0
        if seUpdateSceneInheritance notin sysProcessed_452986733:
          sysProcessed_452986733.incl seUpdateSceneInheritance
          if sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.found:
            sysUpdateSceneInheritance.index.del(entity.entityId)
            let
              topIdx`gensym195 = sysUpdateSceneInheritance.groups.high
              ri`gensym195 = sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row
            if ri`gensym195 < topIdx`gensym195:
              sysUpdateSceneInheritance.groups[ri`gensym195] = move
                  sysUpdateSceneInheritance.groups[topIdx`gensym195]
              let updatedRowEnt_452986886 = sysUpdateSceneInheritance.groups[
                  ri`gensym195].entity
              {.line.}:
                assert updatedRowEnt_452986886.alive, "Internal error: dead entity in system groups: id = " &
                    $updatedRowEnt_452986886.entityId.int &
                    ", current entity id upper bound = " &
                    $entityStorage.entityComponents.len
              sysUpdateSceneInheritance.index[updatedRowEnt_452986886.entityId] = sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row
            {.line.}:
              assert sysUpdateSceneInheritance.groups.len > 0, "Internal error: system \"" &
                  sysUpdateSceneInheritance.name &
                  "\" groups are empty but is scheduling to delete from row " &
                  $ri`gensym195 &
                  ". Top row is " &
                  $topIdx`gensym195
            sysUpdateSceneInheritance.groups.setLen(
                sysUpdateSceneInheritance.groups.len - 1)
            static :
              recordMutation(EcsIdentity("default"), ekRowRemoved, [2])
      of 3:
        var sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw: SystemFetchResult
        sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.found =
          sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row = sysUpdateSceneInheritance.index.getOrDefault(
              entity.entityId, -1)
          sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row >= 0
        if seUpdateSceneInheritance notin sysProcessed_452986733:
          sysProcessed_452986733.incl seUpdateSceneInheritance
          if sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.found:
            sysUpdateSceneInheritance.index.del(entity.entityId)
            let
              topIdx`gensym214 = sysUpdateSceneInheritance.groups.high
              ri`gensym214 = sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row
            if ri`gensym214 < topIdx`gensym214:
              sysUpdateSceneInheritance.groups[ri`gensym214] = move
                  sysUpdateSceneInheritance.groups[topIdx`gensym214]
              let updatedRowEnt_452986889 = sysUpdateSceneInheritance.groups[
                  ri`gensym214].entity
              {.line.}:
                assert updatedRowEnt_452986889.alive, "Internal error: dead entity in system groups: id = " &
                    $updatedRowEnt_452986889.entityId.int &
                    ", current entity id upper bound = " &
                    $entityStorage.entityComponents.len
              sysUpdateSceneInheritance.index[updatedRowEnt_452986889.entityId] = sysFetchupdateSceneInheritance__VKyIrfLUK6NeG39bDAuMnQw.row
            {.line.}:
              assert sysUpdateSceneInheritance.groups.len > 0, "Internal error: system \"" &
                  sysUpdateSceneInheritance.name &
                  "\" groups are empty but is scheduling to delete from row " &
                  $ri`gensym214 &
                  ". Top row is " &
                  $topIdx`gensym214
            sysUpdateSceneInheritance.groups.setLen(
                sysUpdateSceneInheritance.groups.len - 1)
            static :
              recordMutation(EcsIdentity("default"), ekRowRemoved, [2])
      else:
        discard
  for compRef`gensym227 in entityData(entityId).componentRefs:
    caseComponent compRef`gensym227.typeId:
      componentDel(componentInstanceType()(compRef`gensym227.index))
  entityData(entityId).componentRefs.setLen(0)
  entityData(entityId).setup = false
  entityStorage.entityCounter -= 1
  entityStorage.entityRecycler.add entityId
  if entityStorage.entityCounter == 0:
    entityStorage.entityRecycler.setLen 0
    entityStorage.nextEntityId = FIRST_ENTITY_ID
  static :
    endOperation(EcsIdentity("default"))

proc deleteAll*(entities`gensym233: var Entities; resize`gensym233 = true) =
  for i`gensym233 in 0 ..< entities`gensym233.len:
    entities`gensym233[i`gensym233].delete
  if resize`gensym233:
    entities`gensym233.setLen 0

proc resetEntityStorage*() =
  ## This deletes all entities, removes them from associated systems and resets next entity.
  for i`gensym233 in 0 ..< entityStorage.nextEntityId.int:
    let ent`gensym233 = (i`gensym233.EntityId).makeRef
    ent`gensym233.delete
  entityStorage.entityRecycler.setLen 0
  entityStorage.nextEntityId = FIRST_ENTITY_ID
  entityStorage.entityCounter = 0

template matchToSystems*(componentTypeId`gensym234: ComponentTypeId;
                         actions`gensym234: untyped): untyped =
  forAllSystems:
    if componentTypeId`gensym234 in system.requirements:
      actions`gensym234

template transition*(entity`gensym234: EntityRef;
                     prevState`gensym234, newState`gensym234: ComponentList;
                     transitionType`gensym234: static[EntityTransitionType]) =
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
    if prevState`gensym234.len > 0:
      when transitionType`gensym234 == ettUpdate:
        var newIds`gensym234 = newSeq[ComponentTypeId](newState`gensym234.len)
        for i`gensym234, c`gensym234 in newState`gensym234:
          newIds`gensym234[i`gensym234] = c`gensym234.typeId
        for c`gensym234 in prevState`gensym234:
          let tyId`gensym234 = c`gensym234.typeId
          if tyId`gensym234 notin newIds`gensym234:
            caseComponent tyId`gensym234:
              entity`gensym234.removeComponent componentType()
      elif transitionType`gensym234 == ettRemoveAdd:
        for c`gensym234 in prevState`gensym234:
          caseComponent c`gensym234.typeId:
            entity`gensym234.removeComponent componentType()
      else:
        {.fatal: "Unknown transition type \'" & $transitionType`gensym234 &
            "\'".}
    entity`gensym234.addOrUpdate newState`gensym234

template transition*(entity`gensym234: EntityRef;
                     prevState`gensym234, newState`gensym234: ComponentList) =
  ## Removes components in `prevState` that aren't in `newState` and
  ## adds or updates components in `newState`.
  transition(entity`gensym234, prevState`gensym234, newState`gensym234,
             ettUpdate)

var
  manualConstruct: array[1 .. 3, ConstructorProc]
  postConstruct: array[1 .. 3, PostConstructorProc]
  cloneConstruct: array[1 .. 3, CloneConstructorProc]
proc registerConstructor*(typeId: ComponentTypeId; callback: ConstructorProc) =
  manualConstruct[typeId.int] = callback

template registerConstructor*(t`gensym441: typedesc[ComponentTypeClass];
                              callback: ConstructorProc) =
  registerConstructor(t`gensym441.typeId, callback)

proc registerPostConstructor*(typeId: ComponentTypeId;
                              callback: PostConstructorProc) =
  postConstruct[typeId.int] = callback

template registerPostConstructor*(t`gensym441: typedesc[ComponentTypeClass];
                                  callback: PostConstructorProc) =
  registerPostConstructor(t`gensym441.typeId, callback)

proc registerCloneConstructor*(typeId: ComponentTypeId;
                               callback: CloneConstructorProc) =
  cloneConstruct[typeId.int] = callback

template registerCloneConstructor*(t`gensym441: typedesc[ComponentTypeClass];
                                   callback: CloneConstructorProc) =
  registerCloneConstructor(t`gensym441.typeId, callback)

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
  let contextEnt`gensym441 = if context.entityId != NO_ENTITY:
    context else:
    result
  var
    types: Table[int, tuple[component: Component, compIdx: ComponentIndex]]
    visited_452987007 {.used.}: set[SystemsEnum]
  for compRef`gensym441 in componentList:
    assert compRef`gensym441.typeId != InvalidComponent, "Cannot construct: invalid component type id: " &
        $compRef`gensym441.typeId.int
    assert not types.hasKey(compRef`gensym441.typeId.int), "Cannot construct: Entity has duplicate components for " &
        $compRef`gensym441.typeId
    var reference: ComponentRef
    caseComponent compRef`gensym441.typeId:
      let cb`gensym441 = manualConstruct[compRef`gensym441.typeId.int]
      if cb`gensym441 != nil:
        let compsAdded`gensym441 = cb`gensym441(result, compRef`gensym441,
            contextEnt`gensym441)
        for comp`gensym441 in compsAdded`gensym441:
          assert comp`gensym441.typeId != InvalidComponent, "Cannot construct: invalid component type id: " &
              $comp`gensym441.typeId.int
          assert not types.hasKey(comp`gensym441.typeId.int), "Cannot construct: Entity has duplicate components for " &
              $comp`gensym441.typeId
          caseComponent comp`gensym441.typeId:
            when owningSystemIndex == InvalidSystemIndex:
              reference = newInstance(componentRefType()(comp`gensym441).value).toRef
            else:
              let
                c`gensym441 = owningSystem.count
                nextGen`gensym441 = if c`gensym441 < componentGenerations().len:
                  (componentGenerations()[c`gensym441].int + 1).ComponentGeneration else:
                  1.ComponentGeneration
              reference = (componentId(), owningSystem.count.ComponentIndex,
                           nextGen`gensym441)
            entityData(result.entityId).componentRefs.add(reference)
            types[comp`gensym441.typeId.int] = (comp`gensym441, reference.index)
      else:
        when owningSystemIndex == InvalidSystemIndex:
          reference = newInstance(componentRefType()(compRef`gensym441).value).toRef
        else:
          let
            c`gensym441 = owningSystem.count
            nextGen`gensym441 = if c`gensym441 < componentGenerations().len:
              (componentGenerations()[c`gensym441].int + 1).ComponentGeneration else:
              1.ComponentGeneration
          reference = (componentId(), owningSystem.count.ComponentIndex,
                       nextGen`gensym441)
        entityData(result.entityId).componentRefs.add(reference)
        types[compRef`gensym441.typeId.int] = (compRef`gensym441,
            reference.index)
  for curCompInfo in types.pairs:
    case curCompInfo[1].component.typeId.int
    of 1:
      if types.hasKey(2) and types.hasKey(1):
        if seShouldUpdateTrans notin visited_452987007:
          visited_452987007.incl seShouldUpdateTrans
          {.line.}:
            assert not (sysShouldUpdateTrans.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"shouldUpdateTrans\""
          var row_452987065: int
          sysShouldUpdateTrans.groups.add(SysItemShouldUpdateTrans(
              entity: result, transform: TransformInstance(types[1][1]),
              transformMatrix: TransformMatrixInstance(types[2][1])))
          row_452987065 = sysShouldUpdateTrans.groups.high
          sysShouldUpdateTrans.index[result.entityId] = row_452987065
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [1])
    of 2:
      if types.hasKey(2) and types.hasKey(1):
        if seShouldUpdateTrans notin visited_452987007:
          visited_452987007.incl seShouldUpdateTrans
          {.line.}:
            assert not (sysShouldUpdateTrans.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"shouldUpdateTrans\""
          var row_452987145: int
          sysShouldUpdateTrans.groups.add(SysItemShouldUpdateTrans(
              entity: result, transform: TransformInstance(types[1][1]),
              transformMatrix: TransformMatrixInstance(types[2][1])))
          row_452987145 = sysShouldUpdateTrans.groups.high
          sysShouldUpdateTrans.index[result.entityId] = row_452987145
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [1])
      if types.hasKey(3) and types.hasKey(2):
        if seUpdateSceneInheritance notin visited_452987007:
          visited_452987007.incl seUpdateSceneInheritance
          {.line.}:
            assert not (sysUpdateSceneInheritance.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"updateSceneInheritance\""
          var row_452987146: int
          sysUpdateSceneInheritance.groups.add(SysItemUpdateSceneInheritance(
              entity: result,
              relationship: RelationshipInstance(types[3][1]),
              transformMatrix: TransformMatrixInstance(types[2][1])))
          row_452987146 = sysUpdateSceneInheritance.groups.high
          sysUpdateSceneInheritance.index[result.entityId] = row_452987146
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [2])
    of 3:
      if types.hasKey(3) and types.hasKey(2):
        if seUpdateSceneInheritance notin visited_452987007:
          visited_452987007.incl seUpdateSceneInheritance
          {.line.}:
            assert not (sysUpdateSceneInheritance.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"updateSceneInheritance\""
          var row_452987149: int
          sysUpdateSceneInheritance.groups.add(SysItemUpdateSceneInheritance(
              entity: result,
              relationship: RelationshipInstance(types[3][1]),
              transformMatrix: TransformMatrixInstance(types[2][1])))
          row_452987149 = sysUpdateSceneInheritance.groups.high
          sysUpdateSceneInheritance.index[result.entityId] = row_452987149
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [2])
    else:
      discard
  visited_452987007 = {}
  static :
    endOperation(EcsIdentity("default"))

proc construct*(construction: ComponentList; amount`gensym441: int;
                context = NO_ENTITY_REF): seq[EntityRef] {.discardable.} =
  for i`gensym441 in 0 ..< amount`gensym441:
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
      var compIdx`gensym440: int
      while compIdx`gensym440 < entityData(entity.entityId).componentRefs.len:
        let
          compRef`gensym440 = entityData(entity.entityId).componentRefs[
              compIdx`gensym440]
          tId`gensym440 = compRef`gensym440.typeId
          pc`gensym440 = postConstruct[tId`gensym440.int]
        if pc`gensym440 != nil:
          pc`gensym440(entity, compRef`gensym440, result)
        compIdx`gensym440 += 1
      i += 1

proc toTemplate*(entity: EntityRef): seq[Component] =
  ## Creates a list of components ready to be used for construction.
  assert entity.alive
  let length`gensym441 = entityData(entity.entityId).componentRefs.len
  result = newSeq[Component](length`gensym441)
  for i`gensym441, compRef`gensym441 in entity.entityId.pairs:
    caseComponent(compRef`gensym441.typeId):
      result[i`gensym441] = componentInstanceType()(compRef`gensym441.index).makeContainer()

proc clone*(entity`gensym441: EntityRef): EntityRef =
  ## Copy an entity's components to a new entity.
  ## Note that copying objects with pointers/references can have undesirable results.
  ## For special setup, use `registerCloneConstructor` for the type. This gets passed
  ## the clone type it would have added. You can then add a modified component or 
  ## entirely different set of components, or ignore it by not adding anything.
  let entity = entity`gensym441
  assert entity.alive, "Cloning a dead entity"
  static :
    startOperation(EcsIdentity("default"), "clone")
  result = newEntity()
  var
    types: Table[int, ComponentIndex]
    visited_452987008 {.used.}: set[SystemsEnum]
  for compRef`gensym441 in entity.components:
    assert compRef`gensym441.typeId != InvalidComponent, "Cannot construct: invalid component type id: " &
        $compRef`gensym441.typeId.int
    assert not types.hasKey(compRef`gensym441.typeId.int), "Cannot construct: Entity has duplicate components for " &
        $compRef`gensym441.typeId
    var reference: ComponentRef
    caseComponent compRef`gensym441.typeId:
      let cb`gensym441 = cloneConstruct[compRef`gensym441.typeId.int]
      if cb`gensym441 != nil:
        let compsAdded`gensym441 = cb`gensym441(result, compRef`gensym441)
        for comp`gensym441 in compsAdded`gensym441:
          assert comp`gensym441.typeId != InvalidComponent, "Cannot construct: invalid component type id: " &
              $comp`gensym441.typeId.int
          assert not types.hasKey(comp`gensym441.typeId.int), "Cannot construct: Entity has duplicate components for " &
              $comp`gensym441.typeId
          caseComponent comp`gensym441.typeId:
            when owningSystemIndex == InvalidSystemIndex:
              reference = newInstance(componentRefType()(comp`gensym441).value).toRef
            else:
              reference = (componentId(), owningSystem.count.ComponentIndex,
                           1.ComponentGeneration)
            entityData(result.entityId).componentRefs.add(reference)
            types[comp`gensym441.typeId.int] = reference.index
      else:
        when owningSystemIndex == InvalidSystemIndex:
          reference = newInstance(componentInstanceType()(
              compRef`gensym441.index).access).toRef
        else:
          reference = compRef`gensym441
        entityData(result.entityId).componentRefs.add(reference)
        types[compRef`gensym441.typeId.int] = reference.index
  for curCompInfo in types.pairs:
    case curCompInfo[0]
    of 1:
      if types.hasKey(2) and types.hasKey(1):
        if seShouldUpdateTrans notin visited_452987008:
          visited_452987008.incl seShouldUpdateTrans
          {.line.}:
            assert not (sysShouldUpdateTrans.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"shouldUpdateTrans\""
          var row_452987152: int
          sysShouldUpdateTrans.groups.add(SysItemShouldUpdateTrans(
              entity: result, transform: TransformInstance(types[1]),
              transformMatrix: TransformMatrixInstance(types[2])))
          row_452987152 = sysShouldUpdateTrans.groups.high
          sysShouldUpdateTrans.index[result.entityId] = row_452987152
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [1])
    of 2:
      if types.hasKey(2) and types.hasKey(1):
        if seShouldUpdateTrans notin visited_452987008:
          visited_452987008.incl seShouldUpdateTrans
          {.line.}:
            assert not (sysShouldUpdateTrans.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"shouldUpdateTrans\""
          var row_452987155: int
          sysShouldUpdateTrans.groups.add(SysItemShouldUpdateTrans(
              entity: result, transform: TransformInstance(types[1]),
              transformMatrix: TransformMatrixInstance(types[2])))
          row_452987155 = sysShouldUpdateTrans.groups.high
          sysShouldUpdateTrans.index[result.entityId] = row_452987155
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [1])
      if types.hasKey(3) and types.hasKey(2):
        if seUpdateSceneInheritance notin visited_452987008:
          visited_452987008.incl seUpdateSceneInheritance
          {.line.}:
            assert not (sysUpdateSceneInheritance.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"updateSceneInheritance\""
          var row_452987156: int
          sysUpdateSceneInheritance.groups.add(SysItemUpdateSceneInheritance(
              entity: result, relationship: RelationshipInstance(types[3]),
              transformMatrix: TransformMatrixInstance(types[2])))
          row_452987156 = sysUpdateSceneInheritance.groups.high
          sysUpdateSceneInheritance.index[result.entityId] = row_452987156
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [2])
    of 3:
      if types.hasKey(3) and types.hasKey(2):
        if seUpdateSceneInheritance notin visited_452987008:
          visited_452987008.incl seUpdateSceneInheritance
          {.line.}:
            assert not (sysUpdateSceneInheritance.index.hasKey(result.entityId)), "Duplicate insert of entityId " &
                $result.entityId.int &
                " for system \"updateSceneInheritance\""
          var row_452987159: int
          sysUpdateSceneInheritance.groups.add(SysItemUpdateSceneInheritance(
              entity: result, relationship: RelationshipInstance(types[3]),
              transformMatrix: TransformMatrixInstance(types[2])))
          row_452987159 = sysUpdateSceneInheritance.groups.high
          sysUpdateSceneInheritance.index[result.entityId] = row_452987159
          static :
            recordMutation(EcsIdentity("default"), ekRowAdded, [2])
    else:
      discard
  static :
    endOperation(EcsIdentity("default"))


# Commit systems for "default", wrapped to proc `transformSystem()`
# -----------------------------------------------------------------

proc doShouldUpdateTrans*(sys: var ShouldUpdateTransSystem) =
  ## System "shouldUpdateTrans", using components: Transform, TransformMatrix
  if not sys.disabled:
    static :
      EcsIdentity("default").setinSystem true
      EcsIdentity("default").setinSystemIndex 1.SystemIndex
      EcsIdentity("default").setsysRemoveAffectedThisSystem false
      EcsIdentity("default").setsystemCalledDelete false
      const
        errPrelude`gensym32 = "Internal error: "
        internalError`gensym32 = " macrocache storage is unexpectedly populated for system \"" &
            "shouldUpdateTrans" &
            "\""
      assert EcsIdentity("default").readsFrom(1.SystemIndex).len == 0,
             errPrelude`gensym32 & "readsFrom" & internalError`gensym32
      assert EcsIdentity("default").writesTo(1.SystemIndex).len == 0,
             errPrelude`gensym32 & "writesTo" & internalError`gensym32
    if not sys.paused:
      block:
        static :
          if EcsIdentity("default").inSystemAll:
            error "Cannot embed \'all\' blocks within themselves"
          EcsIdentity("default").setinSystemAll true
          EcsIdentity("default").setecsSysIterating true
        var sysLen = sys.count()
        if sysLen > 0:
          var i_452985142: int
          while i_452985142 < sysLen:
            {.line.}:
              let entity {.used, inject, hostEntity.} = sys.groups[i_452985142].entity
              template curEntity(): untyped {.used.} =
                entity

            let
              ## Read-only index into `groups`.
              groupIndex {.used, inject.} = i_452985142
            template item(): SysItemShouldUpdateTrans {.used.} =
              ## Current system item being processed.
              {.line.}:
                static :
                  if not (EcsIdentity("default").ecsSysIterating) or
                      (EcsIdentity("default").ecsSysIterating and
                      EcsIdentity("default").ecsEventEnv.len == 0):
                    if EcsIdentity("default").sysRemoveAffectedThisSystem:
                      error "Potentially unsafe access of \'item\' here: the current system row may be undefined due to an earlier removal of components that affect this system. " &
                          "Use the \'entity\' variable or the system\'s \'deleteList\' to avoid this error."
                    elif EcsIdentity("default").systemCalledDelete:
                      error "Potentially unsafe access of \'item\' here: the current system row may be undefined due to an earlier deletion of an entity. " &
                          "Use the \'entity\' variable or the system\'s \'deleteList\' to avoid this error."
              if groupIndex notin 0 .. sys.high:
                assert false, "\'item\' in " & sys.name & " is out of bounds. " &
                    "Use of \'item\' after remove/delete affected this system?"
              elif sys.groups[groupIndex].entity != entity:
                assert false, "\'item\' in " & sys.name &
                    " is being used after a " &
                    "remove or delete affected this system"
              sys.groups[groupIndex]

            if item.transform.loc != item.transform.oldLoc or
                item.transform.rot != item.transform.oldRot or
                item.transform.sca != item.transform.oldSca:
              var m = mat4f().translate(item.transform.loc).`*`(
                  mat4(item.transform.rot)).scale(item.transform.sca)
              item.transformMatrix.v = m
              item.transform.oldLoc = item.transform.loc
              item.transform.oldRot = item.transform.rot
              item.transform.oldSca = item.transform.sca
              item.transformMatrix.state = TransMatState.UPDATED
            else:
              item.transformMatrix.state = TransMatState.NOT_UPDATED
            when EcsIdentity("default").systemCalledDelete or
                EcsIdentity("default").sysRemoveAffectedThisSystem:
              sysLen = sys.count()
              if sysLen > 0 and
                  (i_452985142 < sysLen and sys.groups[i_452985142].entity == entity):
                i_452985142 = i_452985142 + 1
            else:
              i_452985142 = i_452985142 + 1
        static :
          EcsIdentity("default").setinSystemAll false
          EcsIdentity("default").setecsSysIterating false
    static :
      EcsIdentity("default").setinSystem false
      EcsIdentity("default").setinSystemIndex InvalidSystemIndex
      EcsIdentity("default").setsysRemoveAffectedThisSystem false
      EcsIdentity("default").setsystemCalledDelete false
    for i`gensym35 in 0 ..< sys.deleteList.len:
      sys.deleteList[i`gensym35].delete
    sys.deleteList.setLen 0
  
template doShouldUpdateTrans*(): untyped =
  doShouldUpdateTrans(sysShouldUpdateTrans)

proc doUpdateSceneInheritance*(sys: var UpdateSceneInheritanceSystem) =
  ## System "updateSceneInheritance", using components: Relationship, TransformMatrix
  if not sys.disabled:
    static :
      EcsIdentity("default").setinSystem true
      EcsIdentity("default").setinSystemIndex 2.SystemIndex
      EcsIdentity("default").setsysRemoveAffectedThisSystem false
      EcsIdentity("default").setsystemCalledDelete false
      const
        errPrelude`gensym56 = "Internal error: "
        internalError`gensym56 = " macrocache storage is unexpectedly populated for system \"" &
            "updateSceneInheritance" &
            "\""
      assert EcsIdentity("default").readsFrom(2.SystemIndex).len == 0,
             errPrelude`gensym56 & "readsFrom" & internalError`gensym56
      assert EcsIdentity("default").writesTo(2.SystemIndex).len == 0,
             errPrelude`gensym56 & "writesTo" & internalError`gensym56
    if not sys.paused:
      var q = initDeque[SysItemUpdateSceneInheritance]()
      for scene in sys.scenes:
        var sceneItem = sys.groups[sys.index[scene.entityId]]
        q.addLast(sceneItem)
        while q.len > 0:
          if unlikely(not sys.contains scene):
            continue
          var parentItem = q.popFirst()
          var parentTrans = parentItem.transformMatrix.v
          var parentTransState = parentItem.transformMatrix.state
          for child in parentItem.relationship.children:
            if unlikely(not sys.contains(child.entity)):
              continue
            var childItem = sys.groups[sys.index[child.entity.entityId]]
            if childItem.transformMatrix.state != TransMatState.UPDATED and
                parentTransState != TransMatState.UPDATED:
              continue
            var m = parentTrans * childItem.transformMatrix.v
            childItem.transformMatrix.v = m
            childItem.transformMatrix.state = TransMatState.UPDATED
            q.addLast(childItem)
    static :
      EcsIdentity("default").setinSystem false
      EcsIdentity("default").setinSystemIndex InvalidSystemIndex
      EcsIdentity("default").setsysRemoveAffectedThisSystem false
      EcsIdentity("default").setsystemCalledDelete false
    for i`gensym59 in 0 ..< sys.deleteList.len:
      sys.deleteList[i`gensym59].delete
    sys.deleteList.setLen 0
  
template doUpdateSceneInheritance*(): untyped =
  doUpdateSceneInheritance(sysUpdateSceneInheritance)

proc transformSystem*() =
  doShouldUpdateTrans()
  doUpdateSceneInheritance()

