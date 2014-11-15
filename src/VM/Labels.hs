
module VM.Labels 
    (
     lcompile,
     getLabel,
     getNextLabels
    ) where

import qualified Data.Map as M
import Data.Maybe

import ExtWord
import Util
import VM.Opcodes

import Debug.Trace

type Labels = M.Map String Word256

lcompile::[Operation]->[Operation]
lcompile ops = substituteLabels labels ops
               where
                 labels = calculateBestLabels ops

--Returns a list of labelnames, with obviously wrong positions which use all 32Bytes.
--This gives a bad starting guess, but a maximally conservative one (space wise), which can then be 
--iteratively fixed.
getStupidLabels::[Operation]->Labels
getStupidLabels ops = M.fromList $ op2StupidLabels =<< ops
    where
      op2StupidLabels::Operation->[(String, Word256)]
      op2StupidLabels (LABEL name) = [(name, -1)]
      op2StupidLabels x = []

getBetterLabels::[Operation]->Labels->Labels
getBetterLabels ops oldLabels = M.fromList $ op2Labels oldLabels 0 ops
    where
      op2Labels::Labels->Word256->[Operation]->[(String, Word256)]
      op2Labels _ _ [] = []
      op2Labels oldLabels p (LABEL name:rest) = [(name, p)] ++ op2Labels oldLabels p rest
      op2Labels oldLabels p (x:rest) = op2Labels oldLabels (p+opSize oldLabels x) rest 

      opSize::Labels->Operation->Word256
      opSize labels (LABEL _) = 0
      opSize labels (PUSHLABEL x) = 1+fromIntegral (length $ integer2Bytes $ fromIntegral $ getLabel labels x)
      opSize labels (PUSHDIFF start end) = trace ("subtract: " ++ show (getLabel labels start - getLabel labels end)) $ 
                                           trace ("start: " ++ show (getLabel labels start)) $ 
                                           trace ("end: " ++ show (getLabel labels end)) $ 
          1+fromIntegral (length $ integer2Bytes $ fromIntegral $ (getLabel labels end - getLabel labels start))
      opSize _ (PUSH x) = 1+fromIntegral (length x)
      opSize _ _ = 1

calculateBestLabels::[Operation]->Labels
calculateBestLabels ops = 
    let
        first = getStupidLabels ops
        second = getBetterLabels ops first
        third = getBetterLabels ops second
    in
      trace ("first: " ++ show first) $
      trace ("second: " ++ show second) $
      trace ("third: " ++ show third) $
             third


getLabel::Labels->String->Word256
getLabel labels label = fromMaybe (error $ "Missing label: " ++ show label) $ M.lookup label labels

getNextLabels::(Labels->[Operation])->Labels
getNextLabels = undefined

substituteLabels::Labels->[Operation]->[Operation]
substituteLabels labels ops = substituteLabel labels =<< ops
    where
      substituteLabel::Labels->Operation->[Operation]
      substituteLabel _ (LABEL _) = []
      substituteLabel labels (PUSHDIFF start end) = [PUSH $ integer2Bytes1 $ toInteger (getLabel labels end - getLabel labels start)]
      substituteLabel labels (PUSHLABEL name) = [PUSH $ integer2Bytes1 $ toInteger (getLabel labels name)]
      substituteLabel labels x = [x]



