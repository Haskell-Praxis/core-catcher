{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}
module TH.MonoDerive
  ( deriveMap
  , monoidTh
  , monoTraversableTh
  , monoFunctorTh
  , monoFoldableTh
  , semigroupTh
  , growingAppendTh
  , setContainerTh
  , isMapTh
  ) where

import           ClassyPrelude
import           Language.Haskell.TH

deriveMap :: Name -> DecsQ
deriveMap name = do
    elementInstance <- createMapValueFamily ''Element name
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
    return (elementInstance `cons` instances)

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
    containerKeyFamily <- createContainerFamily
    return [InstanceD Nothing [] instanceType (containerKeyFamily `cons` funcs)]
    where
      memberTh = simpleUnwrap 'member name

      notMemberTh = simpleUnwrap 'notMember name

      unionTh = simpleBinOp 'union name

      differenceTh = simpleBinOp 'difference name

      intersectionTh = simpleBinOp 'intersection name

      keysTh = simplePattern 'keys name

      createContainerFamily :: DecQ
      createContainerFamily = do
          TyConI mn <- reify name
          keyType <- case mn of
              (NewtypeD _ _ _ _ (RecC _ [(_,_, AppT (AppT _ keyType') _)]) _) ->
                  return keyType'

              (NewtypeD _ _ _ _ (NormalC _ [(_, AppT (AppT _ keyType') _)]) _) ->
                  return keyType'

              _ ->
                  fail "Newtype must contain a map like data structure of the form `AppT (AppT (ConT c) key ) value `"

          return $ TySynInstD (mkName "ContainerKey") (TySynEqn [ConT name] keyType)

isMapTh :: Name -> DecsQ
isMapTh name = do
    funcs <- sequenceA [lookupTh, insertMapTh, deleteMapTh, singletonMapTh, mapFromListTh, mapToListTh]
    let instanceType           = AppT (ConT ''IsMap) (ConT name)
    containerKeyFamily <- createMapValueFamily ''MapValue name
    return [InstanceD Nothing [] instanceType (containerKeyFamily `cons` funcs)]
    where
      lookupTh = simpleUnwrap 'lookup name

      insertMapTh = simpleUnwrapWrap1 'insertMap name

      deleteMapTh = simpleUnwrapWrap 'deleteMap name

      singletonMapTh = simpleWrap2 'singletonMap name

      mapFromListTh = simpleWrap1 'mapFromList name

      mapToListTh = simpleUnwrap1 'mapToList name

createMapValueFamily :: Name -> Name -> DecQ
createMapValueFamily typeInstance name = do
    TyConI mn <- reify name
    valueType <- case mn of
        (NewtypeD _ _ _ _ (RecC _ [(_,_, AppT (AppT _ _) valueType')]) _) ->
            return valueType'

        (NewtypeD _ _ _ _ (NormalC _ [(_, AppT (AppT _ _) valueType')]) _) ->
            return valueType'

        _ ->
            fail "Newtype must contain a map like data structure of the form `AppT (AppT (ConT c) key ) value `"

    return $ TySynInstD typeInstance (TySynEqn [ConT name] valueType)



simpleWrap :: Name -> Name -> DecQ
simpleWrap funcName typeName = do
    con <- getNewTypeCon typeName
    let bodyExpr = [e| $(conE con) $(varE funcName) |]
    let cl = clause
            []
            (normalB bodyExpr)
            []
    funD funcName [cl]

simpleWrap1 :: Name -> Name -> DecQ
simpleWrap1 funcName typeName = do
    con <- getNewTypeCon typeName
    let bodyExpr = [e| $(conE con) . $(varE funcName) |]
    let cl = clause
            []
            (normalB bodyExpr)
            []
    funD funcName [cl]

simpleWrap2 :: Name -> Name -> DecQ
simpleWrap2 funcName typeName = do
    con <- getNewTypeCon typeName
    keyVar <- newName "k"
    valueVar <- newName "v"
    let bodyExpr = [e| $(conE con) $ $(varE funcName) $(varE keyVar) $(varE valueVar) |]
    let cl = clause
            [ varP keyVar
            , varP valueVar
            ]
            (normalB bodyExpr)
            []
    funD funcName [cl]

simplePattern :: Name -> Name -> DecQ
simplePattern funcName typeName = do
    con <- getNewTypeCon typeName
    conVar <- newName "a"
    let bodyExpr = [e| $(varE funcName) $(varE conVar) |]
    let cl = clause
            [ conP con [varP conVar]
            ]
            (normalB bodyExpr)
            []
    funD funcName [cl]

simpleUnwrap :: Name -> Name -> DecQ
simpleUnwrap funcName typeName = do
    con <- getNewTypeCon typeName
    conVar <- newName "a"
    otherVar <- newName "p"
    let bodyExpr = [e| $(varE funcName) $(varE otherVar) $(varE conVar) |]
    let cl = clause
            [ varP otherVar
            , conP con [varP conVar]
            ]
            (normalB bodyExpr)
            []
    funD funcName [cl]

simpleUnwrap1 :: Name -> Name -> DecQ
simpleUnwrap1 funcName typeName = do
    con <- getNewTypeCon typeName
    conVar <- newName "a"
    let bodyExpr = [e| $(varE funcName) $(varE conVar) |]
    let cl = clause
            [ conP con [varP conVar]
            ]
            (normalB bodyExpr)
            []
    funD funcName [cl]


simpleUnwrapWrap1 :: Name -> Name -> DecQ
simpleUnwrapWrap1 funcName typeName = do
    con <- getNewTypeCon typeName
    conVar <- newName "a"
    keyVar <- newName "k"
    valueVar <- newName "v"
    let bodyExpr = [e| $(conE con) $ $(varE funcName) $(varE keyVar) $(varE valueVar) $(varE conVar) |]
    let cl = clause
            [ varP keyVar
            , varP valueVar
            , conP con [varP conVar]
            ]
            (normalB bodyExpr)
            []
    funD funcName [cl]

simpleUnwrapWrap :: Name -> Name -> DecQ
simpleUnwrapWrap funcName typeName = do
    con <- getNewTypeCon typeName
    conVar <- newName "a"
    keyVar <- newName "k"
    let bodyExpr = [e| $(conE con) $ $(varE funcName) $(varE keyVar) $(varE conVar) |]
    let cl = clause
            [ varP keyVar
            , conP con [varP conVar]
            ]
            (normalB bodyExpr)
            []
    funD funcName [cl]

simpleFold :: Name -> Name -> DecQ
simpleFold funcName typeName = do
    con <- getNewTypeCon typeName
    conVar <- newName "a"
    funName <- newName "f"
    accName <- newName "acc"
    let bodyExpr = [e| $(varE funcName) $(varE funName) $(varE accName) $(varE conVar) |]
    let cl = clause
            [ varP funName
            , varP accName
            , conP con [varP conVar]
            ]
            (normalB bodyExpr)
            []
    funD funcName [cl]

simpleFold1 :: Name -> Name -> DecQ
simpleFold1 funcName typeName = do
    con <- getNewTypeCon typeName
    conVar <- newName "a"
    funName <- newName "f"
    let bodyExpr = [e| $(varE funcName) $(varE funName) $(varE conVar) |]
    let cl = clause
            [ varP funName
            , conP con [varP conVar]
            ]
            (normalB bodyExpr)
            []
    funD funcName [cl]

simpleMap :: Name -> Name -> DecQ
simpleMap funcName name = do
    con <- getNewTypeCon name
    conVar <- newName "a"
    funName <- newName "f"
    let typePat = conP con [varP conVar]
    let bodyExpr = [e| $(conE con) $ $(varE funcName) $(varE funName) $(varE conVar) |]
    let cl = clause [varP funName, typePat] (normalB bodyExpr) []
    funD funcName [cl]

simpleBinOp :: Name -> Name -> DecQ
simpleBinOp funcName name = do
    con <- getNewTypeCon name
    firstName <- newName "a"
    secondName <- newName "b"
    let firstPat = conP con [varP firstName]
    let secondPat = conP con [varP secondName]
    let bodyExpr = [e| $(conE con) $ $(varE funcName) $(varE firstName) $(varE secondName) |]
    let cl = clause [firstPat, secondPat] (normalB bodyExpr) []
    funD funcName [cl]


emptyDerive :: Name -> Name-> DecsQ
emptyDerive typeclass name = do
    let instanceType           = AppT (ConT typeclass) (ConT name)
    return [InstanceD Nothing [] instanceType [] ]

getNewTypeCon :: Name -> Q Name
getNewTypeCon typeName = do
    TyConI mn <- reify typeName
    case mn of
      (NewtypeD _ _ _ _ (RecC con _) _) -> return con
      (NewtypeD _ _ _ _ (NormalC con _) _) -> return con
      _ -> fail "Only Newtype datastructures are allowed"

{--
TODO: can this instance be derived?
-- answer: probably
type instance Element PlayerPositions = Node

instance SetContainer PlayerPositions where
    -- TODO: could this be somehow done?
    type ContainerKey PlayerPositions = Player
    member p = member p . playerPositions
    notMember p = notMember p . playerPositions
    union pp1 pp2 = PlayerPositions $ union (playerPositions pp1) (playerPositions pp2)
    difference pp1 pp2 = PlayerPositions $ difference (playerPositions pp1) (playerPositions pp2)
    intersection pp1 pp2 = PlayerPositions $ intersection (playerPositions pp1) (playerPositions pp2)
    keys = keys . playerPositions
instance IsMap PlayerPositions where
    -- TODO: could this be somehow done?
    type MapValue PlayerPositions = Node
    lookup k = lookup k . playerPositions
    insertMap k v = PlayerPositions . insertMap k v . playerPositions
    deleteMap k = PlayerPositions . deleteMap k . playerPositions
    singletonMap k v = PlayerPositions $ singletonMap k v
    mapFromList = PlayerPositions . mapFromList
    mapToList = mapToList . playerPositions
--}
