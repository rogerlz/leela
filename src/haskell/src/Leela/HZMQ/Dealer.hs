-- This file is part of Leela.
--
-- Leela is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- Leela is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with Leela.  If not, see <http://www.gnu.org/licenses/>.

module Leela.HZMQ.Dealer
       ( Cfg (..)
       , Pool
       , defaultCfg
       , create
       , request
       ) where

import           Data.Int
import           Data.Maybe
import           System.ZMQ3
import           Leela.Logger
import           Control.Monad
import           Leela.Helpers
import           Leela.Data.Time
import qualified Data.ByteString as B
import           Control.Exception
import           Data.List.NonEmpty
import           Leela.Data.QDevice
import           Leela.Data.Excepts
import           Leela.HZMQ.ZHelpers
import           Control.Concurrent.STM

data Cfg = Cfg { timeout      :: Int64
               , queueSize    :: Int
               , capabilities :: Int
               }

defaultCfg :: Cfg
defaultCfg = Cfg (5 * 1000) 32 8

data Job = Job { jtime :: Time
               , jmsg  :: [B.ByteString]
               , slot  :: TMVar (Maybe [B.ByteString])
               }

data Pool = Pool { readTimeout :: Int64
                 , queue       :: Device Job
                 }

enqueue :: Pool -> [B.ByteString] -> IO (TMVar (Maybe [B.ByteString]))
enqueue pool a = do
  time <- now
  mvar <- newEmptyTMVarIO
  devwriteIO (queue pool) (Job time a mvar)
  return mvar

dequeue :: Pool -> IO Job
dequeue pool = fmap fromJust $ devreadIO (queue pool)

request :: Pool -> [B.ByteString] -> IO (Maybe [B.ByteString])
request pool a = enqueue pool a >>= atomically . takeTMVar

notify :: TMVar (Maybe [B.ByteString]) -> Maybe [B.ByteString] -> IO ()
notify mvar mmsg = atomically (putTMVar mvar mmsg)

logresult :: Job -> Maybe SomeException -> IO ()
logresult job me = do
  elapsed <- fmap (`diff` (jtime job)) now
  linfo HZMQ $ printf "%s (%.4fms)" (failOrSucc me) (1000 * toDouble elapsed)
    where
      failOrSucc :: Maybe SomeException -> String
      failOrSucc Nothing  = "DEALER.ok"
      failOrSucc (Just e) = printf "DEALER.fail[%s]" (show e)

worker :: Pool -> Context -> String -> IO ()
worker pool ctx endpoint = do
  withSocket ctx Req $ \fh -> setup fh >> workLoop fh
    where
      setup fh = do
        connect fh endpoint
        configure fh

      workLoop fh = do
        job  <- dequeue pool
        mres <- try (sendMulti fh (fromList $ jmsg job))
        case mres of
          Left e  -> do
            logresult job (Just e)
            notify (slot job) Nothing
          Right _ -> do
            mresult <- recvTimeout (readTimeout pool) fh
            notify (slot job) mresult
            logresult job (maybe (Just $ SomeException TimeoutExcept) (const Nothing) mresult)
            when (isJust mresult) (workLoop fh)

forkWorker :: Control -> Pool -> Context -> String -> IO ()
forkWorker ctrl pool ctx endpoint = forkOSSupervised (fmap not $ closed ctrl) (worker pool ctx endpoint)

create :: Control -> String -> Cfg -> Context -> [String] -> IO Pool
create ctrl name cfg ctx endpoints = do
  lnotice HZMQ $
    printf "creating zmq.dealer: %s [timeout: %d; qsize: %d; capabilities: %d; endpoint: %s]"
           name
           (timeout cfg * 1000)
           (queueSize cfg)
           (capabilities cfg)
           (show endpoints)
  pool <- fmap (Pool (timeout cfg)) (openIO ctrl (queueSize cfg))
  mapM_ (replicateM_ (capabilities cfg) . forkWorker ctrl pool ctx) endpoints
  return pool
