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

module Main (main) where

import Data.IORef
import System.ZMQ4
import Leela.Logger
import Leela.Naming
import Control.Monad
import Leela.Helpers
import Leela.HZMQ.Dealer
import Control.Concurrent
import Leela.Data.QDevice
import Leela.Network.Core
import System.Environment
import Leela.Data.Endpoint
import System.Posix.Signals
import System.Console.GetOpt
import Leela.Network.ZMQServer
import Leela.Storage.Backend.ZMQ
import Leela.Storage.Backend.Redis

data Options = Options { optEndpoint     :: Endpoint
                       , optDebugLevel   :: Priority
                       , optConsul       :: String
                       , optRedisSecret  :: String
                       , optBacklog      :: Int
                       , optCapabilities :: Int
                       , optTimeout      :: Int
                       }

defaultOptions :: Options
defaultOptions = Options { optEndpoint     = TCP "*" 4080 ""
                         , optDebugLevel   = NOTICE
                         , optConsul       = "http://127.0.0.1:8500"
                         , optRedisSecret  = ""
                         , optBacklog      = 64
                         , optCapabilities = 8
                         , optTimeout      = 60 * 1000
                         }

setReadOpt :: (Read a) => (a -> Options -> Options) -> String -> Options -> Options
setReadOpt f raw opts = case (reads raw) of
                          [(a, "")] -> f a opts
                          _         -> error $ "error parsing: " ++ raw

options :: [OptDescr (Options -> Options)]
options =
  [ Option ['e'] ["endpoint"]
           (ReqArg (setReadOpt (\v opts -> opts { optEndpoint = v })) "ENDPOINT")
           "endpoint to bind this service to"
  , Option [] ["consul-endpoint"]
           (ReqArg (\v opts -> opts { optConsul = v }) "CONSULENDPOINT")
           "the consul endpoint to find leela services"
  , Option [] ["debug-level"]
           (ReqArg (setReadOpt (\v opts -> opts { optDebugLevel = v })) "DEBUG|INFO|NOTICE|WARNING|ERROR")
           "logging level"
  , Option []    ["redis-secret"]
           (ReqArg (\v opts -> opts { optRedisSecret = v }) "REDISSECRET")
           "redis authentication string"
  , Option [] ["backlog"]
           (ReqArg (setReadOpt (\v opts -> opts { optBacklog = v })) "BACKLOG")
           "storage queue size"
  , Option [] ["capabilities"]
           (ReqArg (setReadOpt (\v opts -> opts { optCapabilities = v })) "CAPABILITIES")
           "number of threads per storage connection"
  , Option [] ["timeout-in-ms"]
           (ReqArg (setReadOpt (\v opts -> opts { optTimeout = v})) "TIMEOUT-IN-MS")
           "timeout in milliseconds"
  ]

readOpts :: [String] -> IO Options
readOpts argv =
  case (getOpt Permute options argv) of
    (opts, _, []) -> return $ foldl (flip id) defaultOptions opts
    (_, _, errs)  -> ioError (userError (concat errs ++ usageInfo "usage: warpdrive [OPTION...]" options))

signal :: MVar () -> IO ()
signal x = tryPutMVar x () >> return ()

main :: IO ()
main = do
  opts   <- getArgs >>= readOpts
  alive  <- newEmptyMVar
  naming <- newIORef []
  core   <- newCore naming
  logsetup (optDebugLevel opts)
  void $ installHandler sigTERM (Catch $ signal alive) Nothing
  void $ installHandler sigINT (Catch $ signal alive) Nothing
  lwarn Global
    (printf "warpdrive: starting; timeout=%d, backlog=%d caps=%d endpoint=%s"
            (optTimeout opts)
            (optBacklog opts)
            (optCapabilities opts)
            (show $ optEndpoint opts))
  forkSupervised_ "resolver" $ resolver (optEndpoint opts) naming (optConsul opts)
  withContext $ \ctx -> do
    withControl $ \ctrl -> do
      let cfg = DealerConf (optTimeout opts)
                           (optBacklog opts)
                           (naming, fmap (maybe [] id . lookup "blackbox") . readIORef)
                           (optCapabilities opts)
      cache   <- redisOpen (naming, fmap (maybe [] id . lookup "redis") . readIORef) (optRedisSecret opts)
      storage <- fmap zmqbackend $ create cfg ctx ctrl
      void $ forkFinally (startServer core (optEndpoint opts) ctx ctrl cache storage) $ \e -> do
        lwarn Global (printf "warpdrive has died: %s" (show e))
        signal alive
      takeMVar alive
  lwarn Global "warpdrive: bye!"
