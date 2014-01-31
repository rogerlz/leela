{-# LANGUAGE OverloadedStrings #-}

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

module Leela.Data.Types
       ( GUID (..)
       , Mode (..)
       , Node (..)
       , Tree (..)
       , User (..)
       , Attr (..)
       , Label (..)
       , Value (..)
       , Option (..)
       , Journal (..)
       , Matcher (..)
       , AsByteString (..)
       , glob
       , nextPage
       ) where

import           Data.Int
import           Data.Word
import           Data.Serialize
import           Leela.Data.Time
import qualified Data.ByteString as B
import           Control.Exception
import           Leela.Data.Excepts

data Value = Bool Bool
           | Text B.ByteString
           | Int32 Int32
           | Int64 Int64
           | Double Double
           | UInt32 Word32
           | UInt64 Word64
           deriving (Eq)

data TimeSpec = Point Resolution Time
              | Range Resolution Time Time
              deriving (Eq)

data Resolution = Seconds
                | Minutes
                | Hours
                | Days
                | Months
                | Years
                deriving (Eq)

data Matcher = ByLabel GUID Label
             | ByNode GUID
             | ByEdge GUID Label GUID
             deriving (Eq)

data Journal = PutLink GUID Label GUID
             | PutLabel GUID Label
             | PutNode User Tree Node
             | DelLink GUID Label (Maybe GUID)
             | DelNode GUID
             | DelAttr GUID Attr
             | PutAttr GUID Attr Value [Option]
             deriving (Eq)

data Option = TTL Int
            deriving (Eq)

data Mode a = All (Maybe a)
            | Prefix a a
            | Suffix a a
            | Precise a

glob :: B.ByteString -> Mode B.ByteString
glob s
  | "*" == s           = All Nothing
  | B.isPrefixOf "*" s = uncurry Suffix (range $ B.tail s)
  | B.isSuffixOf "*" s = uncurry Prefix (range $ B.init s)
  | otherwise          = Precise s
    where
      range str = (str, B.init str `B.snoc` (B.last str + 1))

nextPage :: Mode a -> a -> Mode a
nextPage (All _) l      = All (Just l)
nextPage (Prefix _ b) l = Prefix l b
nextPage (Suffix _ b) l = Suffix l b
nextPage _ _            = error "precise has no pagination"

newtype GUID = GUID B.ByteString
        deriving (Eq, Ord, Show)

newtype Label = Label B.ByteString
        deriving (Eq, Ord, Show)

newtype Node = Node B.ByteString
        deriving (Eq, Ord, Show)

newtype User = User B.ByteString
        deriving (Eq, Ord, Show)

newtype Tree = Tree B.ByteString
        deriving (Eq, Ord, Show)

newtype Attr = Attr B.ByteString
        deriving (Eq, Ord, Show)

class AsByteString a where

  toByteString :: a -> B.ByteString

instance AsByteString GUID where

  toByteString (GUID g) = g

instance AsByteString Label where

  toByteString (Label l) = l

instance AsByteString Node where

  toByteString (Node n) = n

instance AsByteString User where

  toByteString (User u) = u

instance AsByteString Attr where

  toByteString (Attr a) = a

instance AsByteString Tree where

  toByteString (Tree t) = t

instance Serialize Value where

  put (Bool v)   = do
    putWord8 0
    putWord8 (fromIntegral $ fromEnum v)
  put (Text v)   = do
    putWord8 1
    putWord16be (fromIntegral $ B.length v)
    putByteString v
  put (Int32 v)  = do
    putWord8 2
    putWord32be (fromIntegral v)
  put (UInt32 v) = do
    putWord8 3
    putWord32be v
  put (Int64 v)  = do
    putWord8 4
    putWord64be (fromIntegral v)
  put (UInt64 v) = do
    putWord8 5
    putWord64be v
  put (Double v) = do
    putWord8 6
    putFloat64be v

  get = do
    magic <- getWord8
    case magic of
      0 -> fmap (Bool . toEnum . fromIntegral) getWord8
      1 -> fmap Text (getWord16be >>= getByteString . fromIntegral)
      2 -> fmap (Int32 . fromIntegral) getWord32be
      3 -> fmap UInt32 getWord32be
      4 -> fmap (Int64 . fromIntegral) getWord64be
      5 -> fmap UInt64 getWord64be
      6 -> fmap Double getFloat64be
      _ -> throw SystemExcept

instance Functor Mode where

  fmap f (All ma)     = All (fmap f ma)
  fmap f (Suffix a b) = Suffix (f a) (f b)
  fmap f (Prefix a b) = Prefix (f a) (f b)
  fmap f (Precise a)  = Precise (f a)