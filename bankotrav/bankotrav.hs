{-# LANGUAGE TupleSections #-}
-- bankotrav: traverse banko boards
module Main where

import Data.List (transpose)
import Safe (atMay)
import Random

import System.IO.Unsafe (unsafePerformIO)


data Cell = BlankCell
          | ValueCell Int
  deriving (Show)

data CellIncomplete = NotFilledIn
                    | FilledIn Cell
  deriving (Show)

hasValue :: CellIncomplete -> Bool
hasValue NotFilledIn = False
hasValue (FilledIn BlankCell) = False
hasValue _ = True

type CellIndex = (Int, Int)

type BoardBase cell = [[cell]] -- 9 columns * 3 rows
type Board = BoardBase Cell -- Complete board
type BoardIncomplete = BoardBase CellIncomplete -- Board in creation

getCell :: BoardBase cell -> CellIndex -> Maybe cell
getCell board (column, row) = do
  elems <- atMay board column
  atMay elems row

setCell :: BoardBase cell -> CellIndex -> cell -> BoardBase cell
setCell board (column, row) cell =
  let elems = board !! column
      elems' = take row elems ++ [cell] ++ drop (row + 1) elems
  in take column board ++
     [elems'] ++
     drop (column + 1) board

type Column cell = (cell, cell, cell)

getColumn :: BoardBase cell -> Int -> Column cell
getColumn board i = (col !! 0, col !! 1, col !! 2)
  where col = board !! i

isFilledIn :: CellIncomplete -> Bool
isFilledIn NotFilledIn = False
isFilledIn _ = True

isFilledInBlank :: CellIncomplete -> Bool
isFilledInBlank (FilledIn BlankCell) = True
isFilledInBlank _ = False

minimumCellValue :: Int -> Int
minimumCellValue column = column * 10 + if column == 0 then 1 else 0

maximumCellValue :: Int -> Int
maximumCellValue column = column * 10 + 9 + if column == 8 then 1 else 0

validCellsRaw :: Int -> [Cell]
validCellsRaw column = BlankCell : map (ValueCell . (10 * column +)) [start..end]
  where start = if column == 0 then 1 else 0
        end  = if column == 8 then 10 else 9

-- Assumes not being called on a filled-in cell
validCells :: BoardIncomplete -> CellIndex -> [Cell]
validCells board index@(column, row) = filter alright $ validCellsRaw column
  where alright cell =
          let board' = setCell board index $ FilledIn cell
          in (getCell board (column, row - 2)) `isLowerOrBlank` (Just (FilledIn cell)) &&
             (getCell board (column, row - 1)) `isLowerOrBlank` (Just (FilledIn cell)) &&
             (Just (FilledIn cell)) `isLowerOrBlank` (getCell board (column, row + 1)) &&
             (Just (FilledIn cell)) `isLowerOrBlank` (getCell board (column, row + 2)) &&
             columnsCanEndWell board'

isLowerOrBlank :: (Maybe CellIncomplete) -> (Maybe CellIncomplete) -> Bool
isLowerOrBlank a b = case (a, b) of
  (Just (FilledIn (ValueCell va)), Just (FilledIn (ValueCell vb))) -> va < vb
  _ -> True


type ColumnSignature = (Int, Int, Int)

validColumnSignatures :: [ColumnSignature]
validColumnSignatures = [ (3, 0, 6)
                        , (2, 2, 5)
                        , (1, 4, 4)
                        , (0, 6, 3)
                        ]

data ColumnKind = ThreeCells | TwoCells | OneCell
  deriving (Show, Eq)

type ColumnBoardKind = [ColumnKind] -- 9 columns

data CellKind = Number | Blank
  deriving (Show)

isNumber :: CellKind -> Bool
isNumber Number = True
isNumber Blank = False

type ColumnPerm = (CellKind, CellKind, CellKind)
type ColumnBoardPerm = [ColumnPerm] -- 9 columns

kindPerms :: ColumnBoardKind -> [ColumnBoardPerm]
kindPerms = filter valid . perms . map columnKindPerms
  where columnKindPerms kind = case kind of
          ThreeCells -> [ (Number, Number, Number) ]
          TwoCells -> [ (Number, Number, Blank)
                      , (Number, Blank, Number)
                      , (Blank, Number, Number)
                      ]
          OneCell -> [ (Number, Blank, Blank)
                     , (Blank, Number, Blank)
                     , (Blank, Blank, Number)
                     ]

        perms :: [[ColumnPerm]] -> [ColumnBoardPerm]
        perms (pos : poss) = concatMap (\t -> map (t :) $ perms poss) pos
        perms [] = [[]]

        valid :: ColumnBoardPerm -> Bool
        valid = all ((== 5) . length . filter isNumber) . transpose . map (\(a, b, c) -> [a, b, c])

-- This is actually only 1554.
columnSignaturePermutations :: ColumnSignature -> [ColumnBoardKind]
columnSignaturePermutations (threes, twos, ones) =
  threes_results ++ twos_results ++ ones_results ++ end
  where threes_results =
          if threes > 0
          then map (ThreeCells :) $ columnSignaturePermutations (threes - 1, twos, ones)
          else []
        twos_results =
          if twos > 0
          then map (TwoCells :) $ columnSignaturePermutations (threes, twos - 1, ones)
          else []
        ones_results =
          if ones > 0
          then map (OneCell :) $ columnSignaturePermutations (threes, twos, ones - 1)
          else []
        end =
          if threes == 0 && twos == 0 && ones == 0
          then [[]]
          else []

allColumnSignaturePermutations :: [ColumnBoardKind]
allColumnSignaturePermutations = concatMap columnSignaturePermutations validColumnSignatures

columnsCanEndWell :: BoardIncomplete -> Bool
columnsCanEndWell board = any (boardColumnsCanEndInKind board) allColumnSignaturePermutations

boardColumnsCanEndInKind :: BoardIncomplete -> ColumnBoardKind -> Bool
boardColumnsCanEndInKind board kind = okayColumnWise && okayRowWise
  where okayRowWise = any columnPermCanWork $ kindPerms kind

        minim column = Just $ FilledIn $ ValueCell $ minimumCellValue column
        maxim column = Just $ FilledIn $ ValueCell $ maximumCellValue column

        okays column a b c =
          let c' = case c of
                FilledIn (ValueCell k) -> FilledIn (ValueCell (k - 1))
                _ -> c

              a_okay =
                not (isFilledInBlank a) && isFilledIn a || (not (isFilledInBlank a) &&
                                 minim column `isLowerOrBlank` Just b &&
                                 minim column `isLowerOrBlank` Just c)
              b_okay = not (isFilledInBlank b) && isFilledIn b || (not (isFilledInBlank b) &&
                                        Just a `isLowerOrBlank` Just c' &&
                                        minim column `isLowerOrBlank` Just c &&
                                        Just a `isLowerOrBlank` maxim column)
              c_okay = not (isFilledInBlank c) && isFilledIn c || (not (isFilledInBlank c) &&
                                        Just b `isLowerOrBlank` maxim column &&
                                        Just a `isLowerOrBlank` maxim column)
          in (a_okay, b_okay, c_okay)

        columnPermCanWork :: ColumnBoardPerm -> Bool
        columnPermCanWork perm = and $ zipWith3 columnColumnPermCanWork [0..8] perm (map (getColumn board) [0..8])

        columnColumnPermCanWork :: Int -> ColumnPerm -> Column CellIncomplete -> Bool
        columnColumnPermCanWork column (ka, kb, kc) (a, b, c) =
          let (a_okay, b_okay, c_okay) = okays column a b c
          in ok ka a a_okay && ok kb b b_okay && ok kc c c_okay
          where ok Number _ o = o
                ok Blank t _ = case t of
                  FilledIn BlankCell -> True
                  NotFilledIn -> True -- ?
                  _ -> False

        okayColumnWise = and $ zipWith3 columnCanEndInKind [0..8] (map (getColumn board) [0..8]) kind

        columnCanEndInKind :: Int -> Column CellIncomplete -> ColumnKind -> Bool
        columnCanEndInKind column (a, b, c) ckind =
          let (a_okay, b_okay, c_okay) = okays column a b c
              (a_notnum, b_notnum, c_notnum) = (not $ hasValue a, not $ hasValue b, not $ hasValue c)
          in case ckind of
            ThreeCells ->
              a_okay && b_okay && c_okay
            TwoCells ->
              (a_okay && b_okay && c_notnum) ||
              (a_okay && c_okay && b_notnum) ||
              (b_okay && c_okay && a_notnum)
            OneCell ->
              (a_okay && b_notnum && c_notnum) ||
              (b_okay && a_notnum && c_notnum) ||
              (c_okay && a_notnum && b_notnum)

emptyBoard :: BoardIncomplete
emptyBoard = replicate 9 $ replicate 3 NotFilledIn

fromIncomplete :: BoardIncomplete -> Board
fromIncomplete = map (map from')
  where from' (FilledIn v) = v
        from' NotFilledIn = error "not fully filled in"

randomBoard :: RandomState Board
randomBoard = do
  indices <- shuffle $ concatMap (\c -> map (c, ) [0..2]) [0..8]
  bi <- step emptyBoard indices
  return $ fromIncomplete bi

  where step :: BoardIncomplete -> [CellIndex] -> RandomState BoardIncomplete
        step b [] = return b
        step b (i : is) = do
          let cs = validCells b i
          c <- choice cs
          let b' = setCell b i $ FilledIn c
          -- unsafePerformIO (print c) `seq`
          step b' is

randomBoardIO :: IO Board
randomBoardIO = evalRandIO randomBoard

formatBoard :: Board -> String
formatBoard = unlines . map (unwords . map cellFormat) . transpose
  where cellFormat BlankCell = "00"
        cellFormat (ValueCell v) = (if length (show v) == 1 then "0" else "") ++ show v



-- data RowCellKind = BlankKind | FilledInKind
--   deriving (Show)
-- type RowKind = [RowCellKind]

-- stuff = stuff' 5 4
--   where stuff' f b = f_res ++ b_res ++ end
--           where f_res = if f > 0
--                         then map (FilledInKind :) (stuff' (f - 1) b)
--                         else []
--                 b_res = if b > 0
--                         then map (BlankKind :) (stuff' f (b - 1))
--                         else []
--                 end = if f == 0 && b == 0
--                       then [[]]
--                       else []

-- --[(RowKind, RowKind, RowKind)]

-- rowsCanEndWell :: BoardIncomplete -> Bool
-- rowsCanEndWell = undefined

main :: IO ()
main = putStr =<< formatBoard <$> randomBoardIO
