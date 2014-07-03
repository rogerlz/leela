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

module Leela.HZMQ.IOLoop
       ( Poller ()
       , alive
       , cancel
       , sendMsg
       , recvMsg
       , aliveSTM
       , pollLoop
       , newIOLoop
       , useSocket
       , newIOLoop_
       ) where

import           System.ZMQ4
import           Control.Monad
import qualified Data.ByteString as B
import           Control.Exception
import           Control.Concurrent
import           Leela.HZMQ.ZHelpers
import qualified Data.ByteString.Lazy as L
import           Control.Concurrent.STM

newtype Poller a = Poller (TChan [B.ByteString], TChan [L.ByteString], MVar (Socket a), TVar Bool)

newIOLoop :: TChan [B.ByteString] -> TChan [L.ByteString] -> Socket a -> IO (Poller a)
newIOLoop qsrc qdst fh = do
  ctrl <- newTVarIO True
  lock <- newMVar fh
  return (Poller (qsrc, qdst, lock, ctrl))

newIOLoop_ :: Socket a -> IO (Poller a)
newIOLoop_ fh = do
  qsrc <- newTChanIO
  qdst <- newTChanIO
  newIOLoop qsrc qdst fh

aliveSTM :: Poller a -> STM Bool
aliveSTM (Poller (_, _, _, ctrl)) = readTVar ctrl

alive :: Poller a -> IO Bool
alive = atomically . aliveSTM

enqueue :: Poller a -> [B.ByteString] -> STM ()
enqueue (Poller (q, _, _, _)) msg =
  case (break B.null msg) of
    (_, (_ : [])) -> return ()
    _             -> writeTChan q msg

dequeue :: Poller a -> Maybe [L.ByteString] -> STM [L.ByteString]
dequeue _ (Just msg)            = return msg
dequeue (Poller (_, q, _, _)) _ = readTChan q

recvMsg :: Poller a -> IO (Maybe [B.ByteString])
recvMsg p@(Poller (q, _, _, _)) = atomically $ do
  ok <- aliveSTM p
  if ok
   then fmap Just (readTChan q)
   else return Nothing

sendMsg :: Poller a -> [L.ByteString] -> IO ()
sendMsg (Poller (_, q, _, _)) msg = atomically $ writeTChan q msg

cancel :: Poller a -> IO ()
cancel (Poller (_, _, _, ctrl)) = atomically $ writeTVar ctrl False

useSocket :: Poller a -> (Socket a -> IO b) -> IO b
useSocket (Poller (_, _, lock, _)) = withMVar lock

pollLoop :: (Receiver a, Sender a) => Poller a -> IO ()
pollLoop p@(Poller (_, _, _, ctrl)) = do
  fd               <- useSocket p fileDescriptor
  (waitW, cancelW) <- waitFor (threadWaitWrite fd)
  (waitR, cancelR) <- waitFor (threadWaitRead fd)
  go waitR waitW Nothing `finally` (cancelR >> cancelW)
    where
      waitFor waitFunc = do
        v <- newEmptyTMVarIO
        t <- forkIO $ forever $ do
          waitFunc
          atomically $ putTMVar v ()
        return (takeTMVar v, killThread t)

      handleRecv fh = do
        zready <- events fh
        if (In `elem` zready)
         then do
           receiveMulti fh >>= atomically . enqueue p
           handleRecv fh
         else return zready

      handleSend msg fh = do
        zready <- events fh
        if (Out `elem` zready)
         then sendAll' fh msg >> return Nothing
         else return (Just msg)
      
      go waitR waitW wMiss = do
        ready <- atomically $ do
          ok <- readTVar ctrl
          if ok
           then fmap Just ((waitW >> fmap Right (dequeue p wMiss)) `orElse` (fmap Left waitR))
           else return Nothing
        case ready of
          Nothing          -> return ()
          Just (Left _)    -> do
            useSocket p handleRecv
            go waitR waitW wMiss
          Just (Right msg) -> do
            wMiss' <- useSocket p (handleSend msg)
            go waitR waitW wMiss'