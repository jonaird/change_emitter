## [2.0] - 2.0 Release
 - reimplemented TextEditingEmitter (breaking changes)

## [1.0.0-beta.3] - Breaking changes to EmitterContainer, Provider, new change emitters
 - `EmitterContainer.emittingChildren` renamed to `dependencies`.
 - `dependencies` and `children` are now sets instead of lists.
 - `children` now defaults to an empty set instead of null.
 - ParentEmitter is now a mixin
 - added a ValueEmitter.late() constructor for when you want a nonnullable type but might not have a value right away

 - added `NavigationStack` change emitter

## [1.0.0-beta.2] - Updated readme

## [1.0.0-beta.1] - Null Safety, removed Provider dependency
Transitioned to NNBD, removed Provider dependency and replaced it with a 
much simpler reimplementation that is more suitable for the desired approach of 
change emitters. Various small breaking changes.

## [0.9.11] - Emitter children are registered from top down rather than bottom up


## [0.9.10] - added method to find ancestors in the emitter tree

## [0.9.9] - Fixed bug in ValueEmitter.reactive constructor

## [0.9.8] - added ListEmitter.removeLast and EmitterList

## [0.9.7] - Added ValueEmitter.unmodifiableView constructor

## [0.9.6] - Fixed bug in ListEmitter.removeWhere

## [0.9.5] - Added protected method containerChangeFromChildChange to EmitterContainer

Overriding this method in a subclass of EmitterContainer allows you to use your own custom
subclass of ContainerChange.

## [0.9.4] - Fixed bug in ListEmitter.removeRange

## [0.9.3] - Fixed link to docs

## [0.9.2] - Added toggle() method to ValueEmitter<bool>

## [0.9.1] - Fixed Async dependency

## [0.9.0] - Initial release


