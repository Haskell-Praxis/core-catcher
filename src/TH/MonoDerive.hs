{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}
module TH.MonoDerive
  ( deriveMap
  , deriveSequence
  , deriveSet
  , monoidTh
  , monoTraversableTh
  , monoFunctorTh
  , monoFoldableTh
  , semigroupTh
  , growingAppendTh
  , setContainerTh
  , semiSequenceTh
  , monoPointedTh
  , isMapTh
  , isSequenceTh
  , isSetTh
  ) where

import           ClassyPrelude
import           Language.Haskell.TH
import qualified TH.TypeFamily as Family
import           TH.MonoFunctions

deriveMap :: Name -> DecsQ
deriveMap name = do
    elementInstance <- Family.deriveNewtypedTypeFamily ''Element name
    instances <-
        map concat
            . sequenceA
            $ map
                (\f -> f name)
                [ monoidTh
                , monoFunctorTh
                , monoFoldableTh
                , monoTraversableTh
                , semigroupTh
                , growingAppendTh
                , setContainerTh
                , isMapTh
                ]
    return (elementInstance ++ instances)

deriveSequence :: Name -> DecsQ
deriveSequence name = do
    -- Does not work for arbitrary types
    elementInstance <- Family.deriveNewtypedTypeFamily ''Element name
    instances <-
        map concat
            . sequenceA
            $ map
                (\f -> f name)
                [ monoidTh
                , monoFunctorTh
                , monoFoldableTh
                , monoTraversableTh
                , semigroupTh
                , growingAppendTh
                , semiSequenceTh
                , monoPointedTh
                , isSequenceTh
                ]
    return (elementInstance ++ instances)

deriveSet :: Name -> DecsQ
deriveSet name = do
    -- Does not work for arbitrary types
    elementInstance <- Family.deriveNewtypedTypeFamily ''Element name
    instances <-
        map concat
            . sequenceA
            $ map
                (\f -> f name)
                [ monoidTh
                , monoFoldableTh
                , semigroupTh
                , growingAppendTh
                , setContainerTh
                , isSetTh
                ]
    return (elementInstance ++ instances)

monoidTh :: Name -> DecsQ
monoidTh name = do
    mem <- memptyTh
    man <- mappendTh
    let instanceType           = AppT (ConT ''Monoid) (ConT name)
    return [InstanceD Nothing [] instanceType [mem, man] ]
    where
      memptyTh :: DecQ
      memptyTh = simpleWrap 'mempty name

      mappendTh :: DecQ
      mappendTh = simpleBinOp 'mappend name

monoFunctorTh :: Name -> DecsQ
monoFunctorTh name = do
    omapTh' <- omapTh
    let instanceType           = AppT (ConT ''MonoFunctor) (ConT name)
    return [InstanceD Nothing [] instanceType [omapTh'] ]
    where
      omapTh :: DecQ
      omapTh = simpleMap 'omap name

monoTraversableTh :: Name -> DecsQ
monoTraversableTh name = do
    otraverse' <- otraverseTh
    let instanceType           = AppT (ConT ''MonoTraversable) (ConT name)
    return [InstanceD Nothing [] instanceType [otraverse'] ]
    where
      otraverseTh :: DecQ
      otraverseTh = do
          con <- getNewTypeCon name
          conVar <- newName "a"
          funName <- newName "f"
          let funcPat = varP funName
          let typePat = conP con [varP conVar]
          let otraverseName = mkName "otraverse"
          let bodyExpr = [e| $(varE 'map) $(conE con) $ $(varE 'otraverse) $(varE funName) $(varE conVar) |]
          let cl = clause [funcPat, typePat] (normalB bodyExpr) []
          funD otraverseName [cl]

monoFoldableTh :: Name -> DecsQ
monoFoldableTh typeName = do
    funcs <- sequenceA [ofoldMapTh, ofoldrTh, ofoldlTh', olengthTh, olength64Th, ofoldr1ExTh, ofoldl1ExTh']
    let instanceType           = AppT (ConT ''MonoFoldable) (ConT typeName)
    return [InstanceD Nothing [] instanceType funcs]
    where
      ofoldMapTh = simpleFold1 'ofoldMap typeName
      ofoldrTh = simpleFold 'ofoldr typeName
      ofoldlTh' = simpleFold 'ofoldl' typeName
      olengthTh = simplePattern 'olength typeName
      olength64Th = simplePattern 'olength64 typeName
      ofoldr1ExTh = simpleFold1 'ofoldr1Ex typeName
      ofoldl1ExTh' = simpleFold1 'ofoldl1Ex' typeName

semigroupTh :: Name -> DecsQ
semigroupTh = emptyDerive ''Semigroup

growingAppendTh :: Name -> DecsQ
growingAppendTh = emptyDerive ''GrowingAppend

setContainerTh :: Name -> DecsQ
setContainerTh name = do
    funcs <- sequenceA [memberTh, notMemberTh, unionTh, differenceTh, intersectionTh, keysTh]
    let instanceType           = AppT (ConT ''SetContainer) (ConT name)
    containerKeyFamily <- Family.deriveNewtypedTypeFamily ''ContainerKey name
    return [InstanceD Nothing [] instanceType (containerKeyFamily ++ funcs)]
    where
      memberTh = simpleUnwrap1 'member name
      notMemberTh = simpleUnwrap1 'notMember name
      unionTh = simpleBinOp 'union name
      differenceTh = simpleBinOp 'difference name
      intersectionTh = simpleBinOp 'intersection name
      keysTh = simplePattern 'keys name

isMapTh :: Name -> DecsQ
isMapTh name = do
    funcs <- sequenceA [lookupTh, insertMapTh, deleteMapTh, singletonMapTh, mapFromListTh, mapToListTh]
    let instanceType           = AppT (ConT ''IsMap) (ConT name)
    containerKeyFamily <- Family.deriveNewtypedTypeFamily ''MapValue name
    return [InstanceD Nothing [] instanceType (containerKeyFamily ++ funcs)]
    where
      lookupTh = simpleUnwrap1 'lookup name
      insertMapTh = simpleUnwrapWrap2 'insertMap name
      deleteMapTh = simpleUnwrapWrap1 'deleteMap name
      singletonMapTh = simpleWrap2 'singletonMap name
      mapFromListTh = simpleWrap1 'mapFromList name
      mapToListTh = simpleUnwrap 'mapToList name

semiSequenceTh :: Name -> DecsQ
semiSequenceTh name = do
    funcs <- sequenceA [intersperseTh, reverseTh, findTh, sortByTh, consTh, snocTh]
    let instanceType           = AppT (ConT ''SemiSequence) (ConT name)
    indexFamily <- Family.deriveNewtypedTypeFamily ''Index name
    return [InstanceD Nothing [] instanceType (indexFamily ++ funcs)]
    where
      intersperseTh = simpleUnwrapWrap1 'intersperse name
      reverseTh = simpleUnwrapWrap 'reverse name
      findTh = simpleUnwrap1 'find name
      sortByTh = simpleUnwrapWrap1 'sortBy name
      consTh = simpleUnwrapWrap1 'cons name
      snocTh = simpleUnwrapWrap1' 'snoc name

isSequenceTh :: Name -> DecsQ
isSequenceTh name = do
    funcs <- sequenceA [fromListTh]
    let instanceType           = AppT (ConT ''IsSequence) (ConT name)
    return [InstanceD Nothing [] instanceType funcs ]
    where
      fromListTh :: DecQ
      fromListTh = simpleWrap1 'fromList name

monoPointedTh :: Name -> DecsQ
monoPointedTh name = do
    funcs <- sequenceA [opointTh]
    let instanceType           = AppT (ConT ''MonoPointed) (ConT name)
    return [InstanceD Nothing [] instanceType funcs ]
    where
      opointTh :: DecQ
      opointTh = simpleWrap1 'opoint name

isSetTh :: Name -> DecsQ
isSetTh name = do
    funcs <- sequenceA [insertSetTh, deleteSetTh, singletonSetTh, setFromListTh, setToListTh]
    let instanceType           = AppT (ConT ''IsSet) (ConT name)
    return [InstanceD Nothing [] instanceType funcs ]
    where
      insertSetTh = simpleUnwrapWrap1 'insertSet name
      deleteSetTh = simpleUnwrapWrap1 'deleteSet name
      singletonSetTh = simpleWrap1 'singletonSet name
      setFromListTh = simpleWrap1 'setFromList name
      setToListTh = simpleUnwrap 'setToList name

emptyDerive :: Name -> Name-> DecsQ
emptyDerive typeclass name = do
    let instanceType           = AppT (ConT typeclass) (ConT name)
    return [InstanceD Nothing [] instanceType [] ]
