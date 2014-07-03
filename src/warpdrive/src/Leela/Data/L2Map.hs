-- Copyright 2014 (c) Diego Souza <dsouza@c0d3.xxx>
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

module Leela.Data.L2Map
       ( L2Map ()
       , empty
       , insert
       , lookup
       , delete
       , toList
       ) where

import           Prelude hiding (lookup)
import           Data.Hashable
import qualified Data.Map.Lazy as M
import qualified Data.HashMap.Lazy as H
import           Control.Concurrent.STM

newtype L2Map k1 k2 v = L2Map (TVar (M.Map k1 (TVar (H.HashMap k2 v))))

empty :: IO (L2Map k1 k2 v)
empty = fmap L2Map (newTVarIO M.empty)

insert :: (Ord k1, Eq k2, Hashable k2) => k1 -> k2 -> v -> L2Map k1 k2 v -> IO ()
insert k1 k2 value (L2Map tm0) = do
  tm1 <- atomically $ do
    m <- readTVar tm0
    v <- newTVar H.empty
    case (M.insertLookupWithKey (\_ -> flip const) k1 v m) of
      (Nothing, m1) -> writeTVar tm0 m1 >> return v
      (Just v1, _)  -> return v1
  atomically $ do
    m <- readTVar tm1
    writeTVar tm1 (H.insert k2 value m)

lookup :: (Ord k1, Eq k2, Hashable k2) => k1 -> k2 -> L2Map k1 k2 v -> IO (Maybe v)
lookup k1 k2 (L2Map tm0) = do
  mtm1 <- fmap (M.lookup k1) (readTVarIO tm0)
  case mtm1 of
    Nothing  -> return Nothing
    Just tm1 -> fmap (H.lookup k2) (readTVarIO tm1)

delete :: (Ord k1, Eq k2, Hashable k2) => k1 -> k2 -> L2Map k1 k2 v -> IO (Maybe v)
delete k1 k2 (L2Map tm0) = atomically $ do
  m0 <- readTVar tm0
  case (M.lookup k1 m0) of
    Nothing  -> return Nothing
    Just tm1 -> do
      (a, m1) <- fmap (\m -> (H.lookup k2 m, H.delete k2 m)) (readTVar tm1)
      writeTVar tm1 m1
      return a

toList :: L2Map k1 k2 v -> ([((k1, k2), v)] -> b -> IO b) -> b -> IO b
toList (L2Map tm0) action b = readTVarIO tm0 >>= go b . M.toList
  where go acc []            = return acc
        go acc ((k, v) : xs) = do
          vs <- fmap (map (\(k1, v1) -> ((k, k1), v1)) . H.toList) (readTVarIO v)
          flip go xs =<< action vs acc
          